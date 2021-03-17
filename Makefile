%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@

CC ?= gcc
CFLAGS = -std=c99 -Wall -Wpedantic -Werror -fPIC
DEFINES = -DHH2_ENABLE_LOGGING -DWITH_MEM_SRCDST=0
INCLUDES = -Isrc -Isrc/engine -Isrc/generated -Isrc/libjpeg-turbo -Isrc/libpng -Isrc/zlib
LIBS = -lm

ifeq ($(DEBUG), 1)
	CFLAGS += -O0 -g -DHH2_DEBUG $(DEFINES)
else
	CFLAGS += -O3 -DHH2_RELEASE -DNDEBUG $(DEFINES)
endif

LIBPNG_OBJ_FILES = \
	src/libpng/pngerror.o  src/libpng/pngget.o  src/libpng/pngmem.o  src/libpng/png.o  src/libpng/pngread.o  src/libpng/pngrio.o \
	src/libpng/pngrtran.o  src/libpng/pngrutil.o  src/libpng/pngset.o  src/libpng/pngtrans.o src/libpng/pngwio.o \
	src/libpng/pngwrite.o src/libpng/pngwtran.o src/libpng/pngwutil.o

ZLIB_OBJ_FILES = \
	src/zlib/adler32.o src/zlib/crc32.o src/zlib/deflate.o src/zlib/inffast.o src/zlib/inflate.o src/zlib/inftrees.o \
	src/zlib/trees.o src/zlib/zutil.o

LIBJPEG_OBJ_FILES = \
	src/libjpeg-turbo/jaricom.o src/libjpeg-turbo/jcomapi.o src/libjpeg-turbo/jdapimin.o src/libjpeg-turbo/jdapistd.o \
	src/libjpeg-turbo/jdarith.o src/libjpeg-turbo/jdcoefct.o src/libjpeg-turbo/jdcolor.o src/libjpeg-turbo/jddctmgr.o \
	src/libjpeg-turbo/jdhuff.o src/libjpeg-turbo/jdinput.o src/libjpeg-turbo/jdmainct.o src/libjpeg-turbo/jdmarker.o \
	src/libjpeg-turbo/jdmaster.o src/libjpeg-turbo/jdmerge.o src/libjpeg-turbo/jdphuff.o src/libjpeg-turbo/jdpostct.o \
	src/libjpeg-turbo/jdsample.o src/libjpeg-turbo/jerror.o src/libjpeg-turbo/jidctflt.o src/libjpeg-turbo/jidctfst.o \
	src/libjpeg-turbo/jidctint.o src/libjpeg-turbo/jidctred.o src/libjpeg-turbo/jmemmgr.o src/libjpeg-turbo/jmemnobs.o \
	src/libjpeg-turbo/jquant1.o src/libjpeg-turbo/jquant2.o src/libjpeg-turbo/jsimd_none.o src/libjpeg-turbo/jutils.o

HH2_OBJS = \
	src/engine/canvas.o src/engine/djb2.o src/engine/filesys.o src/engine/image.o src/engine/log.o src/engine/pixelsrc.o

all: src/version.h hh2_libretro.so

hh2_libretro.so: $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES) $(LIBJPEG_OBJ_FILES) $(HH2_OBJS)
	$(CC) -shared -o $@ $+ $(LIBS)

src/version.h: FORCE
	cat etc/version.templ.h \
		| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
		| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

test/test: test/main.o $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES) $(LIBJPEG_OBJ_FILES) $(HH2_OBJS)
	$(CC) -o $@ $+ $(LIBS)

test/main.o: src/version.h

test/test.hh2: FORCE
	lua etc/riff.lua $@ Makefile test/cryptopunk32.png test/cryptopunk32.jpg

clean: FORCE
	rm -f hh2_libretro.so $(HH2_OBJS)
	rm -f src/version.h
	rm -f test/test test/main.o test/test.hh2 test/cryptopunk32.data

distclean: clean
	rm -f $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES) $(LIBJPEG_OBJ_FILES)

.PHONY: FORCE
