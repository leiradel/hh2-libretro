return function(path, assets)
    local entries = {}
    local size = 4

    for i = 1, #assets do
        local file = assert(io.open(assets[i].path, 'rb'))
        local data = file:read('*a')
        file:close()

        local entryLen = #assets[i].entry

        local e = {
            entry = assets[i].entry,
            path = assets[i].path,
            data = data,
            len = entryLen + 1,
            size = 2 + entryLen + 1 + ((entryLen + 1) & 1) + #data + (#data & 1)
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

    local file = assert(io.open(path, 'wb'))

    file:write('RIFF')
    writeu32(file, size)
    file:write('HH2 ')

    for _, e in pairs(entries) do
        file:write('FILE')
        writeu32(file, e.size)
        writeu16(file, e.len + (e.len & 1))
        file:write(e.entry)
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
end
