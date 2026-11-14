#!/system/bin/sh
MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID

# lepas semua bind mount & pulihkan prop asli sebelum modul hilang
[ -f "$MODDIR/bin/cpufakex.sh" ] && sh "$MODDIR/bin/cpufakex.sh" restore >/dev/null 2>&1

[ -f "$NZ/$MODID/daemon.pid" ] && kill "$(cat "$NZ/$MODID/daemon.pid")" 2>/dev/null
pkill -f "cpufakex.sh daemon" 2>/dev/null
rm -rf "$NZ/$MODID"
