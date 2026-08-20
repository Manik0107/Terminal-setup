#!/usr/bin/env bash
# Terminal-setup - one-command install for Linux and macOS.
#
#   bash install.sh                          # everything
#   bash install.sh --list                   # show components, then exit
#   bash install.sh --only zsh,herdr,ghostty # just these
#   bash install.sh --skip tmux,nvim         # everything except these
#   bash install.sh --configs-only           # place configs, install nothing
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
ONLY_LIST=""
SKIP_LIST=""

# Component order is dependency order: core provides the compilers and curl the
# later ones need, zsh must be configured before anything that reads its path.
ALL_COMPONENTS=(core cli font zsh prompt herdr tmux nvim ghostty opencode)

component_help() {
  cat <<'EOF'
  core      zsh, git, curl, wget, unzip, build tools, python3
  cli       ripgrep, fd, fzf, btop, eza
  font      0xProto Nerd Font
  zsh       Oh My Zsh + plugins, .zshrc/.zprofile, sets zsh as login shell
  prompt    Oh My Posh + the shared theme (alias: omp)
  herdr     herdr binary, ~/.config/herdr/config.toml, zsh completions
  tmux      tmux, TPM + plugins, .tmux.conf, start-tmux-workspace
  nvim      Neovim, LazyVim config, headless plugin sync
  ghostty   Ghostty, ~/.config/ghostty/config
  opencode  OpenCode CLI + config
EOF
}

usage() {
  cat <<'EOF'
Terminal-setup installer (Linux / macOS)

Usage: bash install.sh [options]

Selection:
  --only  a,b,c          Install ONLY these components.
  --skip  a,b,c          Install everything EXCEPT these.
  --list                 List components and exit.

Options:
  --configs-only         Place configs only; install no packages.
  --skip-nvim-bootstrap  Do not run the headless LazyVim plugin sync.
  -h, --help             Show this help.

Components:
EOF
  component_help
  cat <<'EOF'

Examples:
  bash install.sh --only zsh,prompt,herdr,ghostty
  bash install.sh --skip tmux              # on herdr, tmux is redundant
  bash install.sh --skip nvim,opencode
  bash install.sh --only nvim              # just the editor and its config

Notes:
  --only and --skip are mutually exclusive.
  --only installs exactly what you name and nothing else, so it will not pull
  in 'core' implicitly. If a needed tool (git, curl) is missing you get a
  warning naming it rather than a surprise apt/brew run.

Windows: use install.ps1 (see README.md).
EOF
}

# ---- Component selection ---------------------------------------------------

# Accept a few obvious aliases rather than failing on a near-miss.
canonical_component() {
  case "$1" in
    omp|oh-my-posh)      printf 'prompt' ;;
    neovim|vim)          printf 'nvim' ;;
    fonts)               printf 'font' ;;
    tools)               printf 'cli' ;;
    oh-my-zsh|omz|shell) printf 'zsh' ;;
    *)                   printf '%s' "$1" ;;
  esac
}

is_known_component() {
  local c
  for c in "${ALL_COMPONENTS[@]}"; do
    [[ "$c" == "$1" ]] && return 0
  done
  return 1
}

# Normalises a comma/space separated list, validating every entry. An unknown
# name is fatal: silently ignoring a typo would mean quietly not installing
# something the user explicitly asked for.
parse_component_list() {
  local raw="$1" flag="$2" out=() name
  raw="${raw//,/ }"
  for name in $raw; do
    name="$(canonical_component "$name")"
    if ! is_known_component "$name"; then
      printf 'Unknown component for %s: %s\n\nAvailable:\n' "$flag" "$name" >&2
      component_help >&2
      exit 1
    fi
    out+=("$name")
  done
  [[ ${#out[@]} -gt 0 ]] || die "$flag needs at least one component name"
  printf '%s' "${out[*]}"
}

SELECTED=""

resolve_selection() {
  if [[ -n "$ONLY_LIST" && -n "$SKIP_LIST" ]]; then
    die "--only and --skip are mutually exclusive"
  fi

  local chosen=()
  if [[ -n "$ONLY_LIST" ]]; then
    # Preserve ALL_COMPONENTS order, not the order given on the command line,
    # so dependencies still run in the right sequence.
    local want c
    want=" $(parse_component_list "$ONLY_LIST" --only) "
    for c in "${ALL_COMPONENTS[@]}"; do
      [[ "$want" == *" $c "* ]] && chosen+=("$c")
    done
  elif [[ -n "$SKIP_LIST" ]]; then
    local drop c
    drop=" $(parse_component_list "$SKIP_LIST" --skip) "
    for c in "${ALL_COMPONENTS[@]}"; do
      [[ "$drop" == *" $c "* ]] || chosen+=("$c")
    done
  else
    chosen=("${ALL_COMPONENTS[@]}")
  fi

  SELECTED=" ${chosen[*]} "
}

want() {
  [[ "$SELECTED" == *" $1 "* ]]
}

# Wraps a package install so --configs-only turns it into a no-op without every
# component needing its own guard.
pkg() {
  [[ "$CONFIGS_ONLY" -eq 1 ]] && return 0
  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --only)
        [[ $# -ge 2 ]] || die "--only needs a comma-separated list"
        ONLY_LIST="$2"; shift ;;
      --only=*)              ONLY_LIST="${1#*=}" ;;
      --skip)
        [[ $# -ge 2 ]] || die "--skip needs a comma-separated list"
        SKIP_LIST="$2"; shift ;;
      --skip=*)              SKIP_LIST="${1#*=}" ;;
      --list)
        printf 'Components:\n'; component_help; exit 0 ;;
      --configs-only)        CONFIGS_ONLY=1 ;;
      --skip-nvim-bootstrap) SKIP_NVIM_BOOTSTRAP=1 ;;
      -h|--help)             usage; exit 0 ;;
      *)                     die "Unknown option: $1 (try --help)" ;;
    esac
    shift
  done
}

# Warns about tools a selective install assumes but did not include, instead of
# installing them behind the user's back.
check_prerequisites() {
  [[ -n "$ONLY_LIST" ]] || return 0
  local tool
  for tool in git curl; do
    has "$tool" || warn "'$tool' is not installed and 'core' is not in --only; some steps will fail. Add core, or install $tool first."
  done
}

# ---- Components ------------------------------------------------------------

component_core() {
  pkg pkg_install_core
}

component_cli() {
  pkg pkg_install_cli
}

component_font() {
  pkg pkg_install_font
}

component_zsh() {
  if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
      log "Installing Oh My Zsh"
      # KEEP_ZSHRC is essential: the default installer would overwrite the
      # .zshrc this function is about to symlink.
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
      [[ -d "$custom_plugins/$name" ]] || \
        git clone --depth 1 "https://github.com/$repo" "$custom_plugins/$name"
    done
  fi

  link_file "$CONFIG_DIR/zsh/.zshrc"    "$HOME/.zshrc"
  link_file "$CONFIG_DIR/zsh/.zprofile" "$HOME/.zprofile"

  pkg pkg_set_default_shell
}

component_prompt() {
  pkg pkg_install_oh_my_posh
  link_file "$CONFIG_DIR/omp-config/myconfig.json" "$HOME/omp-config/myconfig.json"
}

component_herdr() {
  pkg install_herdr_binary

  render_file "$HOME/.config/herdr/config.toml" \
    "$(sed -e "s|@@ZSH@@|$(zsh_path)|g" "$CONFIG_DIR/herdr/config.toml.tmpl")"

  if has herdr && [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    log "Installing herdr zsh completions"
    mkdir -p "$HOME/.local/share/zsh/site-functions"
    herdr completion zsh > "$HOME/.local/share/zsh/site-functions/_herdr"
  fi
}

component_tmux() {
  pkg pkg_install_tmux

  link_file "$CONFIG_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
  chmod +x "$CONFIG_DIR/tmux/start-workspace.sh"
  mkdir -p "$HOME/.local/bin"
  link_file "$CONFIG_DIR/tmux/start-workspace.sh" "$HOME/.local/bin/start-tmux-workspace"

  if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
      log "Installing TPM"
      git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    else
      log "TPM already installed"
    fi
    if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
      log "Installing tmux plugins"
      "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn "TPM plugin install failed"
    fi
  fi
}

component_nvim() {
  pkg pkg_install_neovim
  link_file "$CONFIG_DIR/nvim" "$HOME/.config/nvim"

  if [[ "$CONFIGS_ONLY" -eq 0 && "$SKIP_NVIM_BOOTSTRAP" -eq 0 ]]; then
    if has nvim; then
      log "Bootstrapping LazyVim plugins"
      nvim --headless "+Lazy! sync" +qa || warn "LazyVim sync failed; open nvim and run :Lazy sync"
    else
      warn "nvim not found; skipping LazyVim bootstrap"
    fi
  fi
}

component_ghostty() {
  pkg pkg_install_ghostty

  local platform_file
  case "$OS_NAME" in
    linux) platform_file="$CONFIG_DIR/ghostty/config.linux" ;;
    macos) platform_file="$CONFIG_DIR/ghostty/config.macos" ;;
  esac

  render_file "$HOME/.config/ghostty/config" \
    "$(cat "$CONFIG_DIR/ghostty/config.shared" "$platform_file" \
       | sed -e "s|@@ENV@@|$(env_path)|g" -e "s|@@ZSH@@|$(zsh_path)|g")"
}

component_opencode() {
  if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    if has opencode; then
      log "OpenCode already installed"
    else
      log "Installing OpenCode"
      curl -fsSL https://opencode.ai/install | bash
    fi
  fi
  link_file "$CONFIG_DIR/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
}

# herdr publishes plain binaries per os/arch. Asset names are resolved from the
# releases API rather than hardcoded, because they have changed between
# versions and differ across platforms. Non-fatal: without herdr, .zshrc falls
# through to a bare shell.
install_herdr_binary() {
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
    warn "herdr install failed for ${os_token}/${ARCH_NAME}. Install it manually from https://herdr.dev - tmux still works, and .zshrc drops to a bare shell without it."
  fi
}

# ---- Verification ----------------------------------------------------------

# Only checks what this run actually generated, so a selective install does not
# warn about a config it was never asked to write.
verify_configs() {
  log "Verifying generated configs"
  if want herdr && has herdr; then
    herdr config check || warn "herdr config check reported problems"
  fi
  if want ghostty && has ghostty; then
    ghostty +validate-config >/dev/null 2>&1 \
      && log "ghostty config valid" \
      || warn "ghostty +validate-config reported problems"
  fi
  # -L keeps this off the user's live server and out of their session list.
  if want tmux && has tmux; then
    tmux -L tsverify -f "$HOME/.tmux.conf" start-server \; kill-server 2>/dev/null \
      && log "tmux config valid" \
      || warn "tmux could not parse ~/.tmux.conf"
  fi
}

# ---- Main ------------------------------------------------------------------

main() {
  parse_args "$@"
  detect_os
  detect_arch
  resolve_selection

  log "Platform: $OS_NAME/$ARCH_NAME$(is_wsl && printf ' (WSL)')"
  log "Components:${SELECTED%" "}"
  [[ "$CONFIGS_ONLY" -eq 1 ]] && log "--configs-only: no packages will be installed"

  # shellcheck source=/dev/null
  source "$ROOT_DIR/lib/pkg_${OS_NAME}.sh"

  check_prerequisites

  local c
  for c in "${ALL_COMPONENTS[@]}"; do
    want "$c" && "component_$c"
  done

  verify_configs

  log "Done. Restart your terminal or run: exec zsh"
}

main "$@"
