#ifndef HH2_IMAGE_H__
#define HH2_IMAGE_H__

#include "filesys.h"

#include <stdint.h>

typedef uint32_t hh2_Pixel;
typedef struct hh2_Image* hh2_Image;

hh2_Image hh2_imageRead(hh2_Filesys filesys, char const* path);
hh2_Image hh2_imageSub(hh2_Image parent, unsigned x0, unsigned y0, unsigned width, unsigned height);
void hh2_imageDestroy(hh2_Image image);

unsigned hh2_imageWidth(hh2_Image image);
unsigned hh2_imageHeight(hh2_Image image);
hh2_Pixel hh2_getPixel(hh2_Image, unsigned x, unsigned y);

#endif // HH2_IMAGE_H__
