-- Display configuration.
--
-- No dynamic-monitor daemon is needed: Hyprland applies each rule when the
-- output it names is connected and ignores it otherwise, so the docked and
-- undocked layouts are both described here at once. Unplugging HDMI-A-1 moves
-- its workspaces to the laptop panel; plugging it back sends them home.
--
-- Two constraints come from omarchy-hyprland-monitor-clamshell, which re-reads
-- the internal panel's scale out of this file every 2s while docked and pushes
-- it back onto Hyprland. Break either one and it silently forces scale 2:
--   1. Keep each hl.monitor rule on ONE line -- its regex wants `hl.monitor({`
--      and `output = "..."` on the same line.
--   2. Match the internal panel by output NAME (eDP-1), not by desc:, because
--      that is the name omarchy-hyprland-monitor-laptop reports.
-- This is also why hyprmoncfg does not fit here: it emits multi-line rules.

-- External AOC, primary, at the origin.
hl.monitor({ output = "desc:AOC 24G2W1G4 ATNM4XA001012", mode = "1920x1080@144.00", position = "0x0", scale = 1 })

-- Laptop panel, to the right of whatever sits at the origin.
hl.monitor({ output = "eDP-1", mode = "1920x1080@60.03", position = "auto-right", scale = 1.25 })

-- Workspaces 1-4 live on the external, 5-6 on the laptop panel.
hl.workspace_rule({ workspace = "1", monitor = "desc:AOC 24G2W1G4 ATNM4XA001012", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:AOC 24G2W1G4 ATNM4XA001012", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "desc:AOC 24G2W1G4 ATNM4XA001012", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "desc:AOC 24G2W1G4 ATNM4XA001012", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", persistent = true, default = true })
hl.workspace_rule({ workspace = "6", monitor = "eDP-1", persistent = true })
