<#
.SYNOPSIS
  Terminal-setup - one-command install for Windows.

.DESCRIPTION
  Sets up the native Windows side (PowerShell 7 profile, oh-my-posh with the
  shared theme, Neovim with the shared LazyVim config, Windows Terminal colours
  and keys, the 0xProto Nerd Font) and can optionally bootstrap WSL and run
  install.sh inside it.

  Read this first: the full keybinding set - herdr/tmux prefix ctrl+a, splits on
  prefix+| and prefix+-, resize on prefix+h/j/k/l, pane focus on bare
  ctrl+h/j/k/l - only exists inside WSL, because neither herdr nor tmux has a
  native Windows build. Use -WithWSL if you want parity with your Linux and mac
  machines. Native Windows gets matching shell editing keys, prompt, colours,
  font and Neovim bindings.

.PARAMETER WithWSL
  Also install WSL + a distro and run install.sh inside it. This is what gives
  you identical multiplexer keybindings.

.PARAMETER ConfigsOnly
  Place configs only; install no packages.

.PARAMETER SkipWindowsTerminal
  Do not touch Windows Terminal's settings.json. Merging rewrites that file
  (dropping any comments in it), so this is the opt-out. A timestamped backup is
  always taken otherwise.

.PARAMETER WSLDistro
  Distro for -WithWSL. Defaults to Ubuntu.

.EXAMPLE
  .\install.ps1
.EXAMPLE
  .\install.ps1 -WithWSL
#>

[CmdletBinding()]
param(
  [switch] $WithWSL,
  [switch] $ConfigsOnly,
  [switch] $SkipWindowsTerminal,
  [string] $WSLDistro = 'Ubuntu'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RootDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $RootDir 'config'

# ---- Logging ---------------------------------------------------------------

function Write-Log  { param([string]$Message) Write-Host "`n[terminal-setup] $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host "`n[terminal-setup] WARN: $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "`n[terminal-setup] ERROR: $Message" -ForegroundColor Red }

function Test-Command {
  param([string]$Name)
  [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---- File placement --------------------------------------------------------

function Backup-Path {
  param([string]$Target)
  if (Test-Path -LiteralPath $Target) {
    $stamp  = Get-Date -Format 'yyyyMMddHHmmss'
    $backup = "$Target.bak.$stamp"
    Move-Item -LiteralPath $Target -Destination $backup -Force
    Write-Log "Backed up $Target -> $backup"
  }
}

# Symlink where possible so repo edits take effect immediately. Creating one
# without elevation needs Developer Mode enabled (Settings > System > For
# developers), so fall back to copying and say so - a copy means future `git
# pull`s here will NOT reach the live config until install.ps1 is re-run.
function New-ConfigLink {
  param(
    [Parameter(Mandatory)][string] $Source,
    [Parameter(Mandatory)][string] $Target
  )

  $existing = Get-Item -LiteralPath $Target -ErrorAction SilentlyContinue
  if ($existing -and $existing.LinkTarget -eq (Resolve-Path $Source).Path) {
    return
  }

  $parent = Split-Path -Parent $Target
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  Backup-Path $Target

  try {
    New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
    Write-Log "Linked $Target -> $Source"
  } catch {
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
    Write-Warn "Could not symlink $Target (needs Developer Mode or an elevated shell); copied instead. Repo changes will not reach this file until you re-run install.ps1."
  }
}

function Write-RenderedFile {
  param(
    [Parameter(Mandatory)][string] $Target,
    [Parameter(Mandatory)][string] $Content
  )
  $parent = Split-Path -Parent $Target
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  if ((Test-Path -LiteralPath $Target) -and
      ((Get-Content -LiteralPath $Target -Raw -ErrorAction SilentlyContinue) -eq $Content)) {
    return
  }
  Backup-Path $Target
  Set-Content -LiteralPath $Target -Value $Content -NoNewline -Encoding utf8
  Write-Log "Rendered $Target"
}

# ---- Packages --------------------------------------------------------------

# Each package is independent: a single winget failure warns rather than
# aborting the whole install.
function Install-WingetPackage {
  param(
    [Parameter(Mandatory)][string] $Id,
    [Parameter(Mandatory)][string] $Label,
    [string] $ProbeCommand
  )

  if ($ProbeCommand -and (Test-Command $ProbeCommand)) {
    Write-Log "$Label already installed"
    return
  }

  Write-Log "Installing $Label"
  try {
    winget install --id $Id --exact --silent `
      --accept-source-agreements --accept-package-agreements `
      --disable-interactivity | Out-Null
  } catch {
    Write-Warn "winget failed for $Label ($Id): $($_.Exception.Message)"
  }
}

function Install-BasePackages {
  if (-not (Test-Command 'winget')) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
  }

  Install-WingetPackage -Id 'Microsoft.PowerShell'        -Label 'PowerShell 7'      -ProbeCommand 'pwsh'
  Install-WingetPackage -Id 'Microsoft.WindowsTerminal'   -Label 'Windows Terminal'
  Install-WingetPackage -Id 'Git.Git'                     -Label 'Git'              -ProbeCommand 'git'
  Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh'     -Label 'Oh My Posh'       -ProbeCommand 'oh-my-posh'
  Install-WingetPackage -Id 'Neovim.Neovim'               -Label 'Neovim'           -ProbeCommand 'nvim'
  Install-WingetPackage -Id 'eza-community.eza'           -Label 'eza'              -ProbeCommand 'eza'
  Install-WingetPackage -Id 'junegunn.fzf'                -Label 'fzf'              -ProbeCommand 'fzf'
  Install-WingetPackage -Id 'BurntSushi.ripgrep.MSVC'     -Label 'ripgrep'          -ProbeCommand 'rg'
  Install-WingetPackage -Id 'sharkdp.fd'                  -Label 'fd'               -ProbeCommand 'fd'
  Install-WingetPackage -Id 'ajeetdsouza.zoxide'          -Label 'zoxide'           -ProbeCommand 'zoxide'
}

function Install-PowerShellModules {
  Write-Log 'Installing PowerShell modules (PSReadLine, PSFzf)'
  foreach ($module in @('PSReadLine', 'PSFzf')) {
    if (Get-Module -ListAvailable -Name $module) {
      Write-Log "$module already installed"
      continue
    }
    try {
      Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -AcceptLicense
    } catch {
      Write-Warn "Could not install $module : $($_.Exception.Message)"
    }
  }
}

# Installed per-user into %LOCALAPPDATA%\Microsoft\Windows\Fonts plus an HKCU
# registry entry, which needs no elevation. winget has no reliable 0xProto Nerd
# Font package, so this pulls the release zip directly.
function Install-NerdFont {
  $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
  if (Test-Path (Join-Path $fontDir '0xProtoNerdFontMono-Regular.ttf')) {
    Write-Log '0xProto Nerd Font already installed'
    return
  }

  Write-Log 'Installing 0xProto Nerd Font'
  $tmp = Join-Path $env:TEMP "0xProto-$(Get-Random)"
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  try {
    $zip = Join-Path $tmp '0xProto.zip'
    Invoke-WebRequest -UseBasicParsing `
      -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip' `
      -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    $regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

    foreach ($font in Get-ChildItem -Path $tmp -Filter '*.ttf' -Recurse) {
      $dest = Join-Path $fontDir $font.Name
      Copy-Item -LiteralPath $font.FullName -Destination $dest -Force
      Set-ItemProperty -Path $regKey `
        -Name "$($font.BaseName) (TrueType)" -Value $dest
    }
    Write-Log 'Font installed for the current user. Restart Windows Terminal to pick it up.'
  } catch {
    Write-Warn "Font install failed: $($_.Exception.Message). Install 0xProto Nerd Font by hand or glyphs in the prompt and tab bar will show as boxes."
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# ---- Configs ---------------------------------------------------------------

function Install-Configs {
  Write-Log 'Placing configs'

  # PowerShell 7 keeps its profile under Documents\PowerShell. CurrentUserAllHosts
  # (profile.ps1) rather than CurrentUserCurrentHost, so the profile also applies
  # when pwsh is hosted by VS Code or the ISE.
  $profileTarget = $PROFILE.CurrentUserAllHosts
  New-ConfigLink -Source (Join-Path $ConfigDir 'powershell\profile.ps1') -Target $profileTarget

  # Same theme file as Linux/macOS, at the same $HOME-relative path, so
  # profile.ps1 and .zshrc can both point at it unchanged.
  New-ConfigLink -Source (Join-Path $ConfigDir 'omp-config\myconfig.json') `
                 -Target (Join-Path $HOME 'omp-config\myconfig.json')

  # Neovim on Windows reads %LOCALAPPDATA%\nvim, not ~/.config/nvim.
  New-ConfigLink -Source (Join-Path $ConfigDir 'nvim') `
                 -Target (Join-Path $env:LOCALAPPDATA 'nvim')

  New-ConfigLink -Source (Join-Path $ConfigDir 'opencode\opencode.jsonc') `
                 -Target (Join-Path $HOME '.config\opencode\opencode.jsonc')

  # No ghostty or herdr config here: Ghostty has no Windows build, and herdr has
  # no native Windows build either. Both are configured on the WSL side by
  # install.sh when -WithWSL is used.
}

# ---- Windows Terminal ------------------------------------------------------

function Get-WindowsTerminalSettingsPath {
  $candidates = @(
    'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json',
    'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
  ) | ForEach-Object { Join-Path $env:LOCALAPPDATA $_ }

  foreach ($path in $candidates) {
    if (Test-Path -LiteralPath $path) { return $path }
  }
  return $null
}

# Strips whole-line // comments only. Windows Terminal ships its default
# settings.json with comment lines, which ConvertFrom-Json rejects. Anchoring to
# start-of-line matters: a naive strip would also cut the "//" inside
# "https://aka.ms/terminal-profiles-schema".
function Remove-JsonLineComments {
  param([Parameter(Mandatory)][string] $Text)
  ($Text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
}

# Drops the "//"-prefixed documentation keys from the fragment so they are not
# written into the user's settings.
function Remove-DocKeys {
  param($Object)
  if ($Object -is [System.Management.Automation.PSCustomObject]) {
    $clean = [ordered]@{}
    foreach ($prop in $Object.PSObject.Properties) {
      if ($prop.Name -like '//*') { continue }
      $clean[$prop.Name] = Remove-DocKeys $prop.Value
    }
    return [PSCustomObject]$clean
  }
  if ($Object -is [System.Object[]]) {
    return @($Object | ForEach-Object { Remove-DocKeys $_ })
  }
  return $Object
}

function Merge-WindowsTerminalSettings {
  $settingsPath = Get-WindowsTerminalSettingsPath
  if (-not $settingsPath) {
    Write-Warn 'Windows Terminal settings.json not found. Launch Windows Terminal once, then re-run install.ps1 to apply the colour scheme, font and keys.'
    return
  }

  $fragmentPath = Join-Path $ConfigDir 'windows-terminal\settings.fragment.json'
  $fragment = Remove-DocKeys (Get-Content -LiteralPath $fragmentPath -Raw | ConvertFrom-Json)

  try {
    $raw      = Get-Content -LiteralPath $settingsPath -Raw
    $settings = Remove-JsonLineComments $raw | ConvertFrom-Json
  } catch {
    Write-Warn "Could not parse $settingsPath : $($_.Exception.Message). Leaving it alone - apply config/windows-terminal/settings.fragment.json by hand."
    return
  }

  # Merging rewrites the file and drops any comments it contained, so keep a
  # copy of the original next to it.
  $stamp = Get-Date -Format 'yyyyMMddHHmmss'
  Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak.$stamp" -Force
  Write-Log "Backed up $settingsPath -> $settingsPath.bak.$stamp"

  # -- schemes: replace by name, else append
  $schemes = @()
  if ($settings.PSObject.Properties.Name -contains 'schemes' -and $settings.schemes) {
    $incoming = $fragment.schemes.name
    $schemes  = @($settings.schemes | Where-Object { $incoming -notcontains $_.name })
  }
  $settings | Add-Member -NotePropertyName 'schemes' `
    -NotePropertyValue @($schemes + $fragment.schemes) -Force

  # -- profiles.defaults: set key by key, leaving the user's other keys alone
  if (-not ($settings.PSObject.Properties.Name -contains 'profiles') -or -not $settings.profiles) {
    $settings | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([PSCustomObject]@{}) -Force
  }
  if (-not ($settings.profiles.PSObject.Properties.Name -contains 'defaults') -or -not $settings.profiles.defaults) {
    $settings.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([PSCustomObject]@{}) -Force
  }
  foreach ($prop in $fragment.profiles.defaults.PSObject.Properties) {
    $settings.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
  }

  # -- actions: drop any existing binding on a chord we define, then append ours
  $ourChords = @($fragment.actions | ForEach-Object { $_.keys })
  $actions   = @()
  if ($settings.PSObject.Properties.Name -contains 'actions' -and $settings.actions) {
    $actions = @($settings.actions | Where-Object {
      -not ($_.PSObject.Properties.Name -contains 'keys') -or $ourChords -notcontains $_.keys
    })
  }
  $settings | Add-Member -NotePropertyName 'actions' `
    -NotePropertyValue @($actions + $fragment.actions) -Force

  # Depth must be generous: WT settings nest several levels deep and the
  # default of 2 would silently truncate them into strings.
  $json = $settings | ConvertTo-Json -Depth 100

  # Serialise to a sibling temp file and move it into place, rather than
  # writing settings.json directly. If ConvertTo-Json or the write fails
  # halfway, the live file is untouched instead of left truncated. Also avoids
  # a sharing violation when something else holds a read handle on it.
  $tempOut = "$settingsPath.new"
  Set-Content -LiteralPath $tempOut -Value $json -Encoding utf8
  Move-Item -LiteralPath $tempOut -Destination $settingsPath -Force
  Write-Log "Merged colour scheme, font and keys into $settingsPath"
}

# ---- Neovim ----------------------------------------------------------------

function Initialize-NeovimPlugins {
  if (-not (Test-Command 'nvim')) {
    Write-Warn 'nvim not found; skipping LazyVim bootstrap'
    return
  }
  Write-Log 'Bootstrapping LazyVim plugins'
  try {
    nvim --headless '+Lazy! sync' +qa
  } catch {
    Write-Warn 'LazyVim sync failed; open nvim and run :Lazy sync'
  }
}

# ---- WSL -------------------------------------------------------------------

function Get-RepoOriginUrl {
  try {
    $url = git -C $RootDir remote get-url origin 2>$null
    if ($url) { return $url.Trim() }
  } catch { }
  return 'https://github.com/Manik0107/Terminal-setup.git'
}

function Install-WSLSetup {
  Write-Log "Setting up WSL ($WSLDistro) for full keybinding parity"

  if (-not (Test-Command 'wsl')) {
    Write-Warn 'wsl.exe not found. Enable WSL first: run "wsl --install" in an elevated prompt, reboot, then re-run install.ps1 -WithWSL.'
    return
  }

  $installed = @(wsl.exe --list --quiet 2>$null) -replace "`0", '' | Where-Object { $_ }
  if ($installed -notcontains $WSLDistro) {
    Write-Log "Installing WSL distro $WSLDistro (this needs an elevated shell and may require a reboot)"
    try {
      wsl.exe --install -d $WSLDistro --no-launch
    } catch {
      Write-Warn "Could not install $WSLDistro : $($_.Exception.Message). Install it manually, then re-run with -WithWSL."
      return
    }
    Write-Warn "$WSLDistro was just installed. Launch it once to create your user account, then re-run install.ps1 -WithWSL to finish the Linux side."
    return
  }

  # Clone fresh inside the distro rather than reusing this checkout: a repo on
  # /mnt/c is slow, and symlinks created from a DrvFs path do not behave as the
  # Linux installer expects.
  $originUrl = Get-RepoOriginUrl
  Write-Log "Running install.sh inside $WSLDistro"
  $script = @"
set -e
if [ -d "`$HOME/Terminal-setup/.git" ]; then
  git -C "`$HOME/Terminal-setup" pull --ff-only
else
  git clone $originUrl "`$HOME/Terminal-setup"
fi
bash "`$HOME/Terminal-setup/install.sh"
"@

  try {
    wsl.exe -d $WSLDistro -- bash -lc $script
  } catch {
    Write-Warn "The Linux installer failed inside $WSLDistro : $($_.Exception.Message). Open the distro and run ~/Terminal-setup/install.sh by hand to see the full output."
  }
}

# ---- Main ------------------------------------------------------------------

function Main {
  Write-Log "Platform: Windows / $env:PROCESSOR_ARCHITECTURE (PowerShell $($PSVersionTable.PSVersion))"

  if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warn 'Running under PowerShell 5.1. The profile targets PowerShell 7 - after this finishes, re-run it from pwsh so the profile lands in the right place.'
  }

  if (-not $ConfigsOnly) {
    Install-BasePackages
    Install-PowerShellModules
    Install-NerdFont
  } else {
    Write-Log '-ConfigsOnly: skipping package installs'
  }

  Install-Configs

  if ($SkipWindowsTerminal) {
    Write-Log '-SkipWindowsTerminal: leaving settings.json alone'
  } else {
    Merge-WindowsTerminalSettings
  }

  if (-not $ConfigsOnly) {
    Initialize-NeovimPlugins
  }

  if ($WithWSL) {
    Install-WSLSetup
  } else {
    Write-Log 'Native Windows setup done. herdr/tmux keybindings (prefix ctrl+a, prefix+|, prefix+h/j/k/l) need WSL - re-run with -WithWSL to get them.'
  }

  Write-Log 'Done. Restart Windows Terminal, then open a new pwsh tab.'
}

Main
