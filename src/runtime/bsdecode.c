#include "bsdecode.h"

#include <stdint.h>
#include <stdlib.h>

typedef struct {
    uint8_t left;
    uint8_t right;
    char symbol;
}
hh2_BsNode;

static hh2_BsNode const hh2_BsTree[] = {
                      /* ndx | weight | bits               */
    {  1, 116,    0}, /*   0 | 261429 |                    */
    {  2,  67,    0}, /*   1 | 107934 |                    */
    {  3,  66,    0}, /*   2 |  48413 |                    */
    {  4,  63,    0}, /*   3 |  24087 |                    */
    {  5,  62,    0}, /*   4 |  11760 |                    */
    {  6,   9,    0}, /*   5 |   5877 |                    */
    {  7,   8,    0}, /*   6 |   2664 |                    */
    {  0,   0,  '"'}, /*   7 |   1237 | 0000000            */
    {  0,   0,  '3'}, /*   8 |   1427 | 0000001            */
    { 10,  39,    0}, /*   9 |   3213 |                    */
    { 11,  18,    0}, /*  10 |   1518 |                    */
    { 12,  17,    0}, /*  11 |    723 |                    */
    { 13,  16,    0}, /*  12 |    333 |                    */
    { 14,  15,    0}, /*  13 |    164 |                    */
    {  0,   0,  'j'}, /*  14 |     80 | 00000100000        */
    {  0,   0,  'L'}, /*  15 |     84 | 00000100001        */
    {  0,   0,  'E'}, /*  16 |    169 | 0000010001         */
    {  0,   0,  '<'}, /*  17 |    390 | 000001001          */
    { 19,  38,    0}, /*  18 |    795 |                    */
    { 20,  37,    0}, /*  19 |    393 |                    */
    { 21,  36,    0}, /*  20 |    195 |                    */
    { 22,  23,    0}, /*  21 |     95 |                    */
    {  0,   0,  'U'}, /*  22 |     46 | 000001010000       */
    { 24,  25,    0}, /*  23 |     49 |                    */
    {  0,   0,  '&'}, /*  24 |     24 | 0000010100010      */
    { 26,  27,    0}, /*  25 |     25 |                    */
    {  0,   0,  'K'}, /*  26 |     12 | 00000101000110     */
    { 28,  29,    0}, /*  27 |     13 |                    */
    {  0,   0,  '@'}, /*  28 |      5 | 000001010001110    */
    { 30,  31,    0}, /*  29 |      8 |                    */
    {  0,   0,  'Y'}, /*  30 |      3 | 0000010100011110   */
    { 32,  35,    0}, /*  31 |      5 |                    */
    { 33,  34,    0}, /*  32 |      2 |                    */
    {  0,   0,  '!'}, /*  33 |      1 | 000001010001111100 */
    {  0,   0,  '`'}, /*  34 |      1 | 000001010001111101 */
    {  0,   0,  'X'}, /*  35 |      3 | 00000101000111111  */
    {  0,   0,  'D'}, /*  36 |    100 | 00000101001        */
    {  0,   0,  'I'}, /*  37 |    198 | 0000010101         */
    {  0,   0,  '%'}, /*  38 |    402 | 000001011          */
    { 40,  59,    0}, /*  39 |   1695 |                    */
    { 41,  42,    0}, /*  40 |    838 |                    */
    {  0,   0,  '>'}, /*  41 |    418 | 000001100          */
    { 43,  50,    0}, /*  42 |    420 |                    */
    { 44,  45,    0}, /*  43 |    201 |                    */
    {  0,   0,  '|'}, /*  44 |    100 | 00000110100        */
    { 46,  47,    0}, /*  45 |    101 |                    */
    {  0,   0,  'z'}, /*  46 |     49 | 000001101010       */
    { 48,  49,    0}, /*  47 |     52 |                    */
    {  0,   0,  'N'}, /*  48 |     26 | 0000011010110      */
    {  0,   0,  'W'}, /*  49 |     26 | 0000011010111      */
    { 51,  54,    0}, /*  50 |    219 |                    */
    { 52,  53,    0}, /*  51 |    107 |                    */
    {  0,   0,  'H'}, /*  52 |     53 | 000001101100       */
    {  0,   0,  'G'}, /*  53 |     54 | 000001101101       */
    { 55,  56,    0}, /*  54 |    112 |                    */
    {  0,   0,  'V'}, /*  55 |     55 | 000001101110       */
    { 57,  58,    0}, /*  56 |     57 |                    */
    {  0,   0,  'B'}, /*  57 |     27 | 0000011011110      */
    {  0,   0,  '$'}, /*  58 |     30 | 0000011011111      */
    { 60,  61,    0}, /*  59 |    857 |                    */
    {  0,   0,  '{'}, /*  60 |    428 | 000001110          */
    {  0,   0,  '}'}, /*  61 |    429 | 000001111          */
    {  0,   0,  '='}, /*  62 |   5883 | 00001              */
    { 64,  65,    0}, /*  63 |  12327 |                    */
    {  0,   0,  'f'}, /*  64 |   5976 | 00010              */
    {  0,   0,  '0'}, /*  65 |   6351 | 00011              */
    {  0,   0,  ' '}, /*  66 |  24326 | 001                */
    { 68, 101,    0}, /*  67 |  59521 |                    */
    { 69,  72,    0}, /*  68 |  27805 |                    */
    { 70,  71,    0}, /*  69 |  13050 |                    */
    {  0,   0,  '.'}, /*  70 |   6446 | 01000              */
    {  0,   0,  ','}, /*  71 |   6604 | 01001              */
    { 73,  98,    0}, /*  72 |  14755 |                    */
    { 74,  83,    0}, /*  73 |   7194 |                    */
    { 75,  76,    0}, /*  74 |   3461 |                    */
    {  0,   0,  '2'}, /*  75 |   1713 | 0101000            */
    { 77,  78,    0}, /*  76 |   1748 |                    */
    {  0,   0,  'v'}, /*  77 |    870 | 01010010           */
    { 79,  80,    0}, /*  78 |    878 |                    */
    {  0,   0,  '8'}, /*  79 |    438 | 010100110          */
    { 81,  82,    0}, /*  80 |    440 |                    */
    {  0,   0,  '#'}, /*  81 |    220 | 0101001110         */
    {  0,   0,  'S'}, /*  82 |    220 | 0101001111         */
    { 84,  97,    0}, /*  83 |   3733 |                    */
    { 85,  86,    0}, /*  84 |   1844 |                    */
    {  0,   0,  ':'}, /*  85 |    912 | 01010100           */
    { 87,  88,    0}, /*  86 |    932 |                    */
    {  0,   0, '\\'}, /*  87 |    441 | 010101010          */
    { 89,  92,    0}, /*  88 |    491 |                    */
    { 90,  91,    0}, /*  89 |    233 |                    */
    {  0,   0,  'F'}, /*  90 |    114 | 01010101100        */
    {  0,   0,  'P'}, /*  91 |    119 | 01010101101        */
    { 93,  94,    0}, /*  92 |    258 |                    */
    {  0,   0,  '/'}, /*  93 |    127 | 01010101110        */
    { 95,  96,    0}, /*  94 |    131 |                    */
    {  0,   0,  '~'}, /*  95 |     63 | 010101011110       */
    {  0,   0,  'R'}, /*  96 |     68 | 010101011111       */
    {  0,   0,  '6'}, /*  97 |   1889 | 0101011            */
    { 99, 100,    0}, /*  98 |   7561 |                    */
    {  0,   0,  '_'}, /*  99 |   3779 | 010110             */
    {  0,   0, '\''}, /* 100 |   3782 | 010111             */
    {102, 113,    0}, /* 101 |  31716 |                    */
    {103, 110,    0}, /* 102 |  15665 |                    */
    {104, 105,    0}, /* 103 |   7742 |                    */
    {  0,   0,  '1'}, /* 104 |   3839 | 011000             */
    {106, 107,    0}, /* 105 |   3903 |                    */
    {  0,   0,  'b'}, /* 106 |   1939 | 0110010            */
    {108, 109,    0}, /* 107 |   1964 |                    */
    {  0,   0,  'w'}, /* 108 |    945 | 01100110           */
    {  0,   0,  'x'}, /* 109 |   1019 | 01100111           */
    {111, 112,    0}, /* 110 |   7923 |                    */
    {  0,   0,  '5'}, /* 111 |   3961 | 011010             */
    {  0,   0,  'p'}, /* 112 |   3962 | 011011             */
    {114, 115,    0}, /* 113 |  16051 |                    */
    {  0,   0,  'a'}, /* 114 |   7947 | 01110              */
    {  0,   0,  'r'}, /* 115 |   8104 | 01111              */
    {117, 174,    0}, /* 116 | 153495 |                    */
    {118, 145,    0}, /* 117 |  71006 |                    */
    {119, 130,    0}, /* 118 |  34571 |                    */
    {120, 121,    0}, /* 119 |  16836 |                    */
    {  0,   0,  'l'}, /* 120 |   8277 | 10000              */
    {122, 129,    0}, /* 121 |   8559 |                    */
    {123, 126,    0}, /* 122 |   4218 |                    */
    {124, 125,    0}, /* 123 |   2074 |                    */
    {  0,   0,  '9'}, /* 124 |   1022 | 10001000           */
    {  0,   0,  '-'}, /* 125 |   1052 | 10001001           */
    {127, 128,    0}, /* 126 |   2144 |                    */
    {  0,   0,  'k'}, /* 127 |   1065 | 10001010           */
    {  0,   0,  ']'}, /* 128 |   1079 | 10001011           */
    {  0,   0,  'u'}, /* 129 |   4341 | 100011             */
    {131, 144,    0}, /* 130 |  17735 |                    */
    {132, 143,    0}, /* 131 |   8825 |                    */
    {133, 134,    0}, /* 132 |   4358 |                    */
    {  0,   0,  'g'}, /* 133 |   2161 | 1001000            */
    {135, 136,    0}, /* 134 |   2197 |                    */
    {  0,   0,  '['}, /* 135 |   1089 | 10010010           */
    {137, 142,    0}, /* 136 |   1108 |                    */
    {138, 139,    0}, /* 137 |    541 |                    */
    {  0,   0,  '+'}, /* 138 |    265 | 1001001100         */
    {140, 141,    0}, /* 139 |    276 |                    */
    {  0,   0,  'T'}, /* 140 |    135 | 10010011010        */
    {  0,   0,  'C'}, /* 141 |    141 | 10010011011        */
    {  0,   0,  '4'}, /* 142 |    567 | 100100111          */
    {  0,   0,  'h'}, /* 143 |   4467 | 100101             */
    {  0,   0,  's'}, /* 144 |   8910 | 10011              */
    {146, 147,    0}, /* 145 |  36435 |                    */
    {  0,   0,  'e'}, /* 146 |  17922 | 1010               */
    {148, 171,    0}, /* 147 |  18513 |                    */
    {149, 170,    0}, /* 148 |   9065 |                    */
    {150, 151,    0}, /* 149 |   4510 |                    */
    {  0,   0,  'y'}, /* 150 |   2218 | 1011000            */
    {152, 153,    0}, /* 151 |   2292 |                    */
    {  0,   0,  'M'}, /* 152 |   1118 | 10110010           */
    {154, 155,    0}, /* 153 |   1174 |                    */
    {  0,   0,  '7'}, /* 154 |    581 | 101100110          */
    {156, 157,    0}, /* 155 |    593 |                    */
    {  0,   0,  'q'}, /* 156 |    289 | 1011001110         */
    {158, 167,    0}, /* 157 |    304 |                    */
    {159, 160,    0}, /* 158 |    147 |                    */
    {  0,   0,  '*'}, /* 159 |     73 | 101100111100       */
    {161, 166,    0}, /* 160 |     74 |                    */
    {162, 163,    0}, /* 161 |     35 |                    */
    {  0,   0,  'Q'}, /* 162 |     15 | 10110011110100     */
    {164, 165,    0}, /* 163 |     20 |                    */
    {  0,   0,  '^'}, /* 164 |     10 | 101100111101010    */
    {  0,   0,  '?'}, /* 165 |     10 | 101100111101011    */
    {  0,   0,  'O'}, /* 166 |     39 | 1011001111011      */
    {168, 169,    0}, /* 167 |    157 |                    */
    {  0,   0,  ';'}, /* 168 |     77 | 101100111110       */
    {  0,   0,  'A'}, /* 169 |     80 | 101100111111       */
    {  0,   0,  ')'}, /* 170 |   4555 | 101101             */
    {172, 173,    0}, /* 171 |   9448 |                    */
    {  0,   0,  '('}, /* 172 |   4567 | 101110             */
    {  0,   0,  'c'}, /* 173 |   4881 | 101111             */
    {175, 180,    0}, /* 174 |  82489 |                    */
    {176, 177,    0}, /* 175 |  38727 |                    */
    {  0,   0, '\t'}, /* 176 |  19314 | 1100               */
    {178, 179,    0}, /* 177 |  19413 |                    */
    {  0,   0,  'i'}, /* 178 |   9607 | 11010              */
    {  0,   0,  'o'}, /* 179 |   9806 | 11011              */
    {181, 184,    0}, /* 180 |  43762 |                    */
    {182, 183,    0}, /* 181 |  20926 |                    */
    {  0,   0, '\n'}, /* 182 |   9872 | 11100              */
    {  0,   0,  'n'}, /* 183 |  11054 | 11101              */
    {185, 188,    0}, /* 184 |  22836 |                    */
    {186, 187,    0}, /* 185 |  11373 |                    */
    {  0,   0,  'd'}, /* 186 |   5665 | 111100             */
    {  0,   0,  'm'}, /* 187 |   5708 | 111101             */
    {  0,   0,  't'}, /* 188 |  11463 | 11111              */
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

        *decoded++ = hh2_BsTree[node].symbol;
    }

    return result;
}
