#include "image.h"
#include "log.h"

#include <png.h>

#include <stdlib.h>

#define TAG "IMG "

// PNG read is coded for 32 bpp, make sure the build fails if hh2_Pixel does not have 32 bits
typedef char hh2_staticAssertPixelMustHave32Bits[sizeof(hh2_Pixel) == 4 ? 1 : -1];

struct hh2_Image {
    unsigned width;
    unsigned height;
    unsigned pitch;
    hh2_Image parent;
    hh2_Pixel* abgr;
    hh2_Pixel data[1];
};

static void hh2_pngError(png_structp const png, png_const_charp const error) {
    (void)png;
    hh2_log(HH2_LOG_ERROR, TAG "error reading PNG: %s", error);
}

static void hh2_pngWarn(png_structp const png, png_const_charp const error) {
    (void)png;
    hh2_log(HH2_LOG_WARN, TAG "warning reading PNG: %s", error);
}

static void hh2_pngRead(png_structp const png, png_bytep const buffer, size_t const count) {
    hh2_File const file = png_get_io_ptr(png);
    hh2_fileRead(file, buffer, count);
}

hh2_Image hh2_imageRead(hh2_Filesys const filesys, char const* const path) {
    hh2_log(HH2_LOG_INFO, TAG "reading image \"%s\" from filesys %p", path, filesys);

    hh2_File const file = hh2_fileOpen(filesys, path);

    if (file == NULL) {
        // Error already logged
        return NULL;
    }

    hh2_Image image = NULL;

    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, hh2_pngError, hh2_pngWarn);

    if (png == NULL) {
error1:
        hh2_fileClose(file);
        return NULL;
    }

    png_infop info = png_create_info_struct(png);

    if (info == NULL) {
        png_destroy_read_struct(&png, NULL, NULL);
        goto error1;
    }

    if (setjmp(png_jmpbuf(png))) {
        if (image != NULL) {
            free(image);
        }

error2:
        png_destroy_read_struct(&png, &info, NULL);
        goto error1;
    }

    png_set_read_fn(png, file, hh2_pngRead);
    png_read_info(png, info);

    png_uint_32 const width = png_get_image_width(png, info);
    png_uint_32 const height = png_get_image_height(png, info);
    size_t const num_pixels = width * height;

    image = malloc(sizeof(*image) + sizeof(image->data[0]) * (num_pixels - 1));

    if (image == NULL) {
        hh2_log(HH2_LOG_ERROR, TAG "out of memory");
        goto error2;
    }

    image->width = width;
    image->height = height;
    image->pitch = width;
    image->parent = NULL;
    image->abgr = image->data;

    // Make sure we always get RGBA pixels
    png_byte const bit_depth = png_get_bit_depth(png, info);
    png_byte const color_type = png_get_color_type(png, info);

    if (bit_depth == 16) {
        png_set_strip_16(png);
    }

    if (color_type == PNG_COLOR_TYPE_PALETTE) {
        png_set_palette_to_rgb(png);
    }

    if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8) {
        png_set_expand_gray_1_2_4_to_8(png);
    }

    // Transform transparent color to alpha
    if (png_get_valid(png, info, PNG_INFO_tRNS)) {
        png_set_tRNS_to_alpha(png);
    }

    // Set alpha to opaque if non-existent
    if (color_type == PNG_COLOR_TYPE_RGB || color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_PALETTE) {
        png_set_filler(png, 0xff, PNG_FILLER_AFTER);
    }

    // Convert gray to RGB
    if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
        png_set_gray_to_rgb(png);
    }

    png_read_update_info(png, info);

    // Turn on interlaced image support to read the PNG line by line
    int const num_passes = png_set_interlace_handling(png);

    for (int i = 0; i < num_passes; i++) {
        for (unsigned y = 0; y < height; y++) {
            png_read_row(png, (uint8_t*)(image->abgr + y * width), NULL);
        }
    }
    
    png_destroy_read_struct(&png, &info, NULL);
    hh2_log(HH2_LOG_DEBUG, TAG "created image %p with dimensions (%u, %u)", image, width, height);
    return image;
}

hh2_Image hh2_imageSub(hh2_Image const parent, unsigned const x0, unsigned const y0, unsigned const width, unsigned const height) {
    hh2_log(
        HH2_LOG_INFO,
        TAG "creating sub image from image %p at (%u, %u) with dimensions (%u, %u)",
        parent, x0, y0, width, height
    );

    if ((x0 + width) > parent->width) {
        return NULL;
    }

    if ((y0 + height) > parent->height) {
        return NULL;
    }

    if (width == 0 || height == 0) {
        return NULL;
    }

    hh2_Image const image = malloc(sizeof(*image));

    if (image == NULL) {
        hh2_log(HH2_LOG_ERROR, TAG "out of memory");
        return NULL;
    }

    image->width = width;
    image->height = height;
    image->pitch = parent->pitch;
    image->abgr = parent->abgr + y0 * parent->pitch + x0;
    image->parent = parent;

    hh2_log(HH2_LOG_DEBUG, TAG "create sub image %p", image);
    return image;
}

void hh2_imageDestroy(hh2_Image const image) {
    free(image);
}

unsigned hh2_imageWidth(hh2_Image const image) {
    return image->width;
}

unsigned hh2_imageHeight(hh2_Image const image) {
    return image->height;
}

hh2_Pixel hh2_getPixel(hh2_Image const image, unsigned const x, unsigned const y) {
    if (x < image->width && y < image->height) {
        return image->abgr[y * image->pitch + x];
    }

    return 0;
}
