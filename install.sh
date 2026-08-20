#!/usr/bin/env bash
# Terminal-setup — one-command install for Linux and macOS.
#
#   bash install.sh                 # everything
#   bash install.sh --configs-only  # skip package installs, just link configs
#   bash install.sh --help
#
# On Windows, run install.ps1 instead.
#
# Safe to re-run: existing files are backed up with a timestamp before being
# replaced, and every install step short-circuits when the tool is present.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"

# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

CONFIGS_ONLY=0
SKIP_NVIM_BOOTSTRAP=0

usage() {
  cat <<'EOF'
Terminal-setup installer (Linux / macOS)

Usage: bash install.sh [options]

Options:
  --configs-only          Link/render configs only; install no packages.
  --skip-nvim-bootstrap   Do not run the headless LazyVim plugin sync.
  -h, --help              Show this help.

Windows: use install.ps1 (see README.md).
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --configs-only)        CONFIGS_ONLY=1 ;;
      --skip-nvim-bootstrap) SKIP_NVIM_BOOTSTRAP=1 ;;
      -h|--help)             usage; exit 0 ;;
      *)                     die "Unknown option: $1 (try --help)" ;;
    esac
    shift
  done
}

# ---- Cross-platform installs (identical on Linux and macOS) ----------------

install_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh"
    # KEEP_ZSHRC is essential: the default installer would overwrite the
    # .zshrc this script is about to symlink.
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    log "Oh My Zsh already installed"
  fi

  local custom_plugins="$HOME/.oh-my-zsh/custom/plugins"
  mkdir -p "$custom_plugins"
  local repo name
  for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
    name="${repo##*/}"
    if [[ ! -d "$custom_plugins/$name" ]]; then
      git clone --depth 1 "https://github.com/$repo" "$custom_plugins/$name"
    fi
  done
}

install_opencode() {
  if has opencode; then
    log "OpenCode already installed"
    return 0
  fi
  log "Installing OpenCode"
  curl -fsSL https://opencode.ai/install | bash
}

# herdr publishes plain binaries per os/arch. Asset names are resolved from the
# releases API rather than hardcoded, because they have changed between
# versions and differ across platforms. Non-fatal: herdr is the multiplexer,
# but tmux is installed too and .zshrc falls through to a bare shell without it.
install_herdr() {
  if has herdr; then
    log "herdr already installed"
    return 0
  fi
  log "Installing herdr"

  local os_token arch_alt asset_url
  case "$OS_NAME" in
    linux) os_token="linux" ;;
    macos) os_token="darwin" ;;
  esac
  case "$ARCH_NAME" in
    x86_64) arch_alt="amd64" ;;
    arm64)  arch_alt="aarch64" ;;
  esac

  asset_url="$(curl -fsSL https://api.github.com/repos/herdrdev/herdr/releases/latest 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]*"' \
    | sed -E 's/.*"(https[^"]*)"/\1/' \
    | grep -i -- "$os_token" \
    | grep -iE -- "$ARCH_NAME|$arch_alt" \
    | head -1 || true)"

  if [[ -z "$asset_url" ]]; then
    # Fall back to the naming scheme used up to v0.8.x.
    asset_url="https://github.com/herdrdev/herdr/releases/latest/download/herdr-${os_token}-${ARCH_NAME}"
    warn "Could not resolve herdr asset from the releases API; trying $asset_url"
  fi

  mkdir -p "$HOME/.local/bin"
  if curl -fsSL -o "$HOME/.local/bin/herdr" "$asset_url"; then
    chmod +x "$HOME/.local/bin/herdr"
  else
    rm -f "$HOME/.local/bin/herdr"
    warn "herdr install failed for ${os_token}/${ARCH_NAME}. Install it manually from https://herdr.dev — tmux still works, and .zshrc drops to a bare shell without it."
  fi
}

install_tpm() {
  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    log "Installing TPM"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  else
    log "TPM already installed"
  fi
}

# ---- Config placement ------------------------------------------------------

link_configs() {
  log "Linking configs"
  mkdir -p "$HOME/.local/bin" "$HOME/.config"

  link_file "$CONFIG_DIR/zsh/.zshrc"             "$HOME/.zshrc"
  link_file "$CONFIG_DIR/zsh/.zprofile"          "$HOME/.zprofile"
  link_file "$CONFIG_DIR/tmux/.tmux.conf"        "$HOME/.tmux.conf"
  link_file "$CONFIG_DIR/tmux/start-workspace.sh" "$HOME/.local/bin/start-tmux-workspace"
  link_file "$CONFIG_DIR/nvim"                   "$HOME/.config/nvim"
  link_file "$CONFIG_DIR/omp-config/myconfig.json" "$HOME/omp-config/myconfig.json"
  link_file "$CONFIG_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"

  chmod +x "$CONFIG_DIR/tmux/start-workspace.sh"
}

# Ghostty and herdr need zsh's absolute path as a literal and support no
# include directive, so they are generated rather than symlinked.
render_configs() {
  log "Rendering platform-specific configs"
  local zsh_bin env_bin platform_file
  zsh_bin="$(zsh_path)"
  env_bin="$(env_path)"

  case "$OS_NAME" in
    linux) platform_file="$CONFIG_DIR/ghostty/config.linux" ;;
    macos) platform_file="$CONFIG_DIR/ghostty/config.macos" ;;
  esac

  render_file "$HOME/.config/ghostty/config" \
    "$(cat "$CONFIG_DIR/ghostty/config.shared" "$platform_file" \
       | sed -e "s|@@ENV@@|$env_bin|g" -e "s|@@ZSH@@|$zsh_bin|g")"

  render_file "$HOME/.config/herdr/config.toml" \
    "$(sed -e "s|@@ZSH@@|$zsh_bin|g" "$CONFIG_DIR/herdr/config.toml.tmpl")"
}

# ---- Post-install ----------------------------------------------------------

install_tmux_plugins() {
  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    log "Installing tmux plugins"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install failed"
  fi
}

install_herdr_completions() {
  has herdr || return 0
  log "Installing herdr zsh completions"
  mkdir -p "$HOME/.local/share/zsh/site-functions"
  herdr completion zsh > "$HOME/.local/share/zsh/site-functions/_herdr"
}

verify_configs() {
  log "Verifying generated configs"
  if has herdr; then
    herdr config check || warn "herdr config check reported problems"
  fi
  if has ghostty; then
    ghostty +validate-config >/dev/null 2>&1 \
      && log "ghostty config valid" \
      || warn "ghostty +validate-config reported problems"
  fi
  # -f keeps this off the user's live server and out of their session list.
  if has tmux; then
    tmux -L tsverify -f "$HOME/.tmux.conf" start-server \; kill-server 2>/dev/null \
      && log "tmux config valid" \
      || warn "tmux could not parse ~/.tmux.conf"
  fi
}

bootstrap_nvim_plugins() {
  [[ "$SKIP_NVIM_BOOTSTRAP" -eq 1 ]] && return 0
  has nvim || { warn "nvim not found; skipping LazyVim bootstrap"; return 0; }
  log "Bootstrapping LazyVim plugins"
  nvim --headless "+Lazy! sync" +qa || warn "LazyVim sync failed; open nvim and run :Lazy sync"
}

# ---- Main ------------------------------------------------------------------

main() {
  parse_args "$@"
  detect_os
  detect_arch
  log "Platform: $OS_NAME/$ARCH_NAME$(is_wsl && printf ' (WSL)')"

  # shellcheck source=/dev/null
  source "$ROOT_DIR/lib/pkg_${OS_NAME}.sh"

  if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    pkg_install_base
    pkg_install_neovim
    pkg_install_font
    pkg_install_ghostty
    pkg_install_oh_my_posh
    install_oh_my_zsh
    install_opencode
    install_herdr
    install_tpm
  else
    log "--configs-only: skipping package installs"
  fi

  link_configs
  render_configs

  if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    install_tmux_plugins
    install_herdr_completions
    bootstrap_nvim_plugins
    pkg_set_default_shell
  fi

  verify_configs

  log "Done. Restart your terminal or run: exec zsh"
}

main "$@"
