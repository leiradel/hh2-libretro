if #arg ~= 1 then
    io.write(string.format('Usage: %s <compressor.lua> <decompressor.c>', arg[0]))
    os.exit(1)
end

local function rle(contents)
    return contents:gsub('\n%s-\n', '\n\n'):gsub('    ', '\t')
end

local dict = {
    [" " ] = "001", -- 24326
    ["\t"] = "1100", -- 19314
    ["e" ] = "1010", -- 17922
    ["t" ] = "11111", -- 11463
    ["n" ] = "11101", -- 11054
    ["\n"] = "11100", -- 9872
    ["o" ] = "11011", -- 9806
    ["i" ] = "11010", -- 9607
    ["s" ] = "10011", -- 8910
    ["l" ] = "10000", -- 8277
    ["r" ] = "01111", -- 8104
    ["a" ] = "01110", -- 7947
    ["," ] = "01001", -- 6604
    ["." ] = "01000", -- 6446
    ["0" ] = "00011", -- 6351
    ["f" ] = "00010", -- 5976
    ["=" ] = "00001", -- 5883
    ["m" ] = "111101", -- 5708
    ["d" ] = "111100", -- 5665
    ["c" ] = "101111", -- 4881
    ["(" ] = "101110", -- 4567
    [")" ] = "101101", -- 4555
    ["h" ] = "100101", -- 4467
    ["u" ] = "100011", -- 4341
    ["p" ] = "011011", -- 3962
    ["5" ] = "011010", -- 3961
    ["1" ] = "011000", -- 3839
    ["'" ] = "010111", -- 3782
    ["_" ] = "010110", -- 3779
    ["y" ] = "1011000", -- 2218
    ["g" ] = "1001000", -- 2161
    ["b" ] = "0110010", -- 1939
    ["6" ] = "0101011", -- 1889
    ["2" ] = "0101000", -- 1713
    ["3" ] = "0000001", -- 1427
    ["\""] = "0000000", -- 1237
    ["M" ] = "10110010", -- 1118
    ["[" ] = "10010010", -- 1089
    ["]" ] = "10001011", -- 1079
    ["k" ] = "10001010", -- 1065
    ["-" ] = "10001001", -- 1052
    ["9" ] = "10001000", -- 1022
    ["x" ] = "01100111", -- 1019
    ["w" ] = "01100110", -- 945
    [":" ] = "01010100", -- 912
    ["v" ] = "01010010", -- 870
    ["7" ] = "101100110", -- 581
    ["4" ] = "100100111", -- 567
    ["\\"] = "010101010", -- 441
    ["8" ] = "010100110", -- 438
    ["}" ] = "000001111", -- 429
    ["{" ] = "000001110", -- 428
    [">" ] = "000001100", -- 418
    ["%" ] = "000001011", -- 402
    ["<" ] = "000001001", -- 390
    ["q" ] = "1011001110", -- 289
    ["+" ] = "1001001100", -- 265
    ["#" ] = "0101001110", -- 220
    ["S" ] = "0101001111", -- 220
    ["I" ] = "0000010101", -- 198
    ["E" ] = "0000010001", -- 169
    ["C" ] = "10010011011", -- 141
    ["T" ] = "10010011010", -- 135
    ["/" ] = "01010101110", -- 127
    ["P" ] = "01010101101", -- 119
    ["F" ] = "01010101100", -- 114
    ["D" ] = "00000101001", -- 100
    ["|" ] = "00000110100", -- 100
    ["L" ] = "00000100001", -- 84
    ["j" ] = "00000100000", -- 80
    ["A" ] = "101100111111", -- 80
    [";" ] = "101100111110", -- 77
    ["*" ] = "101100111100", -- 73
    ["R" ] = "010101011111", -- 68
    ["~" ] = "010101011110", -- 63
    ["V" ] = "000001101110", -- 55
    ["G" ] = "000001101101", -- 54
    ["H" ] = "000001101100", -- 53
    ["z" ] = "000001101010", -- 49
    ["U" ] = "000001010000", -- 46
    ["O" ] = "1011001111011", -- 39
    ["$" ] = "0000011011111", -- 30
    ["B" ] = "0000011011110", -- 27
    ["N" ] = "0000011010110", -- 26
    ["W" ] = "0000011010111", -- 26
    ["&" ] = "0000010100010", -- 24
    ["Q" ] = "10110011110100", -- 15
    ["K" ] = "00000101000110", -- 12
    ["^" ] = "101100111101010", -- 10
    ["?" ] = "101100111101011", -- 10
    ["@" ] = "000001010001110", -- 5
    ["Y" ] = "0000010100011110", -- 3
    ["X" ] = "00000101000111111", -- 3
    ["!" ] = "000001010001111100", -- 1
    ["`" ] = "000001010001111101", -- 1
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
