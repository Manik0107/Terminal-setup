# Keybindings

The reference for what is bound where, and where the three platforms genuinely
differ. Prefix is **`ctrl+a`** everywhere it exists.

Where a cell says **—**, that action has no binding on that platform. Native
Windows has no multiplexer at all, because neither herdr nor tmux has a Windows
build — run `install.ps1 -WithWSL` and work inside WSL for full parity.

## Multiplexer

`herdr` is the default (auto-started by `.zshrc`); tmux stays installed and is
configured identically, so `tmux new` behaves the same. The Windows Terminal
column is the native-Windows approximation, not a multiplexer.

| Action | tmux | herdr | Windows Terminal |
|---|---|---|---|
| Prefix | `ctrl+a` | `ctrl+a` | — *(left unbound on purpose)* |
| New tab / window | `prefix c` | `prefix c` | `ctrl+shift+t` |
| Next / previous tab | `prefix n` / `prefix p` | `prefix n` / `prefix p` | `ctrl+tab` / `ctrl+shift+tab` |
| Jump to tab 1–9 | `prefix 1`–`9` | `prefix 1`–`9` | `ctrl+alt+1`–`9` |
| Split side-by-side | <code>prefix &#124;</code> | <code>prefix &#124;</code> | <code>alt+shift+&#124;</code> |
| Split stacked | `prefix -` | `prefix -` | `alt+shift+-` |
| Pane focus | `ctrl+h/j/k/l` | `ctrl+h/j/k/l` | `alt+←↓↑→` |
| Pane resize | `prefix h/j/k/l` | `prefix h/j/k/l` | `alt+shift+←↓↑→` |
| Sustained resize mode | — | `prefix r`, then `h/j/k/l`, `esc` to exit | — |
| Zoom / maximise pane | `prefix m` | `prefix m` | `ctrl+shift+m` |
| Detach | `prefix d` | `prefix d` | — |
| Reload config | `prefix r` | `prefix shift+R` | — |
| Scrollback / copy mode | `prefix [`, then `v` select, `y` yank, `r` rectangle | `prefix e` — opens the buffer in `$EDITOR` (nvim) | `ctrl+shift+f` to find |
| Previous / next agent | — | `prefix [` / `prefix ]` | — |
| Jump to agent 1–9 | — | `prefix alt+1`–`9` | — |
| Go-to palette | — | `prefix g` | — |

**`prefix r` means two different things.** tmux reloads its config; herdr enters
resize mode and puts reload on `prefix shift+R`. This is the one binding that
does not carry over, and it is a herdr naming decision, not a choice made here.

## Terminal emulator

Ghostty on Linux and macOS; Windows Terminal on native Windows.

| Action | Ghostty | Windows Terminal |
|---|---|---|
| Paste | `ctrl+v` *(and `ctrl+shift+v`)* | `ctrl+v` |
| Copy | `ctrl+shift+c` *(plus copy-on-select)* | `ctrl+shift+c` *(plus copy-on-select)* |
| Toggle maximise | `ctrl+shift+m` | `ctrl+shift+m` |
| Reload config | `ctrl+shift+,` | — *(restart the app)* |
| Open config | `ctrl+,` | `ctrl+,` |
| True fullscreen | `ctrl+enter` | `F11` |
| Font size | `ctrl+=` / `ctrl+-` / `ctrl+0` | `ctrl+=` / `ctrl+-` / `ctrl+0` |

`ctrl+v` is bound to paste deliberately, on both. The cost is that TUIs never
see `ctrl+v` — nvim visual-block mode and readline's quoted-insert are
unreachable while inside the terminal. Use `ctrl+q` for visual-block in nvim.

Windows Terminal deliberately leaves **`ctrl+a` and `ctrl+h/j/k/l` unbound**.
WSL runs inside it, and WT consumes a chord before the shell ever sees it, so
binding either would mean herdr never receives its prefix or its pane-focus
keys. That is why WT's own pane keys sit on alt+arrows instead.

## Shell line editing

zsh runs emacs bindings (oh-my-zsh default); PSReadLine is explicitly set to
`EditMode Emacs` to match, rather than its default Windows mode.

| Action | zsh | PowerShell |
|---|---|---|
| Start / end of line | `ctrl+a` / `ctrl+e` | `ctrl+a` / `ctrl+e` |
| Kill word back / line | `ctrl+w` / `ctrl+u` | `ctrl+w` / `ctrl+u` |
| Clear screen | `ctrl+l` | `ctrl+l` |
| History search (fzf) | `ctrl+r` | `ctrl+r` *(PSFzf)* |
| File search (fzf) | `ctrl+t` | `ctrl+t` *(PSFzf)* |
| Accept suggestion | `→` / `End` | `→` / `End` |
| Prefix history search | `↑` / `↓` | `↑` / `↓` |

## Neovim

Config is byte-identical on all three platforms — the same `config/nvim` is
linked to `~/.config/nvim` (Linux/macOS) or `%LOCALAPPDATA%\nvim` (Windows).

| Action | Binding |
|---|---|
| Move between splits | `ctrl+h/j/k/l` *(via vim-tmux-navigator)* |
| Leader | `space` *(LazyVim default)* |
| File explorer | `<leader>e` |
| Visual block | `ctrl+q` — `ctrl+v` is taken by the terminal's paste binding |

`<leader>e` opens at the **repo root**, not the LSP root: `vim.g.root_spec` in
`config/nvim/lua/config/options.lua` puts `.git` ahead of `lsp`, so a
subdirectory with its own `pyproject.toml` does not become the root.

## Known gaps

Real conflicts, written down rather than papered over.

1. **`ctrl+a` cannot reach the shell inside herdr.** tmux has
   `bind C-a send-prefix`, so pressing `ctrl+a ctrl+a` sends a literal `ctrl+a`
   and start-of-line still works. herdr has no send-prefix action in v0.8.2, so
   while inside herdr, `ctrl+a` is always the prefix and start-of-line is
   unreachable. Workaround: `home`, or `ctrl+x ctrl+a`… is not bound either —
   in practice use `home`.

2. **`ctrl+l` does not clear the screen inside herdr.** It is pane-focus-right.
   tmux keeps an escape hatch (`bind C-l send-keys "C-l"`, i.e. `prefix ctrl+l`);
   herdr has no conditional or send-key binding, so use `clear` instead.

3. **nvim's own `ctrl+h/j/k/l` are shadowed inside herdr.** tmux guards these
   with `if-shell "$is_vim"` and forwards the key to nvim when the pane is
   running vim/nvim/fzf. herdr has no `if-shell`, so it consumes them globally
   and nvim never sees them. Inside tmux this works correctly. The fix, if it
   starts to bite, belongs on the nvim side: a keymap that moves within nvim
   when a split exists in that direction and otherwise shells out to
   `herdr pane focus <dir>` — the vim-tmux-navigator pattern, inverted.

4. **No multiplexer on native Windows.** Points 1–3 do not apply there, but
   neither do any of the prefix bindings. `install.ps1 -WithWSL` is the answer.
