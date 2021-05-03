if #arg ~= 1 then
    io.stderr:write('Usage: lua extmodule.lua <modulename>\n')
    os.exit(1)
end

local source = io.stdin:read('*a')
local start = source:find(string.format('rtl.module("%s"', arg[1]), 1, true)

if not start then
    start = source:find('rtl.module("program"', 1, true)

    if not start then
        io.stderr:write(string.format('Could not find module "%s"\n', arg[1]))
        os.exit(1)
    end
end

local finish = source:find('rtl.module("', start + 1, true)

if not finish then
    finish = source:find('rtl.run()', start + 1, true)
end

print(source:sub(start, finish - 1))
