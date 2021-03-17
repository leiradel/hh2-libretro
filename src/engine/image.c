#include "image.h"
#include "log.h"

#include <stdlib.h>
#include <string.h>

#define TAG "IMG "

enum {
    HH2_RLE_SKIP = 0,
    HH2_RLE_BLIT = 1,
    HH2_RLE_COMPOSE = 2
};

typedef union {
    struct {
        uint16_t length: 14;
        uint16_t code: 2;
    }
    skip;

    struct {
        uint16_t length: 14;
        uint16_t code: 2;
    }
    blit;

    struct {
        uint16_t inv_alpha: 6;
        uint16_t length: 8;
        uint16_t code: 2;
    }
    compose;

    struct {
        uint16_t dummy: 14;
        uint16_t code: 2;
    }
    common;

    hh2_Color color;
}
hh2_Rle;

struct hh2_Image {
    unsigned width;
    unsigned height;
    size_t pixels_used;

    hh2_Rle const* rows[1];
};

static size_t hh2_rleRowDryRun(size_t* const pixels_used, hh2_PixelSource const source, int const y) {
    unsigned const width = hh2_pixelSourceWidth(source);

    size_t words = 0;
    *pixels_used = 0;

    for (unsigned x = 0; x < width;) {
        hh2_Pixel const pixel = hh2_getPixel(source, x, y);
        uint8_t const alpha = HH2_ALPHA(pixel);
        unsigned const remaining = width - x;

        if (alpha == 0) {
            // 0bnnnnnnnn 0bnnnnnn00 Skip n + 1 pixels (alpha 0)
            unsigned const length = remaining <= 16384 ? remaining : 16384;
            words++;
            x += length;
        }
        else if (alpha == 255) {
            // 0xnnnnnnnn 0bnnnnnn01 Blit n + 1 pixels (alpha 255)
            unsigned const length = remaining <= 16384 ? remaining : 16384;
            words += 1 + length;
            *pixels_used += length;
            x += length;
        }
        else {
            // 0baaaaaann 0bnnnnnn10 Blit n + 1 pixels with alpha aaaaaa in the [0,32] range (inclusive)
            unsigned const length = remaining <= 256 ? remaining : 256;
            words += 1 + length;
            *pixels_used += length;
            x += length;
        }
    }

    return words;
}

static size_t hh2_rleRow(hh2_Rle* rle, hh2_PixelSource const source, int const y) {
    unsigned const width = hh2_pixelSourceWidth(source);

    size_t words = 0;

    for (unsigned x = 0; x < width;) {
        hh2_Pixel const pixel = hh2_getPixel(source, x, y);
        uint8_t const alpha = HH2_ALPHA(pixel);
        unsigned const remaining = width - x;

        if (alpha == 0) {
            rle->skip.length = (remaining <= 16384 ? remaining : 16384) - 1;
            rle->skip.code = HH2_RLE_SKIP;
            rle++, words++;
            x += rle->skip.length;
        }
        else if (alpha == 255) {
            rle->blit.length = (remaining <= 16384 ? remaining : 16384) - 1;
            rle->blit.code = HH2_RLE_BLIT;
            rle++;

            for (unsigned i = 0; i < rle->blit.length; i++) {
                hh2_Pixel const pixel = hh2_getPixel(source, x + i, y);

                uint8_t const r = HH2_RED(pixel);
                uint8_t const g = HH2_GREEN(pixel);
                uint8_t const b = HH2_BLUE(pixel);

                rle->color = HH2_COLOR(r, g, b);
                rle++;
            }

            words += 1 + rle->blit.length;
            x += rle->blit.length;
        }
        else {
            rle->compose.inv_alpha = 32 - (((uint16_t)alpha + 4) >> 3);
            rle->compose.length = (remaining <= 256 ? remaining : 256) - 1;
            rle->compose.code = HH2_RLE_COMPOSE;

            for (unsigned i = 0; i < rle->compose.length; i++) {
                hh2_Pixel const pixel = hh2_getPixel(source, x + i, y);

                uint8_t const r = HH2_ALPHA(pixel) * alpha / 255;
                uint8_t const g = HH2_ALPHA(pixel) * alpha / 255;
                uint8_t const b = HH2_ALPHA(pixel) * alpha / 255;

                rle->color = HH2_COLOR(r, g, b);
                rle++;
            }

            words += 1 + rle->compose.length;
            x += rle->compose.length;
        }
    }

    return words;
}

static hh2_Color hh2_compose(hh2_Color const src, hh2_Color const dst, uint8_t const inv_alpha) {
    uint32_t const src32 = (src & 0xf81fU) | (uint32_t)(src & 0x07e0U) << 16;
    uint32_t const dst32 = (dst & 0xf81fU) | (uint32_t)(dst & 0x07e0U) << 16;
    uint32_t const composed = (src32 + dst32 * inv_alpha) / 32;
    return (composed & 0xf81fU) | ((composed >> 16) & 0x07e0U);
}

hh2_Image hh2_createImage(hh2_PixelSource const source) {
    HH2_LOG(HH2_LOG_INFO, TAG "creating image from pixel source %p", source);

    size_t total_words = 0;
    size_t total_pixels_used = 0;

    unsigned const height = hh2_pixelSourceHeight(source);

    for (unsigned y = 0; y < height; y++) {
        size_t pixels_used;
        size_t const words = hh2_rleRowDryRun(&pixels_used, source, y);

        HH2_LOG(HH2_LOG_DEBUG, TAG "row %u needs %zu bytes for RLE data, and changes %zu pixels when blit", words * 2, pixels_used);

        total_words += words;
        total_pixels_used += pixels_used;
    }

    HH2_LOG(
        HH2_LOG_DEBUG, TAG "image needs %zu bytes for RLE data, and changes %zu pixels when blit",
        total_words * 2, total_pixels_used
    );

    hh2_Image const image = (hh2_Image)malloc(sizeof(*image) + sizeof(image->rows[0]) * (height - 1) + total_words * 2);

    if (image == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        return NULL;
    }

    image->width = hh2_pixelSourceWidth(source);
    image->height = height;
    image->pixels_used = total_pixels_used;

    hh2_Rle* rle = (hh2_Rle*)((uint8_t*)image + sizeof(*image) + sizeof(image->rows[0]) * (height - 1));

    for (unsigned y = 0; y < height; y++) {
        image->rows[y] = rle;
        size_t const words = hh2_rleRow(rle, source, y);
        rle += words;
    }

    return image;
}

void hh2_destroyImage(hh2_Image const image) {
    HH2_LOG(HH2_LOG_INFO, TAG "destroying image %p", image);
    free(image);
}

unsigned hh2_imageWidth(hh2_Image const image) {
    return image->width;
}

unsigned hh2_imageHeight(hh2_Image const image) {
    return image->height;
}

size_t hh2_changedPixels(hh2_Image const image) {
    return image->pixels_used;
}

static bool hh2_clip(
    hh2_Image const image, hh2_Canvas const canvas, int* const x0, int* const y0, unsigned* const width, unsigned* const height) {

    unsigned const image_width = hh2_imageWidth(image);
    unsigned const image_height = hh2_imageHeight(image);

    unsigned const canvas_width = hh2_canvasWidth(canvas);
    unsigned const canvas_height = hh2_canvasHeight(canvas);

    if (*x0 < -image_width || *x0 >= canvas_width || *y0 < -image_height || *y0 >= canvas_height) {
        return false; // no visible pixels
    }

    *width = image_width;
    *height = image_height;

    if (*x0 < 0) {
        *width += *x0;
        *x0 = 0;
    }

    if (*x0 + *width > canvas_width) {
        *width -= canvas_width - *x0;
    }

    if (*y0 < 0) {
        *height += *y0;
        *y0 = 0;
    }

    if (*y0 + *height > canvas_height) {
        *height -= canvas_height - *y0;
    }

    return true;
}

hh2_Color* hh2_blit(hh2_Image const image, hh2_Canvas const canvas, int const x0, int const y0, hh2_Color* bg) {
    int new_x0 = x0, new_y0 = y0;
    unsigned width, height;
    
    // Clip the image to the canvas
    if (!hh2_clip(image, canvas, &new_x0, &new_y0, &width, &height)) {
        return bg;
    }

    // Evaluate the pixel on the canvas to blit to
    hh2_Color* pixel = hh2_canvasPixel(canvas, new_x0, new_y0);

    for (unsigned y = 0; y < height; y++) {
        hh2_Rle const* rle = image->rows[new_y0 - y0 + y];

        uint16_t op = rle->common.code;
        uint16_t length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
        rle++;

        for (unsigned to_skip = new_x0 - x0;;) {
            uint16_t const count = length <= to_skip ? length : to_skip;

            if (op != HH2_RLE_SKIP) {
                rle += count;
            }

            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            to_skip -= count;

            if (to_skip == 0) {
                break;
            }
        }

        for (unsigned remaining = width;;) {
            uint16_t const count = length <= remaining ? length : remaining;

            if (op == HH2_RLE_BLIT) {
                size_t const bytes = count * sizeof(*pixel);

                memcpy(bg, pixel, bytes);
                bg += count;

                memcpy(pixel, rle, bytes);
                rle += count;
            }
            else if (op == HH2_RLE_COMPOSE) {
                memcpy(bg, pixel, count * sizeof(*pixel));
                bg += count;

                for (unsigned i = 0; i < count; i++) {
                    pixel[i] = hh2_compose(rle->color, pixel[i], rle->compose.inv_alpha);
                    rle++;
                }
            }

            pixel += count;
            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            remaining -= count;

            if (remaining == 0) {
                break;
            }
        }
    }

    return bg;
}

void hh2_unblit(hh2_Image const image, hh2_Canvas const canvas, int const x0, int const y0, hh2_Color const* bg) {
    int new_x0 = x0, new_y0 = y0;
    unsigned width, height;
    
    // Clip the image to the canvas
    if (!hh2_clip(image, canvas, &new_x0, &new_y0, &width, &height)) {
        return;
    }

    // Evaluate the pixel on the canvas to blit to
    hh2_Color* pixel = hh2_canvasPixel(canvas, x0, y0);

    for (unsigned y = 0; y < height; y++) {
        hh2_Rle const* rle = image->rows[new_y0 - y0 + y];

        uint16_t op = rle->common.code;
        uint16_t length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
        rle++;

        for (unsigned to_skip = new_x0 - x0;;) {
            uint16_t const count = length <= to_skip ? length : to_skip;

            if (op != HH2_RLE_SKIP) {
                rle += count;
            }

            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            to_skip -= count;

            if (to_skip == 0) {
                break;
            }
        }

        for (unsigned remaining = width;;) {
            uint16_t const count = length <= remaining ? length : remaining;

            if (op == HH2_RLE_BLIT || op == HH2_RLE_COMPOSE) {
                memcpy(pixel, bg, count * sizeof(*pixel));
                bg += count;
            }

            pixel += count;
            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            remaining -= count;

            if (remaining == 0) {
                break;
            }
        }
    }
}

void hh2_stamp(hh2_Image const image, hh2_Canvas const canvas, int const x0, int const y0) {
    int new_x0 = x0, new_y0 = y0;
    unsigned width, height;
    
    // Clip the image to the canvas
    if (!hh2_clip(image, canvas, &new_x0, &new_y0, &width, &height)) {
        return;
    }

    // Evaluate the pixel on the canvas to blit to
    hh2_Color* pixel = hh2_canvasPixel(canvas, new_x0, new_y0);

    for (unsigned y = 0; y < height; y++) {
        hh2_Rle const* rle = image->rows[new_y0 - y0 + y];

        uint16_t op = rle->common.code;
        uint16_t length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
        rle++;

        for (unsigned to_skip = new_x0 - x0;;) {
            uint16_t const count = length <= to_skip ? length : to_skip;

            if (op != HH2_RLE_SKIP) {
                rle += count;
            }

            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            to_skip -= count;

            if (to_skip == 0) {
                break;
            }
        }

        for (unsigned remaining = width;;) {
            uint16_t const count = length <= remaining ? length : remaining;

            if (op == HH2_RLE_BLIT) {
                memcpy(pixel, rle, count * sizeof(*pixel));
                rle += count;
            }
            else if (op == HH2_RLE_COMPOSE) {
                for (unsigned i = 0; i < count; i++) {
                    pixel[i] = hh2_compose(rle->color, pixel[i], rle->compose.inv_alpha);
                    rle++;
                }
            }

            pixel += count;
            length -= count;

            if (length == 0) {
                op = rle->common.code;
                length = op == HH2_RLE_SKIP ? rle->skip.length : op == HH2_RLE_BLIT ? rle->blit.length : rle->compose.length;
                rle++;
            }

            remaining -= count;

            if (remaining == 0) {
                break;
            }
        }
    }
}
