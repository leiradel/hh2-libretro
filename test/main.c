#include "../src/log.h"
#include "../src/filesys.h"
#include "../src/image.h"
#include "../src/version.h"

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
    hh2_setlogger(logger);

    hh2_log(HH2_LOG_INFO, "package  %s", HH2_PACKAGE);
    hh2_log(HH2_LOG_INFO, "git hash %s", HH2_GITHASH);
    hh2_log(HH2_LOG_INFO, "version  %s", HH2_VERSION);
    hh2_log(HH2_LOG_INFO, "datatime %s", HH2_DATE);

    FILE* file = fopen("test.hh2", "rb");
    size = fread(buffer, 1, sizeof(buffer), file);
    fclose(file);

    hh2_Filesys fs = hh2_filesystemCreate(buffer, size);

    hh2_log(HH2_LOG_INFO, "\"Makefile\" exists: %s", hh2_fileExists(fs, "Makefile") ? "true" : "false");
    hh2_log(HH2_LOG_INFO, "\"Makefile\" size: %ld", hh2_fileSize(fs, "Makefile"));

    hh2_File mf = hh2_fileOpen(fs, "Makefile");

    if (mf != NULL) {
        size_t const numread = hh2_fileRead(mf, buffer2, sizeof(buffer2));
        buffer2[numread] = 0;

        hh2_log(HH2_LOG_INFO, "read %zu bytes from \"Makefile\"", numread);

        printf("%s", buffer2);
        hh2_fileClose(mf);
    }

    hh2_Image cp = hh2_imageRead(fs, "test/cryptopunk32.png");

    unsigned const w = hh2_imageWidth(cp);
    unsigned const h = hh2_imageHeight(cp);

    FILE* const raw = fopen("cryptopunk32.data", "wb");

    for (unsigned y = 0; y < h; y++) {
        for (unsigned x = 0; x < w; x++) {
            hh2_Pixel const p = hh2_getPixel(cp, x, y);
            fwrite(&p, 1, 4, raw);
        }
    }

    fclose(raw);
    hh2_imageDestroy(cp);

    if (fs != NULL) {
        hh2_filesystemDestroy(fs);
    }

    return 0;
}
