#!/usr/bin/env bash
# Prune local git branches whose remote tracking branch is gone,
# across every repo found in a given folder.
#
# Usage:
#   ./prune_all_branches.sh                  # scans current folder
#   ./prune_all_branches.sh /path/to/repos    # scans a specific folder
#   ./prune_all_branches.sh --dry-run         # preview only, no deletions
#   ./prune_all_branches.sh /path/to/repos --dry-run

ROOT_DIR="."
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) ROOT_DIR="$arg" ;;
  esac
done

for dir in "$ROOT_DIR"/*/; do
  [ -d "$dir/.git" ] || continue
  echo "=== $dir ==="
  (
    cd "$dir" || exit 1
    git fetch --prune --quiet 2>/dev/null

    # Strip a leading "* " (current branch marker) before checking for "gone"
    gone=$(git branch -vv | awk '{ sub(/^\* /, ""); if ($0 ~ /: gone]/) print $1 }')

    if [ -z "$gone" ]; then
      echo "  nothing to prune"
    elif [ "$DRY_RUN" = true ]; then
      echo "  would delete:"
      echo "$gone" | sed 's/^/    /'
    else
      echo "$gone" | xargs -r git branch -D
    fi
  )
done
