# Vim Keymap — VSCode / IntelliJ layer

**Last Updated:** 2026-08-31
**Verified against:** Vim 9.2.0926 (mise build, `+python3 +clipboard_provider +wayland +terminal`), kitty, tmux 3.4, WSL 2

Leader is `,`.

Configuration layout:

| File | Holds |
|------|-------|
| `.vimrc` | loader only |
| `.vim/config/00-xdg.vim` | XDG paths, undo/backup/swap/viminfo |
| `.vim/config/01-clipboard.vim` | clipboard provider (WSLg bridge) |
| `.vim/config/05-plugin-vars.vim` | plugin **variables** — must precede `plug#end()` |
| `.vim/config/10-plugins.vim` | `Plug` declarations + `packadd` |
| `.vim/config/20-options.vim` | every `set` |
| `.vim/config/25-autocmds.vim` | every autocommand |
| `.vim/config/30-keymap-core.vim` | Vim-native keys |
| `.vim/config/31-keymap-ide.vim` | **the table below** |
| `.vim/config/40-ui.vim` | colours |
| `.vim/after/plugin/*.vim` | per-plugin config, sourced after plugins load |

Machine-specific overrides: `.vim/config/90-local.vim` (gitignored, sourced last).

> **Adding plugin configuration?** A plugin *variable* goes in `05-plugin-vars.vim`;
> a *mapping* goes in `after/plugin/`. Most plugins read their variables once, as
> `plug#end()` loads them, so a variable set in `after/plugin/` is silently ignored and
> the plugin's own default mappings win. Guard `after/plugin/` files on a plugin's
> load marker (`g:loaded_foo`, or a command it defines) — **never** on
> `exists('*foo#bar')`, because an autoload function does not exist until its file is
> first sourced, which has usually not happened yet at that point.

---

## Terminal key encoding — read this first

A legacy terminal physically cannot encode `Ctrl+/`, `Alt+Enter`, or `Ctrl+Shift+<letter>`.
Vim's `'keyprotocol'` fixes this where the terminal cooperates:

- **kitty (native)** — works with no extra setup. `config/kitty/kitty.conf` sets
  `term xterm-kitty`, and Vim's default `'keyprotocol'` includes `kitty:kitty`.
- **kitty + tmux** — needs both halves: `extended-keys on` in `config/tmux/tmux.conf`
  (tmux speaks xterm's *modifyOtherKeys*, not kitty's protocol) and the
  `tmux*:mok2` entry that `31-keymap-ide.vim` appends to `'keyprotocol'`.
- **ssh / Windows Terminal / anything else** — the chord silently does nothing.
  **Every such binding has a `<leader>` fallback**, listed below.

The `Ctrl+Shift+*` forms are safe to define everywhere: Vim stores `<C-S-F>` as a
distinct key from `<C-F>`, so on a legacy terminal they never fire rather than
shadowing the plain `Ctrl` mapping.

---

## Navigation & search

| Action | Key | Fallback | Notes |
|---|---|---|---|
| Go to file | `Ctrl+P` / `Ctrl+Shift+N` | `<leader>p` | fzf, project-rooted |
| Find in path | `Ctrl+Shift+F` | `<leader>/` | ripgrep + preview |
| Recent files | `Ctrl+E` | `<leader>e` | |
| Open buffers | `Ctrl+Shift+E` | `<leader>b` | |
| Command palette | `Ctrl+Shift+P` | `<leader>:` | |
| Symbol in file | `Ctrl+Shift+O` | `<leader>o` | `:CocList outline` |
| Symbol in project | `Ctrl+Alt+Shift+N` | `<leader>O` | |
| Marks | — | `<leader>m` | |
| Registers | — | `<leader>"` | |
| Find in file | `Ctrl+F` | `/` | takes `Ctrl+F` from page-forward; use `PageDown` |
| Find next / prev | `F3` / `Shift+F3` | `n` / `N` | |
| Go to line | `Ctrl+G` | `:` | |
| Back / forward | `Ctrl+Alt+Q` / `Ctrl+Alt+W` | `Ctrl+O` / `Ctrl+I` | also `Ctrl+Alt+Left/Right` |
| Last edit location | `Ctrl+Shift+Backspace` | `g;` | walks the changelist |
| Jump to char | `<leader><leader>w` | — | easymotion (AceJump) |

## Code intelligence — coc.nvim

| Action | Key | Fallback |
|---|---|---|
| **Quick fix / intention** | **`Alt+Enter`** | `<leader>a` |
| Go to declaration | `F12` | `gd` |
| Go to type / implementation | — | `gy` / `gi` |
| Find usages | `Shift+F12` | `gr` |
| Rename | `F2` | `<leader>rn` |
| Format document | `Ctrl+Alt+L` | `<leader>F` |
| Organize imports | `Ctrl+Alt+O` | `<leader>oi` |
| Next / prev problem | `F8` / `Shift+F8` | `]e` / `[e` |
| Quick fix current line | — | `<leader>qf` |
| Hover documentation | `K` | — |
| Expand / shrink selection | `Alt+Shift+Right/Left` | — |
| Trigger completion | `Ctrl+Space` | — |
| Accept completion | `Tab` | — |
| Snippet jump fwd / back | `Ctrl+J` / `Ctrl+K` | — |

## Editing

| Action | Key | Fallback |
|---|---|---|
| Comment line | `Ctrl+/` | `gcc` |
| Comment selection | `Ctrl+/` (visual) | `gc` |
| Duplicate line / selection | `Ctrl+D` | — |
| Delete line | `Ctrl+Y` | — |
| Move line / block | `Alt+Shift+Up/Down`, `Ctrl+Shift+Up/Down` | — |
| Move block horizontally | `Alt+Shift+Left/Right` (visual) | — |
| Select all | `Ctrl+A` | — |
| Save | `Ctrl+S` | — |
| Undo / redo | `Ctrl+Z` / `Ctrl+Shift+Z` | `u` / `Ctrl+R` |
| Undo tree | `F5` | — |
| Replace in file | `Ctrl+Shift+H` | `<leader>h` |
| Append semicolon | `Ctrl+Shift+L` / `Ctrl+Enter` | — |
| Multi-cursor: next occurrence | `Ctrl+N` | — |
| Multi-cursor: all occurrences | `Ctrl+Shift+L` (normal) | — |
| Multi-cursor: add above/below | `Ctrl+Alt+Up/Down` | — |
| Toggle value (`true`↔`false`) | `-` / `_` | — |
| Increment / decrement | `g Ctrl+A` / `g Ctrl+X` | — |
| Align | `ga` + char | — |
| Strip trailing whitespace | — | `<leader>$` |
| Word yank | — | `<leader>y` |
| Spell check toggle | `F7` | — |

## Workbench

| Action | Key | Fallback |
|---|---|---|
| Toggle file explorer | `Ctrl+B` | — |
| Close buffer | `Ctrl+W` | — |
| Toggle terminal | ``Ctrl+` `` | — |
| Next / prev buffer | `Ctrl+PageDown` / `Ctrl+PageUp` | `Alt+PageDown` / `Alt+PageUp` |
| Window commands | `<leader>w` + `hjkl/s/v/o/=` | — |
| Resize windows | `<leader>r` then `hjkl` | — |
| Split horizontal / vertical | `<leader>-` / `<leader>\|` | — |
| Navigate splits & tmux panes | `Ctrl+H/J/K/L`, `Alt+arrows` | — |
| New buffer | `<leader>T` | — |
| Close all buffers | `<leader>ba` | — |
| List buffers | `<leader>bl` | — |
| Tabs | `<leader>tn` `to` `tc` `tm` `te` | — |
| Clear search highlight | `<leader><CR>` | — |

---

## IntelliJ spellings

Taken from the keymap the VSCode side actually runs — `k--kato.intellij-idea-keybindings`
plus the personal overrides in `%APPDATA%\Code\User\keybindings.json`. Where a VSCode-style
key for the same action already existed, **both** are bound.

| Action | IntelliJ key | Also bound as |
|---|---|---|
| Navigate back / forward | `Ctrl+Alt+Q` / `Ctrl+Alt+W` | `Ctrl+Alt+Left/Right` |
| Last edit location | `Ctrl+Shift+Backspace` | — |
| Find usages | `Alt+F7` | `Shift+F12`, `gr` |
| Rename | `Shift+F6` | `F2`, `<leader>rn` |
| Go to type declaration | `Ctrl+Shift+B` | `gy` |
| File structure | `Ctrl+F12` | `Ctrl+Shift+O`, `<leader>o` |
| Quick documentation | `Ctrl+Q` | `K` |
| Error description | `Ctrl+F1` | — |
| Refactor this | `Ctrl+Alt+Shift+T` | `Alt+Enter`, `<leader>a` |
| ESLint autofix | `Ctrl+Shift+S` | — (their own override) |
| Previous / next change | `Ctrl+Alt+Shift+Up/Down` | `[g` / `]g` |
| Rollback hunk | `Ctrl+Alt+Z` | `<leader>gu` |
| Project tool window | `Alt+1` | `Ctrl+B` |
| Structure / Problems | `Alt+7` / `Alt+0` | — |
| Join lines | `Ctrl+Shift+J` | `J` |
| Jump to bracket | `Ctrl+Shift+M` | `%` |
| New line below / above | `Shift+Enter` / `Ctrl+Alt+Enter` | `o` / `O` |
| Block comment | `Ctrl+Shift+/` | `gc` |
| Fold / unfold / toggle | `Ctrl+-` / `Ctrl+=` / `Ctrl+.` | `zc` / `zo` / `za` |
| Fold all / unfold all | `Ctrl+Shift+-` / `Ctrl+Shift+=` | `zM` / `zR` |
| Copy file path | `Ctrl+Shift+C` | — |
| Terminal | `Alt+F12` | ``Ctrl+` `` |
| Multi-cursor: next / all | `Alt+J` / `Ctrl+Alt+Shift+J` | `Ctrl+N` / `Ctrl+Shift+L` |
| Delete word forward | `Ctrl+Delete` (insert) | `Ctrl+W` deletes back |

### Known divergences from the VSCode side

- **`Ctrl+B`** is the file explorer here (VSCode convention). In the IntelliJ keymap it is
  *go to declaration*, and the explorer is `Alt+1` — which is now also bound. If you want
  full IntelliJ fidelity, `Ctrl+B` should become `<Plug>(coc-definition)`.
- **`Ctrl+R`** is IntelliJ's replace-in-file. Not bound, because `Ctrl+R` is Vim's redo.
  Replace is on `Ctrl+Shift+H` / `<leader>h`.
- **Alt+Shift+arrows** and **Ctrl+Shift+W** are claimed by VSCode's *integrated terminal*
  (`resizePane`, `terminal.kill`), so inside that terminal they never reach Vim. They work
  normally in kitty.
- **`Ctrl+Alt+I`** opens Copilot Chat in VSCode. Still unbound in the **Vim** config
  (`copilot.vim` is completion-only), but the Neovim config now binds it to CodeCompanion's
  chat — see `config/nvim/lua/plugins/ai.lua`. This is the one capability the Neovim
  migration was actually for.

## `<leader>` + capital pickers

The pre-rewrite bindings were the bare capitals `F H B S T M R`. Those are back to being Vim
motions; the pickers keep the same letters behind `<leader>`, so the association survives
without costing a motion.

| Key | Opens |
|---|---|
| `<leader>F` | files |
| `<leader>H` | recent files |
| `<leader>B` | buffers |
| `<leader>S` | grep in project |
| `<leader>T` | symbols in file |
| `<leader>M` | marks |
| `<leader>R` | registers |

Additional to the chords — `Ctrl+P`, `Ctrl+E`, `Ctrl+Shift+F` and the lowercase fallbacks all
still work.

Three keys moved to make room, and two long-standing ambiguities went with them:

| Was | Now | Why |
|---|---|---|
| `<leader>F` format | `<leader>f`, `Ctrl+Alt+L` | `<leader>f` already formatted |
| `<leader>T` new buffer | `<leader>N` | |
| `<leader>b` buffers | `<leader>B` | `<leader>b` shadowed `<leader>ba`/`bl`/`bu`, so each waited out `timeoutlen` |

## Reclaimed Vim defaults

These were previously mapped and broke core Vim behaviour. They are now **unmapped**;
the functionality they carried moved to the keys shown.

| Key | Was | Why it was a bug | Now |
|---|---|---|---|
| `y` | `viwy<Esc>` | `y` stopped being an operator — `yy`, `y$`, `yap`, `yi(` all dead | word-yank on `<leader>y` |
| `x` | `viwc` | no delete-character | — |
| `s` | `:%s///g` | no substitute-char | `Ctrl+Shift+H` / `<leader>h` |
| `1` `2` | `^` `$` | **every count starting with 1 or 2** (`2dd`, `12j`, `10gg`) was swallowed | — |
| `p` `P` | reindent-paste, inverted | pasted in the wrong direction, corrupted linewise paste | `]p` / `]P` reindent natively |
| `Tab` | `%` | `Tab` is `Ctrl+I`, so jumplist-forward was dead | vim-matchup owns `%` |
| `Esc` | `Ctrl+Alt+L` | **reindented the whole file**, and made `Esc` an ambiguous prefix that hung under `notimeout` | `Ctrl+Alt+L` formats |
| `F` `H` `B` `T` `M` `S` `R` | fzf pickers | lost back-find, WORD-back, screen-top/middle, till-back, substitute-line | motions kept; the pickers are `<leader>`+capital |
| `w'` `w"` `w;` `w.` | change-until | made the plain `w` motion wait on a timeout | native `ct'` `ct"` `ct;` `ct.` |
| `ww` | `viw` | shadowed `w` | — |
| `Ctrl+Space` (insert) | `Esc` | killed coc's trigger-completion | triggers completion |
| `Ctrl+X` (insert) | word-change | killed all of `ins-completion` (`Ctrl+X Ctrl+O`, …) | Vim default |
| `Ctrl+A` | switch.vim increment | — | Select All; increment on `g Ctrl+A` |

## Keys deliberately given up

| Key | Given to | Recover the original with |
|---|---|---|
| `Ctrl+W` | close buffer | `<leader>w` (window prefix) |
| `Ctrl+F` | find in file | `PageDown` |
| `Ctrl+D` | duplicate line | `PageDown` (half-page scroll) |
| `Ctrl+Y` | delete line | `Ctrl+E`-style scroll unavailable |
| `Ctrl+B` | file explorer | `PageUp` |
| `Ctrl+E` | recent files | — |
| `Ctrl+A` | select all | `g Ctrl+A` |
| `Ctrl+X` | multi-cursor skip | `g Ctrl+X` |
| `Ctrl+H` | **not taken** — kept for tmux/kitty pane navigation | — |

`Ctrl+H` is the one IDE key deliberately *not* claimed: it is the pane-navigation key
wired through `config/kitty/linux.conf` (`pass_keys.py`), `config/tmux/tmux.conf`, and
`vim-tmux-navigator`. Replace lives on `Ctrl+Shift+H` instead.
