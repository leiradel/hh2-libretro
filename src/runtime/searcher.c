#include "searcher.h"
#include "log.h"

#include <lua.h>
#include <lauxlib.h>

#include <string.h>

#include "units/classes.lua.h"
#include "units/controls.lua.h"
#include "units/dialogs.lua.h"
#include "units/extctrls.lua.h"
#include "units/fmod.lua.h"
#include "units/fmodtypes.lua.h"
#include "units/forms.lua.h"
#include "units/graphics.lua.h"
#include "units/jpeg.lua.h"
#include "units/math.lua.h"
#include "units/messages.lua.h"
#include "units/registry.lua.h"
#include "units/stdctrls.lua.h"
#include "units/sysutils.lua.h"
#include "units/windows.lua.h"

#define TAG "SRH "

#define HH2_MODL(name, array) {name, {array}, sizeof(array)}
#define HH2_MODC(name, openf) {name, {(char*)openf}, 0}

typedef struct {
    char const* name;

    union {
        char const* source;
        lua_CFunction openf;
    }
    data;

    size_t length;
}
hh2_Module;

static const hh2_Module hh2_modules[] = {
    HH2_MODL("classes", classes_lua),
    HH2_MODL("controls", controls_lua),
    HH2_MODL("dialogs", dialogs_lua),
    HH2_MODL("extctrls", extctrls_lua),
    HH2_MODL("fmod", fmod_lua),
    HH2_MODL("fmodtypes", fmodtypes_lua),
    HH2_MODL("forms", forms_lua),
    HH2_MODL("graphics", graphics_lua),
    HH2_MODL("jpeg", jpeg_lua),
    HH2_MODL("math", math_lua),
    HH2_MODL("messages", messages_lua),
    HH2_MODL("registry", registry_lua),
    HH2_MODL("stdctrls", stdctrls_lua),
    HH2_MODL("sysutils", sysutils_lua),
    HH2_MODL("windows", windows_lua)
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
