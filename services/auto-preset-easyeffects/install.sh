#!/usr/bin/env bash

service_name="auto-detect-p3"
bin_dir="/usr/local/bin"
systemd_dir="$HOME/.config/systemd/user"

echo "Installing $service_name"

chmod +x "$(pwd)/$service_name.sh"

if ! [ -f "$bin_dir/$service_name.sh" ]; then
  sudo ln -s "$(pwd)/$service_name.sh" "$bin_dir/$service_name.sh"
  systemctl --user enable --now "$service_name.service"
fi

if ! [ -f "$systemd_dir/$service_name.service" ]; then
  sudo ln -s "$(pwd)/$service_name.service" "$systemd_dir/$service_name.service"
fi

echo "Done"
