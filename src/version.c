#include "log.h"
#include "version.h"

#include <dr_wav.h>
#include <stdio.h> // for jpeglib.h
#include <jpeglib.h>
#include <lua.h>
#include <png.h>
#include <zlib.h>

#define TAG "VER "

void hh2_logVersions(void) {
    HH2_LOG(HH2_LOG_INFO, TAG "HH2 Core:      %s", HH2_PACKAGE);
    HH2_LOG(HH2_LOG_INFO, TAG "HH2 Version    %s", HH2_VERSION);
    HH2_LOG(HH2_LOG_INFO, TAG "HH2 Date:      %s", HH2_DATE);
    HH2_LOG(HH2_LOG_INFO, TAG "HH2 Commit:    %s", HH2_GITHASH);
    HH2_LOG(HH2_LOG_INFO, TAG "dr_wav:        %s", DRWAV_VERSION_STRING);

    HH2_LOG(
        HH2_LOG_INFO, TAG "libjpeg-turbo: %d.%d.%d",
        LIBJPEG_TURBO_VERSION_NUMBER / 1000000, (LIBJPEG_TURBO_VERSION_NUMBER / 1000) % 1000, LIBJPEG_TURBO_VERSION_NUMBER % 1000
    );

    HH2_LOG(HH2_LOG_INFO, TAG "libpng:        %s", PNG_LIBPNG_VER_STRING);
    HH2_LOG(HH2_LOG_INFO, TAG "Lua:           %s.%s.%s", LUA_VERSION_MAJOR, LUA_VERSION_MINOR, LUA_VERSION_RELEASE);
    HH2_LOG(HH2_LOG_INFO, TAG "Speex:         ?");
    HH2_LOG(HH2_LOG_INFO, TAG "zlib:          %s", ZLIB_VERSION);
}
