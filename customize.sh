#!/system/bin/sh
# info installer — tidak boleh abort

ui_print() { echo "$1"; }

ui_print " "
ui_print "  CPUFakeX v1.0 — eLSanz"
ui_print "  target : Snapdragon 8 Elite Extreme Gen 6"
ui_print "  model  : SM8950 / sunridge"
ui_print " "
ui_print "  lapisan spoof:"
ui_print "   - system.prop (ro.soc.model, ro.board.platform, chipname)"
ui_print "   - /proc/cpuinfo (8 core, part 0x002, features)"
ui_print "   - device-tree model + /sys/devices/soc0"
ui_print "   - cpufreq cpuinfo_max_freq (2 prime 4.75GHz / 6 perf 4.2GHz)"
ui_print " "

_cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
_p=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
_k=$(uname -r 2>/dev/null)
ui_print "  device asli : ${_p:-?} (${_cores:-?} core)"
ui_print "  kernel      : ${_k:-?}"
ui_print "  root        : $([ -x /data/adb/ksu/bin/ksud ] && echo KernelSU || echo Magisk/APatch)"
ui_print " "
ui_print "  WebUI: buka modul dari manager (KernelSU/APatch/MMRL)"
ui_print "  CLI  : sh $MODPATH/bin/cpufakex.sh status|check|apply|restore"
ui_print " "
