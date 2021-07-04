#include "searcher.h"
#include "log.h"

#include <lua.h>
#include <lauxlib.h>
#include <zlib.h>

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>

#include "boot.luagz.h"
#include "class.luagz.h"
#include "units/classes.luagz.h"
#include "units/controls.luagz.h"
#include "units/dialogs.luagz.h"
#include "units/extctrls.luagz.h"
#include "units/fmod.luagz.h"
#include "units/fmodtypes.luagz.h"
#include "units/forms.luagz.h"
#include "units/graphics.luagz.h"
#include "units/hh2.luagz.h"
#include "units/inifiles.luagz.h"
#include "units/jpeg.luagz.h"
#include "units/math.luagz.h"
#include "units/menus.luagz.h"
#include "units/messages.luagz.h"
#include "units/pngimage.luagz.h"
#include "units/registry.luagz.h"
#include "units/shellapi.luagz.h"
#include "units/stdctrls.luagz.h"
#include "units/system.luagz.h"
#include "units/sysutils.luagz.h"
#include "units/windows.luagz.h"

#define TAG "SRH "

#define HH2_MODL(name, array) {name, {array}, array ## _size, sizeof(array)}
#define HH2_MODC(name, openf) {name, {(uint8_t*)openf}, 0, 0}

typedef struct {
    char const* name;

    union {
        uint8_t const* compressed;
        lua_CFunction openf;
    }
    data;

    size_t uncompressed_length;
    size_t compressed_length;
}
hh2_Module;

static const hh2_Module hh2_modules[] = {
    HH2_MODL("boot", boot_lua),
    HH2_MODL("class", class_lua),
    HH2_MODL("classes", classes_lua),
    HH2_MODL("controls", controls_lua),
    HH2_MODL("dialogs", dialogs_lua),
    HH2_MODL("extctrls", extctrls_lua),
    HH2_MODL("fmod", fmod_lua),
    HH2_MODL("fmodtypes", fmodtypes_lua),
    HH2_MODL("forms", forms_lua),
    HH2_MODL("graphics", graphics_lua),
    HH2_MODL("hh2", hh2_lua),
    HH2_MODL("inifiles", inifiles_lua),
    HH2_MODL("jpeg", jpeg_lua),
    HH2_MODL("math", math_lua),
    HH2_MODL("menus", menus_lua),
    HH2_MODL("messages", messages_lua),
    HH2_MODL("pngimage", pngimage_lua),
    HH2_MODL("registry", registry_lua),
    HH2_MODL("shellapi", shellapi_lua),
    HH2_MODL("stdctrls", stdctrls_lua),
    HH2_MODL("system", system_lua),
    HH2_MODL("sysutils", sysutils_lua),
    HH2_MODL("windows", windows_lua)
};

#undef HH2_MODL
#undef HH2_MODC

static int hh2_uncompress(hh2_Module const* const module, void** const uncompressed) {
    // Mostly copied from zlib's uncompr.c
    *uncompressed = (char*)malloc(module->uncompressed_length);

    if (*uncompressed == NULL) {
        return Z_MEM_ERROR;
    }

    z_stream stream;
    memset(&stream, 0, sizeof(stream));

    stream.next_in = (Bytef z_const*)module->data.compressed;
    stream.avail_in = module->compressed_length;
    stream.next_out = *uncompressed;
    stream.avail_out = module->uncompressed_length;

    int const zerr1 = inflateInit2(&stream, 16 + MAX_WBITS);

    if (zerr1 != Z_OK) {
        return zerr1;
    }

    int const zerr2 = inflate(&stream, Z_NO_FLUSH);
    inflateEnd(&stream);

    if (zerr2 == Z_STREAM_END) {
        return Z_OK;
    }
    else if (zerr2 == Z_NEED_DICT) {
        return Z_DATA_ERROR;
    }
    else {
        return zerr2;
    }
}

int hh2_searcher(lua_State* const L) {
    char const* const mod_name = lua_tostring(L, 1);
    HH2_LOG(HH2_LOG_INFO, TAG "searching for module \"%s\"", mod_name);

    // Iterates over all modules we know
    for (size_t i = 0; i < sizeof(hh2_modules) / sizeof(hh2_modules[0]); i++) {
        hh2_Module const* const module = hh2_modules + i;

        if (strcmp(mod_name, module->name) == 0) {
            if (module->uncompressed_length != 0) {
                // It's a Lua module, return the chunk that defines the module
                HH2_LOG(HH2_LOG_DEBUG, TAG "found a Lua module, decompressing");

                void* uncompressed = NULL;
                int const zres = hh2_uncompress(module, &uncompressed);

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

                int const lres = luaL_loadbufferx(L, uncompressed, module->uncompressed_length, mod_name, "t");
                free(uncompressed);

                if (lres != LUA_OK) {
                    return lua_error(L);
                }
            }
            else {
                // It's a native module, return the native function that defines the module.
                HH2_LOG(HH2_LOG_DEBUG, TAG "found a native module");
                lua_pushcfunction(L, module->data.openf);
            }

            return 1;
        }
    }

    // Oops
    HH2_LOG(HH2_LOG_DEBUG, TAG "couldn't find module \"%s\"", mod_name);
    lua_pushfstring(L, "unknown module \"%s\"", mod_name);
    return 1;
}
