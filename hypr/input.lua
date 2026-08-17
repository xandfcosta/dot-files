-- Personal input overrides. Loaded after Omarchy's defaults.
--
-- Omarchy's defaults (default/hypr/input.lua) already provide what the old
-- input.conf set: repeat_rate 40, numlock_by_default, touchpad scroll_factor
-- 0.4 + clickfinger_behavior, and the terminal scroll_touchpad window rules.
-- Only the genuine differences are repeated below.

hl.config({
	input = {
		-- Keyboard: Brazilian ABNT2.
		kb_layout = "br",
		kb_variant = "abnt2",

		-- Old input.conf had force_no_accel = true. Raw, unaccelerated pointer
		-- motion for both mouse and trackpad.
		force_no_accel = true,
	},
})
