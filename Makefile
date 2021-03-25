%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) -c "$<" -o "$@"

%.lua.h: %.lua
	echo "static char const `basename "$<" | sed 's/\./_/'`[] = {\n`cat "$<" | xxd -i`\n};" > "$@"

%.bs: %.lua
	$(LUA) etc/bsenc.lua $< $@

CC ?= gcc
CFLAGS = -std=c99 -Wall -Wpedantic -Werror -fPIC

DEFINES = \
	-DHH2_ENABLE_LOGGING \
	-DWITH_MEM_SRCDST=0 \
	-DLUA_USE_JUMPTABLE=0 \
	-DOUTSIDE_SPEEX -DRANDOM_PREFIX=speex -DEXPORT= -D_USE_SSE -D_USE_SSE2 -DFLOATING_POINT

INCLUDES = \
	-Isrc -Isrc/dr_libs -Isrc/engine -Isrc/generated -Isrc/libjpeg-turbo -Isrc/libpng -Isrc/lua -Isrc/speex -Isrc/runtime \
	-Isrc/zlib

LIBS = -lm
LUA ?= lua

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
	src/libpng/pngerror.o  src/libpng/pngget.o  src/libpng/pngmem.o  src/libpng/png.o  src/libpng/pngread.o  src/libpng/pngrio.o \
	src/libpng/pngrtran.o  src/libpng/pngrutil.o  src/libpng/pngset.o  src/libpng/pngtrans.o src/libpng/pngwio.o \
	src/libpng/pngwrite.o src/libpng/pngwtran.o src/libpng/pngwutil.o

LUA_OBJS = \
    src/lua/lapi.o src/lua/lcode.o src/lua/lctype.o src/lua/ldebug.o  src/lua/ldo.o src/lua/ldump.o src/lua/lfunc.o src/lua/lgc.o \
    src/lua/llex.o src/lua/lmem.o src/lua/lobject.o src/lua/lopcodes.o src/lua/lparser.o  src/lua/lstate.o src/lua/lstring.o \
    src/lua/ltable.o src/lua/ltm.o src/lua/lundump.o src/lua/lvm.o src/lua/lzio.o src/lua/lauxlib.o src/lua/lbaselib.o \
    src/lua/lcorolib.o src/lua/ldblib.o src/lua/liolib.o src/lua/lmathlib.o src/lua/loslib.o src/lua/lstrlib.o src/lua/ltablib.o \
    src/lua/lutf8lib.o src/lua/loadlib.o src/lua/linit.o

SPEEX_OBJS = \
	src/speex/resample.o

ZLIB_OBJS = \
	src/zlib/adler32.o src/zlib/crc32.o src/zlib/deflate.o src/zlib/inffast.o src/zlib/inflate.o src/zlib/inftrees.o \
	src/zlib/trees.o src/zlib/zutil.o

LUA_HEADERS = \
	src/runtime/units/classes.lua.h src/runtime/units/controls.lua.h src/runtime/units/dialogs.lua.h \
	src/runtime/units/extctrls.lua.h src/runtime/units/fmod.lua.h src/runtime/units/fmodtypes.lua.h src/runtime/units/forms.lua.h \
	src/runtime/units/graphics.lua.h src/runtime/units/jpeg.lua.h src/runtime/units/math.lua.h src/runtime/units/messages.lua.h \
	src/runtime/units/registry.lua.h src/runtime/units/stdctrls.lua.h src/runtime/units/sysutils.lua.h \
	src/runtime/units/windows.lua.h

HH2_OBJS = \
	src/core/libretro.o src/engine/canvas.o src/engine/djb2.o src/engine/filesys.o src/engine/image.o src/engine/log.o \
	src/engine/pixelsrc.o src/engine/sound.o src/engine/sprite.o src/runtime/bsreader.o src/runtime/module.o \
	src/runtime/searcher.o src/runtime/state.o src/version.o

all: src/generated/version.h hh2_libretro.so

hh2_libretro.so: $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(LUA_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS) $(HH2_OBJS)
	$(CC) -shared -o $@ $+ $(LIBS)

src/generated/version.h: FORCE
	cat etc/version.templ.h \
		| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
		| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

src/runtime/state.o: src/runtime/state.c src/runtime/bootstrap.lua.h

src/runtime/searcher.o: $(LUA_HEADERS)

test/test: test/main.o $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(LUA_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS) $(HH2_OBJS)
	$(CC) -o $@ $+ $(LIBS)

test/main.o: src/generated/version.h

test/test.hh2: FORCE
	lua etc/riff.lua $@ Makefile test/cryptopunk32.png test/cryptopunk32.jpg test/tick.wav test/bsenc.bs

clean: FORCE
	rm -f hh2_libretro.so $(HH2_OBJS)
	rm -f src/generated/version.h src/runtime/bootstrap.lua.h $(LUA_HEADERS)
	rm -f test/test test/main.o test/test.hh2 test/cryptopunk32.data

distclean: clean
	rm -f $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(LUA_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS)

.PHONY: FORCE
