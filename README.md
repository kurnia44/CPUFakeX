# CPUFakeX

Modul KernelSU / APatch / Magisk yang memalsukan identitas SoC perangkat secara menyeluruh,
membuatnya terbaca sebagai **Snapdragon 8 Elite Extreme Gen 6 (SM8950 / sunridge)**.

## Lapisan spoof

| Lapisan | Yang diubah | Metode |
|---|---|---|
| System props | `ro.soc.model`, `ro.board.platform`, `ro.chipname`, `ro.vendor.qti.soc_model`, dll (18 key) | `system.prop` (boot) + `resetprop -n` |
| `/proc/cpuinfo` | 8 core, `CPU part 0x002`, variant, features, BogoMIPS | bind mount |
| Device-tree | `/proc/device-tree/model`, `/sys/firmware/devicetree/base/model` | bind mount |
| soc0 | `/sys/devices/soc0/machine`, `family` | bind mount |
| cpufreq (default ON) | `cpuinfo_max_freq` + `scaling_max_freq` + `*_min_freq` per **policy**: 6 perf 4.2 GHz, 2 prime 4.75 GHz | bind mount |

Bind cpufreq dilakukan per `policyN`, bukan per `cpuN` — `cpuN/cpufreq/*` adalah symlink ke
`policyN/*`, jadi satu bind per file per policy menutup semua core sekaligus.

Mount dilakukan di namespace init **dan** zygote lewat `nsenter`, plus `post-fs-data.sh` supaya
app yang dijalankan belakangan mewarisi mount-nya.

## Pakai

```sh
sh /data/adb/modules/cpufakex/bin/cpufakex.sh status
sh /data/adb/modules/cpufakex/bin/cpufakex.sh check
sh /data/adb/modules/cpufakex/bin/cpufakex.sh apply
sh /data/adb/modules/cpufakex/bin/cpufakex.sh restore
sh /data/adb/modules/cpufakex/bin/cpufakex.sh setk prime_max 5000000
```

WebUI: buka modul dari KernelSU / APatch / MMRL — toggle per lapisan, editor identitas,
topologi, checker, kartu **Diagnostik** (resetprop / getprop / nsenter / SELinux / namespace),
tombol **Restore** dan **Muat ulang**.

Tombol **Action** di manager menjalankan status + apply + check lalu menampilkan hasilnya.
Tidak ada menu volume-key: manager tidak memberi terminal interaktif, dan `getevent` tidak
bisa dibaca dari konteks action di banyak device.

## Bridge WebUI

WebUI mencoba dua bentuk API dan mengingat mana yang bekerja:

1. `exec(cmd, "namaFungsiCallback")` — KernelSU / KernelSU-Next (callback berupa **nama**, bukan objek)
2. `exec(cmd)` yang mengembalikan string / Promise — APatch dan varian lain

Probe `echo __cfok` dijalankan sekali di awal. Kalau dua-duanya gagal, status bridge tampil
`tidak ada` dan pesan di kartu Verifikasi menyebut penyebabnya. Kegagalan tidak di-cache —
tombol **Muat ulang** memaksa probe ulang tanpa menutup WebUI.

## Config

`/data/adb/cpufakex/config.conf` — flat `key=value`, semua lapisan membaca dari sini.
`prop.<nama>=<value>` untuk prop map. `freq.cpuN=<khz>` untuk override per core.

## Batas teknis

- Nilai palsu adalah hasil *read interception*, bukan hardware. Benchmark yang membaca
  `/proc/cpuinfo`, sysfs, atau `getprop` akan melihat nilai palsu; yang membaca MSR/registri
  MIDR langsung tetap melihat silikon asli.
- Beberapa app memakai syscall yang tidak lewat mount (mis. `uname`, `sysconf`) — itu di luar
  cakupan modul ini.
- `restore` mengembalikan semua mount dan prop asli; `uninstall.sh` memanggilnya otomatis.
