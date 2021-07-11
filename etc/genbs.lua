local function code(paths)
    local function rle(contents)
        contents = contents:gsub('\n%s-\n', '\n\n')

        for i = 16, 1, -1 do
            local spaces = string.rep(' ', i * 4)
            contents = contents:gsub(spaces, string.char(0xf0 | (i - 1)))
        end

        return contents
    end

    local counts = {}

    for i = 1, #paths do
        local file = assert(io.open(paths[i], 'rb'))
        local contents = rle(file:read('*a'))
        file:close()

        for j = 1, #contents do
            local char = contents:sub(j, j)
            counts[char] = (counts[char] or 0) + 1
        end
    end

    local queue1, queue2 = {}, {}
    local i1, i2 = 1, 1
    local c1, c2 = 0, 0

    for char, count in pairs(counts) do
        c1 = c1 + 1
        queue1[c1] = {symbol = char, weight = count}
    end

    table.sort(queue1, function(a, b) return a.weight < b.weight end)

    while ((c1 - i1) + 1 + (c2 - i2) + 1) > 1 do
        local e1, e2

        if i1 > c1 then
            e1 = queue2[i2]
            i2 = i2 + 1
        elseif i2 > c2 then
            e1 = queue1[i1]
            i1 = i1 + 1
        elseif queue1[i1].weight < queue2[i2].weight then
            e1 = queue1[i1]
            i1 = i1 + 1
        else
            e1 = queue2[i2]
            i2 = i2 + 1
        end

        if i1 > c1 then
            e2 = queue2[i2]
            i2 = i2 + 1
        elseif i2 > c2 then
            e2 = queue1[i1]
            i1 = i1 + 1
        elseif queue1[i1].weight < queue2[i2].weight then
            e2 = queue1[i1]
            i1 = i1 + 1
        else
            e2 = queue2[i2]
            i2 = i2 + 1
        end

        c2 = c2 + 1
        queue2[c2] = {left = e1, right = e2, weight = e1.weight + e2.weight}
    end

    return queue2[c2]
end

local function dictionary(root)
    local dict = {}

    local function traverse(node, bits)
        if node.symbol then
            -- leaf
            dict[#dict + 1] = {symbol = node.symbol, weight = node.weight, bits = bits}
        else
            -- internal
            traverse(node.left, bits .. '0')
            traverse(node.right, bits .. '1')
        end
    end

    traverse(root, '')
    table.sort(dict, function(a, b)
        if a.weight > b.weight then
            return true
        elseif a.weight < b.weight then
            return false
        elseif #a.bits < #b.bits then
            return true
        elseif #a.bits > #b.bits then
            return false
        else
            return tonumber(a.bits, 2) < tonumber(b.bits, 2)
        end
    end)

    return dict
end

local function genCompressor(dict, out)
    out:write[[
if #arg ~= 1 then
    io.write(string.format('Usage: %s <compressor.lua> <decompressor.c>', arg[0]))
    os.exit(1)
end

local function rle(contents)
    contents = contents:gsub('\n%s-\n', '\n\n')

    for i = 16, 1, -1 do
        local spaces = string.rep(' ', i * 4)
        contents = contents:gsub(spaces, string.char(0xf0 | (i - 1)))
    end

    return contents
end

local dict = {
]]

    for i = 1, #dict do
        local node = dict[i]
        local symbol = string.byte(node.symbol, 1, 1)

        if symbol < 0x20 or symbol >= 0x80 then
            symbol = string.format('"\\x%02x"', symbol)
        elseif node.symbol == '"' then
            symbol = '"\\""  '
        elseif node.symbol == '\\' then
            symbol = '"\\\\"  '
        else
            symbol = string.format('"%s"   ', node.symbol)
        end

        out:write(string.format('    [%s] = "%s", -- %d\n', symbol, node.bits, node.weight))
    end

out:write[[
}

local file = assert(io.open(arg[1], 'rb'))
local contents = rle(file:read('*a'))
file:close()

local b1 = #contents & 0xff
local b2 = (#contents >> 8) & 0xff
local b3 = (#contents >> 16) & 0xff
local b4 = (#contents >> 24) & 0xff

contents = contents:gsub('.', function(symbol)
    return dict[symbol] or error(string.format('symbol %q not in dictionary', symbol))
end)

if #contents % 8 ~= 0 then
    contents = contents .. string.rep('0', 8 - (#contents % 8))
end

contents = contents:gsub('%d%d%d%d%d%d%d%d', function(bits) return string.char(tonumber(bits, 2)) end)

io.write(string.char(b1, b2, b3, b4), contents)
]]
end

local function genDecompressor(root, outc, outh)
    outh:write[[
#ifndef HH2_BSDECODE_H__
#define HH2_BSDECODE_H__

#include <stddef.h>

char const* hh2_bsDecode(void const* const data, size_t* const size);

#endif /* HH2_BSDECODE_H__ */
]]

    outc:write[[
#include "bsdecode.h"

#include <stdint.h>
#include <stdlib.h>

typedef struct {
    uint8_t left;
    uint8_t right;
    uint8_t symbol;
}
hh2_BsNode;

static hh2_BsNode const hh2_BsTree[] = {
                      /* ndx | weight | bits               */
]]

    local array = {}

    local function traverse(node, bits)
        if node.symbol then
            -- leaf
            array[#array + 1] = {symbol = node.symbol, weight = node.weight, bits = bits}
        else
            -- internal
            local int = {weight = node.weight}
            array[#array + 1] = int

            int.left = #array + 1
            traverse(node.left, bits .. '0')

            int.right = #array + 1
            traverse(node.right, bits .. '1')
        end
    end

    traverse(root, '')

    for i = 1, #array do
        local node = array[i]

        local symbol = node.symbol and string.byte(node.symbol, 1, 1) or 0

        if symbol == 0 then
            symbol = '   0'
        elseif symbol == 10 then
            symbol = '\'\\n\''
        elseif symbol < 0x20 or symbol >= 0x80 then
            symbol = string.format('0x%02x', symbol)
        elseif node.symbol == '\'' then
            symbol = '\'\\\'\''
        elseif node.symbol == '\\' then
            symbol = '\'\\\\\''
        else
            symbol = string.format(' \'%s\'', node.symbol)
        end

        local code = string.format(
            '    {%3d, %3d, %s},',
            node.left and (node.left - 1) or 0,
            node.right and (node.right - 1) or 0,
            symbol
        )

        outc:write(string.format('%s /* %3d | %6d | %-18s */\n', code, i - 1, node.weight, node.bits or ''))
    end

    outc:write[[
};

char const* hh2_bsDecode(void const* const data, size_t* const size) {
    uint8_t const* bits = (uint8_t const*)data;
    size_t const count = bits[0] | bits[1] << 8 | bits[2] << 16 | bits[3] << 24;
    *size = count;
    bits += 4;

    char* decoded = (char*)malloc(*size);

    if (decoded == NULL) {
        return NULL;
    }

    char const* const result = decoded;
    char const* const end = decoded + count;
    uint8_t bit = 0x80;

    while (decoded < end) {
        uint16_t node = 0;

        while (hh2_BsTree[node].symbol == 0) {
            node = (*bits & bit) == 0 ? hh2_BsTree[node].left : hh2_BsTree[node].right;

            if ((bit >>= 1) == 0) {
                bits++;
                bit = 0x80;
            }
        }

        switch (hh2_BsTree[node].symbol) {
            case 0xf0: case 0xf1: case 0xf2: case 0xf3: case 0xf4: case 0xf5: case 0xf6: case 0xf7:
            case 0xf8: case 0xf9: case 0xfa: case 0xfb: case 0xfc: case 0xfd: case 0xfe: case 0xff:
                for (int i = (hh2_BsTree[node].symbol & 0x0f) * 4; i >= 0 && decoded < end; i--) {
                    *decoded++ = ' ';
                }

                break;

            default:
                *decoded++ = hh2_BsTree[node].symbol;
        }
    }

    return result;
}
]]
end

local root = code(arg)
local dict = dictionary(root)

local encoder = assert(io.open('bsencode.lua', 'w'))
genCompressor(dict, encoder)
encoder:close()

local decoderh = assert(io.open('bsdecode.h', 'w'))
local decoderc = assert(io.open('bsdecode.c', 'w'))
genDecompressor(root, decoderc, decoderh)
decoderh:close()
decoderc:close()
