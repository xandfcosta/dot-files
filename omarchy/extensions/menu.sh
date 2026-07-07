# Overwrite parts of the omarchy-menu with user-specific submenus.
# See $OMARCHY_PATH/bin/omarchy-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Omarchy changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) omarchy-lock-screen ;;
#   *Shutdown*) omarchy-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
# show_about() {
#   exec omarchy-launch-or-focus-tui "zsh -c 'fastfetch; read -k 1'"
# }

# Add "Docked Display" toggle (external-only <-> dual) to the Toggle menu.
# NOTE: copied from omarchy-menu; new stock toggles won't appear here until re-synced.
show_toggle_menu() {
  local options="󱄄  Screensaver\n󰔎  Nightlight\n󱫖  Idle Lock\n󰂛  Notifications\n󰍜  Top Bar\n󱂬  Workspace Layout\n  Window Gaps\n  1-Window Ratio\n󰍹  Monitor Scaling\n󰍹  Docked Display\n  Direct Boot\n󰟵  Passwordless Sudo"

  case $(menu "Toggle" "$options") in
  *Screensaver*) omarchy-toggle-screensaver ;;
  *Nightlight*) omarchy-toggle-nightlight ;;
  *Idle*) omarchy-toggle-idle ;;
  *Notifications*) omarchy-toggle-notification-silencing ;;
  *Bar*) omarchy-toggle-waybar ;;
  *Layout*) omarchy-hyprland-workspace-layout-toggle ;;
  *Ratio*) omarchy-hyprland-window-single-square-aspect-toggle ;;
  *Gaps*) omarchy-hyprland-window-gaps-toggle ;;
  *"Docked Display"*) hdm-docked-toggle ;;
  *Scaling*) omarchy-hyprland-monitor-scaling-cycle ;;
  *"Direct Boot"*) present_terminal omarchy-config-direct-boot ;;
  *"Passwordless Sudo"*) present_terminal omarchy-sudo-passwordless ;;
  *) back_to show_trigger_menu ;;
  esac
}
