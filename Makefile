%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@

CC ?= gcc
CFLAGS = -std=c99 -Wall -Wpedantic -Werror -fPIC
INCLUDES = -Isrc -Isrc/libpng
LIBS = -lm

ifeq ($(DEBUG), 1)
	CFLAGS += -O0 -g -DHH2_DEBUG
else
	CFLAGS += -O3 -DHH2_RELEASE -DNDEBUG
endif

LIBPNG_OBJ_FILES = \
	src/libpng/png.o \
	src/libpng/pngerror.o \
	src/libpng/pngget.o \
	src/libpng/pngmem.o \
	src/libpng/pngread.o \
	src/libpng/pngrio.o \
	src/libpng/pngrtran.o \
	src/libpng/pngrutil.o \
	src/libpng/pngset.o \
	src/libpng/pngtrans.o \
	src/libpng/pngwio.o \
	src/libpng/pngwrite.o \
	src/libpng/pngwtran.o \
	src/libpng/pngwutil.o

ZLIB_OBJ_FILES = \
	src/zlib/adler32.o \
	src/zlib/crc32.o \
	src/zlib/deflate.o \
	src/zlib/inffast.o \
	src/zlib/inflate.o \
	src/zlib/inftrees.o \
	src/zlib/trees.o \
	src/zlib/zutil.o

HH2_OBJS = \
	src/djb2.o \
	src/filesys.o \
	src/image.o \
	src/log.o

all: src/version.h hh2_libretro.so

hh2_libretro.so: $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES) $(HH2_OBJS)
	$(CC) -shared -o $@ $+ $(LIBS)

src/version.h: FORCE
	cat etc/version.templ.h \
		| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
		| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

test/test: test/main.o $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES) $(HH2_OBJS)
	$(CC) -o $@ $+ $(LIBS)

test/main.o: src/version.h

test/test.hh2: FORCE
	lua etc/riff.lua $@ Makefile test/cryptopunk32.png

clean: FORCE
	rm -f hh2_libretro.so $(HH2_OBJS)
	rm -f src/version.h
	rm -f test/test test/main.o

distclean: clean
		rm -f $(LIBPNG_OBJ_FILES) $(ZLIB_OBJ_FILES)

.PHONY: FORCE
