#include "libretro.h"

#include "filesys.h"
#include "log.h"
#include "state.h"
#include "sound.h"
#include "sprite.h"
#include "version.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define TAG "COR "

// Libretro callbacks
static retro_environment_t environment_cb;
static retro_log_printf_t log_printf_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_video_refresh_t video_refresh_cb;
static retro_audio_sample_batch_t audio_sample_batch_cb;

// hh2 globals
static void* content;
static hh2_Filesys filesys;
static hh2_State state;
static bool first_frame;

// The logger function to hh2_setLogger
static void logger(hh2_LogLevel const level, char const* const format, va_list ap) {
    enum retro_log_level lr_level = RETRO_LOG_ERROR;

    switch (level) {
        case HH2_LOG_DEBUG: lr_level = RETRO_LOG_DEBUG; break;
        case HH2_LOG_INFO:  lr_level = RETRO_LOG_INFO; break;
        case HH2_LOG_WARN:  lr_level = RETRO_LOG_WARN; break;
        default: break;
    }

    char message[4096];
    vsnprintf(message, sizeof(message), format, ap);
    log_printf_cb(lr_level, "%s\n", message);
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
    environment_cb = cb;

    struct retro_log_callback log;

    if (cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log)) {
        log_printf_cb = log.log;
        hh2_setLogger(logger);
    }
}

unsigned retro_api_version() {
    return RETRO_API_VERSION;
}

void retro_init() {
    hh2_logVersions();
}

void retro_set_input_poll(retro_input_poll_t const cb) {
    input_poll_cb = cb;
}

void retro_set_input_state(retro_input_state_t const cb) {
    input_state_cb = cb;
}

void retro_set_video_refresh(retro_video_refresh_t const cb) {
    video_refresh_cb = cb;
}

void retro_set_audio_sample(retro_audio_sample_t const cb) {
    (void)cb;
}

void retro_set_audio_sample_batch(retro_audio_sample_batch_t const cb) {
    audio_sample_batch_cb = cb;
}

bool retro_load_game(struct retro_game_info const* const info) {
    if (info == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "retro_game_info is NULL");
        return false;
    }

    enum retro_pixel_format pixel_format = RETRO_PIXEL_FORMAT_RGB565;

    if (!environment_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &pixel_format)) {
        HH2_LOG(HH2_LOG_ERROR, TAG "front-end does not support RGB565");
        return false;
    }

    content = malloc(info->size);

    if (content == NULL) {
        HH2_LOG(HH2_LOG_ERROR, TAG "out of memory");
        return false;
    }

    memcpy(content, info->data, info->size);
    filesys = hh2_createFilesystem(content, info->size);

    if (filesys == NULL) {
        // Error already logged
        free(content);
        return false;
    }

    if (!hh2_initState(&state, filesys)) {
        // Error already logged
        hh2_destroyFilesystem(filesys);
        free(content);
        return false;
    }

    first_frame = true;
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
    return id == RETRO_MEMORY_SAVE_RAM ? sizeof(state.sram) : 0;
}

void* retro_get_memory_data(unsigned id) {
    return id == RETRO_MEMORY_SAVE_RAM ? &state.sram : NULL;
}

void retro_run() {
    hh2_RGB565 const* const framebuffer = hh2_canvasPixel(state.canvas, 0, 0);

    unsigned const width = hh2_canvasWidth(state.canvas);
    unsigned const height = hh2_canvasHeight(state.canvas);

    if (!first_frame) {
        hh2_unblitSprites(state.canvas);
    }
    else {
        first_frame = false;

        struct retro_system_av_info info;

        info.geometry.base_width = width;
        info.geometry.base_height = height;
        info.geometry.max_width = width;
        info.geometry.max_height = height;
        info.geometry.aspect_ratio = 0.0f;
        info.timing.fps = 60.0;
        info.timing.sample_rate = 44100.0;

        environment_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &info);
    }

    // run game logic

    hh2_blitSprites(state.canvas);
    size_t const pitch = hh2_canvasPitch(state.canvas);

    video_refresh_cb(framebuffer, width, height, pitch);

    size_t frames;
    int16_t const* const samples = hh2_soundMix(&frames);
    audio_sample_batch_cb(samples, frames);
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
    hh2_destroyFilesystem(filesys);
    free(content);
    hh2_destroyState(&state);
}

void retro_deinit() {}
