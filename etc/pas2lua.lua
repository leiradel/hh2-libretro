-- Requires
local pascal = require 'pascal'
local ddlt = require 'ddlt'
local access = require 'access'

local function dump(tab, level)
    local spaces = string.rep('    ', level or 0)

    if not level then
        print('=======================================================')
    end

    for k, v in pairs(tab) do
        print(string.format('%s\t%s', tostring(k), tostring(v)))

        if level and type(v) == 'table' then
            dump(v, level + 1)
        end
    end

    if not level then
        print('-------------------------------------------------------')
    end
end

local cache = {}

local function parse(path, macros)
    assert(type(path) == 'string')
    assert(type(macros) == 'table')

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

local function findUnit(unit, searchPaths)
    assert(type(unit) == 'string')
    assert(type(searchPaths) == 'table')

    unit = ddlt.join(nil, unit:lower(), 'pas')

    for i = 1, #searchPaths do
        for lower, entry in pairs(searchPaths[i]) do
            local dir, name, extension = ddlt.split(lower)
            local filename = ddlt.join(nil, name, extension)

            if filename == unit then
                return entry
            end
        end
    end

    return nil
end

local function generate(ast, searchPaths, macros, out)
    assert(type(ast) == 'userdata')
    assert(type(searchPaths) == 'table')
    assert(type(macros) == 'table')
    assert(type(out) == 'table')

    local defaultTypes = {
        real48 = 0,
        real = 0,
        single = 0,
        double = 0,
        extended = 0,
        currency = 0,
        comp = 0,
        shortint = 0,
        smallint = 0,
        integer = 0,
        byte = 0,
        longint = 0,
        int64 = 0,
        word = 0,
        boolean = false,
        char = '#0',
        widechar = '#0',
        longword = 0,
        pchar = nil
    }

    local scope = false

    local function fatal(line, format, ...)
        error(string.format('%s:%u: %s', ast.path, line, string.format(format, ...)))
    end

    local function push(ids, declareFmt, accessFmt)
        assert(type(ids) == 'table')
        assert(declareFmt == nil or type(declareFmt) == 'string')
        assert(type(accessFmt) == 'string')

        local new_scope = access.const {
            ids = ids,
            declare = declareFmt,
            access = accessFmt,
            previous = scope
        }

        scope = new_scope
    end

    local function findScope(id)
        assert(type(id) == 'string')

        id = id:lower()
        local current = scope

        while current do
            if current.ids[id] then
                return current
            end

            current = current.previous
        end
    end

    local function accessId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope and scope.access then
            return string.format(scope.access, id:lower())
        end
    end

    local function declareId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope and scope.declare then
            return string.format(scope.declare, id:lower())
        end
    end

    local function findId(id)
        assert(type(id) == 'string')

        local scope = findScope(id)

        if scope  then
            return scope.ids[id:lower()]
        end
    end

    local function getDeclarations(declarations)
        local ids = {}

        for i = 1, #declarations do
            local node = declarations[i]

            if node.type == 'types' then
                for i = 1, #node.types do
                    local type = node.types[i]
                    ids[type.id:lower()] = type
                end
            elseif node.type == 'constants' then
                for i = 1, #node.constants do
                    local const = node.constants[i]
                    ids[const.id:lower()] = const
                end
            elseif node.type == 'variables' then
                for i = 1, #node.variables do
                    local var = node.variables[i]

                    for j = 1, #var.ids do
                        ids[var.ids[j]:lower()] = var
                    end
                end
            elseif node.type == 'decl' then
                ids[table.concat(node.heading.id, ''):lower()] = node
            elseif node.type == 'prochead' then
                ids[table.concat(node.id.id, ''):lower()] = node
            elseif node.type == 'funchead' then
                ids[table.concat(node.id.id, ''):lower()] = node
            elseif node.type == 'consthead' then
                ids[table.concat(node.id.id, ''):lower()] = node
            elseif node.type == 'field' then
                for i = 1, #node.ids do
                    ids[node.ids[i]:lower()] = node
                end
            else
                dump(node)
                fatal(node.line, 'Do not know how to declare "%s"', node.type)
            end
        end

        return ids
    end

    local function findQid(qid)
        local node = findId(qid[1])

        for i = 2, #qid do
            if node.type == 'class' or node.type == 'type' then
                local ids = getDeclarations(node.subtype.declarations)
                node = ids[qid[i]:lower()]
            else
                dump(qid)
                dump(node)
                error(string.format('Don\'t know how to find ids in node "%s"', node.type))
            end

            if not node then
                return nil
            end
        end

        return node
    end

    local function pop()
        scope = scope.previous
    end

    local function pushDeclarations(declarations, declareFmt, accessFmt)
        assert(type(declarations) == 'userdata')
        assert(declareFmt == nil or type(declareFmt) == 'string')
        assert(type(accessFmt) == 'string')

        local ids = getDeclarations(declarations)
        push(ids, declareFmt, accessFmt)
    end

    local gen

    local function genUnit(node)
        out('-- Generated code for Pascal unit "%s"\n\n', node.id)
        out('-- Our exported module\n')
        out('local M = {}\n\n')
        out('-- Load the runtime and the implied system unit\n')
        out('local hh2rt = require "hh2rt"\n')
        out('local system = require "system"\n\n')

        do
            local path = findUnit('system', searchPaths)

            if not path then
                fatal(node.line, 'Cannot find the path to unit "system"')
            end

            local ast, err = parse(path, macros)

            if not ast then
                fatal(node.line, err)
            end

            pushDeclarations(ast.interface.declarations, nil, 'system.%s')
        end

        pushDeclarations(node.interface.declarations, 'M.%s', 'M.%s')
        gen(node.interface)

        pushDeclarations(node.implementation.declarations, 'local %s', '%s')
        gen(node.implementation)

        gen(node.initialization)

        out('-- Return the module\n')
        out('return M\n')
    end

    local function genInterface(node)
        out('-- Interface section\n\n')

        if node.uses then
            gen(node.uses)
        end

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end
    end

    local function genUses(node)
        if #node.units ~= 0 then
            out('-- Require other units\n')
        end

        for i = 1, #node.units do
            local unit = node.units[i]
            local path = findUnit(unit, searchPaths)

            if not path then
                fatal(node.line, 'Cannot find the path to unit "%s"', unit)
            end

            unit = unit:lower()
            out('local %s = require "%s"\n', unit, unit)

            local ast, err = parse(path, macros)

            if not ast then
                fatal(node.line, err)
            end

            pushDeclarations(ast.interface.declarations, nil, unit .. '.%s')
        end

        if #node.units ~= 0 then
            out('\n')
        end
    end

    local function genTypes(node)
        out('-- Types\n')

        for i = 1, #node.types do
            gen(node.types[i])
        end

        if #node.types ~= 0 then
            out('\n')
        end
    end

    local function genType(node)
        out('M.%s = ', node.id:lower())
        gen(node.subtype)
    end

    local function genClass(node)
        if node.super then
            out('hh2rt.newClass(%s, {\n', accessId(node.super))
        else
            out('hh2rt.newClass(nil, {\n')
        end

        out:indent()

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end

        out:unindent()
        out('})\n\n')
    end

    local function genField(node)
        for i = 1, #node.ids do
            if node.subtype.type == 'typeid' then
                out('%s = nil, -- %s\n', node.ids[i]:lower(), node.subtype.id)
            elseif node.subtype.type == 'ordident' then
                out('%s = %s, -- %s\n', node.ids[i]:lower(), tostring(defaultTypes[node.subtype.subtype]), node.subtype.subtype)
            elseif node.subtype.type == 'stringtype' then
                out('%s = "", -- string\n', node.ids[i]:lower())
            else
                dump(node)
                dump(node.subtype)
                error('don\'t know how to generate this field')
            end
        end
    end

    local function genProcHead(node)
        if node.id then
            out('-- Procedure %s(', table.concat(node.id.id, '.'))
        else
            out('-- Procedure(')
        end

        if node.parameters then
            local semicolon = ''

            for i = 1, #node.parameters do
                local param = node.parameters[i]
                local comma = ''

                out(semicolon)
                semicolon = '; '

                for j = 1, #param.ids do
                    out('%s%s', comma, param.ids[j])
                    comma = ', '
                end

                out(': %s', param.subtype.type == 'typeid' and param.subtype.id or param.subtype.subtype)
            end
        end

        out(')\n')
    end

    local function genVariables(node)
        out('-- Variables\n')

        for i = 1, #node.variables do
            gen(node.variables[i])
        end

        out('\n')
    end

    local function genVar(node)
        if node.subtype.type == 'ordident' or node.subtype.type == 'realtype' then
            for i = 1, #node.ids do
                out('%s = %s\n', declareId(node.ids[i]), tostring(defaultTypes[node.subtype.subtype]))
            end
        elseif node.subtype.type == 'arraytype' then
            for i = 1, #node.ids do
                out('%s = hh2rt.newArray(', declareId(node.ids[i]))

                local limits = node.subtype.limits

                for i = 1, #limits do
                    gen(limits[i])
                    out(', ')
                end

                local subtype = node.subtype.subtype

                if subtype.type == 'typeid' then
                    out('nil) -- %s\n', subtype.id)
                elseif subtype.type == 'ordident' then
                    out('%s) -- %s\n', tostring(defaultTypes[subtype.subtype]), subtype.subtype)
                elseif subtype.type == 'stringtype' then
                    out('"") -- string\n')
                else
                    dump(node)
                    dump(node.subtype)
                    error('don\'t know how to generate this variable')
                end
            end
        else
            for i = 1, #node.ids do
                out('%s = nil -- %s\n', declareId(node.ids[i]), node.subtype.id)
            end
        end
    end

    local function genImplementation(node)
        out('-- Implementation section\n\n')

        if node.uses then
            gen(node.uses)
        end

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end
    end

    local function genDecl(node)
        if #node.heading.id.id == 1 then
            -- local function
            dump(node)
            error('implement me')
        else
            -- class method
            out('%s.%s = function(self', accessId(node.heading.id.id[1]), node.heading.id.id[2]:lower())

            local class = findId(node.heading.id.id[1])

            while true do
                pushDeclarations(class.subtype.declarations, nil, 'self.%s')

                if not class.subtype.super then
                    break
                end

                class = findId(class.subtype.super)
            end
        end

        local ids = {}

        if node.heading.parameters then
            for i = 1, #node.heading.parameters do
                local param = node.heading.parameters[i]

                for j = 1, #param.ids do
                    local id = param.ids[j]:lower()
                    ids[id] = param.subtype
                    out(', %s', id)
                end
            end
        end

        push(ids, '%s', '%s')

        out(')\n')
        out:indent()
        gen(node.block)
        out:unindent()
        out('end\n\n')
    end

    local function genBlock(node)
        pushDeclarations(node.declarations, 'local %s', '%s')

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end

        gen(node.statement)
    end

    local function genCompoundStmt(node)
        out('-- Statements\n')

        for i = 1, #node.statements do
            gen(node.statements[i])
            out('\n')
        end
    end

    local function genAssignment(node)
        gen(node.designator)
        out(' = ')
        gen(node.value)
    end

    local function genVariable(node)
        gen(node.qid)
    end

    local function genProcCall(node)
        gen(node.designator)

        if node.designator.type ~= 'call' then
            out('()')
        end
    end

    local function genFor(node)
        out('\n')
        out('for ')
        gen(node.variable)
        out(' = ')
        gen(node.first)
        out(', ')
        gen(node.last)

        if node.direction == 'down' then
            out(', -1')
        end

        out(' do\n')
        out:indent()
        gen(node.body)
        out:unindent()
        out('\nend\n')
    end

    local function genQualId(node)
        local type = findQid(node.id)

        if type.type == 'consthead' then
            out('hh2rt.newInstance(%s, %q)', accessId(node.id[1]), table.concat(type.id.id, ''):lower())
        else
            out('%s', accessId(node.id[1]))

            for i = 2, #node.id do
                out('.%s', node.id[i]:lower())
            end
        end
    end

    local function genLiteral(node)
        if node.subtype == '<decimal>' then
            out('%s', tostring(node.value))
        elseif node.subtype == '<string>' then
            local value = node.value
            value = value:gsub('^\'', '')
            value = value:gsub('\'$', '')
            value = value:gsub('\'\'', '\'')

            value = value:gsub('\'#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('#(%d+)\'', function(x) return string.char(tonumber(x)) end)
            value = value:gsub('\'#(%d+)', function(x) return string.char(tonumber(x)) end)

            out('%q', value)
        elseif node.subtype == 'boolean' then
            out('%s', tostring(node.value))
        elseif node.subtype == 'nil' then
            out('nil')
        else
            dump(node)
            error('Do not know how to generate literal "%s"', node.type)
        end
    end

    local function genCall(node)
        gen(node.designator)
        out('(')

        local comma = ''

        for i = 1, #node.arguments do
            out('%s', comma)
            comma = ', '
            gen(node.arguments[i])
        end

        out(')')
    end

    local function genAccField(node)
        gen(node.designator)
        out('.%s', node.id:lower())
    end

    local function genAccIndex(node)
        gen(node.designator)
        out('[')
        gen(node.indices[1])

        for i = 2, #node.indices do
            out('][')
            gen(node.indices[i])
        end

        out(']')
    end

    local function genSubtract(node)
        out('(')
        gen(node.left)
        out(' - ')
        gen(node.right)
        out(')')
    end

    local function genUnaryMinus(node)
        out('(-')
        gen(node.operand)
        out(')')
    end

    local function genIf(node)
        out('\n')
        out('if ')
        gen(node.condition)
        out(' then\n')

        out:indent()
        gen(node.ontrue)
        out:unindent()

        if node.onfalse then
            out('else\n')
            out:indent()
            gen(node.onfalse)
            out:unindent()
        end

        out('\nend\n')
    end

    local function genAnd(node)
        out('(')
        gen(node.left)
        out(' and ')
        gen(node.right)
        out(')')
    end

    local function genNotEqual(node)
        out('(')
        gen(node.left)
        out(' ~= ')
        gen(node.right)
        out(')')
    end

    local function genNot(node)
        out('(not ')
        gen(node.operand)
        out(')')
    end

    local function genEnumerated(node)
        out('hh2rt.newEnumeration({%q', node.elements[1].id:lower())

        for i = 2, #node.elements do
            out(', %q', node.elements[i].id:lower())
        end

        out('})\n\n')
    end

    local function genSet(node)
        if findId(node.subtype) then
            out('hh2rt.newSet(%s)\n\n', accessId(node.subtype))
        else
            out('hh2rt.newSet() -- %s\n\n', node.subtype)
        end
    end

    local function genProcType(node)
        out('nil ')
        gen(node.subtype)
        out('\n')
    end

    local function genConstHead(node)
        if node.id then
            out('-- Constructor %s(', table.concat(node.id.id, '.'))
        else
            out('-- Constructor(')
        end

        if node.parameters then
            local semicolon = ''

            for i = 1, #node.parameters do
                local param = node.parameters[i]
                local comma = ''

                out(semicolon)
                semicolon = '; '

                for j = 1, #param.ids do
                    out('%s%s', comma, param.ids[j])
                    comma = ', '
                end

                out(': %s', param.subtype.type == 'typeid' and param.subtype.id or param.subtype.subtype)
            end
        end

        out(')\n')
    end

    local function genAsm(node)
        out('%s', node.code:sub(4, -4))
    end

    local function genInherited(node)
        out('hh2rt.callInherited(self, %q)', table.concat(node.designator.qid.id):lower())
    end

    local function genInitialization(node)
        out('-- Initialization section\n')

        for i = 1, #node.statements do
            gen(node.statements[i])
            out('\n')
        end

        out('\n')
    end

    local function genRecType(node)
        out('hh2rt.newRecord({\n')
        out:indent()

        for i = 1, #node.declarations do
            gen(node.declarations[i])
        end

        out:unindent()
        out('})\n')
    end

    local function genConstants(node)
        out('-- Constants\n')

        for i = 1, #node.constants do
            out('%s = ', accessId(node.constants[i].id))
            gen(node.constants[i].value)
            out('\n')
        end

        out('\n')
    end

    local function genAdd(node)
        local l, r = node.left, node.right
        local op = '+'

        -- TODO: this is too little to actually determine that we must do a string concatenation
        if (l.type == 'literal' and l.subtype == '<string>') or (r.type == 'literal' and r.subtype == '<string>') then
            op = '..'
        end

        out('(')
        gen(l)
        out(' %s ', op)
        gen(r)
        out(')')
    end

    local function genArrayConst(node)
        local function value(v)
            if #v ~= 0 then
                out('{')
                value(v[1])

                for i = 2, #v do
                    out(', ')
                    value(v[i])
                end

                out('}')
            elseif v.type == 'arrayconst' then
                out('\n')
                out:indent()
                gen(v)
                out:unindent()
            else
                gen(v)
            end
        end

        value(node.value)
    end

    local function genTypeId(node)
        out('%s', accessId(node.id))
    end

    local function genSubRange(node)
        out('{')
        gen(node.min)
        out(', ')
        gen(node.max)
        out('}')
    end

    gen = function(node)
        -- Use a series of ifs to have better stack traces
        if node.type == 'unit' then
            genUnit(node)
        elseif node.type == 'interface' then
            genInterface(node)
        elseif node.type == 'uses' then
            genUses(node)
        elseif node.type == 'types' then
            genTypes(node)
        elseif node.type == 'type' then
            genType(node)
        elseif node.type == 'class' then
            genClass(node)
        elseif node.type == 'field' then
            genField(node)
        elseif node.type == 'prochead' then
            genProcHead(node)
        elseif node.type == 'variables' then
            genVariables(node)
        elseif node.type == 'var' then
            genVar(node)
        elseif node.type == 'implementation' then
            genImplementation(node)
        elseif node.type == 'decl' then
            genDecl(node)
        elseif node.type == 'block' then
            genBlock(node)
        elseif node.type == 'compoundstmt' then
            genCompoundStmt(node)
        elseif node.type == 'assignment' then
            genAssignment(node)
        elseif node.type == 'variable' then
            genVariable(node)
        elseif node.type == 'proccall' then
            genProcCall(node)
        elseif node.type == 'for' then
            genFor(node)
        elseif node.type == 'qualid' then
            genQualId(node)
        elseif node.type == 'literal' then
            genLiteral(node)
        elseif node.type == 'call' then
            genCall(node)
        elseif node.type == 'accfield' then
            genAccField(node)
        elseif node.type == 'accindex' then
            genAccIndex(node)
        elseif node.type == '-' then
            genSubtract(node)
        elseif node.type == 'unm' then
            genUnaryMinus(node)
        elseif node.type == 'if' then
            genIf(node)
        elseif node.type == 'and' then
            genAnd(node)
        elseif node.type == '<>' then
            genNotEqual(node)
        elseif node.type == 'not' then
            genNot(node)
        elseif node.type == 'enumerated' then
            genEnumerated(node)
        elseif node.type == 'set' then
            genSet(node)
        elseif node.type == 'proctype' then
            genProcType(node)
        elseif node.type == 'consthead' then
            genConstHead(node)
        elseif node.type == 'asm' then
            genAsm(node)
        elseif node.type == 'inherited' then
            genInherited(node)
        elseif node.type == 'initialization' then
            genInitialization(node)
        elseif node.type == 'rectype' then
            genRecType(node)
        elseif node.type == 'constants' then
            genConstants(node)
        elseif node.type == '+' then
            genAdd(node)
        elseif node.type == 'arrayconst' then
            genArrayConst(node)
        elseif node.type == 'typeid' then
            genTypeId(node)
        elseif node.type == 'subrange' then
            genSubRange(node)
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
local macros, searchPaths = {}, {}
local input_path

for i = 1, #arg do
    if arg[i]:sub(1, 2) == '-D' then
        macros[arg[i]:sub(3, -1):lower()] = true
    elseif arg[i]:sub(1, 2) == '-I' then
        searchPaths[#searchPaths + 1] = arg[i]:sub(3, -1)
    else
        input_path = arg[i]
    end
end

-- Add the path to the input file to the search paths
do
    local dir, _, _ = ddlt.split(input_path)

    if dir then
        searchPaths[#searchPaths + 1] = dir
    end
end

-- Create sets with the contents of the search paths
for i = 1, #searchPaths do
    local search_path = searchPaths[i]
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

    searchPaths[i] = set
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

generate(ast, searchPaths, macros, out)
