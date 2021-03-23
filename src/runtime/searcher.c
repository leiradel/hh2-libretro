#include "searcher.h"
#include "log.h"

#include <lua.h>
#include <lauxlib.h>

#include <string.h>

#define TAG "SRH "

#define HH2_MODL(name, array) {name, {array}, sizeof(array)}
#define HH2_MODC(name, openf) {name, {(char*)openf}, 0}

typedef struct {
    const char* name;

    union {
        const char* source;
        lua_CFunction openf;
    }
    data;

    size_t length;
}
hh2_Module;

static const hh2_Module hh2_modules[1] = {
    HH2_MODL("test", "return nil")
};

#undef HH2_MODL
#undef HH2_MODC

static int hh2_searcher(lua_State* const L) {
    char const* const mod_name = lua_tostring(L, 1);
    HH2_LOG(HH2_LOG_INFO, TAG "searching for module \"%s\"", mod_name);

    // Iterates over all modules we know
    for (size_t i = 0; i < sizeof(hh2_modules) / sizeof(hh2_modules[0]); i++) {
        if (strcmp(mod_name, hh2_modules[i].name) == 0) {
            if (hh2_modules[i].length != 0) {
                // It's a Lua module, return the chunk that defines the module
                HH2_LOG(HH2_LOG_DEBUG, TAG "found a Lua module");
                int const res = luaL_loadbufferx(L, hh2_modules[i].data.source, hh2_modules[i].length, mod_name, "t");

                if (res != LUA_OK) {
                    return lua_error(L);
                }
            }
            else {
                // It's a native module, return the native function that defines the module.
                HH2_LOG(HH2_LOG_DEBUG, TAG "found a native module");
                lua_pushcfunction(L, hh2_modules[i].data.openf);
            }

            return 1;
        }
    }

    // Oops
    lua_pushfstring(L, "unknown module \"%s\"", mod_name);
    return 1;
}

void hh2_pushSearcher(lua_State* const L) {
    lua_pushcfunction(L, hh2_searcher);
}
