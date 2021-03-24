#include "module.h"
#include "bsreader.h"
#include "filesys.h"
#include "log.h"
#include "searcher.h"
#include "state.h"

#include <stdlib.h>

#include <lauxlib.h>

static int hh2_contentLoader(lua_State* const L) {
    hh2_State* state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));
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

static int hh2_bsDecoder(lua_State* const L) {
    char const* const data = luaL_checkstring(L, 1);
    hh2_BsStream const stream = hh2_createBsDecoder(data);

    if (stream == NULL) {
        return luaL_error(L, "error creating bs stream");
    }

    luaL_Buffer B;
    luaL_buffinit(L, &B);

    for (lua_Integer i = 1;; i++) {
        size_t length = 0;
        char const* const decoded = hh2_decode(stream, &length);

        if (decoded == NULL) {
            break;
        }

        luaL_addlstring(&B, decoded, length);
    }

    hh2_destroyBsDecoder(stream);
    luaL_pushresult(&B);
    return 1;
}

void hh2_pushModule(lua_State* const L, hh2_State* const state) {
    static luaL_Reg const functions[] = {
        {"bsDecoder", hh2_bsDecoder},
        {"contentLoader", hh2_contentLoader},
        {"nativeSearcher", hh2_searcher}
    };

    lua_createtable(L, 0, sizeof(functions) / sizeof(functions[0]));

    lua_pushlightuserdata(L, state);
    luaL_setfuncs(L, functions, 1);
}
