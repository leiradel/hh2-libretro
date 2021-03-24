#ifndef HH2_BSREADER_H__
#define HH2_BSREADER_H__

#include <stddef.h>

typedef struct hh2_BsStream* hh2_BsStream;

hh2_BsStream hh2_createBsDecoder(void const* data);
void hh2_destroyBsDecoder(hh2_BsStream stream);

char const* hh2_decode(hh2_BsStream stream, size_t* size);

#endif // HH2_BSREADER_H__
