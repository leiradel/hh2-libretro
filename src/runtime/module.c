#include "module.h"
#include "bsdecode.h"
#include "filesys.h"
#include "log.h"
#include "searcher.h"
#include "state.h"
#include "version.h"
#include "pixelsrc.h"
#include "canvas.h"
#include "image.h"
#include "sprite.h"

#include <stdlib.h>

#include <lauxlib.h>

#define HH2_PIXELSOURCE_MT "hh2_PixelSource"
#define HH2_IMAGE_MT "hh2_Image"
#define HH2_SPRITE_MT "hh2_Sprite"

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
    lua_pushinteger(L, state->now);
    return 1;
}

static int hh2_decodeTimeUsLua(lua_State* const L) {
    lua_Integer now = luaL_checkinteger(L, 1);

    //lua_Integer const usecs = now % 1000;
    now /= 1000;

    lua_Integer const msecs = now % 1000;
    now /= 1000;

    lua_Integer const seconds = now % 60;
    now /= 60;

    lua_Integer const minutes = now % 60;
    now /= 60;

    lua_Integer const hours = now;

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

static int hh2_bsDecoderLua(lua_State* const L) {
    char const* const encoded = luaL_checkstring(L, 1);

    size_t size = 0;
    char const* const decoded = hh2_bsDecode(encoded, &size);

    if (decoded == NULL) {
        return luaL_error(L, "error decoding bs stream");
    }

    lua_pushlstring(L, decoded, size);
    free((void*)decoded);
    return 1;
}

static int hh2_pokeLua(lua_State* const L) {
    HH2_LOG(HH2_LOG_WARN, "poke not implemented");
    return 0;
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

static int hh2_readPixelSourceLua(lua_State* const L) {
    hh2_State* const state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
    char const* const path = luaL_checkstring(L, 1);

    hh2_PixelSource const pixelsrc = hh2_readPixelSource(state->filesys, path);

    if (pixelsrc == NULL) {
        return luaL_error(L, "error reading pixel source from \"%s\"", path);
    }

    hh2_PixelSource* const self = lua_newuserdata(L, sizeof(hh2_PixelSource));
    *self = pixelsrc;

    if (luaL_newmetatable(L, HH2_PIXELSOURCE_MT) != 0) {
        static luaL_Reg const methods[] = {
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
    hh2_Image const image = *(hh2_Image*)luaL_checkudata(L, 2, HH2_IMAGE_MT);

    if (ud->image_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, ud->image_ref);
        ud->image_ref = LUA_NOREF;
    }

    if (!hh2_setImage(ud->sprite, image)) {
        return luaL_error(L, "could not set image for sprite");
    }

    lua_pushvalue(L, 2);
    ud->image_ref = luaL_ref(L, LUA_REGISTRYINDEX);
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

void hh2_pushModule(lua_State* const L, hh2_State* const state) {
    static luaL_Reg const functions[] = {
        {"log", hh2_logLua},
        {"now", hh2_nowLua},
        {"decodeTimeUs", hh2_decodeTimeUsLua},
        {"contentLoader", hh2_contentLoaderLua},
        {"bsDecoder", hh2_bsDecoderLua},
        {"poke", hh2_pokeLua},
        {"nativeSearcher", hh2_searcher},
        {"readPixelSource", hh2_readPixelSourceLua},
        {"createCanvas", hh2_createCanvasLua},
        {"createImage", hh2_createImageLua},
        {"createSprite", hh2_createSpriteLua},
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
