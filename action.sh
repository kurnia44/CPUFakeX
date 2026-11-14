#!/system/bin/sh
# CPUFakeX — tombol Action di manager (KernelSU / APatch / Magisk).
# Manager tidak memberi terminal interaktif, jadi action = status + apply + check.
# Tanpa getevent: volume key tidak bisa dibaca dari konteks ini di banyak device.

MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID
SH=$MODDIR/bin/cpufakex.sh

if [ ! -f "$SH" ]; then
  printf '! CPUFakeX: script tidak ditemukan\n  %s\n' "$SH"
  exit 1
fi

printf '\n== CPUFakeX ==\n'
sh "$SH" status
printf '\n== apply ==\n'
sh "$SH" apply
printf '\n'
sh "$SH" check
printf '\nTekan lagi untuk apply ulang. Restore: CLI cpufakex.sh restore\n'
