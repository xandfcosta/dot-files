# Hardware Monitor

An Omarchy bar widget that names the silicon in the machine, then stays out of the way.

Left click the chip for a Power-style panel: CPU model, temperature and per-core bars, RAM type and speed, **every GPU in the box** with its own load and temperature, disk model and fill. It follows the active Omarchy theme. Right click opens `btop` if you want the full TUI.

| Left click | Right click |
| --- | --- |
| CPU name, temp, per-core bars, RAM type/speed, integrated **and** discrete GPU with load + temp, storage model and mounts | Launch or focus `btop` |

Load-aware status lines rotate the same way the Power panel does — idle machines loaf, busy GPUs push pixels, a local model run starts chewing context.

## Fork

This is a fork of [Hardware Tooltip](https://github.com/IM0001GT/omarchy-hw-tooltip) by IM0001GT (MIT), kept as a separate plugin id so the original stays independently updatable. Both can be installed at once; they share no cache or state files.

What this fork adds:

- **One compiled binary instead of bash + 4 python interpreters.** 67 ms of CPU per sample against 252 ms, and 51 ms of wall time against 430 ms, so the card opens already filled in.
- **Nothing runs while the panel is closed.** The bar chip is a static glyph, so the sampler only spawns while the card is up. Closed, the widget costs nothing.
- **Left click opens the panel** instead of hover, so crossing the bar never pops it open.
- **Every GPU, not just the first one.** A hybrid laptop shows `GPU` (discrete) and `iGPU` (integrated) as separate blocks, each with its own load bar and hardware name.
- **Temperatures** for the CPU package and for each GPU, under the percentage.

## Temperatures

| Part | Source |
| --- | --- |
| CPU | `coretemp` / `k10temp` / `zenpower` package sensor, hottest core as a stand-in, then `x86_pkg_temp` |
| NVIDIA | `nvidia-smi temperature.gpu` |
| AMD, Intel Arc | the hwmon nodes the GPU exposes under its own PCI device (`edge` preferred over `junction` / `hotspot`) |
| Integrated GPU with no sensor | the CPU package sensor — pre-Arc `i915` exposes no hwmon of its own, and that silicon is the same die |

## Integrated vs discrete

The class decides the block title (`GPU` / `iGPU`) and comes from sysfs alone:

- anything on PCI bus `00` hangs off the host bridge, so it is integrated
- NVIDIA is always discrete
- AMD APU graphics sits behind an internal GPP bridge, so the bus number cannot tell it apart from a Radeon card. An APU carves its VRAM out of system RAM, so a small `mem_info_vram_total` (≤ 2 GiB) means integrated; the BC-250 is matched by PCI id instead, since its 16 GB of unified GDDR6 would read as a card

## GPU load

Per GPU, the first source that actually answers:

| GPU | Extra package | How load is read |
| --- | --- | --- |
| Intel | none | DRM fdinfo engine busy (attributed by `drm-pdev`), then RC6 residency. No `kernel.perf_event_paranoid` change |
| NVIDIA | `nvidia-utils` | `nvidia-smi`, and only when the NVIDIA driver is loaded |
| AMD | none | `gpu_busy_percent`. If that node is missing or `ENOTSUPP` (BC-250), DRM fdinfo engine time |

Walking `/proc` for fdinfo only happens for GPUs that nothing else could answer.

## ASRock BC-250

Tuned for the BC-250 / Cyan Skillfish board (`1002:13fe`). Linux binds the GPU as `amdgpu`, but SMU telemetry on this cut-down Oberon part is empty, so generic AMD tools report a stuck `0%`:

| Signal | What Linux does on a BC-250 |
| --- | --- |
| `gpu_busy_percent` | node exists, `read()` returns `ENOTSUPP` |
| `gpu_metrics` `average_gfx_activity` | stays `0xFFFF` |
| `radeontop` | unknown card, stuck `0%` |
| DIMM / SPD | none — 16 GB soldered GDDR6, `dmidecode` / `inxi` show type `N/A` and a `1750 MT/s` command clock |

This widget:

- samples GPU load from `/proc/*/fdinfo` `drm-engine-*` time (Render/3D) instead of the broken busy node
- labels memory as **GDDR6 14000 MT/s** from the published 14 Gbps-per-pin spec, not the command clock

## Install

Plugins run as unsandboxed code inside `omarchy-shell`. Only add folders you trust.

The repo root **is** the plugin, and the folder name must be the plugin id:

```bash
cp -r hw-monitor ~/.config/omarchy/plugins/xandfcosta.hw-monitor
~/.config/omarchy/plugins/xandfcosta.hw-monitor/install.sh
```

`install.sh` enables the widget next to Power and restarts the shell. Or do it by hand:

```bash
omarchy plugin enable xandfcosta.hw-monitor --after omarchy.power
omarchy restart shell
```

Intel and AMD need no extra packages and no sysctl changes. On NVIDIA, if `nvidia-smi` is missing:

```bash
~/.config/omarchy/plugins/xandfcosta.hw-monitor/install.sh --deps
```

`--deps` is optional. Without it the widget still works; a missing NVIDIA tool just shows `n/a` for that GPU.

## Use

- **Left click** the chip — panel with CPU, memory, every GPU, and storage. Click the chip again, or anywhere outside, to dismiss it
- **Right click** — launch or focus `btop`

The panel sizes itself to the hardware in the machine: more CPU threads add columns and height, a second GPU adds a block, extra disks grow the storage block, and the card still stops at the screen edge.

Move it with `omarchy bar move xandfcosta.hw-monitor`.

## Update

After editing any file:

```bash
omarchy restart shell
```

Quickshell keeps the previous QML in memory until the shell restarts.

## Uninstall

```bash
omarchy plugin remove xandfcosta.hw-monitor
```

## Requirements

- [Omarchy](https://omarchy.org/) with the shell plugin CLI
- `btop` and `jq` (already on Omarchy)
- `lspci` for GPU names, `dmidecode` or `inxi` for the RAM type (both optional; the panel just drops that label without them)
- Optional NVIDIA tools, only if `nvidia-smi` is missing
- Go, only to rebuild the sampler from `src/`

## Layout

```text
manifest.json          Omarchy plugin manifest (must live at repo root)
HardwareMonitor.qml    Bar icon + click-to-open panel
scripts/system-usage   Compiled sampler (CPU / RAM / GPU / temps / disks)
scripts/build          Rebuilds that binary from src/
src/                   Go sources for the sampler
install.sh             Optional NVIDIA deps + enable / place the widget
```

The sampler is a static Go binary (x86-64, no libc dependency), committed so
the plugin works straight from a clone. After editing `src/`, run
`./scripts/build` and `omarchy restart shell`.

## License

MIT. See [LICENSE](LICENSE). Original work © IM0001GT.
