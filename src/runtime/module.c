#include "module.h"
#include "filesys.h"
#include "log.h"
#include "state.h"
#include "version.h"

#include <zlib.h>

#include <stdlib.h>
#include <errno.h>

#include "boot.js.gz.h"

#include "rtl/classes.js.gz.h"
#include "rtl/js.js.gz.h"
#include "rtl/rtl.js.gz.h"
#include "rtl/rtlconsts.js.gz.h"
#include "rtl/system.js.gz.h"
#include "rtl/sysutils.js.gz.h"
#include "rtl/types.js.gz.h"
#include "rtl/typinfo.js.gz.h"

#include "units/controls.js.gz.h"
#include "units/dialogs.js.gz.h"
#include "units/extctrls.js.gz.h"
#include "units/fmod.js.gz.h"
#include "units/fmodtypes.js.gz.h"
#include "units/forms.js.gz.h"
#include "units/graphics.js.gz.h"
#include "units/hh2.js.gz.h"
#include "units/inifiles.js.gz.h"
#include "units/jpeg.js.gz.h"
#include "units/menus.js.gz.h"
#include "units/messages.js.gz.h"
#include "units/pngimage.js.gz.h"
#include "units/registry.js.gz.h"
#include "units/shellapi.js.gz.h"
#include "units/stdctrls.js.gz.h"
#include "units/windows.js.gz.h"

typedef struct {
    char const* name;
    uint8_t const* compressed;
    size_t compressed_length;
    size_t uncompressed_length;
}
hh2_Module;

static const hh2_Module hh2_modules[] = {
    {"boot.js.gz", boot_js, sizeof(boot_js), boot_js_size},

    {"classes.js.gz", classes_pas, sizeof(classes_pas), classes_pas_size},
    {"js.js.gz", js_pas, sizeof(js_pas), js_pas_size},
    {"rtl.js.gz", rtl_js, sizeof(rtl_js), rtl_js_size},
    {"rtlconsts.js.gz", rtlconsts_pas, sizeof(rtlconsts_pas), rtlconsts_pas_size},
    {"system.js.gz", system_pas, sizeof(system_pas), system_pas_size},
    {"sysutils.js.gz", sysutils_pas, sizeof(sysutils_pas), sysutils_pas_size},
    {"types.js.gz", types_pas, sizeof(types_pas), types_pas_size},
    {"typinfo.js.gz", typinfo_pas, sizeof(typinfo_pas), typinfo_pas_size},

    {"controls.js.gz", controls_pas, sizeof(controls_pas), controls_pas_size},
    {"dialogs.js.gz", dialogs_pas, sizeof(dialogs_pas), dialogs_pas_size},
    {"extctrls.js.gz", extctrls_pas, sizeof(extctrls_pas), extctrls_pas_size},
    {"fmod.js.gz", fmod_pas, sizeof(fmod_pas), fmod_pas_size},
    {"fmodtypes.js.gz", fmodtypes_pas, sizeof(fmodtypes_pas), fmodtypes_pas_size},
    {"forms.js.gz", forms_pas, sizeof(forms_pas), forms_pas_size},
    {"graphics.js.gz", graphics_pas, sizeof(graphics_pas), graphics_pas_size},
    {"hh2.js.gz", hh2_pas, sizeof(hh2_pas), hh2_pas_size},
    {"inifiles.js.gz", inifiles_pas, sizeof(inifiles_pas), inifiles_pas_size},
    {"jpeg.js.gz", jpeg_pas, sizeof(jpeg_pas), jpeg_pas_size},
    {"menus.js.gz", menus_pas, sizeof(menus_pas), menus_pas_size},
    {"messages.js.gz", messages_pas, sizeof(messages_pas), messages_pas_size},
    {"pngimage.js.gz", pngimage_pas, sizeof(pngimage_pas), pngimage_pas_size},
    {"registry.js.gz", registry_pas, sizeof(registry_pas), registry_pas_size},
    {"shellapi.js.gz", shellapi_pas, sizeof(shellapi_pas), shellapi_pas_size},
    {"stdctrls.js.gz", stdctrls_pas, sizeof(stdctrls_pas), stdctrls_pas_size},
    {"windows.js.gz", windows_pas, sizeof(windows_pas), windows_pas_size},
};

static duk_ret_t hh2_zerror(duk_context* const ctx, int const res) {
    switch (res) {
        case Z_ERRNO: return duk_error(ctx, DUK_ERR_ERROR, "Z_ERRNO: %s", strerror(errno));
        case Z_STREAM_ERROR: return duk_error(ctx, DUK_ERR_ERROR, "Z_STREAM_ERROR");
        case Z_DATA_ERROR: return duk_error(ctx, DUK_ERR_ERROR, "Z_DATA_ERROR");
        case Z_MEM_ERROR: return duk_error(ctx, DUK_ERR_ERROR, "Z_MEM_ERROR");
        case Z_BUF_ERROR: return duk_error(ctx, DUK_ERR_ERROR, "Z_BUF_ERROR");
        case Z_VERSION_ERROR: return duk_error(ctx, DUK_ERR_ERROR, "Z_VERSION_ERROR");
        default: return duk_error(ctx, DUK_ERR_ERROR, "Unknown zlib error");
    }
}

static duk_ret_t hh2_uncompress(
    duk_context* const ctx, void const* const compressed, size_t const compressed_length, size_t const uncompressed_length) {

    // Mostly copied from zlib's uncompr.c
    void* const uncompressed = malloc(uncompressed_length);

    if (uncompressed == NULL) {
        return hh2_zerror(ctx, Z_MEM_ERROR);
    }

    z_stream stream;
    memset(&stream, 0, sizeof(stream));

    stream.next_in = (Bytef z_const*)compressed;
    stream.avail_in = compressed_length;
    stream.next_out = uncompressed;
    stream.avail_out = uncompressed_length;

    int const zerr1 = inflateInit2(&stream, 16 + MAX_WBITS);

    if (zerr1 != Z_OK) {
        return hh2_zerror(ctx, zerr1);
    }

    int const zerr2 = inflate(&stream, Z_NO_FLUSH);
    inflateEnd(&stream);

    if (zerr2 == Z_NEED_DICT) {
        return hh2_zerror(ctx, Z_DATA_ERROR);
    }
    else if (zerr2 != Z_STREAM_END) {
        return hh2_zerror(ctx, zerr2);
    }

    duk_push_lstring(ctx, uncompressed, uncompressed_length);
    free(uncompressed);
    return 1;
}

static duk_ret_t hh2_jslog(duk_context* const ctx) {
    duk_size_t length = 0;
    char const* const levelStr = duk_require_lstring(ctx, 0, &length);

    if (length != 1) {
error:
        return duk_error(ctx, DUK_ERR_ERROR, "invalid log level: \"%s\"", levelStr);
    }

    hh2_LogLevel level = HH2_LOG_INFO;

    switch (*levelStr) {
        case 'd': level = HH2_LOG_DEBUG; break;
        case 'i': level = HH2_LOG_INFO; break;
        case 'w': level = HH2_LOG_WARN; break;
        case 'e': level = HH2_LOG_ERROR; break;
        default: goto error;
    }

    duk_concat(ctx, duk_get_top(ctx) - 1);
    char const* const string = duk_require_string(ctx, 1);
    HH2_LOG(level, "JS  %s", string);
    return 0;
}

static duk_ret_t hh2_loadFile(duk_context* const ctx) {
    duk_push_current_function(ctx);
    duk_get_prop_string(ctx, -1, "\xff" "state");
    hh2_State* const state = (hh2_State*)duk_get_pointer(ctx, -1);
    duk_pop_2(ctx);

    char const* const name = duk_require_string(ctx, 0);

    for (size_t i = 0; i < sizeof(hh2_modules) / sizeof(hh2_modules[0]); i++) {
        hh2_Module const* const mod = hh2_modules + i;

        if (strcmp(name, mod->name) == 0) {
            return hh2_uncompress(ctx, mod->compressed, mod->compressed_length, mod->uncompressed_length);
        }
    }

    long const size = hh2_fileSize(state->filesys, name);

    if (size < 0) {
        return duk_error(ctx, DUK_ERR_ERROR, "file not found: \"%s\"", name);
    }

    hh2_File const file = hh2_openFile(state->filesys, name);

    if (file == NULL) {
        return duk_error(ctx, DUK_ERR_ERROR, "error opening file: \"%s\"", name);
    }

    void* const buffer = malloc(size);

    if (buffer == NULL) {
        hh2_close(file);
        return duk_error(ctx, DUK_ERR_ERROR, "out of memory");
    }

    if (hh2_read(file, buffer, size) != size) {
        free(buffer);
        hh2_close(file);
        return duk_error(ctx, DUK_ERR_ERROR, "error reading from file: \"%s\"", name);
    }

    hh2_close(file);
    duk_push_lstring(ctx, buffer, size);
    free(buffer);
    return 1;
}

static duk_ret_t hh2_decrypt(duk_context* const ctx) {
    return 0;
}

static duk_ret_t hh2_compile(duk_context* const ctx) {
    duk_set_top(ctx, 2);
    duk_compile(ctx, DUK_COMPILE_FUNCTION);
    return 1;
}

void hh2_pushModule(duk_context* const ctx, hh2_State* const state) {
    duk_idx_t const index = duk_push_object(ctx);

    duk_push_c_function(ctx, hh2_jslog, DUK_VARARGS);
    duk_put_prop_literal(ctx, index, "log");

    duk_push_c_function(ctx, hh2_loadFile, 1);
    duk_push_pointer(ctx, state);
    duk_put_prop_string(ctx, -2, "\xff" "state");
    duk_put_prop_literal(ctx, index, "loadFile");
    duk_push_pointer(ctx, state);
    duk_put_prop_string(ctx, -2, "\xff" "state");
    duk_put_prop_literal(ctx, index, "load");

    duk_push_c_function(ctx, hh2_decrypt, 1);
    duk_put_prop_literal(ctx, index, "decrypt");

    duk_push_c_function(ctx, hh2_compile, 2);
    duk_put_prop_literal(ctx, index, "compile");

    duk_push_literal(ctx, HH2_VERSION);
    duk_put_prop_literal(ctx, index, "version");
}
