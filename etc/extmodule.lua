if #arg ~= 1 then
    io.stderr:write('Usage: lua extmodule.lua <modulename>')
    os.exit(1)
end

local source = io.stdin:read('*a')
local start = source:find(string.format('rtl.module("%s"', arg[1]), 1, true)
local finish = source:find('rtl.module("', start + 1, true)

if not finish then
    finish = source:find('rtl.run()', start + 1, true)
end

print(source:sub(start, finish - 1))
