#include "uncomp.h"

#include <zlib.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

int hh2_uncompress(void const* compressed, size_t size, void** uncompressed, size_t* uncompressed_size) {
    // Mostly copied from zlib's uncompr.c
    if (size < 4) {
        return Z_DATA_ERROR;
    }

    uint8_t const* const data = (uint8_t const*)compressed;
    *uncompressed_size = data[0] | data[1] << 8 | data[2] << 16 | data[3] << 24;

    *uncompressed = (char*)malloc(*uncompressed_size);

    if (*uncompressed == NULL) {
        return Z_MEM_ERROR;
    }

    z_stream stream;
    memset(&stream, 0, sizeof(stream));

    stream.next_in = (Bytef z_const*)(data + 4);
    stream.avail_in = size - 4;
    stream.next_out = *uncompressed;
    stream.avail_out = *uncompressed_size;

    int const zerr1 = inflateInit2(&stream, 16 + MAX_WBITS);

    if (zerr1 != Z_OK) {
        return zerr1;
    }

    int const zerr2 = inflate(&stream, Z_NO_FLUSH);
    inflateEnd(&stream);

    if (zerr2 == Z_STREAM_END) {
        return Z_OK;
    }
    else if (zerr2 == Z_NEED_DICT) {
        return Z_DATA_ERROR;
    }
    else {
        return zerr2;
    }
}
