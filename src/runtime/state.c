#include "state.h"
#include "log.h"
#include "module.h"

#include <zlib.h>

#include <string.h>

#include "bootstrap.js.h"

static duk_ret_t hh2_bootstrap(duk_context* const ctx) {
    hh2_State* const state = (hh2_State*)duk_get_pointer(ctx, 0);

    duk_push_literal(ctx, "bootstrap.js");
    duk_compile_lstring_filename(ctx, DUK_COMPILE_FUNCTION, bootstrap_js, sizeof(bootstrap_js));

    hh2_pushModule(ctx, state);
    duk_call(ctx, 1);
    return 1;
}

bool hh2_initState(hh2_State* const state, hh2_Filesys const filesys) {
    memset(&state->sram, 0, sizeof(state->sram));

    state->ctx = duk_create_heap_default();

    if (state->ctx == NULL) {
        return false;
    }

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

    duk_push_c_function(state->ctx, hh2_bootstrap, 1);
    duk_push_pointer(state->ctx, state);
    duk_int_t const res = duk_pcall(state->ctx, 1);

    if (res != DUK_EXEC_SUCCESS) {
        HH2_LOG(
            HH2_LOG_ERROR,
            "\n===============================================================================\n"
            "%s\n"
            "-------------------------------------------------------------------------------",
            duk_safe_to_stacktrace(state->ctx, -1)
        );

        hh2_destroyState(state);
        return false;
    }

    return true;
}

void hh2_destroyState(hh2_State* const state) {
    duk_destroy_heap(state->ctx);

    if (state->canvas != NULL) {
        hh2_destroyCanvas(state->canvas);
    }

    memset(state, 0, sizeof(*state));
}
