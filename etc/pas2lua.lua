-- Requires
local pascal = require 'pascal'
local ddlt = require 'ddlt'

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

-- Parse the units recursively
do
    local function find_unit(name)
        name = ddlt.join(nil, name:lower(), 'pas')

        for i = 1, #search_paths do
            for lower, entry in pairs(search_paths[i]) do
                local dir, name2, extension = ddlt.split(lower)
                local filename = ddlt.join(nil, name2, extension)

                print(i, name, lower, entry, dir, name2, extension, filename)

                if filename == name then
                    return entry
                end
            end
        end

        return nil
    end

    for _, unit in pairs(ast.interface.uses.units) do
        print(find_unit(unit))
    end
end
