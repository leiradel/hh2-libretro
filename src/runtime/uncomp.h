#ifndef HH2_UNCOMP_H__
#define HH2_UNCOMP_H__

#include <stddef.h>

int hh2_uncompress(void const* compressed, size_t size, void** uncompressed, size_t* uncompressed_size);

#endif // HH2_UNCOMP_H__
