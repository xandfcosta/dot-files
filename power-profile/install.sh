#!/usr/bin/env bash

echo "Installing..."

cwd=$(pwd)
echo "$cwd"

cd /usr/local/bin/ || exit
sudo chmod +x "$cwd/power-profile-auto.sh"
sudo ln -s "$cwd/power-profile-auto.sh" power-profile-auto.sh

cd /etc/udev/rules.d/ || exit
sudo ln -s "$cwd/99-power-profile.rules" 99-power-profile.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

cd /etc/systemd/system/ || exit
sudo cp "$cwd/power-profile-auto.service" power-profile-auto.service
sudo systemctl enable power-profile-auto.service

echo "Installed succesfully"
