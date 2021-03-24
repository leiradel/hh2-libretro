#include "log.h"
#include "filesys.h"
#include "pixelsrc.h"
#include "state.h"
#include "version.h"

#include <stdio.h>
#include <stdint.h>

static uint8_t buffer[16 * 1024 * 1024];
static size_t size = 0;

static uint8_t buffer2[16 * 1024 * 1024];

static void logger(hh2_LogLevel level, char const* format, va_list ap) {
    switch (level) {
        case HH2_LOG_DEBUG: printf("DEBUG "); break;
        case HH2_LOG_INFO:  printf("INFO  "); break;
        case HH2_LOG_WARN:  printf("WARN  "); break;
        case HH2_LOG_ERROR: printf("ERROR "); break;
    }

    vprintf(format, ap);
    putchar('\n');
}

int main() {
    hh2_setLogger(logger);
    hh2_logVersions();

    FILE* file = fopen("test.hh2", "rb");
    size = fread(buffer, 1, sizeof(buffer), file);
    fclose(file);

    hh2_Filesys fs = hh2_createFilesystem(buffer, size);

    HH2_LOG(HH2_LOG_INFO, "\"Makefile\" exists: %s", hh2_fileExists(fs, "Makefile") ? "true" : "false");
    HH2_LOG(HH2_LOG_INFO, "\"Makefile\" size: %ld", hh2_fileSize(fs, "Makefile"));

    hh2_File mf = hh2_openFile(fs, "Makefile");

    if (mf != NULL) {
        size_t const numread = hh2_read(mf, buffer2, sizeof(buffer2));
        buffer2[numread] = 0;

        HH2_LOG(HH2_LOG_INFO, "read %zu bytes from \"Makefile\"", numread);

        printf("%s", buffer2);
        hh2_close(mf);
    }

    hh2_PixelSource cp = hh2_readPixelSource(fs, "test/cryptopunk32.jpg");

    if (cp != NULL) {
        unsigned const w = hh2_pixelSourceWidth(cp);
        unsigned const h = hh2_pixelSourceHeight(cp);

        FILE* const raw = fopen("cryptopunk32.data", "wb");

        for (unsigned y = 0; y < h; y++) {
            for (unsigned x = 0; x < w; x++) {
                hh2_ARGB8888 const p = hh2_getPixel(cp, x, y);
                fwrite(&p, 1, 4, raw);
            }
        }

        fclose(raw);
        hh2_destroyPixelSource(cp);
    }

    hh2_State state;

    if (hh2_initState(&state, fs)) {
        hh2_destroyState(&state);
    }

    if (fs != NULL) {
        hh2_destroyFilesystem(fs);
    }

    return 0;
}
