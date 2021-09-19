#include "module.h"
#include "filesys.h"
#include "log.h"
#include "searcher.h"
#include "uncomp.h"
#include "state.h"
#include "version.h"
#include "pixelsrc.h"
#include "canvas.h"
#include "image.h"
#include "sprite.h"
#include "sound.h"

#include "boxybold.png.h"

#include <lauxlib.h>
#include <zlib.h>
#include <aes.h>

#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
#include <string.h>
#include <errno.h>

#define HH2_PIXELSOURCE_MT "hh2_PixelSource"
#define HH2_IMAGE_MT "hh2_Image"
#define HH2_SPRITE_MT "hh2_Sprite"
#define HH2_PCM_MT "hh2_Pcm"

static int hh2_logLua(lua_State* const L) {
    char const* const level = luaL_checkstring(L, 1);
    char const* const message = luaL_checkstring(L, 2);

    if (level[0] == 0 || level[1] != 0) {
        return luaL_error(L, "invalid log level: %s", level);
    }

    switch (level[0]) {
        case 'd': HH2_LOG(HH2_LOG_DEBUG, "LUA %s", message); break;
        case 'i': HH2_LOG(HH2_LOG_INFO, "LUA %s", message); break;
        case 'w': HH2_LOG(HH2_LOG_WARN, "LUA %s", message); break;
        case 'e': HH2_LOG(HH2_LOG_ERROR, "LUA %s", message); break;
    }

    return 0;
}

static int hh2_nowLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    lua_pushinteger(L, state->now_us);

    time_t const timep = time(NULL);
    
    if (timep == (time_t)-1) {
        return luaL_error(L, "error getting the current time: %s", strerror(errno));
    }

    struct tm* const tm = localtime(&timep);

    if (tm == NULL) {
        return luaL_error(L, "error getting the local time: %s", strerror(errno));
    }

    lua_pushinteger(L, tm->tm_hour * 3600 + tm->tm_min * 60 + tm->tm_sec);
    return 2;
}

static int hh2_decodeTimeUsLua(lua_State* const L) {
    lua_Integer now = luaL_checkinteger(L, 1);

    lua_Integer const msecs = 0;
    lua_Integer const seconds = now % 60;
    now /= 60;

    lua_Integer const minutes = now % 60;
    now /= 60;

    lua_Integer const hours = now % 24;

    lua_pushinteger(L, hours);
    lua_pushinteger(L, minutes);
    lua_pushinteger(L, seconds);
    lua_pushinteger(L, msecs);
    return 4;
}

static int hh2_contentLoaderLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    char const* const path = luaL_checkstring(L, 1);
    long const size = hh2_fileSize(state->filesys, path);

    if (size < 0) {
        return luaL_error(L, "file not found: \"%s\"", path);
    }

    hh2_File const file = hh2_openFile(state->filesys, path);

    if (file == NULL) {
        return luaL_error(L, "error opening file: \"%s\"", path);
    }

    void* const buffer = malloc(size);

    if (buffer == NULL) {
        hh2_close(file);
        return luaL_error(L, "out of memory");
    }

    if (hh2_read(file, buffer, size) != size) {
        free(buffer);
        hh2_close(file);
        return luaL_error(L, "error reading from file: \"%s\"", path);
    }

    hh2_close(file);
    lua_pushlstring(L, buffer, size);
    free(buffer);
    return 1;
}

static int hh2_decryptLua(lua_State* const L) {
    static uint8_t const key[] = "ljLvET5KkIYM0ghV4Bvd3MTmJ0QnNpbN";
    static uint8_t const iv[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};

    size_t length = 0;
    char const* const encoded = luaL_checklstring(L, 1, &length);

    char* const decoded = (char*)malloc(length);

    if (decoded == NULL) {
        return luaL_error(L, "error decoding bs stream");
    }

    uint32_t key_schedule[60];
    aes_key_setup(key, key_schedule, 256);
    aes_decrypt_ctr((uint8_t const*)encoded, length, (uint8_t*)decoded, key_schedule, 256, iv);

    lua_pushlstring(L, decoded, length);
    free((void*)decoded);
    return 1;
}

static int hh2_uncompressLua(lua_State* const L) {
    size_t compressed_length = 0;
    char const* const compressed = luaL_checklstring(L, 1, &compressed_length);

    void* uncompressed = NULL;
    size_t uncomp_length = 0;
    int const zres = hh2_uncompress(compressed, compressed_length, &uncompressed, &uncomp_length);

    if (zres != Z_OK) {
        switch (zres) {
            case Z_ERRNO: return luaL_error(L, "Z_ERRNO: %s", strerror(errno));
            case Z_STREAM_ERROR: return luaL_error(L, "Z_STREAM_ERROR");
            case Z_DATA_ERROR: return luaL_error(L, "Z_DATA_ERROR");
            case Z_MEM_ERROR: return luaL_error(L, "Z_MEM_ERROR");
            case Z_BUF_ERROR: return luaL_error(L, "Z_BUF_ERROR");
            case Z_VERSION_ERROR: return luaL_error(L, "Z_VERSION_ERROR");
            default: return luaL_error(L, "unknown zlib error");
        }
    }

    lua_pushlstring(L, uncompressed, uncomp_length);
    return 1;
}

static int hh2_pokeLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    lua_Integer const address = luaL_checkinteger(L, 1);

    if (address < 0 || address >= sizeof(state->sram.sram) / sizeof(state->sram.sram[0])) {
        return luaL_error(L, "address out of bounds: %I", address);
    }

    uint32_t const value = luaL_checkinteger(L, 2);

    union {
        uint16_t u16;
        uint8_t u8[2];
    }
    endian;

    endian.u16 = 1;

    if (endian.u8[0]) {
        state->sram.sram[address] = value;
    }
    else {
        state->sram.sram[address] = ((value >> 24) & 0x000000ff)
                                  | ((value >>  8) & 0x0000ff00)
                                  | ((value <<  8) & 0x00ff0000)
                                  | ((value << 24) & 0xff000000);
    }

    return 0;
}

static int hh2_getInputLua(lua_State* const L) {
    static char const* const button_names[] = {
        "up", "down", "left", "right", "a",  "b",  "x",     "y",
        "l1", "r1",   "l2",   "r2",    "l3", "r3", "start", "select"
    };

    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));

    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_pushvalue( L, 1 );
    }
    else {
        lua_createtable(L, 0, 37);
    }

    for (unsigned port = 0; port < 2; port++) {
        for (size_t i = 0; i < sizeof(state->button_state[0]) / sizeof(state->button_state[0][0] ); i++) {
            char name[32];
            snprintf(name, sizeof(name), "%s%s", button_names[i], port == 0 ? "" : "/2");

            lua_pushboolean(L, state->button_state[port][i]);
            lua_setfield(L, -2, name);
        }
    }

    if (state->is_zoomed) {
        lua_pushinteger(L, state->zoom_x0 + (state->mouse_x + 32767) * state->zoom_width / 65534);
        lua_setfield(L, -2, "mouseX");

        lua_pushinteger(L, state->zoom_y0 + (state->mouse_y + 32767) * state->zoom_height / 65534);
        lua_setfield(L, -2, "mouseY");
    }
    else {
        lua_pushinteger(L, (state->mouse_x + 32767) * hh2_canvasWidth(state->canvas) / 65534);
        lua_setfield(L, -2, "mouseX");
        
        lua_pushinteger(L, (state->mouse_y + 32767) * hh2_canvasHeight(state->canvas) / 65534);
        lua_setfield(L, -2, "mouseY");
    }

    lua_pushboolean(L, state->mouse_pressed);
    lua_setfield(L, -2, "mousePressed");

    return 1;
}

static int hh2_pushPixelSourceLua(lua_State* const L, hh2_PixelSource const pixelsrc);

static int hh2_subPixelSourceLua(lua_State* const L) {
    hh2_PixelSource const pixelsrc = *(hh2_PixelSource*)luaL_checkudata(L, 1, HH2_PIXELSOURCE_MT);
    lua_Integer const x0 = luaL_checkinteger(L, 2);
    lua_Integer const y0 = luaL_checkinteger(L, 3);
    lua_Integer const width = luaL_checkinteger(L, 4);
    lua_Integer const height = luaL_checkinteger(L, 5);

    hh2_PixelSource const sub = hh2_subPixelSource(pixelsrc, x0, y0, width, height);

    if (sub == NULL) {
        return luaL_error(L, "error creating sub pixel source");
    }

    return hh2_pushPixelSourceLua(L, sub);
}

static int hh2_pixelSourceWidthLua(lua_State* const L) {
    hh2_PixelSource const pixelsrc = *(hh2_PixelSource*)luaL_checkudata(L, 1, HH2_PIXELSOURCE_MT);
    lua_pushinteger(L, hh2_pixelSourceWidth(pixelsrc));
    return 1;
}

static int hh2_pixelSourceHeightLua(lua_State* const L) {
    hh2_PixelSource const pixelsrc = *(hh2_PixelSource*)luaL_checkudata(L, 1, HH2_PIXELSOURCE_MT);
    lua_pushinteger(L, hh2_pixelSourceHeight(pixelsrc));
    return 1;
}

static int hh2_gcPixelSourceLua(lua_State* const L) {
    hh2_PixelSource const pixelsrc = *(hh2_PixelSource*)lua_touserdata(L, 1);
    hh2_destroyPixelSource(pixelsrc);
    return 0;
}

static int hh2_pushPixelSourceLua(lua_State* const L, hh2_PixelSource const pixelsrc) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    hh2_PixelSource* const self = lua_newuserdata(L, sizeof(hh2_PixelSource));
    *self = pixelsrc;

    if (luaL_newmetatable(L, HH2_PIXELSOURCE_MT) != 0) {
        static luaL_Reg const methods[] = {
            {"sub", hh2_subPixelSourceLua},
            {"width", hh2_pixelSourceWidthLua},
            {"height", hh2_pixelSourceHeightLua},
            {NULL, NULL}
        };

        lua_createtable(L, 0, sizeof(methods) / sizeof(methods[0]) - 1);
        lua_pushlightuserdata(L, state);
        luaL_setfuncs(L, methods, 1);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, hh2_gcPixelSourceLua);
        lua_setfield(L, -2, "__gc");
    }

    lua_setmetatable(L, -2);
    return 1;
}

static int hh2_readPixelSourceLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    char const* const path = luaL_checkstring(L, 1);

    hh2_PixelSource const pixelsrc = hh2_readPixelSource(state->filesys, path);

    if (pixelsrc == NULL) {
        return luaL_error(L, "error reading pixel source from \"%s\"", path);
    }

    return hh2_pushPixelSourceLua(L, pixelsrc);
}

static int hh2_createCanvasLua(lua_State* const L) {
    // Canvas is a global for the Lua world
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));

    if (state->canvas != NULL) {
        return luaL_error(L, "canvas has already been created");
    }

    lua_Integer const width = luaL_checkinteger(L, 1);
    lua_Integer const height = luaL_checkinteger(L, 2);

    state->canvas = hh2_createCanvas(width, height);

    if (state->canvas == NULL) {
        return luaL_error(L, "error creating canvas with dimensions (%I, %I)", width, height);
    }

    hh2_clearCanvas(state->canvas, HH2_COLOR_RGB565(0, 0, 0));
    return 0;
}

static int hh2_stampLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    hh2_Image const image = *(hh2_Image*)luaL_checkudata(L, 1, HH2_IMAGE_MT);

    lua_Integer const x0 = luaL_checkinteger(L, 2);
    lua_Integer const y0 = luaL_checkinteger(L, 3);

    hh2_stamp(image, state->canvas, x0, y0);
    return 0;
}

static int hh2_gcImageLua(lua_State* const L) {
    hh2_Image const image = *(hh2_Image*)lua_touserdata(L, 1);
    hh2_destroyImage(image);
    return 0;
}

static int hh2_createImageLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    hh2_PixelSource const pixelsrc = *(hh2_PixelSource*)luaL_checkudata(L, 1, HH2_PIXELSOURCE_MT);

    hh2_Image const image = hh2_createImage(pixelsrc);

    if (image == NULL) {
        return luaL_error(L, "error creating image from pixel source");
    }

    hh2_Image* const self = lua_newuserdata(L, sizeof(hh2_Image));
    *self = image;

    if (luaL_newmetatable(L, HH2_IMAGE_MT) != 0) {
        static luaL_Reg const methods[] = {
            {"stamp", hh2_stampLua},
            {NULL, NULL}
        };

        lua_createtable(L, 0, sizeof(methods) / sizeof(methods[0]) - 1);
        lua_pushlightuserdata(L, state);
        luaL_setfuncs(L, methods, 1);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, hh2_gcImageLua);
        lua_setfield(L, -2, "__gc");
    }

    lua_setmetatable(L, -2);
    return 1;
}

typedef struct {
    hh2_Sprite sprite;
    int image_ref;
}
hh2_SpriteUd;

static int hh2_setPositionLua(lua_State* const L) {
    hh2_SpriteUd* const ud = (hh2_SpriteUd*)luaL_checkudata(L, 1, HH2_SPRITE_MT);
    lua_Integer const x = luaL_checkinteger(L, 2);
    lua_Integer const y = luaL_checkinteger(L, 3);

    hh2_setPosition(ud->sprite, x, y);
    return 0;
}

static int hh2_setLayerLua(lua_State* const L) {
    hh2_SpriteUd* const ud = (hh2_SpriteUd*)luaL_checkudata(L, 1, HH2_SPRITE_MT);
    lua_Integer const layer = luaL_checkinteger(L, 2);

    hh2_setLayer(ud->sprite, layer);
    return 0;
}

static int hh2_setImageLua(lua_State* const L) {
    hh2_SpriteUd* const ud = (hh2_SpriteUd*)luaL_checkudata(L, 1, HH2_SPRITE_MT);
    hh2_Image const image = lua_isnoneornil(L, 2) ? NULL : *(hh2_Image*)luaL_checkudata(L, 2, HH2_IMAGE_MT);

    if (ud->image_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, ud->image_ref);
        ud->image_ref = LUA_NOREF;
    }

    if (!hh2_setImage(ud->sprite, image)) {
        return luaL_error(L, "could not set image for sprite");
    }

    if (image != NULL) {
        lua_pushvalue(L, 2);
        ud->image_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    return 0;
}

static int hh2_setVisibilityLua(lua_State* const L) {
    hh2_SpriteUd* const ud = (hh2_SpriteUd*)luaL_checkudata(L, 1, HH2_SPRITE_MT);
    bool const visible = lua_toboolean(L, 2) != 0;

    hh2_setVisibility(ud->sprite, visible);
    return 0;
}

static int hh2_gcSpriteLua(lua_State* const L) {
    hh2_SpriteUd* const ud = (hh2_SpriteUd*)lua_touserdata(L, 1);
    hh2_destroySprite(ud->sprite);

    if (ud->image_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, ud->image_ref);
    }

    return 0;
}

static int hh2_createSpriteLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));

    hh2_Sprite const sprite = hh2_createSprite();

    if (sprite == NULL) {
        return luaL_error(L, "error creating sprite");
    }

    hh2_SpriteUd* const self = lua_newuserdata(L, sizeof(hh2_SpriteUd));
    self->sprite = sprite;
    self->image_ref = LUA_NOREF;

    if (luaL_newmetatable(L, HH2_SPRITE_MT) != 0) {
        static luaL_Reg const methods[] = {
            {"setPosition", hh2_setPositionLua},
            {"setLayer", hh2_setLayerLua},
            {"setImage", hh2_setImageLua},
            {"setVisibility", hh2_setVisibilityLua},
            {NULL, NULL}
        };

        lua_createtable(L, 0, sizeof(methods) / sizeof(methods[0]) - 1);
        lua_pushlightuserdata(L, state);
        luaL_setfuncs(L, methods, 1);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, hh2_gcSpriteLua);
        lua_setfield(L, -2, "__gc");
    }

    lua_setmetatable(L, -2);
    return 1;
}

static int hh2_playLua(lua_State* const L) {
    hh2_Pcm const pcm = *(hh2_Pcm*)luaL_checkudata(L, 1, HH2_PCM_MT);
    
    if (!hh2_playPcm(pcm)) {
        return luaL_error(L, "not enough voices to play PCM");
    }

    return 0;
}

static int hh2_gcPcmLua(lua_State* const L) {
    hh2_Pcm const pcm = *(hh2_Pcm*)lua_touserdata(L, 1);
    hh2_destroyPcm(pcm);
    return 0;
}

static int hh2_readPcmLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    char const* const path = luaL_checkstring(L, 1);

    hh2_Pcm const pcm = hh2_readPcm(state->filesys, path);

    if (pcm == NULL) {
        return luaL_error(L, "error reading PCM from \"%s\"", path);
    }

    hh2_Pcm* const self = lua_newuserdata(L, sizeof(hh2_Pcm));
    *self = pcm;

    if (luaL_newmetatable(L, HH2_PCM_MT) != 0) {
        static luaL_Reg const methods[] = {
            {"play", hh2_playLua},
            {NULL, NULL}
        };

        lua_createtable(L, 0, sizeof(methods) / sizeof(methods[0]) - 1);
        lua_pushlightuserdata(L, state);
        luaL_setfuncs(L, methods, 1);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, hh2_gcPcmLua);
        lua_setfield(L, -2, "__gc");
    }

    lua_setmetatable(L, -2);
    return 1;
}

static int hh2_stopPcmsLua(lua_State* const L) {
    hh2_stopPcms();
    return 0;
}

static int hh2_getBoxyBoldLua(lua_State* const L) {
    hh2_PixelSource const pixelsrc = hh2_initPixelSource(boxy_bold_font_4_png, sizeof(boxy_bold_font_4_png));

    if (pixelsrc == NULL) {
        return luaL_error(L, "error creating pixel source from boxy bold data");
    }

    return hh2_pushPixelSourceLua(L, pixelsrc);
}

void hh2_pushModule(lua_State* const L, hh2_State* const state) {
    static luaL_Reg const functions[] = {
        {"nativeSearcher", hh2_searcher},
        {"log", hh2_logLua},
        {"now", hh2_nowLua},
        {"decodeTimeUs", hh2_decodeTimeUsLua},
        {"contentLoader", hh2_contentLoaderLua},
        {"decrypt", hh2_decryptLua},
        {"uncompress", hh2_uncompressLua},
        {"poke", hh2_pokeLua},
        {"getInput", hh2_getInputLua},
        {"readPixelSource", hh2_readPixelSourceLua},
        {"createCanvas", hh2_createCanvasLua},
        {"createImage", hh2_createImageLua},
        {"createSprite", hh2_createSpriteLua},
        {"readPcm", hh2_readPcmLua},
        {"stopPcms", hh2_stopPcmsLua},
        {"getBoxyBold", hh2_getBoxyBoldLua},
        {NULL, NULL}
    };

    lua_createtable(L, 0, sizeof(functions) / sizeof(functions[0]) - 1 + 2);

    lua_pushliteral(L, HH2_VERSION);
    lua_setfield(L, -2, "VERSION");

#ifdef HH2_DEBUG
    lua_pushboolean(L, 1);
#else
    lua_pushboolean(L, 0);
#endif

    lua_setfield(L, -2, "DEBUG");

    lua_pushlightuserdata(L, state);
    luaL_setfuncs(L, functions, 1);
}
