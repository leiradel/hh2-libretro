#ifndef HH2_PIXELSRC_H__
#define HH2_PIXELSRC_H__

#include "filesys.h"

#include <stdint.h>

#define HH2_R(p) (((p) >> 32) & 255)
#define HH2_G(p) (((p) >> 24) & 255)
#define HH2_B(p) (((p) >>  8) & 255)
#define HH2_A(p) (((p) >>  0) & 255)

typedef uint32_t hh2_Pixel;
typedef struct hh2_PixelSource* hh2_PixelSource;

hh2_PixelSource hh2_pixelSourceRead(hh2_Filesys filesys, char const* path);
hh2_PixelSource hh2_pixelSourceSub(hh2_PixelSource parent, unsigned x0, unsigned y0, unsigned width, unsigned height);
void hh2_pixelSourceDestroy(hh2_PixelSource source);

unsigned hh2_pixelSourceWidth(hh2_PixelSource source);
unsigned hh2_pixelSourceHeight(hh2_PixelSource source);
hh2_Pixel hh2_getPixel(hh2_PixelSource, unsigned x, unsigned y);

#endif // HH2_PIXELSRC_H__
