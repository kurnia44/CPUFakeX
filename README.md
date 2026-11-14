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
| cpufreq | `cpuinfo_max_freq` per policy: 6 perf 4.2 GHz, 2 prime 4.75 GHz | bind mount |

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
topologi, dan checker yang membandingkan target vs nilai yang benar-benar terbaca.

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
