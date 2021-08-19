#!/bin/sh

BASEDIR=$(dirname "$0")

generate() {
    LUA_PATH="$LUAMODS/access/src/?.lua;$LUAMODS/inifile/src/?.lua" \
    LUA_CPATH="$LUAMODS/proxyud/src/?.so;$LUAMODS/ddlt/?.so" \
    lua $BASEDIR/packgame.lua --settings $1 > $1/hh2config.lua

    LUA_PATH="$LUAMODS/access/src/?.lua;$LUAMODS/inifile/src/?.lua;../etc/?.lua" \
    LUA_CPATH="$LUAMODS/proxyud/src/?.so;$LUAMODS/ddlt/?.so" \
    lua $BASEDIR/dfm2pas.lua $1/unit1.dfm > $1/hh2dfm.pas

    LUA_PATH="$LUAMODS/access/src/?.lua;$LUAMODS/inifile/src/?.lua;../etc/?.lua" \
    LUA_CPATH="$LUAMODS/proxyud/src/?.so;$LUAMODS/ddlt/?.so" \
    lua $BASEDIR/packgame.lua --makefile $1 > Makefile.$1

    LUA_PATH="$LUAMODS/access/src/?.lua;$LUAMODS/inifile/src/?.lua;../etc/?.lua" \
    LUA_CPATH="$LUAMODS/proxyud/src/?.so;$LUAMODS/ddlt/?.so" \
    lua $BASEDIR/packgame.lua --gfxinit $1 > gfxinit.$1.pas
}

generate popeye
