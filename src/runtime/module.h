#ifndef HH2_MODULE_H__
#define HH2_MODULE_H__

#include "state.h"

#include <duktape.h>

void hh2_pushModule(duk_context* const ctx, hh2_State* const state);

#endif // HH2_MODULE_H__
