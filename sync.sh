#! /bin/bash

sync_dir() {
  target_dir="$1/$2"
  sync_dir="$git_dir/$2"

  echo "Syncing dir $target_dir -> $sync_dir"

  if ! [ -d "$target_dir" ]; then
    echo "[!] Target dir don't exist ($target_dir)"
    return
  fi

  if [ -d "$sync_dir" ]; then
    echo "Sync dir already exists, removing..."
    rm -r "$sync_dir"
  else
    echo "[!] Sync dir don't exist"
    mkdir -p "$sync_dir"
  fi

  cp -r "$target_dir" "$sync_dir"
}

sync_file() {
  target_file_path=$1
  sync_dir="$git_dir/$2"
  sync_file_name=$3

  echo "Syncing file $target_file_path -> $sync_dir$sync_file_name"

  if ! [ -f "$target_file_path" ]; then
    echo "[!] Target file don't exist ($target_file_path)"
    return
  fi

  if ! [ -d "$sync_dir" ]; then
    echo "[!] Sync dir don't exist"
    mkdir -p "$sync_dir"
  fi

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
sync_dir "$config_dir" "hyprdynamicmonitors/"
sync_dir "$config_dir" "nvim/"
sync_dir "$config_dir" "waybar/"
sync_dir "$local_dir" "easyeffects/output/"

echo ""
echo "Syncing files"

sync_file "$HOME/.bashrc" "bash/" ".bashrc"
sync_file "$HOME/intel-undervolt/intel-undervolt.conf" "intel-undervolt" "intel-undervolt.conf"
sync_file "$config_dir/tmux/tmux.conf" "tmux" "tmux.conf"
sync_file "$config_dir/omarchy/extensions/menu.sh" "omarchy/extensions" "menu.sh"
sync_file "$HOME/.local/bin/hdm-docked-toggle" "bin" "hdm-docked-toggle"

echo ""
echo "Pushing to github"

git add .
git commit -q -m "sync: $(date -u)"
git push -q

echo "Syncronization done"
