#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Uninstalling obsidian sync..."

# Reload and enable user service
systemctl --user disable obsidian-sync.service
systemctl --user stop obsidian-sync.service
systemctl --user daemon-reload

# Uninstall script
sudo rm /usr/local/bin/obsidian-sync.sh

echo "Uninstallation completed successfully."

