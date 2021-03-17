#ifndef HH2_CANVAS_H__
#define HH2_CANVAS_H__

#include <stdint.h>
#include <stddef.h>

#define HH2_COLOR(r, g, b) ((((hh2_Color)(r) << 8 | (hh2_Color)(b) >> 3) & 0xf81fU) | (((hh2_Color)(g) << 3) & 0x07e0U))

typedef uint16_t hh2_Color;
typedef struct hh2_Canvas* hh2_Canvas;

hh2_Canvas hh2_createCanvas(unsigned width, unsigned height);
void hh2_destroyCanvas(hh2_Canvas canvas);

unsigned hh2_canvasWidth(hh2_Canvas canvas);
unsigned hh2_canvasHeight(hh2_Canvas canvas);
size_t hh2_canvasPitch(hh2_Canvas canvas);

void hh2_clear(hh2_Canvas canvas, hh2_Color color);

hh2_Color* hh2_canvasPixel(hh2_Canvas canvas, unsigned x, unsigned y);

#endif // HH2_CANVAS_H__
