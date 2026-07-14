#!/bin/sh
# Print the ssh destination host if the given pane is running ssh (directly or
# via a descendant), else print nothing. Used by tmux status-right.
#
# Usage: ssh-status.sh <pane_pid>

pane_pid="$1"
[ -n "$pane_pid" ] || exit 0

# Collect the pane's process subtree (breadth-first) and find the first `ssh`.
ssh_pid=""
queue="$pane_pid"
while [ -n "$queue" ]; do
	next=""
	for pid in $queue; do
		# Match the ssh client, not sshd or scp/sftp.
		if [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = "ssh" ]; then
			ssh_pid="$pid"
			break 2
		fi
		next="$next $(pgrep -P "$pid" 2>/dev/null)"
	done
	queue="$next"
done

[ -n "$ssh_pid" ] || exit 0

# Full argument list of the ssh process.
args=$(ps -o args= -p "$ssh_pid" 2>/dev/null)
[ -n "$args" ] || exit 0

# Parse the destination: first non-option token, skipping options and any
# option that takes a separate argument.
set -- $args
shift # drop "ssh" itself
host=""
skip_next=0
for tok in "$@"; do
	if [ "$skip_next" = 1 ]; then
		skip_next=0
		continue
	fi
	case "$tok" in
		# Options that consume the following token as their value.
		-b|-c|-D|-E|-e|-F|-I|-i|-J|-L|-l|-m|-O|-o|-p|-Q|-R|-S|-W|-w)
			skip_next=1
			;;
		-*) # flag with no separate value (incl. bundled like -tt)
			;;
		*)
			host="$tok"
			break
			;;
	esac
done

[ -n "$host" ] || exit 0

# Strip user@ prefix and any :port suffix.
host="${host#*@}"
host="${host%%:*}"

printf ' %s' "$host"
