#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing obsidian sync..."

echo "Installing script"
# Install script
sudo ln -sf "$SCRIPT_DIR/obsidian-sync.sh" /usr/local/bin/obsidian-sync.sh
sudo chmod +x /usr/local/bin/obsidian-sync.sh

echo "Installing service"
# Install user systemd unit
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$SCRIPT_DIR/obsidian-sync.service" \
      "$HOME/.config/systemd/user/obsidian-sync.service"

echo "Starting service"
# Reload and enable user service
systemctl --user daemon-reload
systemctl --user enable obsidian-sync.service
systemctl --user start obsidian-sync.service

echo "Installation completed successfully."

