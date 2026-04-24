#!/usr/bin/env bash

service_name="auto-detect-p3"
bin_dir="/usr/local/bin"
systemd_dir="$HOME/.config/systemd/user"

echo "Uninstalling..."

if [ -f "$bin_dir$service_name.sh" ]; then
  sudo rm "$bin_dir$service_name.sh"
fi

if [ -f "$systemd_dir/$service_name.service" ]; then
  systemctl --user disable "$service_name.service"
  systemctl --user stop "$service_name.service"
fi

echo "Uninstalled succesfully"
