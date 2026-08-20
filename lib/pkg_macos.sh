#!/usr/bin/env bash
# macOS package installation via Homebrew. Sourced by install.sh.

pkg_bootstrap_homebrew() {
  if has brew; then
    log "Homebrew already installed"
  else
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
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

pkg_install_base() {
  pkg_bootstrap_homebrew
  log "Installing base packages"
  # Deliberately NOT installing brew's zsh: macOS ships zsh as the default
  # login shell already, and .tmux.conf / the rendered herdr config resolve to
  # /bin/zsh. Installing brew zsh would also mean editing /etc/shells before
  # chsh would accept it. If you do install it later, the if-shell probes in
  # .tmux.conf prefer it automatically.
  brew install \
    tmux git curl wget ripgrep fd fzf btop eza neovim coreutils
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
}

pkg_install_neovim() {
  # Covered by pkg_install_base; brew's neovim is current.
  log "Neovim installed via Homebrew"
}

pkg_install_font() {
  if system_profiler SPFontsDataType 2>/dev/null | grep -qi "0xProto"; then
    log "0xProto Nerd Font already installed"
    return 0
  fi
  log "Installing 0xProto Nerd Font"
  brew install --cask font-0xproto-nerd-font
}

pkg_install_ghostty() {
  if has ghostty || [[ -d /Applications/Ghostty.app ]]; then
    log "Ghostty already installed"
    return 0
  fi
  log "Installing Ghostty"
  brew install --cask ghostty
}

pkg_install_oh_my_posh() {
  # Covered by pkg_install_base.
  has oh-my-posh || warn "oh-my-posh missing after brew install; prompt will be plain"
}

pkg_set_default_shell() {
  local current target
  current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  target="$(command -v zsh)"
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
