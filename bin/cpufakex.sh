#!/system/bin/sh
# CPUFakeX — spoof SoC total. POSIX sh, tanpa bashism.

MODID=cpufakex
NZ=${NVBASE:-/data/adb}
MODDIR=$NZ/modules/$MODID
CFG=$NZ/$MODID
CONF=$CFG/config.conf
FAKE=$CFG/fake
LOG=$CFG/module.log
STATE=$CFG/state
ORIG=$CFG/orig.props
PID=$CFG/daemon.pid
MOUNTLIST=$CFG/mounts.list

mkdir -p "$FAKE" 2>/dev/null

log() { printf '%s %s\n' "$(date '+%m-%d %H:%M:%S' 2>/dev/null)" "$*" >> "$LOG"; }
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 600 ]; then
  tail -300 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi

getv() { awk -v k="$1" 'index($0,k"=")==1{sub(/^[^=]*=/,"");print;exit}' "$CONF" 2>/dev/null; }
setv() { K="$1" V="$2" awk 'BEGIN{k=ENVIRON["K"];v=ENVIRON["V"];d=0}
  index($0,k"=")==1{if(!d){print k"="v;d=1};next}{print}END{if(!d)print k"="v}' "$CONF" > "$CONF.new" && mv "$CONF.new" "$CONF"; }
unsetk() { K="$1" awk 'BEGIN{k=ENVIRON["K"]}index($0,k"=")==1{next}{print}' "$CONF" > "$CONF.new" && mv "$CONF.new" "$CONF"; }

SELFDIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

seed() {
  [ -d "$CFG" ] || mkdir -p "$CFG"
  [ -d "$FAKE" ] || mkdir -p "$FAKE"
  if [ ! -s "$CONF" ]; then
    for _s in "$MODDIR/defaults.conf" "$SELFDIR/../defaults.conf" "$SELFDIR/defaults.conf"; do
      [ -s "$_s" ] && { cp -f "$_s" "$CONF" 2>/dev/null; break; }
    done
  fi
  chmod 600 "$CONF" 2>/dev/null
}

seed

# ---------- resetprop ----------
RP=""
find_rp() {
  [ -n "$RP" ] && return 0
  for _c in /data/adb/ksu/bin/resetprop /data/adb/ap/bin/resetprop \
            /data/adb/magisk/resetprop /data/adb/modules/magisk/resetprop /data/adb/ksud; do
    [ -x "$_c" ] && { RP="$_c -n"; return 0; }
  done
  if command -v resetprop >/dev/null 2>&1; then RP="resetprop -n"; return 0; fi
  if [ -x /data/adb/ksu/bin/ksud ]; then RP="/data/adb/ksu/bin/ksud resetprop"; return 0; fi
  if [ -x /data/adb/ksu/bin/busybox ]; then RP="/data/adb/ksu/bin/busybox resetprop -n"; return 0; fi
  if [ -x /data/adb/magisk/busybox ]; then RP="/data/adb/magisk/busybox resetprop -n"; return 0; fi
  return 1
}
putprop() {
  [ -n "$2" ] || return 1
  if find_rp; then $RP "$1" "$2" >/dev/null 2>&1 && return 0; fi
  setprop "$1" "$2" >/dev/null 2>&1
}
delprop() { find_rp && $RP -d "$1" >/dev/null 2>&1 && return 0; return 1; }

saveorig() {
  grep -q "^$1=" "$ORIG" 2>/dev/null && return 0
  _ov=$(getprop "$1" 2>/dev/null)
  printf '%s=%s\n' "$1" "$_ov" >> "$ORIG" 2>/dev/null
}

# ---------- nilai turunan ----------
num() { case "$1" in ''|*[!0-9]*) printf '%s' "$2" ;; *) printf '%s' "$1" ;; esac; }

CORES=$(num "$(getv cores)" 8)
PRIME_N=$(num "$(getv prime_cores)" 2)
PRIME_MAX=$(num "$(getv prime_max)" 4752000)
PERF_MAX=$(num "$(getv perf_max)" 4200000)
MIN_FREQ=$(num "$(getv min_freq)" 300000)
[ "$CORES" -lt 1 ] && CORES=8
[ "$PRIME_N" -gt "$CORES" ] && PRIME_N=$CORES

freq_of() {
  _o=$(getv "freq.cpu$1")
  case "$_o" in ''|*[!0-9]*) : ;; *) printf '%s' "$_o"; return 0 ;; esac
  if [ "$1" -ge $((CORES - PRIME_N)) ]; then printf '%s' "$PRIME_MAX"; else printf '%s' "$PERF_MAX"; fi
}

is_prime() { [ "$1" -ge $((CORES - PRIME_N)) ] && return 0; return 1; }

# ---------- generasi file palsu ----------
chcon_fake() {
  for _f in "$FAKE"/*; do
    [ -e "$_f" ] || continue
    chcon u:object_r:proc_cpuinfo:s0 "$_f" 2>/dev/null || \
    chcon u:object_r:proc:s0 "$_f" 2>/dev/null || true
  done
}

build_fakes() {
  _f=$FAKE/cpuinfo
  : > "$_f"
  _i=0
  while [ "$_i" -lt "$CORES" ]; do
    if is_prime "$_i"; then
      _var=$(getv prime_variant); _part=$(getv prime_part)
    else
      _var=$(getv cpu_variant); _part=$(getv cpu_part)
    fi
    [ -n "$_var" ] || _var=$(getv cpu_variant)
    [ -n "$_part" ] || _part=$(getv cpu_part)
    {
      printf 'processor\t: %s\n' "$_i"
      printf 'BogoMIPS\t: %s\n' "$(getv bogomips)"
      printf 'Features\t: %s\n' "$(getv cpu_features)"
      printf 'CPU implementer\t: 0x51\n'
      printf 'CPU architecture: 8\n'
      printf 'CPU variant\t: %s\n' "$_var"
      printf 'CPU part\t: %s\n' "$_part"
      printf 'CPU revision\t: 4\n'
      printf '\n'
    } >> "$_f"
    _i=$((_i+1))
  done

  printf '%s' "$(getv dt_model)" 2>/dev/null > "$FAKE/dt_model"
  printf '%s' "$(getv soc_machine)" 2>/dev/null > "$FAKE/soc_machine"
  printf '%s' "$(getv soc_family)" 2>/dev/null > "$FAKE/soc_family"

  _i=0
  while [ "$_i" -lt "$CORES" ]; do
    printf '%s' "$(freq_of "$_i")" 2>/dev/null > "$FAKE/maxfreq.$_i"
    printf '%s' "$MIN_FREQ" 2>/dev/null > "$FAKE/minfreq.$_i"
    _i=$((_i+1))
  done

  chmod 644 "$FAKE"/* 2>/dev/null
  chcon_fake
  log "fakes: $CORES core, prime=$PRIME_MAX perf=$PERF_MAX (part $(getv prime_part)/$(getv cpu_part))"
}

# ---------- namespace target ----------
# mount harus masuk ke ns init DAN ns zygote, kalau tidak app yang sudah
# jalan tidak pernah melihat file pengganti.
ns_pids() {
  printf '1\n'
  _p=$(pidof zygote64 2>/dev/null || true)
  for _x in $_p; do printf '%s\n' "$_x"; done
  _p=$(pidof zygote 2>/dev/null || true)
  for _x in $_p; do printf '%s\n' "$_x"; done
  if [ -z "$(pidof zygote64 2>/dev/null)$(pidof zygote 2>/dev/null)" ]; then
    ps -A -o PID,NAME 2>/dev/null | awk '/zygote/{print $1}' | while read -r _z; do printf '%s\n' "$_z"; done
  fi
}

have_nsenter() { command -v nsenter >/dev/null 2>&1; }

_ns_mount() { # $1 src $2 dst
  _src=$1; _dst=$2; _ok=0
  if have_nsenter; then
    for _p in $(ns_pids); do
      [ "$_p" = "$$" ] && continue
      nsenter -t "$_p" -m -- mount -o bind "$_src" "$_dst" >/dev/null 2>>"$LOG" && _ok=$((_ok+1))
    done
  fi
  if [ "$_ok" -eq 0 ]; then
    mount -o bind "$_src" "$_dst" >/dev/null 2>>"$LOG" && _ok=1
  fi
  [ "$_ok" -gt 0 ] && return 0
  return 1
}

_ns_umount() { # $1 dst
  _dst=$1; _ok=0
  if have_nsenter; then
    for _p in $(ns_pids); do
      [ "$_p" = "$$" ] && continue
      nsenter -t "$_p" -m -- umount "$_dst" >/dev/null 2>&1 && _ok=$((_ok+1))
    done
  fi
  umount "$_dst" >/dev/null 2>&1 && _ok=$((_ok+1))
  [ "$_ok" -gt 0 ] && return 0
  return 1
}

_dstreal() { [ -L "$1" ] && readlink -f "$1" 2>/dev/null || printf '%s' "$1"; }

bind_to() { # $1 src $2 dst
  _src=$1; _dst=$2
  [ -e "$_dst" ] || return 1
  _ns_umount "$_dst" 2>/dev/null
  if _ns_mount "$_src" "$_dst"; then
    printf '%s -> %s\n' "$_src" "$_dst" >> "$MOUNTLIST" 2>/dev/null
    log "bind ok: $_dst"
    return 0
  fi
  log "bind GAGAL: $_dst"
  return 1
}

unbind() { [ -e "$1" ] || return 0; _ns_umount "$1" && log "unmount: $1"; }

mount_layer() {
  : > "$MOUNTLIST" 2>/dev/null
  _count=0
  if [ "$(getv spoof_cpuinfo)" = "1" ]; then
    bind_to "$FAKE/cpuinfo" /proc/cpuinfo && _count=$((_count+1))
  fi
  if [ "$(getv spoof_devicetree)" = "1" ]; then
    for _d in /proc/device-tree/model /sys/firmware/devicetree/base/model; do
      [ -e "$_d" ] && { bind_to "$FAKE/dt_model" "$(_dstreal "$_d")" && _count=$((_count+1)); }
    done
  fi
  if [ "$(getv spoof_soc)" = "1" ]; then
    for _pair in machine:soc_machine family:soc_family; do
      _k=${_pair%%:*}; _s=${_pair##*:}
      [ -e "/sys/devices/soc0/$_k" ] && { bind_to "$FAKE/$_s" "/sys/devices/soc0/$_k" && _count=$((_count+1)); }
    done
  fi
  if [ "$(getv spoof_cpufreq)" = "1" ]; then
    # cpuN/cpufreq adalah symlink ke policyN — resolusi dulu, satu bind per policy
    _seen=" "
    _i=0
    while [ "$_i" -lt "$CORES" ]; do
      _f=/sys/devices/system/cpu/cpu$_i/cpufreq/cpuinfo_max_freq
      if [ -e "$_f" ]; then
        _r=$(readlink -f "$_f" 2>/dev/null)
        [ -n "$_r" ] || _r=$_f
        case "$_seen" in
          *" $_r "*)
            ;;
          *)
            _seen="$_seen$_r "
            _rel=$(cat "/sys/devices/system/cpu/cpu$_i/cpufreq/related_cpus" 2>/dev/null)
            [ -n "$_rel" ] || _rel=$_i
            _best=0
            for _c in $_rel; do
              _v=$(freq_of "$_c")
              [ "$_v" -gt "$_best" ] 2>/dev/null && _best=$_v
            done
            [ "$_best" -gt 0 ] || _best=$(freq_of "$_i")
            printf '%s' "$_best" > "$FAKE/pol.$_i" 2>/dev/null
            chmod 644 "$FAKE/pol.$_i" 2>/dev/null
            bind_to "$FAKE/pol.$_i" "$_r" && _count=$((_count+1))
            ;;
        esac
      fi
      _i=$((_i+1))
    done
  fi
  printf '%s' "$_count"
}

unmount_layer() {
  if [ -s "$MOUNTLIST" ]; then
    while IFS= read -r _line; do
      _d=${_line##* -> }
      [ -n "$_d" ] && unbind "$_d"
    done < "$MOUNTLIST"
    : > "$MOUNTLIST" 2>/dev/null
  fi
  # sapu sisa (kalau mounts.list hilang)
  unbind /proc/cpuinfo
  for _d in /proc/device-tree/model /sys/firmware/devicetree/base/model; do
    [ -e "$_d" ] && unbind "$(_dstreal "$_d")"
  done
  unbind /sys/devices/soc0/machine
  unbind /sys/devices/soc0/family
  _i=0
  while [ "$_i" -lt 32 ]; do
    [ -e "/sys/devices/system/cpu/cpu$_i/cpufreq/cpuinfo_max_freq" ] && \
      unbind "$(readlink -f "/sys/devices/system/cpu/cpu$_i/cpufreq/cpuinfo_max_freq" 2>/dev/null)"
    _i=$((_i+1))
  done
  return 0
}

# ---------- props ----------
apply_props() {
  _n=0; _ok=0
  grep '^prop\.' "$CONF" 2>/dev/null > "$CFG/props.list"
  if [ ! -s "$CFG/props.list" ]; then printf '0/0'; return 0; fi
  while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _k=${_line%%=*}
    _v=${_line#*=}
    _k=${_k#prop.}
    [ -n "$_k" ] || continue
    _n=$((_n+1))
    saveorig "$_k"
    putprop "$_k" "$_v" && _ok=$((_ok+1))
  done < "$CFG/props.list"
  printf '%s/%s' "$_ok" "$_n"
}

restore_props() {
  [ -f "$ORIG" ] || return 0
  while IFS= read -r _line; do
    _rk=${_line%%=*}; _rv=${_line#*=}
    [ -n "$_rk" ] || continue
    if [ -n "$_rv" ]; then putprop "$_rk" "$_rv"; else delprop "$_rk"; fi
  done < "$ORIG"
  log "props asli dipulihkan"
}

# ---------- apply / restore ----------
sig() {
  { md5sum "$CONF" 2>/dev/null || cksum "$CONF" 2>/dev/null; } | awk '{print $1}'
}

apply() {
  [ "$(getv enabled)" = "1" ] || { log "disabled: skip"; printf 'disabled'; return 1; }
  build_fakes
  _m=$(mount_layer)
  _p="0/0"
  [ "$(getv spoof_props)" = "1" ] && _p=$(apply_props)
  printf 'apply=%s mounts=%s props=%s sig=%s\n' "$(date '+%s')" "$_m" "$_p" "$(sig)" > "$STATE" 2>/dev/null
  log "apply: mounts=$_m props=$_p"
  printf '%s|%s' "$_m" "$_p"
}

restore() {
  unmount_layer
  restore_props
  printf 'apply=0 mounts=0 props=0\n' > "$STATE" 2>/dev/null
  log "restore selesai"
  printf 'restored'
}

# ---------- status / check ----------
status() {
  _model=$(getprop ro.soc.model 2>/dev/null)
  _board=$(getprop ro.board.platform 2>/dev/null)
  _ci=$(awk -F': ' '/^CPU part/{print $2; exit}' /proc/cpuinfo 2>/dev/null | tr -d ' ')
  _dt=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
  _soc=$(tr -d '\0' < /sys/devices/soc0/machine 2>/dev/null)
  _mx=$(cat /sys/devices/system/cpu/cpu7/cpufreq/cpuinfo_max_freq 2>/dev/null)
  printf 'CPUFakeX  v1.1\n'
  printf 'target   : %s (%s)\n' "$(getv marketing)" "$(getv soc_model)"
  printf 'enabled  : %s\n' "$(getv enabled)"
  printf 'prop soc : %s | board %s\n' "${_model:-?}" "${_board:-?}"
  printf 'cpuinfo  : part %s (harap %s)\n' "${_ci:-?}" "$(getv cpu_part)"
  printf 'dt model : %s\n' "${_dt:-?}"
  printf 'soc0     : %s\n' "${_soc:-?}"
  printf 'cpu7 max : %s (harap %s)\n' "${_mx:-?}" "$(freq_of 7)"
  printf 'state    : %s\n' "$(cat "$STATE" 2>/dev/null)"
  printf 'daemon   : %s\n' "$(if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then printf 'hidup(%s)' "$(cat "$PID")"; else printf 'mati'; fi)"
}

check() {
  _v_prop=FAIL; _hit=0; _tot=0
  _pairs="ro.soc.model:$(getv soc_model) ro.board.platform:$(getv platform) ro.hardware:$(getv hardware)"
  for _pr in $_pairs; do
    _k=${_pr%%:*}; _e=${_pr##*:}
    [ -z "$_e" ] && continue
    _tot=$((_tot+1))
    [ "$(getprop "$_k" 2>/dev/null)" = "$_e" ] && _hit=$((_hit+1))
  done
  [ "$_tot" -gt 0 ] && [ "$_hit" -eq "$_tot" ] && _v_prop=OK
  [ "$_hit" -gt 0 ] && [ "$_hit" -lt "$_tot" ] && _v_prop=WARN

  _cn=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null)
  _v_ci=FAIL; _ci=""
  _core_bad=""
  _i=0
  while [ "$_i" -lt "$_cn" ]; do
    _pv=$(awk -v n="$_i" -F': ' '
      /^processor/{p=$2}
      /^CPU part/{if(p+0==n+0){print $2; exit}}' /proc/cpuinfo 2>/dev/null | tr -d ' ')
    [ -z "$_ci" ] && _ci=$_pv
    if is_prime "$_i"; then _exp=$(getv prime_part); else _exp=$(getv cpu_part); fi
    [ -n "$_exp" ] || _exp=$(getv cpu_part)
    [ "$_pv" = "$_exp" ] || _core_bad="$_core_bad cpu$_i=$_pv"
    _i=$((_i+1))
  done
  if [ -z "$_core_bad" ] && [ "$_cn" = "$CORES" ]; then _v_ci=OK
  elif [ -n "$_ci" ]; then _v_ci=WARN; fi

  _dt=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
  _v_dt=FAIL; [ "$_dt" = "$(getv dt_model)" ] && _v_dt=OK
  _soc=$(tr -d '\0' < /sys/devices/soc0/machine 2>/dev/null)
  _v_soc=FAIL; [ "$_soc" = "$(getv soc_machine)" ] && _v_soc=OK

  _v_fr=OK; _badfr=""
  if [ "$(getv spoof_cpufreq)" = "1" ]; then
    _i=0
    while [ "$_i" -lt "$CORES" ]; do
      _f=/sys/devices/system/cpu/cpu$_i/cpufreq/cpuinfo_max_freq
      if [ -e "$_f" ]; then
        _r=$(cat "$_f" 2>/dev/null)
        [ "$_r" = "$(freq_of "$_i")" ] || { _v_fr=FAIL; _badfr="$_badfr cpu$_i=$_r"; }
      fi
      _i=$((_i+1))
    done
  fi

  _pass=0; _fail=0
  for _x in $_v_prop $_v_ci $_v_dt $_v_soc $_v_fr; do
    [ "$_x" = "OK" ] && _pass=$((_pass+1)) || _fail=$((_fail+1))
  done
  _verdict=OK
  [ "$_fail" -gt 0 ] && _verdict=WARN
  [ "$_fail" -ge 3 ] && _verdict=FAIL

  printf 'check.verdict=%s\n' "$_verdict"
  printf 'check.props=%s (%s/%s)\n' "$_v_prop" "$_hit" "$_tot"
  printf 'check.cpuinfo=%s (%s core)%s\n' "$_v_ci" "${_cn:-0}" "$_core_bad"
  printf 'check.devicetree=%s\n' "$_v_dt"
  printf 'check.soc0=%s\n' "$_v_soc"
  printf 'check.cpufreq=%s%s\n' "$_v_fr" "$_badfr"
  printf 'check.target=%s %s\n' "$(getv soc_model)" "$(getv marketing)"
  printf 'check.msg=prop %s/%s | cpuinfo %s | dt %s | soc0 %s | freq %s\n' \
    "$_hit" "$_tot" "$_v_ci" "$_v_dt" "$_v_soc" "$_v_fr"
}

dump() {
  _d=$(cat "$STATE" 2>/dev/null)
  printf 'rt.enabled=%s\n' "$(getv enabled)"
  printf 'rt.resetprop=%s\n' "$(find_rp && printf 'ada' || printf 'tidak')"
  printf 'rt.daemon=%s\n' "$(if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then printf '1'; else printf '0'; fi)"
  printf 'rt.mounts=%s\n' "$(printf '%s' "$_d" | sed -n 's/.*mounts=\([^ ]*\).*/\1/p')"
  printf 'rt.props=%s\n' "$(printf '%s' "$_d" | sed -n 's/.*props=\([^ ]*\).*/\1/p')"
  printf 'rt.cpuinfo_part=%s\n' "$(awk -F': ' '/^CPU part/{print $2; exit}' /proc/cpuinfo 2>/dev/null | tr -d ' ')"
  printf 'rt.dt_model=%s\n' "$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
  printf 'rt.soc_model_prop=%s\n' "$(getprop ro.soc.model 2>/dev/null)"
  printf 'rt.marketing=%s\n' "$(getv marketing)"
  printf 'rt.ns_pids=%s\n' "$(ns_pids | tr '\n' ' ')"
  cat "$CONF"
}

# ---------- daemon ----------
daemon() {
  if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    log "daemon sudah jalan pid=$(cat "$PID")"; return 0
  fi
  printf '%s' "$$" > "$PID"
  log "daemon start pid=$$"
  _last=""
  _tick=0
  _force=0
  while :; do
    _iv=$(num "$(getv interval)" 60)
    [ "$_iv" -lt 10 ] && _iv=10
    if [ "$(getv enabled)" = "1" ]; then
      _s=$(sig)
      if [ "$_s" != "$_last" ] || [ "$_force" = "1" ]; then
        apply >/dev/null 2>&1
        _last=$_s; _tick=0; _force=0
      else
        # mount bisa hilang saat zygote/app restart: cek cepat lalu pasang ulang
        if [ "$(getv spoof_cpuinfo)" = "1" ] && ! head -c 400 /proc/cpuinfo 2>/dev/null | grep -q "$(getv cpu_part)"; then
          _force=1
        fi
        if [ "$(getv spoof_props)" = "1" ] && [ $((_tick % 5)) -eq 0 ]; then
          apply_props >/dev/null 2>&1
        fi
        _tick=$((_tick+1))
        [ "$_tick" -gt 40 ] && _force=1
      fi
    fi
    sleep "$_iv"
  done
}

seed

case "$1" in
  apply) shift; apply ;;
  restore) shift; restore ;;
  status) status ;;
  check) check ;;
  dump) dump ;;
  log) tail -60 "$LOG" 2>/dev/null ;;
  mounts) cat "$MOUNTLIST" 2>/dev/null ;;
  setk) shift; setv "$1" "$2"; printf 'ok %s=%s\n' "$1" "$(getv "$1")" ;;
  unsetk) shift; unsetk "$1"; printf 'ok hapus %s\n' "$1" ;;
  cores) _i=0; while [ "$_i" -lt "$CORES" ]; do printf '%s %s\n' "$_i" "$(freq_of "$_i")"; _i=$((_i+1)); done ;;
  daemon) daemon ;;
  *)
    seed
    printf 'CPUFakeX v1.1 — spoof SoC total\n'
    printf 'pakai: cpufakex.sh apply|restore|status|check|dump|log|mounts|cores|daemon|setk <k> <v>\n'
    ;;
esac
