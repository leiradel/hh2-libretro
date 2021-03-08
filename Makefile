%.o: %.c
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@

CC ?= gcc
CFLAGS = -std=c99 -Wall -Wpedantic -Werror -fPIC
INCLUDES = -Isrc
LIBS = -lm

ifeq ($(DEBUG), 1)
	CFLAGS += -O0 -g -DHH2_DEBUG
else
	CFLAGS += -O3 -DHH2_RELEASE -DNDEBUG
endif

OBJS = \
	src/djb2.o \
	src/filesys.o \
	src/log.o

all: src/version.h hh2_libretro.so

hh2_libretro.so: $(OBJS)
	$(CC) -shared -o $@ $+ $(LIBS)

src/version.h: FORCE
	#cat etc/version.templ.h \
	#	| sed s/\&HASH/`git rev-parse HEAD | tr -d "\n"`/g \
	#	| sed s/\&VERSION/`git tag | sort -r -V | head -n1 | tr -d "\n"`/g \
	#	| sed s/\&DATE/`date -Iseconds`/g \
	#	> $@
	cat etc/version.templ.h \
		| sed s/\&HASH/0000000000000000000000000000000000000000/g \
		| sed s/\&VERSION/0.0.1/g \
		| sed s/\&DATE/`date -Iseconds`/g \
		> $@

test/test: test/main.o $(OBJS)
		$(CC) -o $@ $+ $(LIBS)

clean: FORCE
	rm -f hh2_libretro.so $(OBJS)
	rm -f src/version.h
	rm -f test/test test/main.o

.PHONY: FORCE
