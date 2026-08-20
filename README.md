# Terminal-setup

One command per platform to rebuild the same terminal on Linux, macOS and
Windows: zsh/PowerShell, herdr + tmux, Neovim (LazyVim), Ghostty, Oh My Posh —
with the same keybindings, colours and prompt everywhere.

Full keybinding reference, including the places the platforms genuinely differ:
**[docs/KEYBINDINGS.md](docs/KEYBINDINGS.md)**.

## Quick setup

### Linux (Debian / Ubuntu, including WSL2)

```bash
git clone https://github.com/Manik0107/Terminal-setup.git ~/Terminal-setup && bash ~/Terminal-setup/install.sh
```

### macOS (Apple Silicon or Intel)

```bash
git clone https://github.com/Manik0107/Terminal-setup.git ~/Terminal-setup && bash ~/Terminal-setup/install.sh
```

Same command: `install.sh` detects the OS and switches between `lib/pkg_linux.sh`
(apt) and `lib/pkg_macos.sh` (Homebrew), installing Homebrew first if missing.

### Windows 10 / 11

```powershell
git clone https://github.com/Manik0107/Terminal-setup.git "$HOME\Terminal-setup"; powershell -ExecutionPolicy Bypass -File "$HOME\Terminal-setup\install.ps1" -WithWSL
```

`-WithWSL` is what buys keybinding parity — see [Windows](#windows) below. Drop
it for native Windows only. If `git` is missing, run `winget install Git.Git`
first.

Then restart your terminal, or `exec zsh` / open a new tab.

## Windows

Neither herdr nor tmux has a native Windows build, so the multiplexer
keybindings (prefix `ctrl+a`, splits, pane focus and resize) cannot exist
natively. `install.ps1` therefore does two things:

| | Native Windows | With `-WithWSL` |
|---|---|---|
| Shell | PowerShell 7 + profile | zsh + Oh My Zsh |
| Prompt | Oh My Posh, same theme file | Oh My Posh, same theme file |
| Terminal | Windows Terminal, matching scheme + font | Windows Terminal hosting WSL |
| Editor | Neovim, same LazyVim config | Neovim, same LazyVim config |
| Line editing | PSReadLine in Emacs mode — `ctrl+a/e/w/u/r` match zsh | zsh emacs bindings |
| Multiplexer | none | **herdr + tmux, identical bindings** |

Run it with `-WithWSL` if this machine should match your Linux and mac boxes.

Two Windows notes:

- **Enable Developer Mode** (*Settings → System → For developers*) before
  running, or run from an elevated shell. Without it, Windows refuses to create
  symlinks and the installer falls back to copying — which works, but later
  `git pull`s in this repo will not reach your live config until you re-run
  `install.ps1`.
- The installer **merges** into Windows Terminal's `settings.json` rather than
  replacing it: your profiles, `defaultProfile` and other keys are preserved,
  and only the colour scheme, font and the chords listed in
  `config/windows-terminal/settings.fragment.json` are applied. A timestamped
  backup is taken first. Merging does drop any `//` comments the file had — use
  `-SkipWindowsTerminal` to leave it untouched.

## What gets installed

| | Linux | macOS | Windows |
|---|---|---|---|
| Package source | apt | Homebrew | winget |
| Shell | zsh + Oh My Zsh | zsh *(system)* + Oh My Zsh | PowerShell 7 |
| zsh plugins | autosuggestions, syntax-highlighting, z, colored-man-pages | same | PSReadLine prediction, PSFzf, zoxide |
| Prompt | Oh My Posh | Oh My Posh | Oh My Posh |
| Multiplexer | herdr + tmux (TPM) | herdr + tmux (TPM) | — *(WSL only)* |
| Terminal | Ghostty | Ghostty | Windows Terminal |
| Editor | Neovim *(latest tarball)* | Neovim *(brew)* | Neovim *(winget)* |
| CLI tools | eza, fzf, ripgrep, fd, btop | same | eza, fzf, ripgrep, fd |
| Font | 0xProto Nerd Font | 0xProto Nerd Font | 0xProto Nerd Font |
| Agent CLI | OpenCode | OpenCode | — |

macOS deliberately does **not** install Homebrew's zsh — macOS already ships zsh
as the default login shell, and installing brew's would mean editing
`/etc/shells` before `chsh` accepts it. If you install it later, `.tmux.conf`
picks it up automatically.

## Where things land

Most configs are **symlinked**, so editing this repo takes effect immediately.

| Repo path | Linux / macOS | Windows |
|---|---|---|
| `config/zsh/.zshrc` | `~/.zshrc` | — |
| `config/zsh/.zprofile` | `~/.zprofile` | — |
| `config/powershell/profile.ps1` | — | `$PROFILE.CurrentUserAllHosts` |
| `config/tmux/.tmux.conf` | `~/.tmux.conf` | — |
| `config/tmux/start-workspace.sh` | `~/.local/bin/start-tmux-workspace` | — |
| `config/nvim/` | `~/.config/nvim` | `%LOCALAPPDATA%\nvim` |
| `config/omp-config/myconfig.json` | `~/omp-config/myconfig.json` | `~\omp-config\myconfig.json` |
| `config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `~\.config\opencode\opencode.jsonc` |
| `config/ghostty/config.shared` + `.linux`/`.macos` | `~/.config/ghostty/config` *(generated)* | — |
| `config/herdr/config.toml.tmpl` | `~/.config/herdr/config.toml` *(generated)* | — |
| `config/windows-terminal/settings.fragment.json` | — | merged into WT `settings.json` |

**Ghostty and herdr are generated, not symlinked.** Both need zsh's absolute
path as a literal (`/usr/bin/zsh` on Debian, `/bin/zsh` on macOS,
`$(brew --prefix)/bin/zsh` with Homebrew's) and neither supports an include
directive that would let a shared file stay portable. Edit the repo templates,
then re-run `install.sh` — editing the generated file directly means losing it
on the next run.

## Installing only what you want

Nothing is all-or-nothing. Components are named, and you pick them with
`--only` (exactly these) or `--skip` (everything but these). `--list` prints
them.

```bash
bash install.sh --skip tmux                 # on herdr, tmux is redundant
bash install.sh --skip nvim,opencode        # keep your own editor setup
bash install.sh --only zsh,prompt,herdr     # minimal shell + multiplexer
bash install.sh --only nvim                 # just the editor and its config
bash install.sh --list
```

| Component | Installs | Places |
|---|---|---|
| `core` | zsh, git, curl, wget, unzip, build tools, python3 | — |
| `cli` | ripgrep, fd, fzf, btop, eza | — |
| `font` | 0xProto Nerd Font | — |
| `zsh` | Oh My Zsh + 2 plugins, sets login shell | `.zshrc`, `.zprofile` |
| `prompt` | Oh My Posh | `omp-config/myconfig.json` |
| `herdr` | herdr binary + zsh completions | `~/.config/herdr/config.toml` |
| `tmux` | tmux, TPM + plugins | `.tmux.conf`, `start-tmux-workspace` |
| `nvim` | Neovim + headless plugin sync | `~/.config/nvim` |
| `ghostty` | Ghostty | `~/.config/ghostty/config` |
| `opencode` | OpenCode CLI | `~/.config/opencode/opencode.jsonc` |

Aliases are accepted for near-misses: `neovim`/`vim`, `omp`/`oh-my-posh`,
`omz`/`shell`, `fonts`, `tools`.

Windows uses the same model with eight components — `core`, `cli`, `font`,
`pwsh`, `prompt`, `nvim`, `terminal`, `wsl`:

```powershell
.\install.ps1 -Skip nvim,terminal
.\install.ps1 -Only pwsh,prompt,font
.\install.ps1 -List
.\install.ps1 -WithWSL -WSLArgs '--skip tmux,nvim'   # scope both sides
```

Two rules worth knowing:

- **`--only` means only.** It will not quietly pull in `core` to satisfy a
  dependency. If `git` or `curl` is missing you get a warning naming it, not a
  surprise `apt`/`brew` run.
- **A typo is fatal.** `--only nvimm` exits 1 and prints the component list,
  rather than silently installing nothing.
- **`wsl` is opt-in.** It is excluded from a default Windows run, and `-Skip`
  subtracts from that default — so `-Skip nvim` will never start installing a
  distro behind your back. Use `-WithWSL` or `-Only wsl`.

## Other options

```bash
bash install.sh --configs-only         # link/render configs, install nothing
bash install.sh --skip-nvim-bootstrap  # skip the headless LazyVim sync
bash install.sh --help
```

```powershell
.\install.ps1 -ConfigsOnly             # place configs, install nothing
.\install.ps1 -WSLDistro Debian        # non-default distro
Get-Help .\install.ps1 -Detailed
```

## Secrets and machine-specific values

Never commit these; both paths are gitignored.

| Platform | File | Loaded by |
|---|---|---|
| Linux / macOS | `~/.zshrc.local` | end of `.zshrc` |
| Windows | `profile.local.ps1`, beside the PowerShell profile | end of `profile.ps1` |

Start from `config/zsh/.zshrc.local.example`.

## Re-running and rollback

Both installers are **idempotent**: every install step short-circuits when the
tool is present, and re-running produces no new backups when nothing changed.

Anything replaced is moved to `<path>.bak.YYYYMMDDHHMMSS` first, so rollback is
`mv ~/.zshrc.bak.20260820120000 ~/.zshrc`.

`install.sh` finishes by validating what it generated — `herdr config check`,
`ghostty +validate-config`, and parsing `~/.tmux.conf` on a throwaway tmux
server — so a broken config surfaces during install rather than at next login.

## Behaviour worth knowing

- **herdr auto-starts** on interactive local shells. Escape hatches:
  `AUTO_HERDR=0` in `~/.zshrc.local` for a bare shell; it also skips itself over
  SSH and inside an existing tmux session.
- **tmux is installed but not auto-started.** Run `tmux new` by hand;
  `start-tmux-workspace` opens the 5-window layout (code, codex, terminal,
  monitoring, misc).
- Under WSL there is no `wl-copy`, `xclip` or `win32yank`, so yanks reach the
  Windows clipboard purely over **OSC 52** — `set -g set-clipboard on` in tmux
  plus `clipboard-read`/`clipboard-write = allow` in Ghostty. Removing either
  breaks copy out of a pane.
