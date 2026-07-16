#!/usr/bin/env bash
#
# Install user's nvim config on a VPS.
# Installs Neovim from GitHub releases (if system nvim is missing or <0.9),
# sparse-clones ONLY the nvim/ folder from a public repo, then symlinks it
# into ~/.config/nvim.
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

NVIM_VERSION="stable"                       # or a tag like v0.10.2
CLONE_DIR="${HOME}/.local/share/dot-files"  # where sparse repo lives
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
NVIM_PREFIX="${HOME}/.local"                # nvim installs under here
BIN_DIR="${NVIM_PREFIX}/bin"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo ">> $*"; }

[ -n "$REPO_URL" ] || die "repo URL required. Usage: bash -s -- <repo-url> [branch] [subdir]"
command -v git >/dev/null || die "git not installed. Install git first."
command -v curl >/dev/null || die "curl not installed."

# ---------------------------------------------------------------------------
# 1. Install Neovim from GitHub releases (Debian's nvim is too old for LazyVim)
# ---------------------------------------------------------------------------
install_nvim() {
  # Skip only if a recent-enough nvim (>=0.9) is already on PATH.
  if command -v nvim >/dev/null; then
    local v
    v="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    if [ -n "$v" ] && [ "$(printf '%s\n0.9\n' "$v" | sort -V | head -1)" = "0.9" ]; then
      log "nvim ${v} already present (>=0.9), skip install"
      return
    fi
    log "nvim ${v:-unknown} too old, installing newer from GitHub releases"
  fi

  local arch asset url dest
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  asset="nvim-linux-x86_64" ;;
    aarch64|arm64) asset="nvim-linux-arm64" ;;
    *) die "unsupported arch: $arch" ;;
  esac

  url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${asset}.tar.gz"
  dest="${NVIM_PREFIX}/nvim-dist"

  log "downloading nvim ${NVIM_VERSION} (${asset})"
  mkdir -p "$dest" "$BIN_DIR"
  curl -fsSL "$url" | tar xz -C "$dest" --strip-components=1

  ln -sf "${dest}/bin/nvim" "${BIN_DIR}/nvim"
  log "nvim installed -> ${BIN_DIR}/nvim"
}

# ---------------------------------------------------------------------------
# 2. Sparse-clone only the config subdir
# ---------------------------------------------------------------------------
clone_config() {
  # Fresh clone every run — avoids stale sparse/partial state from prior runs
  # (e.g. a clone made before this subdir existed). Repo is tiny, cost trivial.
  if [ -e "$CLONE_DIR" ]; then
    log "removing old clone at ${CLONE_DIR}"
    rm -rf "$CLONE_DIR"
  fi

  log "sparse-cloning ${SUBDIR} from ${REPO_URL} (${BRANCH})"
  git clone --filter=blob:none --sparse --depth 1 \
    --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
  git -C "$CLONE_DIR" sparse-checkout set "$SUBDIR"

  [ -d "${CLONE_DIR}/${SUBDIR}" ] || die "subdir '${SUBDIR}' not found in repo"

  # Drop broken symlinks (e.g. omarchy theme.lua -> ~/.config/omarchy/... which
  # does not exist on a VPS). LazyVim then falls back to its default colorscheme.
  local dead
  dead="$(find "${CLONE_DIR}/${SUBDIR}" -xtype l)"
  if [ -n "$dead" ]; then
    log "removing broken symlinks:"
    echo "$dead"
    find "${CLONE_DIR}/${SUBDIR}" -xtype l -delete
  fi
}

# ---------------------------------------------------------------------------
# 3. Symlink into ~/.config/nvim
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
  install_nvim
  clone_config
  link_config

  case ":$PATH:" in
    *":${BIN_DIR}:"*) ;;
    *) log "NOTE: add ${BIN_DIR} to PATH -> echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.bashrc && exec bash" ;;
  esac

  log "done. run: nvim  (LazyVim will bootstrap plugins on first launch)"
}

main
