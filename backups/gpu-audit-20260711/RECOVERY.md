# GPU hybrid-offload audit — recovery point (2026-07-11)

Acer Nitro 5 AN515-54 · Intel UHD 630 (iGPU) + NVIDIA GTX 1650 (dGPU) · Omarchy/Hyprland.

## ⚠️ POSTMORTEM: `NVreg_DynamicPowerManagement` froze the LUKS prompt

**What happened:** after adding `/etc/modprobe.d/nvidia-pm.conf` with
`options nvidia NVreg_DynamicPowerManagement=0x02` and rebuilding the UKI,
the next boot got **stuck at the LUKS password prompt** (frozen / no input).
Reverting that file + rebuilding the UKI restored a normal boot.

**Root cause (verified on this machine):**
- omarchy loads nvidia **early**, inside the initramfs:
  `/etc/mkinitcpio.conf.d/nvidia.conf` → `MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`
  (present since 2026-04-24, so early KMS itself is NOT the bug — the old
  05-28 UKI booted fine for weeks with it).
- `mkinitcpio` bundles `/etc/modprobe.d/*` into the initramfs, so the new
  `NVreg_DynamicPowerManagement=0x02` param was applied **at the LUKS prompt
  stage**, letting the dGPU runtime-suspend / power-gate mid-prompt → freeze.
- `fbcon: i915drmfb (fb0) is primary` — Intel drives the prompt; nvidia is
  secondary (`fb1`, HDMI). The aggressive PM param is the trigger, not the
  display owner.

**This is a known bug class, not machine-specific luck:**
- NVIDIA dev forums — `NVreg_DynamicPowerManagement=0x02` causes crashes /
  unresponsiveness: https://forums.developer.nvidia.com/t/xorg-crashes-and-is-unresponsive-with-driver-option-nvreg-dynamicpowermanagement-0x02/112853
- Ubuntu bug #1638983 — LUKS boot-splash password prompt broken with nvidia
  in initramfs: https://bugs.launchpad.net/bugs/1638983
- Arch wiki NVIDIA/Troubleshooting — early-KMS caveats; advises loading
  nvidia *after* initramfs if not needed: https://wiki.archlinux.org/title/NVIDIA/Troubleshooting

**Rule for this machine:** never put nvidia power-management module params in
`/etc/modprobe.d` while nvidia is in the early initramfs MODULES. Meaningful
nvidia idle savings need `NVreg_DynamicPowerManagement` at module load, so the
ONLY safe way to enable it here is to first remove nvidia from the early
initramfs MODULES (so nvidia loads *after* LUKS) — see "Option B" below —
otherwise skip dGPU PM entirely (dGPU idles ~3W). `power/control=auto` alone
does almost nothing on the nvidia driver without the NVreg param.

**Recovery if a boot config change bricks the prompt again:** at the limine
menu pick a **snapshot** entry (limine-snapper) to boot a working rootfs, then
undo the change and rebuild the UKI. No live-USB needed.

### Option B (proper dGPU PM, deferred — do only with a snapshot ready)
```bash
# 1. remove nvidia from EARLY initramfs so the PM param applies post-LUKS:
sudoedit /etc/mkinitcpio.conf.d/nvidia.conf     # delete/comment the MODULES+=(nvidia ...) line
# 2. add the PM param (now applied when nvidia loads in the real system):
echo 'options nvidia NVreg_DynamicPowerManagement=0x02' | sudo tee /etc/modprobe.d/nvidia-pm.conf
# 3. rebuild UKI + verify fresh, then reboot:
sudo limine-mkinitcpio
```
Caveat: without early nvidia KMS the LUKS prompt shows only on the **internal
panel** early (not the external HDMI, which is on the dGPU). Only matters if
you unlock while docked with the lid closed.

## Hardware facts (verified)
- `pci-0000:00:02.0` = Intel UHD 630 → drives internal panel `eDP-1`.
- `pci-0000:01:00.0` = NVIDIA GTX 1650 → drives **`HDMI-A-1`** (external AOC 1080p@144).
- HDMI port is muxed to the dGPU; the iGPU cannot drive the external monitor.

## Files in this backup
| file | meaning |
|------|---------|
| `envs.conf.orig`        | ORIGINAL `~/.config/hypr/envs.conf` (global NVIDIA env block) |
| `envs.conf.new`         | edited version (block commented out) |
| `env-hyprland.orig`     | ORIGINAL `~/.config/uwsm/env-hyprland` (`AQ_DRM_DEVICES` raw cardN) |
| `env-hyprland.new`      | edited version (by-path symlinks) |
| `etc-modprobe.d-nvidia.conf` | untouched `/etc/modprobe.d/nvidia.conf` (`modeset=1`) for reference |

## To revert the USER config changes
```bash
cp ~/dot-files/backups/gpu-audit-20260711/envs.conf.orig    ~/.config/hypr/envs.conf
cp ~/dot-files/backups/gpu-audit-20260711/env-hyprland.orig ~/.config/uwsm/env-hyprland
# then restart Hyprland session (log out / back in)
```

## To revert the SYSTEM changes (only if they were applied)
These files did NOT exist before the audit — reverting = deleting them.
```bash
sudo rm -f /etc/modprobe.d/nvidia-pm.conf
sudo rm -f /etc/udev/rules.d/80-nvidia-pm.rules
sudo limine-mkinitcpio   # rebuild the UKI without the PM option (NOT mkinitcpio -P)
sudo reboot
```
`nvidia-prime` package can stay (harmless); to remove: `sudo pacman -Rns nvidia-prime`.

## IMPORTANT: this machine is UKI-based (limine + LUKS)
`/etc/mkinitcpio.d/` is empty — `sudo mkinitcpio -P` is a NO-OP here.
The boot image is a Unified Kernel Image at
`/boot/EFI/Linux/omarchy_linux.efi`, built by **`limine-mkinitcpio`**
(pkg `limine-mkinitcpio-hook`). Any change to `/etc/modprobe.d`,
`/etc/mkinitcpio.conf.d`, or HOOKS requires:
```bash
sudo limine-mkinitcpio       # or: omarchy-refresh-limine
# verify the UKI mtime is fresh BEFORE rebooting:
ls -la --time-style=+%m-%d_%H:%M /boot/EFI/Linux/omarchy_linux.efi
```
Run sudo in a REAL terminal — the Claude `!` prompt has no tty for the
sudo password.

## What "good" looks like after the changes + reboot
```bash
glxinfo -B            | grep "OpenGL vendor string"   # → Intel
prime-run glxinfo -B  | grep "OpenGL vendor string"   # → NVIDIA
# undocked, idle ~30s:
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # → suspended
cat /sys/bus/pci/devices/0000:01:00.0/power/control          # → auto
```
