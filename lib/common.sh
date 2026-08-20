#!/usr/bin/env bash
# Shared helpers for install.sh. Sourced, never executed directly.
# Every function here must behave identically on Linux and macOS.

# ---- Logging ---------------------------------------------------------------

log() {
  printf "\n\033[1;36m[terminal-setup]\033[0m %s\n" "$1"
}

warn() {
  printf "\n\033[1;33m[terminal-setup] WARN:\033[0m %s\n" "$1" >&2
}

die() {
  printf "\n\033[1;31m[terminal-setup] ERROR:\033[0m %s\n" "$1" >&2
  exit 1
}

# ---- Platform detection ----------------------------------------------------

# Sets OS_NAME to one of: linux, macos
detect_os() {
  case "$(uname -s)" in
    Linux*)  OS_NAME="linux" ;;
    Darwin*) OS_NAME="macos" ;;
    *)       die "Unsupported OS: $(uname -s). Use install.ps1 on Windows." ;;
  esac
  export OS_NAME
}

# True when running inside WSL. Some steps (Ghostty via WSLg, clipboard over
# OSC 52) only make sense there.
is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# Sets ARCH_NAME to one of: x86_64, arm64
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  ARCH_NAME="x86_64" ;;
    aarch64|arm64) ARCH_NAME="arm64" ;;
    *)             die "Unsupported architecture: $(uname -m)" ;;
  esac
  export ARCH_NAME
}

need_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

has() {
  command -v "$1" >/dev/null 2>&1
}

# ---- Linking ---------------------------------------------------------------

backup_path() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    log "Backed up $target -> $backup"
  fi
}

# Symlink $1 -> $2, backing up whatever was there. Idempotent: an existing
# link already pointing at the right place is left alone.
link_file() {
  local src="$1"
  local dst="$2"
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  backup_path "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

# Write a generated (non-symlinked) config. Used for the two files that need
# platform-specific absolute paths baked in and support no include directive.
render_file() {
  local dst="$1"
  local content="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && [[ "$(cat "$dst")" == "$content" ]]; then
    return 0
  fi
  backup_path "$dst"
  printf '%s' "$content" > "$dst"
  log "Rendered $dst"
}

# ---- Resolved tool paths ---------------------------------------------------

# Absolute path to zsh. tmux, herdr and Ghostty all need this literal, and it
# differs per platform: /usr/bin/zsh on Debian, /bin/zsh on macOS stock,
# /opt/homebrew/bin/zsh when Homebrew's newer zsh is installed.
#
# Falls back rather than aborting: with a selective install such as
# `--only herdr`, zsh may legitimately not be present yet. A generated config
# pointing at a not-yet-installed path is recoverable (install zsh, re-run);
# aborting the whole run is not.
zsh_path() {
  local p
  p="$(command -v zsh 2>/dev/null || true)"
  if [[ -z "$p" ]]; then
    case "$OS_NAME" in
      macos) p="/bin/zsh" ;;
      *)     p="/usr/bin/zsh" ;;
    esac
    warn "zsh not found on PATH; generated configs will point at $p. Install zsh (or run without --only/--skip) and re-run to correct it."
  fi
  printf '%s' "$p"
}

# Absolute path to env(1), for Ghostty's `command = direct:` line.
env_path() {
  if [[ -x /usr/bin/env ]]; then
    printf '/usr/bin/env'
  else
    command -v env
  fi
}
