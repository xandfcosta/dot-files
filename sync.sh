#! /bin/bash

config_dir="$HOME/.config"
dot_dir="$HOME/dot-files"

declare -A dirs
dirs["alacritty"]="$dot_dir/alacritty/"
dirs["ghostty"]="$dot_dir/ghostty/"
dirs["hypr"]="$dot_dir/hypr"
dirs["hyprdynamicmonitors"]="$dot_dir/hyprdynamicmonitors/"
dirs["nvim"]="$dot_dir/nvim/"
dirs["waybar"]="$dot_dir/waybar/"

declare -A files
files[".bashrc"]="$HOME/.bashrc"
files["intel-undervolt.conf"]="$HOME/intel-undervolt/intel-undervolt.conf"
files["tmux"]="$config_dir/tmux/tmux.conf"

declare -A files_out
files_out[".bashrc"]="$dot_dir/bash/.bashrc"
files_out["intel-undervolt.conf"]="$dot_dir/intel-undervolt/intel-undervolt.conf"
files_out["tmux"]="$dot_dir/tmux/tmux.conf"

echo "Syncing hole folders"
for chave in "${!dirs[@]}"; do
  echo "Syncing $chave | $config_dir/$chave -> ${dirs[$chave]}"
  rm -r -f "${dirs[$chave]}"
  cp -r "$config_dir/$chave" "${dirs[$chave]}"
done

echo "Syncing files"
for chave in "${!files[@]}"; do
  echo "Syncing $chave | ${files[$chave]} -> ${files_out[$chave]}"
  cp "${files[$chave]}" "${files_out[$chave]}"
done

echo "Done"
