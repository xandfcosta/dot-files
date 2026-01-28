#!/usr/bin/env bash

echo "Unnstalling..."

sudo rm /usr/local/bin/power-profile-auto.sh

sudo rm /etc/udev/rules.d/99-power-profile.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

sudo systemctl stop power-profile-auto.service
sudo systemctl disable power-profile-auto.service
sudo rm /etc/systemd/system/power-profile-auto.service

echo "Unnstalled succesfully"
