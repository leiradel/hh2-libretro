%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) -std=c99 -Wall -Wpedantic -Werror -c "$<" -o "$@"

%.js.h: %.js
	echo "static char const `basename "$<" | sed 's/\./_/'`[] = {\n`cat "$<" | xxd -i`\n};" > "$@"

%.js.gz.h: %.js
	echo "static uint8_t const `basename "$<" | sed 's/\./_/'`[] = {\n`cat "$<" | gzip -c9n | xxd -i`\n};\n" > "$@"
	echo "static size_t const `basename "$<" | sed 's/\./_/'`_size = `wc -c "$<" | sed 's/ .*//'`;" >> "$@"

%.js.gz.h: %.pas
	echo "static uint8_t const `basename "$<" | sed 's/\./_/'`[] = {\n`$(PAS2JS) "$<" | gzip -c9n | xxd -i`\n};\n" > "$@"
	echo "static size_t const `basename "$<" | sed 's/\./_/'`_size = `$(PAS2JS) "$<" | wc -c - | sed 's/ .*//'`;" >> "$@"

CC ?= gcc
CFLAGS = -fPIC

DEFINES = \
	-DHH2_ENABLE_LOGGING \
	-DWITH_MEM_SRCDST=0 \
	-DLUA_USE_JUMPTABLE=0 \
	-DOUTSIDE_SPEEX -DRANDOM_PREFIX=speex -DEXPORT= -D_USE_SSE -D_USE_SSE2 -DFLOATING_POINT

INCLUDES = \
	-Isrc -Isrc/dr_libs -Isrc/duktape -Isrc/engine -Isrc/generated -Isrc/libjpeg-turbo -Isrc/libpng -Isrc/speex -Isrc/runtime \
	-Isrc/zlib

LIBS = -lm
PAS2JS = etc/pas2js-hh2.sh

ifeq ($(DEBUG), 1)
	CFLAGS += -O0 -g -DHH2_DEBUG $(DEFINES)
else
	CFLAGS += -O3 -DHH2_RELEASE -DNDEBUG $(DEFINES)
endif

LIBJPEG_OBJS = \
	src/libjpeg-turbo/jaricom.o src/libjpeg-turbo/jcomapi.o src/libjpeg-turbo/jdapimin.o src/libjpeg-turbo/jdapistd.o \
	src/libjpeg-turbo/jdarith.o src/libjpeg-turbo/jdcoefct.o src/libjpeg-turbo/jdcolor.o src/libjpeg-turbo/jddctmgr.o \
	src/libjpeg-turbo/jdhuff.o src/libjpeg-turbo/jdinput.o src/libjpeg-turbo/jdmainct.o src/libjpeg-turbo/jdmarker.o \
	src/libjpeg-turbo/jdmaster.o src/libjpeg-turbo/jdmerge.o src/libjpeg-turbo/jdphuff.o src/libjpeg-turbo/jdpostct.o \
	src/libjpeg-turbo/jdsample.o src/libjpeg-turbo/jerror.o src/libjpeg-turbo/jidctflt.o src/libjpeg-turbo/jidctfst.o \
	src/libjpeg-turbo/jidctint.o src/libjpeg-turbo/jidctred.o src/libjpeg-turbo/jmemmgr.o src/libjpeg-turbo/jmemnobs.o \
	src/libjpeg-turbo/jquant1.o src/libjpeg-turbo/jquant2.o src/libjpeg-turbo/jsimd_none.o src/libjpeg-turbo/jutils.o

LIBPNG_OBJS = \
	src/libpng/pngerror.o src/libpng/pngget.o src/libpng/pngmem.o src/libpng/png.o src/libpng/pngread.o src/libpng/pngrio.o \
	src/libpng/pngrtran.o src/libpng/pngrutil.o src/libpng/pngset.o src/libpng/pngtrans.o src/libpng/pngwio.o \
	src/libpng/pngwrite.o src/libpng/pngwtran.o src/libpng/pngwutil.o

DUKTAPE_OBJS = \
	src/duktape/duktape.o

SPEEX_OBJS = \
	src/speex/resample.o

ZLIB_OBJS = \
	src/zlib/adler32.o src/zlib/crc32.o src/zlib/deflate.o src/zlib/inffast.o src/zlib/inflate.o src/zlib/inftrees.o \
	src/zlib/trees.o src/zlib/zutil.o

JS_HEADERS = \
	src/runtime/boot.js.gz.h src/runtime/rtl/rtl.js.gz.h

PAS_HEADERS = \
	src/runtime/rtl/classes.js.gz.h src/runtime/rtl/js.js.gz.h src/runtime/rtl/rtlconsts.js.gz.h src/runtime/rtl/system.js.gz.h \
	src/runtime/rtl/sysutils.js.gz.h src/runtime/rtl/types.js.gz.h src/runtime/rtl/typinfo.js.gz.h \
	src/runtime/units/controls.js.gz.h src/runtime/units/extctrls.js.gz.h src/runtime/units/fmod.js.gz.h \
	src/runtime/units/fmodtypes.js.gz.h src/runtime/units/forms.js.gz.h src/runtime/units/graphics.js.gz.h src/runtime/units/menus.js.gz.h \
	src/runtime/units/registry.js.gz.h src/runtime/units/stdctrls.js.gz.h src/runtime/units/windows.js.gz.h

HH2_OBJS = \
	src/core/libretro.o src/engine/canvas.o src/engine/djb2.o src/engine/filesys.o src/engine/image.o src/engine/log.o \
	src/engine/pixelsrc.o src/engine/sound.o src/engine/sprite.o src/runtime/module.o src/runtime/state.o src/version.o

all: src/generated/version.h hh2_libretro.so

hh2_libretro.so: $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(DUKTAPE_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS) $(HH2_OBJS)
	$(CC) -shared -o $@ $+ $(LIBS)

src/generated/version.h: FORCE
	cat etc/version.templ.h \
		| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
		| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

src/runtime/module.o: src/runtime/module.c $(JS_HEADERS) $(PAS_HEADERS)

src/runtime/state.o: src/runtime/state.c src/runtime/bootstrap.js.h

test/test: test/main.o $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(DUKTAPE_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS) $(HH2_OBJS)
	$(CC) -o $@ $+ $(LIBS)

test/main.o: src/generated/version.h

test/test.hh2: FORCE
	lua etc/riff.lua $@ Makefile test/cryptopunk32.png test/cryptopunk32.jpg test/tick.wav test/bsenc.bs

clean: FORCE
	rm -f hh2_libretro.so $(HH2_OBJS)
	rm -f src/generated/version.h src/runtime/bootstrap.js.h $(JS_HEADERS) $(PAS_HEADERS)
	rm -f test/test test/main.o test/test.hh2 test/cryptopunk32.data

distclean: clean
	rm -f $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(DUKTAPE_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS)

.PHONY: FORCE
