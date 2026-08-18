-- Extra autostart processes.
--
-- Migrated from the old autostart.conf `exec-once = [workspace N silent] ...`
-- lines. In the Lua API the exec rules are the second argument to
-- hl.exec_cmd, and "silent" is part of the workspace value -- passing
-- `silent = true` as its own key makes Hyprland drop the exec entirely.

hl.on("hyprland.start", function()
	-- No exec rule for the browser: omarchy-launch-browser hands the launch to
	-- systemd-run, which drops Hyprland's initial-workspace token, so the rule
	-- would be ignored. The window rule below places it instead.
	hl.exec_cmd("omarchy-launch-browser")
	hl.exec_cmd(o.launch("xdg-terminal-exec"), { workspace = "2 silent" })
	hl.exec_cmd(o.launch("discord"), { workspace = "5 silent" })
	hl.exec_cmd("omarchy-launch-or-focus spotify", { workspace = "special:scratchpad silent" })
	hl.exec_cmd("omarchy-launch-or-focus obsidian", { workspace = "special:scratchpad silent" })
end)

-- Keep these apps on their workspace however they get launched.
--
-- A window with no workspace of its own opens on whichever workspace is
-- active, and while the scratchpad is showing that is the scratchpad -- which
-- is how browsers kept ending up in there. Pinning them to 1 settles it for
-- every launch path. The tags come from Omarchy's default/hypr/apps/browser.lua
-- and cover chromium, chrome, brave, edge, vivaldi, firefox, zen and librewolf.
o.window({ tag = "chromium-based-browser" }, { workspace = "1" })
o.window({ tag = "firefox-based-browser" }, { workspace = "1" })

o.window("^(discord)$", { workspace = "5 silent" })
o.window("^([Ss]potify)$", { workspace = "special:scratchpad silent" })

