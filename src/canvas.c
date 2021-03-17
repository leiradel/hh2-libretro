#include "canvas.h"
#include "log.h"

#include <stdlib.h>

#define TAG "CNV "

// Image blit is coded for 16 bpp, make sure the build fails if hh2_Color does not have 16 bits
typedef char hh2_staticAssertColorMustHave16Bits[sizeof(hh2_Color) == 2 ? 1 : -1];

struct hh2_Canvas {
    unsigned width;
    unsigned height;
    size_t pitch; // in bytes

    hh2_Color pixels[1];
};

hh2_Canvas hh2_createCanvas(unsigned const width, unsigned const height) {
    HH2_LOG(HH2_LOG_INFO, TAG "creating %u x %u canvas", width, height);

    size_t const pitch = ((width + 3) & ~3) * sizeof(hh2_Color);
    size_t const size = pitch * height;

    HH2_LOG(HH2_LOG_DEBUG, TAG "canvas pitch is %zu bytes, data is %zu bytes", pitch, size);

    hh2_Canvas const canvas = (hh2_Canvas)malloc(sizeof(*canvas) + size - sizeof(canvas->pixels[0]));

    if (canvas == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        return NULL;
    }

    canvas->width = width;
    canvas->height = height;
    canvas->pitch = canvas->pitch;

    HH2_LOG(HH2_LOG_DEBUG, TAG "created canvas %p", canvas);
    return canvas;
}

void hh2_destroyCanvas(hh2_Canvas const canvas) {
    HH2_LOG(HH2_LOG_INFO, TAG "destroying canvas %p", canvas);
    free(canvas);
}

unsigned hh2_canvasWidth(hh2_Canvas const canvas) {
    return canvas->width;
}

unsigned hh2_canvasHeight(hh2_Canvas const canvas) {
    return canvas->height;
}

size_t hh2_canvasPitch(hh2_Canvas const canvas) {
    return canvas->pitch;
}

void hh2_clear(hh2_Canvas const canvas, hh2_Color const color) {
    unsigned const width = canvas->width;
    unsigned const height = canvas->height;
    size_t const pitch = canvas->pitch;
    hh2_Color* pixel = canvas->pixels;

    for (unsigned y = 0; y < height; y++) {
        for (unsigned x = 0; x < width; x++) {
            pixel[x] = color;
        }

        pixel = (hh2_Color*)((uint8_t*)pixel + pitch);
    }
}
