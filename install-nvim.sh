#!/usr/bin/env bash
#
# Install user's nvim config on a VPS.
# Sparse-clones ONLY the nvim/ folder from a public repo, then symlinks it
# into ~/.config/nvim. Assumes nvim is already installed.
#
# Usage (pipe to bash, pass args after --):
#   curl -fsSL https://raw.githubusercontent.com/YOU/dot-files/main/install-nvim.sh \
#     | bash -s -- https://github.com/YOU/dot-files main nvim
#
# Args:
#   $1  repo URL        (required, e.g. https://github.com/YOU/dot-files)
#   $2  branch          (optional, default: main)
#   $3  subdir in repo  (optional, default: nvim)

set -euo pipefail

REPO_URL="${1:-}"
BRANCH="${2:-main}"
SUBDIR="${3:-nvim}"

CLONE_DIR="${HOME}/.local/share/dot-files"  # where sparse repo lives
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo ">> $*"; }

[ -n "$REPO_URL" ] || die "repo URL required. Usage: bash -s -- <repo-url> [branch] [subdir]"
command -v git >/dev/null || die "git not installed. Install git first."

# ---------------------------------------------------------------------------
# 1. Sparse-clone only the config subdir
# ---------------------------------------------------------------------------
clone_config() {
  if [ -d "${CLONE_DIR}/.git" ]; then
    log "repo exists, pulling latest"
    git -C "$CLONE_DIR" fetch --depth 1 origin "$BRANCH"
    git -C "$CLONE_DIR" checkout "$BRANCH"
    git -C "$CLONE_DIR" reset --hard "origin/${BRANCH}"
  else
    log "sparse-cloning ${SUBDIR} from ${REPO_URL}"
    git clone --filter=blob:none --sparse --depth 1 \
      --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
    git -C "$CLONE_DIR" sparse-checkout set "$SUBDIR"
  fi

  [ -d "${CLONE_DIR}/${SUBDIR}" ] || die "subdir '${SUBDIR}' not found in repo"
}

# ---------------------------------------------------------------------------
# 2. Symlink into ~/.config/nvim
# ---------------------------------------------------------------------------
link_config() {
  mkdir -p "$(dirname "$CONFIG_DIR")"

  if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
    local backup="${CONFIG_DIR}.bak.$(date +%s)"
    log "existing ${CONFIG_DIR} -> backup ${backup}"
    mv "$CONFIG_DIR" "$backup"
  fi

  ln -s "${CLONE_DIR}/${SUBDIR}" "$CONFIG_DIR"
  log "linked ${CONFIG_DIR} -> ${CLONE_DIR}/${SUBDIR}"
}

# ---------------------------------------------------------------------------
main() {
  clone_config
  link_config
  log "done. run: nvim  (LazyVim will bootstrap plugins on first launch)"
}

main
