#!/usr/bin/env bash

service_name="power-profile-auto"
bin_dir="/usr/local/bin"
systemd_dir="$HOME/.config/systemd/user"
udev_rules_dir="/etc/udev/rules.d"

echo "Uninstalling..."

if [ -f "$bin_dir$service_name.sh" ]; then
  sudo rm "$bin_dir$service_name.sh"
fi

if [ -f "$systemd_dir/$service_name.service" ]; then
  systemctl --user disable "$service_name.service"
  systemctl --user stop "$service_name.service"
fi

if [ -f "$udev_rules_dir/99-$service_name.rules" ]; then
  sudo rm "$udev_rules_dir/99-$service_name.rules"
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi

echo "Uninstalled succesfully"
