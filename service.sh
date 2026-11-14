#!/system/bin/sh
MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID
CFG=$NZ/$MODID
SH=$MODDIR/bin/cpufakex.sh

mkdir -p "$CFG" 2>/dev/null
[ -s "$CFG/config.conf" ] || cp -f "$MODDIR/defaults.conf" "$CFG/config.conf" 2>/dev/null

# tunggu boot selesai
_i=0
while [ "$_i" -lt 120 ]; do
  _bc=""
  for _g in getprop /system/bin/getprop; do
    _bc=$($_g sys.boot_completed 2>/dev/null) && break
  done
  [ "$_bc" = "1" ] && break
  sleep 1
  _i=$((_i+1))
done
sleep 3

# layer props + mount harus sudah aktif sebelum app pertama dibaca
sh "$SH" apply >/dev/null 2>&1
exec sh "$SH" daemon
