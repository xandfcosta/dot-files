# GPU hybrid-offload audit — recovery point (2026-07-11)

Acer Nitro 5 AN515-54 · Intel UHD 630 (iGPU) + NVIDIA GTX 1650 (dGPU) · Omarchy/Hyprland.

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
