#include "module.h"
#include "bsdecode.h"
#include "filesys.h"
#include "log.h"
#include "searcher.h"
#include "state.h"
#include "version.h"

#include <stdlib.h>

#include <lauxlib.h>

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

void hh2_pushModule(lua_State* const L, hh2_State* const state) {
    static luaL_Reg const functions[] = {
        {"log", hh2_logLua},
        {"bsDecoder", hh2_bsDecoder},
        {"contentLoader", hh2_contentLoader},
        {"nativeSearcher", hh2_searcher},
        {NULL, NULL}
    };

    lua_createtable(L, 0, sizeof(functions) / sizeof(functions[0]) + 1);

    lua_pushliteral(L, HH2_VERSION);
    lua_setfield(L, -2, "VERSION");

    lua_pushlightuserdata(L, state);
    luaL_setfuncs(L, functions, 1);
}
