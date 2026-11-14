#!/system/bin/sh
# CPUFakeX — post-fs-data: jalan SEBELUM zygote, jadi semua app mewarisi mount.
MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID
CFG=$NZ/$MODID
SH=$MODDIR/bin/cpufakex.sh

mkdir -p "$CFG" "$CFG/fake" 2>/dev/null
[ -s "$CFG/config.conf" ] || cp -f "$MODDIR/defaults.conf" "$CFG/config.conf" 2>/dev/null
chmod 600 "$CFG/config.conf" 2>/dev/null
chmod 755 "$SH" 2>/dev/null

# mount di namespace init → diwarisi zygote + semua app turunannya
[ -x "$SH" ] && sh "$SH" apply >/dev/null 2>&1

exit 0
