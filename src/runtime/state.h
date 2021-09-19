#ifndef HH2_STATE_H__
#define HH2_STATE_H__

#include "canvas.h"
#include "filesys.h"

#include <lua.h>

// Do not change these values!
#define HH2C_SRAM_MAX_ENTRIES 8
#define HH2C_SRAM_MAX_KEY_LENGTH 32
#define HH2C_SRAM_MAX_VALUE_LENGTH 64

typedef struct {
    // 777 bytes for the registry
    uint8_t types[HH2C_SRAM_MAX_ENTRIES];
    uint8_t keys[HH2C_SRAM_MAX_ENTRIES][HH2C_SRAM_MAX_KEY_LENGTH];
    uint8_t values[HH2C_SRAM_MAX_ENTRIES][HH2C_SRAM_MAX_VALUE_LENGTH];
    uint8_t count;

    // Pad to next multiple of four
    uint8_t padding[3];

    // Fake SRAM for achievements, all values are guaranteed to be written in little-endian
    uint32_t sram[317];
}
hh2_Sram;

// Make sure hh2_Sram has 2048 bytes
typedef char hh2c_staticAssertSramMustHave2048Bytes[sizeof(hh2_Sram) == 2048 ? 1 : -1];

typedef enum {
    HH2_BUTTON_UP,
    HH2_BUTTON_DOWN,
    HH2_BUTTON_LEFT,
    HH2_BUTTON_RIGHT,
    HH2_BUTTON_A,
    HH2_BUTTON_B,
    HH2_BUTTON_X,
    HH2_BUTTON_Y,
    HH2_BUTTON_L1,
    HH2_BUTTON_R1,
    HH2_BUTTON_L2,
    HH2_BUTTON_R2,
    HH2_BUTTON_L3,
    HH2_BUTTON_R3,
    HH2_BUTTON_START,
    HH2_BUTTON_SELECT,
    HH2_NUM_BUTTONS
}
hh2_Button;

typedef struct {
    hh2_Sram sram;
    lua_State* L;
    int reference;

    hh2_Filesys filesys;

    int64_t now_us;

    hh2_Canvas canvas;
    unsigned zoom_x0, zoom_y0, zoom_width, zoom_height;
    bool is_zoomed;

    bool button_state[2][HH2_NUM_BUTTONS];
    int mouse_x, mouse_y;
    bool mouse_pressed;
}
hh2_State;

bool hh2_initState(hh2_State* state, hh2_Filesys filesys);

void hh2_setButton(hh2_State* state, unsigned port, hh2_Button button, bool pressed);
void hh2_setMouse(hh2_State* state, int x, int y, bool pressed);
bool hh2_tick(hh2_State* state, int64_t now_us);

void hh2_destroyState(hh2_State* state);

#endif // HH2_STATE_H__
