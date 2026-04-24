#!/usr/bin/env bash

service_name="power-profile-auto"
bin_dir="/usr/local/bin"
systemd_dir="$HOME/.config/systemd/user"
udev_rules_dir="/etc/udev/rules.d"

echo "Installing $service_name"

sudo chmod +x "$(pwd)/$service_name.sh"

if ! [ -f "$bin_dir/$service_name.sh" ]; then
  sudo ln -s "$(pwd)/$service_name.sh" "$bin_dir/$service_name.sh"
fi

if ! [ -f "$systemd_dir/$service_name.service" ]; then
  sudo ln -s "$(pwd)/$service_name.service" "$systemd_dir/$service_name.service"
  systemctl --user enable --now "$service_name.service"
fi

if ! [ -f "$udev_rules_dir/99-$service_name.rules" ]; then
  sudo ln -s "$(pwd)/$service_name.rules" "$udev_rules_dir/99-$service_name.rules"
  sudo udevadm control --reload-rules
  sudo udevadm trigger
fi

echo "Done"
