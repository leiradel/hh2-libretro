if #arg < 2 then
    io.stderr:write('USAGE: lua riff.lua <riff name> <file name>...\n\n')
    os.exit(1)
end

local entries = {}
local size = 4

for i = 2, #arg do
    local file = assert(io.open(arg[i], 'rb'))
    local data = file:read('*a')
    file:close()

    local e = {
        path = arg[i],
        data = data,
        len = #arg[i] + 1,
        size = 2 + #arg[i] + 1 + ((#arg[i] + 1) & 1) + #data + (#data & 1)
    }

    entries[#entries + 1] = e
    size = size + e.size + 8
end

local function writeu8(file, x)
    file:write(string.char(x))
end

local function writeu16(file, x)
    file:write(string.char(x & 0xff,(x >> 8) & 0xff))
end

local function writeu32(file, x)
    file:write(string.char(x & 0xff,(x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff))
end

local file = assert(io.open(arg[1], 'wb'))

file:write('RIFF')
writeu32(file, size)
file:write('HH2 ')

for _, e in pairs(entries) do
    file:write('FILE')
    writeu32(file, e.size)
    writeu16(file, e.len + (e.len & 1))
    file:write(e.path)
    writeu8(file, 0)

    if (e.len & 1) ~= 0 then
        writeu8(file, 0)
    end

    file:write(e.data)

    if (#e.data & 1) ~= 0 then
        writeu8(file, 0)
    end
end

file:close()
