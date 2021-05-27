-- Requires
local pascal = require 'pascal'
local ddlt = require 'ddlt'
local access = require 'access'

local cache = {}

local function parse(path, macros)
    -- Use absolute path with the cache
    local abs_path = ddlt.realpath(path)

    -- Check the cache, assumes the same macros are always used
    local source = cache[abs_path]

    if source then
        return source
    end

    -- Load the source code from the file system
    local file, err = io.open(path, 'r')

    if not file then
        return nil, string.format('%s:0: Error opening input file: %s', path, err)
    end

    local source = file:read('*a')
    file:close()

    -- Pre-process the source code with the macros
    local new_source, err = pascal.preprocess(path, source, macros)

    if not new_source then
        return nil, err
    end

    -- Tokenized the pre-processed source code
    local tokens, err = pascal.tokenize(path, new_source)

    if not tokens then
        return nil, err
    end

    -- Parse the token stream
    local ast, err = pascal.parse(path, tokens)

    if not ast then
        return nil, err
    end

    -- We have an AST
    return ast
end

local function findUnit(unit_name, search_paths)
    unit_name = ddlt.join(nil, unit_name:lower(), 'pas')

    for i = 1, #search_paths do
        for lower, entry in pairs(search_paths[i]) do
            local dir, name, extension = ddlt.split(lower)
            local filename = ddlt.join(nil, name, extension)

            if filename == unit_name then
                return entry
            end
        end
    end

    return nil
end

local function generate(ast, search_paths, out)
    local scope = nil

    local function fatal(line, format, ...)
        error(string.format('%s:%u: %s', ast.path, line, string.format(format, ...)))
    end

    local function push(ids, declareFmt, accessFmt)
        local new_scope = access.const {
            ids = ids,
            declare = declareFmt,
            access = accessFmt,
            previous = scope
        }

        scope = new_scope
    end

    local function pop()
        scope = scope.previous
    end

    local function pushUnit(unit, id, all)
        local ids = {}

        local function declare(node)
            if node.type == 'type' then
                -- No need to declare types
            elseif node.type == 'variables' then
                for i = 1, #node.variables do
                    declare(node.variables[i])
                end
            elseif node.type == 'var' then
                ids[table.concat(node.ids, ''):lower()] = true
            elseif node.type == 'decl' then
                ids[table.concat(node.heading.id, ''):lower()] = true
            else
                for k, v in pairs(node) do
                    io.stderr:write(string.format('%s\t%s\n', k, v))
                end

                fatal(unit.line, 'Do not know how to declare "%s"', node.type)
            end
        end

        for i = 1, #unit.interface.declarations do
            declare(unit.interface.declarations[i])
        end

        if all then
            for i = 1, #unit.implementation.declarations do
                declare(unit.implementation.declarations[i])
            end
        end

        push(access.const(ids), 'M.%s', 'M.%s')
    end

    local gen

    local genUnit = function(node)
        out('-- Generated code for Pascal unit "%s"\n\n', node.id)
        out('local M = {}\n\n')

        pushUnit(node, 'M', true)

        gen(node.interface)
        gen(node.implementation)
        gen(node.initialization)
    end

    local genInterface = function(node)
        gen(node.uses)

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end
    end

    local genUses = function(node)
        out('local luart = require "luart"\n')

        for i = 1, #node.units do
            local unit = node.units[i]
            local path = findUnit(unit, search_paths)

            if not path then
                --fatal(node.line, 'Cannot find the path to unit "%s"', unit)
            end

            unit = unit:lower()
            out('local %s = require "%s"\n', unit, unit)
        end

        out('\n')
    end

    local genType = function(node)
        for k, v in pairs(node) do
            io.stderr:write(string.format('%s\t%s\n', tostring(k), tostring(v)))
        end

        for i = 1, #node.types do
            gen(node.types[i])
        end
    end

    gen = function(node)
        -- Use a series of ifs to have better stack traces
        if node.type == 'unit' then
            genUnit(node)
        elseif node.type == 'interface' then
            genInterface(node)
        elseif node.type == 'uses' then
            genUses(node)
        elseif node.type == 'type' then
            genType(node)
        else
            io.stderr:write('-------------------------------------------\n')

            for k, v in pairs(node) do
                io.stderr:write(string.format('%s\t%s\n', tostring(k), tostring(v)))
            end

            fatal(node.line, 'Cannot generate code for node type "%s"', node.type)
        end
    end

    out('-- Generated from "%s"\n', ast.path)
    gen(ast)
end

if #arg == 0 then
    print(string.format('Usage: lua %s [-D<macro>...] [-I<include_dir_path>...] <input_file_path>', arg[0]))
    os.exit(1)
end

-- Pasrse command line arguments
local macros, search_paths = {}, {}
local input_path

for i = 1, #arg do
    if arg[i]:sub(1, 2) == '-D' then
        macros[arg[i]:sub(3, -1):lower()] = true
    elseif arg[i]:sub(1, 2) == '-I' then
        search_paths[#search_paths + 1] = arg[i]:sub(3, -1)
    else
        input_path = arg[i]
    end
end

-- Add the path to the input file to the search paths
do
    local dir, _, _ = ddlt.split(input_path)

    if dir then
        search_paths[#search_paths + 1] = dir
    end
end

-- Create sets with the contents of the search paths
for i = 1, #search_paths do
    local search_path = search_paths[i]
    local entries, err = ddlt.scandir(search_path)

    if not entries then
        print(string.format('%s:0: Error listing files in "%s": %s', input_path, search_path, err))
        os.exit(1)
    end

    local set = {}

    for j = 1, #entries do
        local entry = entries[j]
        local info = ddlt.stat(entry)

        if info.file then
            set[entry:lower()] = entry
        end
    end

    search_paths[i] = set
end

-- Parse the main file
local ast, err = parse(input_path, macros)

if not ast then
    print(err)
    os.exit(1)
end

-- Generate code
local out

do
    local props = {
        level = 0,
        at_start = true,

        indent = function(self)
            self.level = self.level + 1
        end,

        unindent = function(self)
            self.level = self.level - 1
        end,

        spaces = function(self)
            return string.rep('    ', self.level)
        end
    }

    local mt = {
        __call = function(self, ...)
            local str = string.format(...)

            if self.at_start then
                io.write(self:spaces())
                self.at_start = false
            end

            str = str:gsub('\n([^\n])', string.format('\n%s%%1', self:spaces()))
            io.write(str)
            self.at_start = str:sub(-1, -1) == '\n'
        end,
    }

    out = debug.setmetatable(props, mt)
end

--[[local ok, err = pcall(generate, ast, out)

if not ok then
    print(err)
    os.exit(1)
end]]

generate(ast, search_paths, out)
