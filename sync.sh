#! /bin/bash

sync_dir() {
  # Trailing slashes on the name would double up in the paths below.
  local name="${2%/}"
  local target_dir="$1/$name"
  local sync_dir="$git_dir/$name"

  echo "Syncing dir $target_dir -> $sync_dir"

  if ! [ -d "$target_dir" ]; then
    echo "[!] Target dir doesn't exist ($target_dir)"
    return
  fi

  # Always copy onto a missing destination. Creating it first would make cp
  # nest the source inside it instead (dot-files/hypr/hypr/), which is what
  # used to happen the first time a directory was ever synced.
  rm -rf "$sync_dir"
  mkdir -p "$(dirname "$sync_dir")"
  cp -r "$target_dir" "$sync_dir"
}

sync_file() {
  local target_file_path="$1"
  local sync_dir="$git_dir/${2%/}"
  local sync_file_name="$3"

  echo "Syncing file $target_file_path -> $sync_dir/$sync_file_name"

  if ! [ -f "$target_file_path" ]; then
    echo "[!] Target file doesn't exist ($target_file_path)"
    return
  fi

  mkdir -p "$sync_dir"
  cp "$target_file_path" "$sync_dir/$sync_file_name"
}

config_dir="$HOME/.config"
local_dir="$HOME/.local/share"
git_dir="$HOME/dot-files"

echo "Syncronization started"
echo ""

echo "Syncing folders"

sync_dir "$config_dir" "ghostty/"
sync_dir "$config_dir" "hypr/"
sync_dir "$config_dir" "nvim/"

echo ""
echo "Syncing files"

sync_file "$HOME/.bashrc" "bash/" ".bashrc"
sync_file "$HOME/intel-undervolt/intel-undervolt.conf" "intel-undervolt" "intel-undervolt.conf"
sync_file "$config_dir/tmux/tmux.conf" "tmux" "tmux.conf"
sync_file "$config_dir/omarchy/extensions/omarchy-menu.jsonc" "omarchy/extensions" "omarchy-menu.jsonc"
sync_file "$config_dir/omarchy/shell.json" "omarchy" "shell.json"
sync_file "$config_dir/uwsm/env-hyprland" "uwsm" "env-hyprland"
# Holds the default browser/editor picked via `omarchy default ...`.
sync_file "$config_dir/mimeapps.list" "xdg" "mimeapps.list"

echo ""
echo "Pushing to github"

cd "$git_dir" || exit 1
git add -A

if git diff --cached --quiet; then
  echo "Nothing changed, skipping commit"
else
  git commit -q -m "sync: $(date -u)"
  git push -q
fi

echo "Syncronization done"
