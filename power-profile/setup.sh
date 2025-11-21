#!/usr/bin/env bash

sudo cp ./power-profile-auto.sh /usr/local/bin/power-profile-auto.sh
sudo chmod +x /usr/local/bin/power-profile-auto.sh

sudo cp ./99-power-profile.rules /etc/udev/rules.d/99-power-profile.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

sudo cp ./power-profile-auto.service /etc/systemd/system/power-profile-auto.service
sudo systemctl enable power-profile-auto.service
