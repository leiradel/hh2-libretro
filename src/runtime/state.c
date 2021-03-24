#include "state.h"
#include "bsreader.h"
#include "log.h"
#include "searcher.h"

#include "bootstrap.lua.h"

#include <lauxlib.h>
#include <lualib.h>

#include <string.h>
#include <stdlib.h>

static int hh2_traceback(lua_State* const L) {
    luaL_traceback(L, L, lua_tostring(L, -1), 1);
    return 1;
}

static bool hh2_pcall(lua_State* const L, int const num_args, int const num_results) {
    int const error_index = lua_gettop(L) - num_args;
    lua_pushcfunction(L, hh2_traceback);
    lua_insert(L, error_index);

    int const ret = lua_pcall(L, num_args, num_results, error_index);
    lua_remove(L, error_index);

    if (ret != LUA_OK) {
        HH2_LOG(HH2_LOG_ERROR, "===============================================================================");
        HH2_LOG(HH2_LOG_ERROR, "%s", lua_tostring(L, -1));
        HH2_LOG(HH2_LOG_ERROR, "-------------------------------------------------------------------------------");
        lua_pop(L, 1);
        return false;
    }

    return true;
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

static int hh2_bootstrap(lua_State* const L) {
    hh2_State* state = (hh2_State*)lua_touserdata(L, lua_upvalueindex(1));

    // Load the bootstrap code
    int const res = luaL_loadbufferx(L, bootstrap_lua, sizeof(bootstrap_lua), "bootstrap.lua", "t");

    if (res != LUA_OK) {
        return lua_error(L);
    }

    // Call the compiled chunk to get the bootstrap main function
    lua_call(L, 0, 1);

    // Create a table with the arguments to the main function
    static luaL_Reg const functions[] = {
        {"contentLoader", hh2_contentLoader},
        {"bsDecoder", hh2_bsDecoder}
    };

    lua_createtable(L, 0, sizeof(functions) / sizeof(functions[0]) + 1);

    hh2_pushSearcher(L);
    lua_setfield(L, -2, "nativeSearcher");

    lua_pushlightuserdata(L, state);
    luaL_setfuncs(L, functions, 1);

    // Call the main function
    lua_call(L, 1, 1);

    // Get a reference to whatever the main function returns
    state->reference = luaL_ref(L, LUA_REGISTRYINDEX);
    return 0;
}

bool hh2_initState(hh2_State* const state, hh2_Filesys const filesys) {
    memset(&state->sram, 0, sizeof(state->sram));

    state->L = luaL_newstate();

    if (state->L == NULL) {
        return false;
    }

    state->reference = LUA_NOREF;
    state->filesys = filesys;
    state->next_tick = 0;
    state->canvas = NULL;
    state->zoom_x0 = 0;
    state->zoom_y0 = 0;
    state->zoom_width = 0;
    state->zoom_height = 0;
    state->sprite_layer = 1023; // decreasing

    memset(state->button_state, 0, sizeof(state->button_state));
    state->pointer_x = 0;
    state->pointer_y = 0;
    state->pointer_pressed = false;

    static luaL_Reg const lualibs[] = {
        {"_G", luaopen_base},
        {LUA_LOADLIBNAME, luaopen_package},
        {LUA_COLIBNAME, luaopen_coroutine},
        {LUA_TABLIBNAME, luaopen_table},
        // {LUA_IOLIBNAME, luaopen_io},
        // {LUA_OSLIBNAME, luaopen_os},
        {LUA_STRLIBNAME, luaopen_string},
        {LUA_MATHLIBNAME, luaopen_math},
        {LUA_UTF8LIBNAME, luaopen_utf8},
        // {LUA_DBLIBNAME, luaopen_debug}
    };

    for (size_t i = 0; i < sizeof(lualibs) / sizeof(lualibs[0]); i++ ) {
        luaL_requiref(state->L, lualibs[i].name, lualibs[i].func, 1);
        lua_pop(state->L, 1);
    }

    lua_pushlightuserdata(state->L, (void*)state);
    lua_pushcclosure(state->L, hh2_bootstrap, 1);

    if (!hh2_pcall(state->L, 0, 0)) {
        lua_close(state->L);
        memset(state, 0, sizeof(*state));
        return false;
    }

    return true;
}

void hh2_destroyState(hh2_State* const state) {
    lua_close(state->L);

    if (state->canvas != NULL) {
        hh2_destroyCanvas(state->canvas);
    }

    memset(state, 0, sizeof(*state));
}
