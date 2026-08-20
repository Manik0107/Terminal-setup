#!/usr/bin/env bash
# Linux (Debian/Ubuntu) package installation. Sourced by install.sh.

have_apt_package() {
  apt-cache show "$1" >/dev/null 2>&1
}

pkg_install_base() {
  has apt || die "install.sh supports Debian/Ubuntu on Linux (apt not found)"
  log "Installing base packages"
  need_sudo apt update
  need_sudo apt install -y \
    zsh tmux git curl wget unzip build-essential ca-certificates \
    fontconfig python3 python3-pip ripgrep fd-find fzf btop

  # eza is only packaged from Ubuntu 24.04 / Debian 13 onward.
  if have_apt_package eza; then
    need_sudo apt install -y eza
  else
    warn "eza not in apt; ls/ll/la/lt aliases will fall back to plain ls"
  fi
}

pkg_install_neovim() {
  log "Installing latest Neovim"
  local tmp_dir archive extracted_dir
  tmp_dir="$(mktemp -d)"
  case "$ARCH_NAME" in
    x86_64) archive="nvim-linux-x86_64.tar.gz"; extracted_dir="nvim-linux-x86_64" ;;
    arm64)  archive="nvim-linux-arm64.tar.gz";  extracted_dir="nvim-linux-arm64" ;;
  esac
  curl -fsSL -o "$tmp_dir/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/$archive"
  need_sudo rm -rf /opt/nvim
  need_sudo tar -C /opt -xzf "$tmp_dir/nvim.tar.gz"
  need_sudo mv "/opt/$extracted_dir" /opt/nvim
  need_sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp_dir"
}

pkg_install_font() {
  if fc-list 2>/dev/null | grep -qi "0xProto Nerd Font"; then
    log "0xProto Nerd Font already installed"
    return 0
  fi
  log "Installing 0xProto Nerd Font"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "$HOME/.local/share/fonts"
  curl -fsSL -o "$tmp_dir/0xProto.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip"
  unzip -qo "$tmp_dir/0xProto.zip" -d "$HOME/.local/share/fonts"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null
  rm -rf "$tmp_dir"
}

pkg_install_ghostty() {
  if has ghostty; then
    log "Ghostty already installed"
    return 0
  fi
  # Ghostty is only in the official Ubuntu repos from 26.04 onward; 24.04 uses
  # the community PPA. Under WSL it runs as a WSLg GUI app inside the distro.
  log "Installing Ghostty from ppa:mkasberg/ghostty-ubuntu"
  if ! has add-apt-repository; then
    need_sudo apt install -y software-properties-common
  fi
  need_sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
  need_sudo apt update
  need_sudo apt install -y ghostty
}

pkg_install_oh_my_posh() {
  if has oh-my-posh; then
    log "Oh My Posh already installed"
    return 0
  fi
  log "Installing Oh My Posh"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
}

# zsh ships as a package here, so it needs no separate step, but chsh does.
pkg_set_default_shell() {
  local current target
  current="$(getent passwd "$USER" | cut -d: -f7)"
  target="$(command -v zsh)"
  if [[ "$current" != "$target" ]]; then
    log "Setting zsh as default shell (may ask for your password)"
    chsh -s "$target" || warn "chsh failed; run 'chsh -s $target' yourself"
  fi
}
