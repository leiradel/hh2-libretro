if #arg < 2 then
    io.stderr:write('USAGE: lua riff.lua <riff name> <file name>...\n\n')
    os.exit(1)
end

local function mkentry(id, data)
    local function writeu8(file, x)
        file:write(string.char(x))
    end

    local function writeu16(file, x)
        file:write(string.char(x & 0xff,(x >> 8) & 0xff))
    end

    local function writeu32(file, x)
        file:write(string.char(x & 0xff, (x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff))
    end

    local function pad(length)
        return length + (length & 1)
    end

    local function save(self, file)
        file:write(self.id)

        local length = self:length()
        writeu32(file, length - 8)

        if self.id == 'RIFF' then
            file:write('HH2 ')
        end

        if type(self.data) == 'string' then
            file:write(self.data)
        else
            for i = 1, #self.data do
                self.data[i]:save(file)
            end
        end

        if length ~= pad(length) then
            writeu8(file, 0)
        end
    end

    local function length(self)
        local size = self.id == 'RIFF' and 12 or 8

        if type(self.data) == 'string' then
            size = size + #self.data
        else
            for i = 1, #self.data do
                size = size + pad(self.data[i]:length())
            end
        end

        return size
    end

    return {
        id = id,
        data = data,
        save = save,
        length = length
    }
end

local entries = {}

for i = 2, #arg do
    local path = arg[i]
    local file = assert(io.open(path, 'rb'))
    local data = file:read('*a')
    file:close()

    local path = mkentry('path', path .. '\0')
    local data = mkentry('data', data)
    local list = mkentry('LIST', {path, data})

    entries[#entries + 1] = list
end

local riff = mkentry('RIFF', entries)
local file = assert(io.open(arg[1], 'wb'))

riff:save(file)
file:close()
