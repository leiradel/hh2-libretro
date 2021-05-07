#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "USAGE: $0 <input.pas>"
    echo
    exit 1
fi

pas2js -vz -O2 -dHH2 -Fu"`dirname $0`/../src/runtime/rtl/" -Fu"`dirname $0`/../src/runtime/units/" -Mdelphi -Pecmascript5 -Tnodejs \
-Jl -Jeconsole -Jrunit -JRjs -Jirtl.js- -o. "$1" | lua "`dirname $0`/extmodule.lua" `basename $1 .pas`
