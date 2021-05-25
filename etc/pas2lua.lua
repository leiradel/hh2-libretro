-- Requires
local pas2ast = require 'pas2ast'

if #arg == 0 then
    print(string.format('Usage: lua %s [-Dmacro...] [-I<include_dir_path>...] <input_file_path>', arg[0]))
    os.exit(1)
end

local macros, search_paths = {}, {}
local input_file_path

for i = 1, #arg do
    if arg[i]:sub(1, 2) == '-D' then
        macros[arg[i]:sub(3, -1):lower()] = true
    elseif arg[i]:sub(1, 2) == '-I' then
        search_paths[#search_paths + 1] = arg[i]:sub(3, -1)
    else
        input_file_path = arg[i]
    end
end

local input_file, err = io.open(input_file_path, 'r')

if not input_file then
    io.stderr:write(string.format('%s:0: Error opening input file: %s', input_file_path, err))
    os.exit(1)
end

local source = input_file:read('*a')
input_file:close()

local source, err = pas2ast.preprocess(input_file_path, source, macros)

if not source then
    io.stderr:write(err, '\n')
    os.exit(1)
end

local tokens, err = pas2ast.tokenize(input_file_path, source)

if not tokens then
    io.stderr:write(err, '\n')
    os.exit(1)
end

local ast, err = pas2ast.parse(input_file_path, tokens)

if not ast then
    io.stderr:write(err, '\n')
    os.exit(1)
end

for k, v in pairs(ast.interface.uses.units) do
    print(k, v)
end
