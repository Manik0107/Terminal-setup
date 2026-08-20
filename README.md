# Terminal-setup

One command per platform to rebuild the same terminal on Linux, macOS and
Windows: zsh/PowerShell, herdr + tmux, Neovim (LazyVim), Ghostty, Oh My Posh —
with the same keybindings, colours and prompt everywhere.

Full keybinding reference, including the places the platforms genuinely differ:
**[docs/KEYBINDINGS.md](docs/KEYBINDINGS.md)**.

## What's in the repo

```
Terminal-setup/
├── install.sh                  Linux + macOS installer (detects which)
├── install.ps1                 Windows installer (native, optional WSL)
├── README.md
├── docs/
│   └── KEYBINDINGS.md          every binding, per platform, plus known gaps
├── lib/                        sourced by install.sh, never run directly
│   ├── common.sh               OS/arch detection, symlink + render helpers
│   ├── pkg_linux.sh            apt packages, Neovim tarball, Ghostty PPA
│   └── pkg_macos.sh            Homebrew equivalents
└── config/                     the actual dotfiles
    ├── zsh/                    .zshrc, .zprofile, .zshrc.local.example
    ├── powershell/profile.ps1  the Windows counterpart to .zshrc
    ├── tmux/                   .tmux.conf, start-workspace.sh
    ├── herdr/config.toml.tmpl  template - zsh path substituted at install
    ├── ghostty/                config.shared + config.linux + config.macos
    ├── nvim/                   LazyVim config (init.lua, lua/, lazy-lock.json)
    ├── omp-config/             Oh My Posh theme, shared by all 3 platforms
    ├── opencode/               OpenCode CLI config
    └── windows-terminal/       settings fragment merged into settings.json
```

35 tracked files. Everything under `config/` is what actually lands on your
machine; everything outside it exists to put it there.

## Requirements

| | Linux | macOS | Windows |
|---|---|---|---|
| OS | Debian/Ubuntu (apt) | macOS 12+, Intel or Apple Silicon | Windows 10 2004+ / 11 |
| Needed up front | `git`, `curl`, `sudo` rights | `git`, admin for Homebrew | `git`, `winget` |
| Installed for you | — | Homebrew, if missing | — |
| Also needs | — | — | Developer Mode *(for symlinks)* |

Everything else is installed by the script. All three need network access —
packages, fonts and plugins are fetched at install time.

Not Debian-based? `install.sh` exits with a clear message rather than guessing
at your package manager. Use `--configs-only` to place the configs and install
the tools yourself.

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

## What the installer actually does

`install.sh`, in order. Every step is skipped if that component is deselected,
and short-circuits if the tool is already present.

1. **Detect** OS and architecture, flag WSL, then load `lib/pkg_linux.sh` (apt)
   or `lib/pkg_macos.sh` (Homebrew, installing Homebrew first if missing).
2. **`core`** — zsh, git, curl, wget, unzip, build tools, python3.
3. **`cli`** — ripgrep, fd, fzf, btop, eza.
4. **`font`** — 0xProto Nerd Font into `~/.local/share/fonts`, then `fc-cache`.
5. **`zsh`** — Oh My Zsh (with `KEEP_ZSHRC=yes`, so its installer cannot clobber
   the `.zshrc` about to be linked) + autosuggestions + syntax-highlighting;
   links `.zshrc` and `.zprofile`; sets zsh as your login shell via `chsh`
   *(may ask for your password)*.
6. **`prompt`** — Oh My Posh, links the shared theme.
7. **`herdr`** — resolves the right binary for your OS/arch from the GitHub
   releases API, generates `~/.config/herdr/config.toml` with your platform's
   zsh path baked in, installs zsh completions. **Non-fatal** — warns and
   continues if unavailable.
8. **`tmux`** — tmux, TPM, plugins; links `.tmux.conf` and
   `start-tmux-workspace`.
9. **`nvim`** — Neovim (latest tarball on Linux, brew on macOS), links
   `config/nvim`, runs a headless `Lazy! sync`.
10. **`ghostty`** — Ghostty, generates `~/.config/ghostty/config` from
    `config.shared` + your platform's file.
11. **`opencode`** — OpenCode CLI + its config.
12. **Verify** what it generated: `herdr config check`,
    `ghostty +validate-config`, and parsing `~/.tmux.conf` on a throwaway tmux
    server — so a broken config surfaces now, not at next login.

`install.ps1` follows the same shape: winget packages → PSReadLine/PSFzf → font
via `%LOCALAPPDATA%` + an HKCU registry entry *(no admin needed)* → PowerShell
profile and nvim to `%LOCALAPPDATA%\nvim` → merge into Windows Terminal
`settings.json` → then, with `-WithWSL`, install the distro and run `install.sh`
inside it.

Nothing is deleted at any point. Anything replaced is renamed to
`<path>.bak.YYYYMMDDHHMMSS` first.

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
  `-Skip terminal` to leave it untouched.

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

Three rules worth knowing:

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

## Updating

```bash
cd ~/Terminal-setup && git pull && bash install.sh
```

Symlinked configs (`.zshrc`, `.tmux.conf`, `nvim/`, …) pick up a `git pull`
immediately — no re-run needed. You only need to re-run `install.sh` to:

- regenerate the **Ghostty** and **herdr** configs, which are templates
- pick up new packages or components
- refresh the Windows side, where symlinks may have fallen back to copies

`--configs-only` is the fast path when you just want the config changes.

## Re-running and rollback

Both installers are **idempotent**: every install step short-circuits when the
tool is present, and re-running produces no new backups when nothing changed.

Anything replaced is moved to `<path>.bak.YYYYMMDDHHMMSS` first, so rollback is
one `mv`:

```bash
ls -d ~/.zshrc.bak.*                       # find the backup
mv ~/.zshrc.bak.20260820120000 ~/.zshrc    # put it back
```

## Uninstalling

There is no uninstall script — the installer only ever adds symlinks, generated
files and packages, so removing it is manual and predictable:

```bash
# 1. Drop the symlinks this repo owns (leaves your .bak.* files in place)
rm -f ~/.zshrc ~/.zprofile ~/.tmux.conf ~/.local/bin/start-tmux-workspace
rm -f ~/.config/nvim ~/omp-config/myconfig.json ~/.config/opencode/opencode.jsonc

# 2. Remove the two generated configs
rm -f ~/.config/ghostty/config ~/.config/herdr/config.toml

# 3. Restore whatever was there before, if you want it back
for f in ~/.zshrc ~/.tmux.conf; do ls -dt "$f".bak.* 2>/dev/null | head -1; done

# 4. Put your login shell back
chsh -s /bin/bash
```

Packages (zsh, tmux, Neovim, Ghostty, herdr, fonts) stay installed — remove them
with `apt`/`brew`/`winget` if you want them gone. On Windows, restore Windows
Terminal from `settings.json.bak.*` in the same directory.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Prompt and tab bar show boxes or `?` | The Nerd Font is not active. Set your terminal's font to **0xProto Nerd Font Mono**; on Windows, restart Windows Terminal after install. |
| `herdr: command not found` | The release asset could not be resolved. Install from [herdr.dev](https://herdr.dev), or use tmux — `AUTO_HERDR=0` in `~/.zshrc.local` gives a bare shell. |
| Prompt is plain, no colours | `oh-my-posh` is not on `PATH`. Check `~/.local/bin` is in `PATH` and `~/omp-config/myconfig.json` exists. |
| `ls` has no icons | `eza` was unavailable (older Debian/Ubuntu). Install it manually; the aliases activate on their own once it exists. |
| Colours look wrong inside tmux | Terminal is not advertising truecolor. Check `echo $TERM` — the config expects `xterm-ghostty` or a `*-256color`. |
| Windows: config edits do nothing | Symlinks fell back to copies. Enable Developer Mode, then re-run `install.ps1`. |
| Windows: Terminal settings unchanged | Launch Windows Terminal once so `settings.json` exists, then re-run. |
| Windows: profile not loading | You ran it under PowerShell 5.1. Re-run from `pwsh`; the profile targets PowerShell 7. |
| `chsh` refused the shell | On macOS, zsh must be listed in `/etc/shells` — the installer adds it, but needs your password. |
| Want to see what would change | `bash install.sh --configs-only` touches no packages, and every replacement is backed up. |

`install.sh` validates its own output at the end, so if `herdr config check` or
`ghostty +validate-config` reports a problem, that is the first thing to read.

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
