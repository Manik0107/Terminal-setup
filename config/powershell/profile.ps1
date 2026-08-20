# PowerShell 7 profile - native Windows counterpart to config/zsh/.zshrc
#
# Installed by install.ps1 to $PROFILE.CurrentUserAllHosts.
# Reload without restarting: . $PROFILE
#
# This mirrors the zsh setup as closely as PowerShell allows. What has no
# equivalent, and why, is listed at the bottom of this file.

# ---- PATH ------------------------------------------------------------------
# Mirrors .zshrc's $HOME/.local/bin prepend. Scoop and winget shims land here
# too, so user-installed tools win over machine-wide ones.
$LocalBin = Join-Path $HOME '.local\bin'
if ((Test-Path $LocalBin) -and ($env:PATH -notlike "*$LocalBin*")) {
  $env:PATH = "$LocalBin;$env:PATH"
}

# ---- Prompt ----------------------------------------------------------------
# Same oh-my-posh theme file as Linux/macOS, so the prompt is byte-identical.
$OmpConfig = Join-Path $HOME 'omp-config\myconfig.json'
if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path $OmpConfig)) {
  oh-my-posh init pwsh --config $OmpConfig | Invoke-Expression
}

# ---- Line editing ----------------------------------------------------------
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine

  # Emacs, NOT the PowerShell default 'Windows' mode. zsh with oh-my-zsh runs
  # emacs bindings, so this is what makes ctrl+a, ctrl+e, ctrl+w, ctrl+u and
  # ctrl+r behave the same on Windows as in zsh.
  # NOTE: ctrl+a is beginning-of-line here. It is the multiplexer prefix only
  # inside herdr/tmux, which do not exist natively on Windows - so there is no
  # collision, but the key does mean two different things depending on whether
  # you are in native pwsh or in WSL.
  Set-PSReadLineOption -EditMode Emacs

  # Stands in for zsh-autosuggestions: greys out a prediction from history that
  # RightArrow / End accepts, same gesture as zsh.
  Set-PSReadLineOption -PredictionSource HistoryAndPlugin
  Set-PSReadLineOption -PredictionViewStyle InlineView

  # Stands in for zsh-syntax-highlighting. Colours chosen to match the cyan
  # accent (#22d3ee) used in ghostty, tmux and herdr.
  Set-PSReadLineOption -Colors @{
    Command   = '#22d3ee'
    Parameter = '#8be9fd'
    Operator  = '#e6e6e6'
    Variable  = '#22d3ee'
    String    = '#a5d6a7'
    Number    = '#ffb86c'
    Comment   = '#6b7280'
    Error     = '#ff5555'
  }

  # Prefix-search on the arrow keys, like oh-my-zsh's history-substring search.
  Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  Set-PSReadLineOption -HistorySearchCursorMovesToEnd
}

# ---- fzf -------------------------------------------------------------------
# PSFzf provides ctrl+t (files) and ctrl+r (history), the same two bindings the
# fzf shell integration installs under zsh.
if (Get-Module -ListAvailable -Name PSFzf) {
  Import-Module PSFzf
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ---- Aliases ---------------------------------------------------------------
# Same four eza aliases as .zshrc. Remove-Item first: ls and Get-ChildItem are
# built-in aliases and Set-Alias alone will not override ls.
if (Get-Command eza -ErrorAction SilentlyContinue) {
  Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
  function ls { eza --icons --group-directories-first @args }
  function ll { eza -lah --icons --group-directories-first @args }
  function la { eza -a --icons --group-directories-first @args }
  function lt { eza --tree --level=2 --icons @args }
}

# Matches EZA_COLORS in .zshrc - everything in cyan.
$env:EZA_COLORS = 'di=1;36:fi=1;36:ln=1;36:ex=1;36:pi=1;36:so=1;36:bd=1;36:cd=1;36:su=1;36:sg=1;36:da=1;36:ur=1;36:uw=1;36:ux=1;36:gr=1;36:gw=1;36:gx=1;36:tr=1;36:tw=1;36:tx=1;36'

# ---- z ---------------------------------------------------------------------
# zoxide is the maintained equivalent of oh-my-zsh's `z` plugin, and registers
# the same `z <partial-dir>` verb.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init powershell --cmd z | Out-String) })
}

# ---- conda -----------------------------------------------------------------
# Mirrors the optional conda block in .zshrc. Windows keeps the hook script in
# the install root rather than etc/profile.d.
$CondaHook = Join-Path $HOME 'miniconda3\shell\condabin\conda-hook.ps1'
if (Test-Path $CondaHook) { . $CondaHook }

# ---- Editor ----------------------------------------------------------------
if (Get-Command nvim -ErrorAction SilentlyContinue) {
  $env:EDITOR = 'nvim'
  $env:VISUAL = 'nvim'
  Set-Alias vi nvim
  Set-Alias vim nvim
}

# ---- WSL shortcut ----------------------------------------------------------
# The full keybinding set (herdr/tmux prefix ctrl+a, pane focus on bare
# ctrl+h/j/k/l) only exists inside WSL. `ws` is the one-word way in.
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
  function ws { wsl.exe @args }
}

# ---- Local overrides -------------------------------------------------------
# Counterpart to ~/.zshrc.local: secrets, tokens, machine-only paths.
# Gitignored - never commit it.
$LocalProfile = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'profile.local.ps1'
if (Test-Path $LocalProfile) { . $LocalProfile }

# ---- No native equivalent --------------------------------------------------
# 1. herdr / tmux. Neither has a native Windows build, so the multiplexer
#    keybindings (prefix ctrl+a, prefix+| and prefix+- splits, prefix+h/j/k/l
#    resize, prefix+m zoom, bare ctrl+h/j/k/l pane focus) do not exist in native
#    pwsh. Run `install.ps1 -WithWSL` and work inside WSL to get them; Windows
#    Terminal's own pane bindings are on alt+arrows precisely so they do not
#    intercept the keys herdr needs.
# 2. The auto-start-multiplexer block at the end of .zshrc. Nothing to start.
# 3. ENABLE_CORRECTION (zsh's "did you mean" prompt). PSReadLine has no
#    equivalent; the prediction view covers most of what it was useful for.
# 4. The pokemon-colorscripts + fastfetch startup banner. fastfetch has a
#    Windows build, but pokemon-colorscripts is a shell script that needs a
#    POSIX environment.
