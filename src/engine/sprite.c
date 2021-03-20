#include "sprite.h"

#include <stdlib.h>

#define HH2_MIN_SPRITES 64

typedef enum {
    HH2_SPRITE_INVISIBLE = 0x4000U,
    HH2_SPRITE_UNUSED = 0x8000U,
    HH2_SPRITE_FLAGS = HH2_SPRITE_INVISIBLE | HH2_SPRITE_UNUSED,
    HH2_SPRITE_LAYER = ~HH2_SPRITE_FLAGS
}
hh2_SpriteFlags;

struct hh2_Sprite {
    uint16_t flags; // Sprite layer [0..16383] | visibility << 14 | << unused << 15
    int x;
    int y;

    hh2_Image image;
    hh2_RGB565* bg;
};

static hh2_Sprite hh2_sprites;
static size_t hh2_spriteCount = 0;
static size_t hh2_spriteReserved = 0;

hh2_Sprite hh2_createSprite(void) {
    if (hh2_spriteCount < hh2_spriteReserved) {
        hh2_Sprite const sprite = hh2_sprites + hh2_spriteCount;

        if ((sprite->flags & HH2_SPRITE_UNUSED) != 0) {
            hh2_spriteCount++;
            sprite->flags = 0;
            sprite->bg = NULL;
            return sprite;
        }
    }

    size_t const new_reserved = hh2_spriteReserved == 0 ? HH2_MIN_SPRITES : hh2_spriteReserved * 2;
    hh2_Sprite const new_sprites = (hh2_Sprite)realloc(hh2_sprites, new_reserved * sizeof(*new_sprites));

    if (new_sprites != NULL) {
        hh2_sprites = new_sprites;
        hh2_spriteReserved = new_reserved;

        hh2_Sprite const sprite = hh2_sprites + hh2_spriteCount++;
        sprite->flags = 0;
        sprite->bg = NULL;
        return sprite;
    }

    return NULL;
}

void hh2_destroySprite(hh2_Sprite sprite) {
    if (sprite->bg != NULL) {
        free(sprite->bg);
    }

    sprite->flags = HH2_SPRITE_UNUSED;
}

void hh2_setPosition(hh2_Sprite sprite, int x, int y) {
    sprite->x = x;
    sprite->y = y;
}

void hh2_setLayer(hh2_Sprite sprite, unsigned layer) {
    sprite->flags = (sprite->flags & HH2_SPRITE_FLAGS) | (layer & HH2_SPRITE_LAYER);
}

bool hh2_setImage(hh2_Sprite sprite, hh2_Image image) {
    if (sprite->bg != NULL) {
        free(sprite->bg);
        sprite->bg = NULL;
    }

    if (image != NULL) {
        size_t const count = hh2_changedPixels(image);
        sprite->bg = (hh2_RGB565*)malloc(count * sizeof(*sprite->bg));
    }

    sprite->image = image;
    return image != NULL && sprite->bg != NULL;
}

void hh2_setVisibility(hh2_Sprite sprite, bool visible) {
    sprite->flags = (HH2_SPRITE_INVISIBLE * !visible) | (sprite->flags & HH2_SPRITE_LAYER);
}

static int hh2_compareSprites(void const* e1, void const* e2) {
    hh2_Sprite const s1 = (hh2_Sprite)e1;
    hh2_Sprite const s2 = (hh2_Sprite)e2;

    if (s1->flags == s2->flags) {
        bool const i1 = s1->image != NULL;
        bool const i2 = s2->image != NULL;

        if (i1 == i2) {
            return 0;
        }
        else if (i1 && !i2) {
            return -1;
        }
        else {
            return 1;
        }
    }
    else if (s1->flags < s2->flags) {
        return -1;
    }
    else {
        return 1;
    }
}

void hh2_blitSprites(hh2_Canvas const canvas) {
    qsort(hh2_sprites, hh2_spriteCount, sizeof(*hh2_sprites), hh2_compareSprites);
    hh2_Sprite sprite = hh2_sprites;

    if ((sprite->flags & HH2_SPRITE_INVISIBLE) == 0 && sprite->image != NULL) {
        do {
            hh2_blit(sprite->image, canvas, sprite->x, sprite->y, sprite->bg);
            sprite++;
        }
        while ((sprite->flags & HH2_SPRITE_INVISIBLE) == 0 && sprite->image != NULL);
    }
}

void hh2_unblitSprites(hh2_Canvas const canvas) {
    hh2_Sprite sprite = hh2_sprites;

    if ((sprite->flags & HH2_SPRITE_INVISIBLE) == 0 && sprite->image != NULL) {
        do {
            hh2_unblit(sprite->image, canvas, sprite->x, sprite->y, sprite->bg);
            sprite++;
        }
        while ((sprite->flags & HH2_SPRITE_INVISIBLE) == 0 && sprite->image != NULL);
    }
}
