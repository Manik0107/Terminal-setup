#!/usr/bin/env bash
# macOS package installation via Homebrew. Sourced by install.sh.
# One function per component, so install.sh can select them individually.

pkg_bootstrap_homebrew() {
  if has brew; then
    return 0
  fi
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # brew is not on PATH in the same shell that just installed it.
  local prefix
  for prefix in /opt/homebrew /usr/local; do
    if [[ -x "$prefix/bin/brew" ]]; then
      eval "$("$prefix/bin/brew" shellenv)"
      break
    fi
  done
  has brew || die "Homebrew install finished but brew is not on PATH"
}

pkg_install_core() {
  pkg_bootstrap_homebrew
  log "Installing core packages"
  # Deliberately NOT installing brew's zsh: macOS ships zsh as the default
  # login shell already, and .tmux.conf plus the rendered herdr config resolve
  # to /bin/zsh. Installing brew zsh would also mean editing /etc/shells before
  # chsh would accept it. If you do install it later, the if-shell probes in
  # .tmux.conf prefer it automatically.
  brew install git curl wget coreutils
}

pkg_install_cli() {
  pkg_bootstrap_homebrew
  log "Installing CLI tools"
  brew install ripgrep fd fzf btop eza
}

pkg_install_tmux() {
  pkg_bootstrap_homebrew
  log "Installing tmux"
  brew install tmux
}

pkg_install_neovim() {
  pkg_bootstrap_homebrew
  log "Installing Neovim"
  brew install neovim
}

pkg_install_font() {
  pkg_bootstrap_homebrew
  if system_profiler SPFontsDataType 2>/dev/null | grep -qi "0xProto"; then
    log "0xProto Nerd Font already installed"
    return 0
  fi
  log "Installing 0xProto Nerd Font"
  brew install --cask font-0xproto-nerd-font
}

pkg_install_ghostty() {
  pkg_bootstrap_homebrew
  if has ghostty || [[ -d /Applications/Ghostty.app ]]; then
    log "Ghostty already installed"
    return 0
  fi
  log "Installing Ghostty"
  brew install --cask ghostty
}

pkg_install_oh_my_posh() {
  pkg_bootstrap_homebrew
  if has oh-my-posh; then
    log "Oh My Posh already installed"
    return 0
  fi
  log "Installing Oh My Posh"
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
}

pkg_set_default_shell() {
  local current target
  target="$(command -v zsh || true)"
  if [[ -z "$target" ]]; then
    warn "zsh is not installed; leaving your login shell alone"
    return 0
  fi
  current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  if [[ "$current" == "$target" ]]; then
    return 0
  fi
  # chsh refuses any shell absent from /etc/shells.
  if ! grep -qxF "$target" /etc/shells 2>/dev/null; then
    log "Adding $target to /etc/shells (may ask for your password)"
    printf '%s\n' "$target" | need_sudo tee -a /etc/shells >/dev/null
  fi
  log "Setting zsh as default shell (may ask for your password)"
  chsh -s "$target" || warn "chsh failed; run 'chsh -s $target' yourself"
}
