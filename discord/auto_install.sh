#!/bin/bash

cd ~/Downloads/ || exit
echo "Downloading..."
wget "https://discord.com/api/download?platform=linux&format=tar.gz" -O discord.tar.gz

echo "Removing old folder"
sudo rm -f -r /usr/share/discord/Discord/

echo "Extracting to /usr/share/discord/"
sudo tar -xf discord.tar.gz -C /usr/share/
sudo mv /usr/share/Discord /usr/share/discord

echo "Creating symlinks"
sudo ln -s /usr/share/discord/discord.png /usr/share/icons/discord.png
sudo ln -s /usr/share/discord/Discord /usr/bin/discord
sudo ln -s /usr/share/discord/discord.desktop /usr/share/applications/discord.desktop

echo "Removing discord.tar.gz"
rm discord.tar.gz

echo "Installing vencord"
bash -c "$(curl -sS https://vencord.dev/install.sh)"

