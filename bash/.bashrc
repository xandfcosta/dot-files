# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
dev() {
    command -v tmux >/dev/null 2>&1 || {
        echo "tmux is not installed"
        return 1
    }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    tmux new -A -s dev -c ~/projects/
}

wavoip() {
    command -v tmux >/dev/null 2>&1 || {
        echo "tmux is not installed"
        return 1
    }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    eval $(keychain --eval --quiet ~/.ssh/prod)

    tmux new-session -A -d -s wavoip -n "21"

    for i in 22 23 24 25; do
        tmux new-window -t wavoip -n "$i" 2>/dev/null || true
    done

    tmux new-window -t wavoip -n MYSQL

    tmux send-keys -t wavoip:1 "ssh node-21-wavoip"
    tmux send-keys -t wavoip:2 "ssh node-22-wavoip"
    tmux send-keys -t wavoip:3 "ssh node-23-wavoip"
    tmux send-keys -t wavoip:4 "ssh node-24-wavoip"
    tmux send-keys -t wavoip:5 "ssh node-25-wavoip"
    tmux send-keys -t wavoip:MYSQL "sqlit" C-m

    if [ "$1" != "detach" ]; then
        tmux a -t wavoip
    fi
}

obsidian_nvim() {
    command -v tmux >/dev/null 2>&1 || {
        echo "tmux is not installed"
        return 1
    }

    if [ -n "$TMUX" ]; then
        tmux detach
    fi

    tmux new -A -d -s obsidian -c ~/Documents/obsidian-vaults/Personal/ "nvim ."

    if [ "$1" != "detach" ]; then
        tmux a -t obsidian
    fi
}

y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd <"$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

work() {
    wavoip detach
    obsidian_nvim detach
    dev
}

. "$HOME/.local/share/../bin/env"
