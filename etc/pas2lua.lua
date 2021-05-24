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

local ast, err = pas2ast(input_file_path, macros)

if not ast then
    io.stderr:write(err, '\n')
    os.exit(1)
end

for k, v in pairs(ast) do
    print(k, v)
end
