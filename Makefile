ifeq ($(shell uname -s),)
    SOEXT=dll
    ECHO="echo -e"
else ifneq ($(findstring MINGW,$(shell uname -a)),)
    SOEXT=dll
    ECHO="echo -e"
else ifneq ($(findstring MSYS,$(shell uname -a)),)
    SOEXT=dll
    ECHO="echo -e"
else ifneq ($(findstring win,$(shell uname -a)),)
    SOEXT=dll
    ECHO="echo -e"
else ifneq ($(findstring Darwin,$(shell uname -a)),)
    SOEXT=dylib
    ECHO="echo"
else
    SOEXT=so
    ECHO="echo"
endif

%.o: %.c
	@$(ECHO) "Compiling: $@"
	@$(CC) $(INCLUDES) $(CFLAGS) -c "$<" -o "$@"

%.lua: %.pas
	@$(ECHO) "Transpiling to Lua: $@"
	@$(LUA) etc/pas2lua.lua -Isrc/runtime/units -DHH2 "$<" > "$@"

%.lua.h: %.lua
	@$(ECHO) "Creating header: $@"
	@$(ECHO) "static char const `basename "$<" | sed 's/\./_/'`[] = {\n`cat "$<" | xxd -i`\n};" > "$@"

%.luagz.h: %.lua
	@$(ECHO) "Creating compressed header: $@"
	@$(ECHO) "static uint8_t const `basename "$<" | sed 's/\./_/'`[] = {" > "$@"
	@$(ECHO) "  UINT32_C(`wc -c '$<' | sed 's/ .*//'`) & 0xff," >> "$@"
	@$(ECHO) "  (UINT32_C(`wc -c '$<' | sed 's/ .*//'`) >> 8) & 0xff," >> "$@"
	@$(ECHO) "  (UINT32_C(`wc -c '$<' | sed 's/ .*//'`) >> 16) & 0xff," >> "$@"
	@$(ECHO) "  (UINT32_C(`wc -c '$<' | sed 's/ .*//'`) >> 24) & 0xff," >> "$@"
	@cat "$<" | gzip -c9n | xxd -i >> "$@"
	@$(ECHO) "};\n" >> "$@"

CC ?= gcc
CFLAGS = -std=c99 -Wall -Wpedantic -Werror -fPIC

DEFINES = \
	-DHH2_ENABLE_LOGGING \
	-DWITH_MEM_SRCDST=0 \
	-DLUA_USE_JUMPTABLE=0 \
	-DOUTSIDE_SPEEX -DRANDOM_PREFIX=speex -DEXPORT= -D_USE_SSE -D_USE_SSE2 -DFLOATING_POINT

INCLUDES = \
	-Isrc -Isrc/crypto-algorithms -Isrc/dr_libs -Isrc/engine -Isrc/generated -Isrc/libjpeg-turbo -Isrc/libpng -Isrc/lua \
	-Isrc/speex -Isrc/runtime -Isrc/zlib

LIBS = -lm

LUA ?= \
	LUA_PATH="$$LUAMODS/access/src/?.lua;$$LUAMODS/inifile/src/?.lua;etc/?.lua" \
	LUA_CPATH="$$LUAMODS/proxyud/src/?.$(SOEXT);$$LUAMODS/ddlt/?.$(SOEXT)" \
	lua

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

LUA_OBJS = \
    src/lua/lapi.o src/lua/lauxlib.o src/lua/lbaselib.o src/lua/lcode.o src/lua/lcorolib.o src/lua/lctype.o src/lua/ldebug.o \
    src/lua/ldo.o src/lua/ldump.o src/lua/lfunc.o src/lua/lgc.o src/lua/llex.o src/lua/lmathlib.o src/lua/lmem.o src/lua/loadlib.o \
    src/lua/lobject.o src/lua/lopcodes.o src/lua/lparser.o src/lua/lstate.o src/lua/lstring.o src/lua/lstrlib.o src/lua/ltable.o \
    src/lua/ltablib.o src/lua/ltm.o src/lua/lundump.o src/lua/lutf8lib.o src/lua/lvm.o src/lua/lzio.o

AES_OBJS = \
	src/crypto-algorithms/aes.o

SPEEX_OBJS = \
	src/speex/resample.o

ZLIB_OBJS = \
	src/zlib/adler32.o src/zlib/crc32.o src/zlib/deflate.o src/zlib/inffast.o src/zlib/inflate.o src/zlib/inftrees.o \
	src/zlib/trees.o src/zlib/zutil.o

LUA_HEADERS = \
	src/runtime/boot.luagz.h src/runtime/runtime.luagz.h src/runtime/units/classes.luagz.h src/runtime/units/controls.luagz.h \
	src/runtime/units/dialogs.luagz.h src/runtime/units/extctrls.luagz.h src/runtime/units/fmod.luagz.h \
	src/runtime/units/fmodtypes.luagz.h src/runtime/units/forms.luagz.h src/runtime/units/graphics.luagz.h \
	src/runtime/units/hh2.luagz.h src/runtime/units/inifiles.luagz.h src/runtime/units/jpeg.luagz.h src/runtime/units/math.luagz.h \
	src/runtime/units/menus.luagz.h src/runtime/units/messages.luagz.h src/runtime/units/pngimage.luagz.h \
	src/runtime/units/registry.luagz.h src/runtime/units/shellapi.luagz.h src/runtime/units/stdctrls.luagz.h \
	src/runtime/units/system.luagz.h src/runtime/units/sysutils.luagz.h src/runtime/units/windows.luagz.h

HH2_OBJS = \
	src/core/libretro.o src/engine/canvas.o src/engine/djb2.o src/engine/filesys.o src/engine/image.o src/engine/log.o \
	src/engine/pixelsrc.o src/engine/sound.o src/engine/sprite.o src/runtime/module.o src/runtime/searcher.o src/runtime/state.o \
	src/runtime/uncomp.o src/version.o

all: src/generated/version.h hh2_libretro.$(SOEXT)

hh2_libretro.$(SOEXT): $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(LUA_OBJS) $(AES_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS) $(HH2_OBJS)
	@$(ECHO) "Linking: $@"
	@$(CC) -shared -o $@ $+ $(LIBS)

src/generated/version.h: FORCE
	@$(ECHO) "Creating version header: $@"
	@cat etc/version.templ.h \
		| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
		| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

src/runtime/boxybold.png.h: etc/boxy_bold_font_4x2.png
	@$(ECHO) "Creating header: $@"
	@$(ECHO) "static uint8_t const `basename "$<" | sed 's/\./_/'`[] = {\n`cat "$<" | xxd -i`\n};" > "$@"

src/runtime/module.o: src/runtime/boxybold.png.h

src/runtime/searcher.o: $(LUA_HEADERS)

src/runtime/state.o: src/runtime/state.c src/runtime/bootstrap.lua.h

clean: FORCE
	@$(ECHO) "Cleaning up"
	@rm -f hh2_libretro.$(SOEXT) $(HH2_OBJS)
	@rm -f src/generated/version.h src/runtime/bootstrap.lua.h src/runtime/boxybold.png.h $(LUA_HEADERS)

distclean: clean
	@$(ECHO) "Cleaning up (including 3rd party libraries)"
	@rm -f $(LIBJPEG_OBJS) $(LIBPNG_OBJS) $(LUA_OBJS) $(AES_OBJS) $(SPEEX_OBJS) $(ZLIB_OBJS)

.PHONY: FORCE
