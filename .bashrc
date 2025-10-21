# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

wavoip() {
  wavoip_nodes
  cd ~/projects/wavoip/
  tmux new-session -A -s wavoip
}


wavoip_nodes() {
    command -v tmux >/dev/null 2>&1 || { echo "tmux is not installed"; return 1; }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    tmux new-session -A -d -s wavoip-nodes -n "21"

    for i in 22 23 24; do
        tmux new-window -t wavoip-nodes -n "$i" 2>/dev/null || true
    done

    tmux new-window -t wavoip-nodes -n MYSQL

    tmux send-keys -t wavoip-nodes:1 "ssh root@141.11.73.91"
    tmux send-keys -t wavoip-nodes:2 "ssh root@45.139.208.59"
    tmux send-keys -t wavoip-nodes:3 "ssh root@141.11.73.94"
    tmux send-keys -t wavoip-nodes:4 "ssh root@45.139.208.61"
    tmux send-keys -t wavoip-nodes:MYSQL "lazysql" C-m
}

. "$HOME/.local/share/../bin/env"
