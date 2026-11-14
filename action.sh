#!/system/bin/sh
MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID
SH=$MODDIR/bin/cpufakex.sh

# action button Magisk: menu volume-key, tanpa UI
[ -f "$SH" ] || exit 0
sh "$SH" status
printf '\n[+] VOLUME+ = apply | VOLUME- = restore\n'

TMP=/dev/tmp_cpufakex
: > "$TMP" 2>/dev/null
getevent -c 40 > "$TMP" 2>/dev/null &
_i=0
_choice=""
while [ "$_i" -lt 100 ]; do
  if grep -q 'KEY_VOLUMEUP.*DOWN' "$TMP" 2>/dev/null; then _choice=up; break; fi
  if grep -q 'KEY_VOLUMEDOWN.*DOWN' "$TMP" 2>/dev/null; then _choice=down; break; fi
  sleep 0.3
  _i=$((_i+1))
done
pkill -f "getevent -c 40" 2>/dev/null
rm -f "$TMP"

case "$_choice" in
  up) sh "$SH" apply; printf '\n[ok] apply\n' ;;
  down) sh "$SH" restore; printf '\n[ok] restore\n' ;;
  *) printf '\n[!] tidak ada input\n' ;;
esac
sh "$SH" check
