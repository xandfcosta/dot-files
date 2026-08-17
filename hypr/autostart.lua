-- Extra autostart processes.
--
-- Migrated from the old autostart.conf `exec-once = [workspace N silent] ...`
-- lines. In the Lua API the exec rules are the second argument to
-- hl.exec_cmd, and "silent" is part of the workspace value -- passing
-- `silent = true` as its own key makes Hyprland drop the exec entirely.

hl.on("hyprland.start", function()
	hl.exec_cmd("omarchy-launch-browser", { workspace = "1 silent" })
	hl.exec_cmd(o.launch("xdg-terminal-exec"), { workspace = "2 silent" })
	hl.exec_cmd(o.launch("discord"), { workspace = "5 silent" })
	hl.exec_cmd("omarchy-launch-or-focus spotify", { workspace = "special:scratchpad silent" })
	hl.exec_cmd("omarchy-launch-or-focus obsidian", { workspace = "special:scratchpad silent" })
end)

-- Keep these apps on their workspace however they get launched.
o.window("^(discord)$", { workspace = "5 silent" })
o.window("^(spotify)$", { workspace = "special:scratchpad silent" })

