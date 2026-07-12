# GPU hybrid-offload audit — recovery point (2026-07-11)

Acer Nitro 5 AN515-54 · Intel UHD 630 (iGPU) + NVIDIA GTX 1650 (dGPU) · Omarchy/Hyprland.

## ✅ FINAL OUTCOME (2026-07-12 00:17) — what to actually keep

Working, stable config after the whole saga:
- `~/.config/uwsm/env-hyprland` → `AQ_DRM_DEVICES="/dev/dri/card2:/dev/dri/card1"`
  (RAW cardN — **NOT** by-path; see below).
- `~/.config/hypr/envs.conf` → global NVIDIA block stays commented (harmless; file
  isn't even sourced). iGPU primary, `prime-run` for offload.
- `/etc/mkinitcpio.conf.d/nvidia.conf` → `MODULES+=(nvidia ...)` RESTORED (nvidia
  early KMS). No `nvidia-pm.conf`, no `80-nvidia-pm.rules`.
- Result: Intel primary, external HDMI 1080p@144 works, prime-run offload works,
  dGPU idles ~3W (battery PM abandoned — see Option B).

### ❌ Two mistakes this audit made — do not repeat
1. **`AQ_DRM_DEVICES` by-path symlinks CRASH Hyprland here.** aquamarine matches
   entries against udev `cardN` nodes; `/dev/dri/by-path/...` → `CBackend::create()
   failed!` → Hyprland aborts at startup. Issue #1776 suggests named symlinks, but
   on THIS setup **raw `card2:card1` is required**. (card2 = Intel 00:02.0,
   card1 = NVIDIA 01:00.0.) The by-path value was never tested in a live session
   before reboot, so it silently broke the desktop.
2. **Battery PM (Option B) abandoned.** It DID fix the LUKS freeze (nvidia out of
   initramfs → boots past LUKS), but once booting, the by-path crash surfaced and
   the two got conflated. Even with by-path fixed, Option B's benefit (~3W idle) is
   not worth the boot fragility. Keep nvidia early KMS + no PM.

### Two distinct faults (they were conflated)
- **Fault A — real LUKS freeze:** `NVreg_DynamicPowerManagement` param WITH nvidia
  in the early initramfs froze the LUKS prompt (that boot never mounted root → no
  journal). Fixed by removing nvidia from initramfs.
- **Fault B — desktop crash:** `AQ_DRM_DEVICES` by-path → aquamarine `CBackend::create()
  failed!`. Present in every booted session except the one that still ran the
  original raw env. Fixed by restoring raw `card2:card1`.

Journal proof: every recorded boot PASSED LUKS; the only crash-free session (boot
-5, 41 min) was the one running raw env. So the initramfs change was never the
desktop-breaker — the AQ env was.

---

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

### Option B — dGPU runtime PM (STAGED 2026-07-11, reboot pending)

Approved: LUKS unlock on internal panel is fine; changes staged, user reboots
on own schedule. Goal: dGPU deep-suspends (RTD3) when idle/undocked.

**Why this is safe (the kms-hook question):** removing nvidia from the early
`MODULES` is *sufficient*. The `kms` initramfs hook only scans in-tree
`/drivers/gpu/drm/`, but nvidia is out-of-tree at
`/lib/modules/$(uname -r)/updates/dkms/nvidia*.ko.zst`, so kms will NOT re-add
it. Intel i915 (in-tree) still gets early KMS and drives the LUKS prompt.

**Staging commands (run in a real terminal, then reboot when ready):**
```bash
# 1. nvidia out of early initramfs (loads post-boot, param applies post-LUKS)
sudo tee /etc/mkinitcpio.conf.d/nvidia.conf >/dev/null <<'EOF'
# nvidia intentionally NOT early-loaded (froze LUKS prompt 2026-07-11).
# MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
# 2. runtime-PM module param
sudo tee /etc/modprobe.d/nvidia-pm.conf >/dev/null <<'EOF'
options nvidia NVreg_DynamicPowerManagement=0x02
EOF
# 3. allow PCI runtime suspend on the dGPU (udev fires post-boot)
sudo tee /etc/udev/rules.d/80-nvidia-pm.rules >/dev/null <<'EOF'
ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
EOF
# 4. rebuild UKI
sudo limine-mkinitcpio
```

**Verification gate — MUST print OK before rebooting:**
```bash
cd /tmp && objcopy -O binary --only-section=.initrd /boot/EFI/Linux/omarchy_linux.efi ck.img && \
( lsinitcpio ck.img | grep -qi nvidia && echo "!! ABORT: nvidia still in UKI — do NOT reboot" \
  || echo "OK: nvidia absent from initramfs — safe to reboot" ); rm -f /tmp/ck.img
```

**Post-reboot verification:**
```bash
lsmod | grep nvidia                                          # loads post-boot
hyprctl monitors | grep HDMI                                 # external still works
# undock, idle ~30s:
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status   # → suspended
cat /sys/bus/pci/devices/0000:01:00.0/power/control          # → auto
```

**Rollback:** at the limine menu pick a **snapshot** entry to boot a working
rootfs, then restore `/etc/mkinitcpio.conf.d/nvidia.conf` (uncomment the
MODULES line), `sudo rm /etc/modprobe.d/nvidia-pm.conf /etc/udev/rules.d/80-nvidia-pm.rules`,
`sudo limine-mkinitcpio`, reboot.

**Caveat:** without early nvidia KMS the LUKS prompt shows only on the internal
panel (not the external HDMI, which is on the dGPU) — fine, unlock on the
laptop screen.

## Hardware facts (verified)
- `pci-0000:00:02.0` = Intel UHD 630 → drives internal panel `eDP-1`.
- `pci-0000:01:00.0` = NVIDIA GTX 1650 → drives **`HDMI-A-1`** (external AOC 1080p@144).
- HDMI port is muxed to the dGPU; the iGPU cannot drive the external monitor.

## Files in this backup
| file | meaning |
|------|---------|
| `envs.conf.orig`        | ORIGINAL `~/.config/hypr/envs.conf` (global NVIDIA env block) |
| `envs.conf.new`         | edited version (block commented out) |
| `env-hyprland.orig`     | ORIGINAL raw cardN — **this is the CORRECT/working value** |
| `env-hyprland.new`      | by-path version — **BROKEN, crashes Hyprland (do not use)** |
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
