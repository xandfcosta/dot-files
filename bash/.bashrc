# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

dev() {
    command -v tmux >/dev/null 2>&1 || { echo "tmux is not installed"; return 1; }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    tmux new-session -A -s dev -c ~/projects/
}


wavoip_nodes() {
    command -v tmux >/dev/null 2>&1 || { echo "tmux is not installed"; return 1; }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    tmux new-session -A -d -s wavoip -n "21"

    for i in 22 23 24; do
        tmux new-window -t wavoip -n "$i" 2>/dev/null || true
    done

    tmux new-window -t wavoip -n MYSQL
    tmux new-window -t wavoip -n MONGO

    tmux send-keys -t wavoip:1 "ssh root@141.11.73.91"
    tmux send-keys -t wavoip:2 "ssh root@45.139.208.59"
    tmux send-keys -t wavoip:3 "ssh root@141.11.73.94"
    tmux send-keys -t wavoip:4 "ssh root@45.139.208.61"
    tmux send-keys -t wavoip:MYSQL "lazysql" C-m
    tmux send-keys -t wavoip:MONGO "vi-mongo" C-m

    tmux a -t wavoip
}

. "$HOME/.local/share/../bin/env"
