#include "libretro.h"

#include "canvas.h"
#include "filesys.h"
#include "image.h"
#include "log.h"
#include "pixelsrc.h"
#include "sprite.h"
#include "version.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define TAG "COR "

// Do not change these values!
#define HH2C_SRAM_MAX_ENTRIES 8
#define HH2C_SRAM_MAX_KEY_LENGTH 32
#define HH2C_SRAM_MAX_VALUE_LENGTH 64

typedef struct {
    // 777 bytes for the registry
    uint8_t types[HH2C_SRAM_MAX_ENTRIES];
    uint8_t keys[HH2C_SRAM_MAX_ENTRIES][HH2C_SRAM_MAX_KEY_LENGTH];
    uint8_t values[HH2C_SRAM_MAX_ENTRIES][HH2C_SRAM_MAX_VALUE_LENGTH];
    uint8_t count;

    // Pad to next multiple of four
    uint8_t padding[3];

    // Fake SRAM for achievements, all values are guaranteed to be written in little-endian
    uint32_t sram[317];
}
hh2c_Sram;

// Make sure hh2_Sram has 2048 bytes
typedef char hh2c_staticAssertSramMustHave2048Bytes[sizeof(hh2c_Sram) == 2048 ? 1 : -1];

// Libretro callbacks
static retro_environment_t hh2c_environment_cb;
static retro_log_printf_t hh2c_log_printf_cb;
static retro_input_poll_t hh2c_input_poll_cb;
static retro_input_state_t hh2c_input_state_cb;
static retro_video_refresh_t hh2c_video_refresh_cb;
static retro_audio_sample_batch_t hh2c_audio_sample_batch_cb;

// hh2 globals
static void* hh2c_content;
static hh2_Filesys hh2c_filesys;
static hh2_Canvas hh2c_canvas;
static hh2_Image hh2c_image;
static hh2_Sprite hh2c_sprite;
static int hh2c_x, hh2c_y, hh2c_dx, hh2c_dy;
static bool hh2c_unblit;

// The logger function to hh2_setLogger
static void hh2c_logger(hh2_LogLevel const level, char const* const format, va_list ap) {
    enum retro_log_level lr_level = RETRO_LOG_ERROR;

    switch (level) {
        case HH2_LOG_DEBUG: lr_level = RETRO_LOG_DEBUG; break;
        case HH2_LOG_INFO:  lr_level = RETRO_LOG_INFO; break;
        case HH2_LOG_WARN:  lr_level = RETRO_LOG_WARN; break;
        default: break;
    }

    char message[256];
    vsnprintf(message, sizeof(message), format, ap);
    hh2c_log_printf_cb(lr_level, "%s\n", message);
}

// Libretro API implementation
void retro_get_system_info(struct retro_system_info* const info) {
    info->library_name = HH2_PACKAGE;
    info->library_version = HH2_VERSION;
    info->need_fullpath = false;
    info->block_extract = false;
    info->valid_extensions = "hh2";
}

void retro_set_environment(retro_environment_t const cb) {
    hh2c_environment_cb = cb;

    struct retro_log_callback log;

    if (cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log)) {
        hh2c_log_printf_cb = log.log;
        hh2_setLogger(hh2c_logger);
    }
}

unsigned retro_api_version() {
    return RETRO_API_VERSION;
}

void retro_init() {
    hh2_logVersions();
}

void retro_set_input_poll(retro_input_poll_t const cb) {
    hh2c_input_poll_cb = cb;
}

void retro_set_input_state(retro_input_state_t const cb) {
    hh2c_input_state_cb = cb;
}

void retro_set_video_refresh(retro_video_refresh_t const cb) {
    hh2c_video_refresh_cb = cb;
}

void retro_set_audio_sample(retro_audio_sample_t const cb) {
    (void)cb;
}

void retro_set_audio_sample_batch(retro_audio_sample_batch_t const cb) {
    hh2c_audio_sample_batch_cb = cb;
}

bool retro_load_game(struct retro_game_info const* const info) {
    if (info == NULL) {
        hh2_log(HH2_LOG_ERROR, TAG "retro_game_info is NULL");
        return false;
    }

    enum retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_RGB565;

    if (!hh2c_environment_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &pixel_format)) {
        hh2_log(HH2_LOG_ERROR, TAG "front-end does not support RGB565");
        return false;
    }

    hh2c_content = malloc(info->size);

    if (hh2c_content == NULL) {
        hh2_log(HH2_LOG_ERROR, TAG "out of memory");
        return false;
    }

    memcpy(hh2c_content, info->data, info->size);
    hh2c_filesys = hh2_createFilesystem(hh2c_content, info->size);

    if (hh2c_filesys == NULL) {
        // Error already logged
        free(hh2c_content);
        return false;
    }

    hh2_PixelSource const source = hh2_readPixelSource(hh2c_filesys, "test/cryptopunk32.png");

    if (source == NULL) {
        // Error already logged
        hh2_destroyFilesystem(hh2c_filesys);
        free(hh2c_content);
        return false;
    }

    hh2c_image = hh2_createImage(source);

    if (hh2c_image == NULL) {
        // Error already logged
        hh2_destroyPixelSource(source);
        hh2_destroyFilesystem(hh2c_filesys);
        free(hh2c_content);
        return false;
    }

    hh2_destroyPixelSource(source);
    hh2c_sprite = hh2_createSprite();

    if (hh2c_sprite == NULL) {
        // error already logged
        hh2_destroyImage(hh2c_image);
        hh2_destroyFilesystem(hh2c_filesys);
        free(hh2c_content);
        return false;
    }

    hh2_setLayer(hh2c_sprite, 0);
    hh2_setImage(hh2c_sprite, hh2c_image);
    hh2_setVisibility(hh2c_sprite, true);

    hh2c_canvas = hh2_createCanvas(256, 192);
    hh2_clearCanvas(hh2c_canvas, HH2_COLOR_RGB565(0x84, 0xb0, 0x95));

    hh2c_x = hh2c_y = 0;
    hh2c_dx = hh2c_dy = 1;
    hh2c_unblit = false;

    return true;
}

bool retro_load_game_special(unsigned const a, struct retro_game_info const* const b, size_t const c) {
    (void)a;
    (void)b;
    (void)c;
    return false;
}

void retro_reset() {}

void retro_get_system_av_info(struct retro_system_av_info* const info) {
    info->geometry.base_width = 256;
    info->geometry.base_height = 192;
    info->geometry.max_width = 256;
    info->geometry.max_height = 192;
    info->geometry.aspect_ratio = 0.0f;
    info->timing.fps = 60.0;
    info->timing.sample_rate = 44100.0;
}

unsigned retro_get_region() {
    return RETRO_REGION_NTSC;
}

size_t retro_get_memory_size(unsigned id) {
    return 0; //id == RETRO_MEMORY_SAVE_RAM ? sizeof(hh2c_state.sram) : 0;
}

void* retro_get_memory_data(unsigned id) {
    return NULL; //id == RETRO_MEMORY_SAVE_RAM ? &hh2c_state.sram : NULL;
}

void retro_run() {
    if (hh2c_unblit) {
        hh2_unblitSprites(hh2c_canvas);
    }

    hh2c_x += hh2c_dx;

    if (hh2c_x < -24 || hh2c_x > 256) {
        hh2c_dx = -hh2c_dx;
    }

    hh2c_y += hh2c_dy;

    if (hh2c_y < -24 || hh2c_y > 192) {
        hh2c_dy = -hh2c_dy;
    }

    hh2c_input_poll_cb();

    hh2_setPosition(hh2c_sprite, hh2c_x, hh2c_y);

    hh2_blitSprites(hh2c_canvas);
    hh2c_unblit = true;

    hh2_RGB565 const* const framebuffer = hh2_canvasPixel(hh2c_canvas, 0, 0);
    size_t const pitch = hh2_canvasPitch(hh2c_canvas);

    hh2c_video_refresh_cb(framebuffer, 256, 192, pitch);

    int16_t samples[44100 / 60 * 2];
    memset(samples, 0, sizeof(samples));
    hh2c_audio_sample_batch_cb(samples, 44100 / 60);
}

void retro_set_controller_port_device(unsigned const port, unsigned const device) {
    (void)port;
    (void)device;
}

size_t retro_serialize_size() {
    return 0;
}

bool retro_serialize(void* const data, size_t const size) {
    (void)data;
    (void)size;
    return false;
}

bool retro_unserialize(const void* const data, size_t const size ) {
    (void)data;
    (void)size;
    return false;
}

void retro_cheat_reset() {}

void retro_cheat_set(unsigned const a, bool const b, char const* const c) {
    (void)a;
    (void)b;
    (void)c;
}

void retro_unload_game() {
    hh2_destroyCanvas(hh2c_canvas);
}

void retro_deinit() {}
