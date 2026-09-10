# Neovim Keymap

**Last Updated:** 2026-09-02
**Verified against:** Neovim 0.12.5 (mise), `config/nvim/`, WSL 2 + kitty + tmux 3.4
**Generated from live bindings**, not from memory — every key below was dumped from a running
instance with `vim.fn.maplist()` and its source file.

Leader is `,`.

> **This is the Neovim keymap.** [`VIM_KEYMAP.md`](VIM_KEYMAP.md) documents the Vim config in
> `.vim/`, which is still the default daily driver. The two share most keys but **not all** —
> the divergences are listed first, because those are what will surprise you after `usenvim`.

Switch between them with `usenvim` / `usevim`; `whichvim` says which is active.

---

## Differs from the Vim keymap

Everything else in this document matches `VIM_KEYMAP.md`. These do not:

| Key | Neovim | Vim |
|---|---|---|
| `<leader><leader>` | flash jump (labels appear as you type) | easymotion `<leader><leader>w` |
| `<leader>v` | flash treesitter select | — |
| `f` `F` `t` `T` | flash char mode — press again to advance | clever-f |
| `<leader>u` | undo tree | — (Vim has it on `F5`) |
| `F5` | **start/continue debugging** | undo tree |
| `F9` `F10` `F11` `Shift+F11` | breakpoint / step over / into / out | — |
| `Ctrl+Alt+I` | AI chat (CodeCompanion) | — (no Vim equivalent) |
| `af` `if` `ac` `ic` `aa` `ia` | treesitter text objects | targets.vim / indent-object |
| `]f` `[f` | jump between functions | — |
| `grn` `gra` `grr` `gri` | Neovim 0.11 default LSP maps | — |
| `<leader>ih` | toggle inlay hints | — |
| `Alt+E` | wrap next word in the pair just typed | — |
| `:Root` / `:Rcd` | print / cd to project root | vim-rooter did this implicitly |

**flash deliberately does not use its own defaults.** It wants `s` and `S`; both must stay
unmapped here (see *Reclaimed defaults* in `VIM_KEYMAP.md`), so jump is on `<leader><leader>`.

---

## Navigation & search

| Action | Key | Fallback |
|---|---|---|
| Go to file | `Ctrl+P` / `Ctrl+Shift+N` | `<leader>p` |
| Find in path | `Ctrl+Shift+F` | `<leader>/` |
| Recent files | `Ctrl+E` | `<leader>e` |
| Open buffers | `Ctrl+Shift+E` | `<leader>b` |
| Command palette | `Ctrl+Shift+P` | `<leader>:` |
| Marks / registers | — | `<leader>m` / `<leader>"` |
| Find in file | `Ctrl+F` | `/` |
| Find next / prev | `F3` / `Shift+F3` | `n` / `N` |
| Go to line | `Ctrl+G` | `:` |
| Back / forward | `Ctrl+Alt+Q` / `Ctrl+Alt+W` | `Ctrl+O` / `Ctrl+I`, also `Ctrl+Alt+Left/Right` |
| Last edit location | `Ctrl+Shift+Backspace` | `g;` |
| Jump to label | `<leader><leader>` | `<leader>s` |

**The file-shaped pickers are fzf.vim** — files, recent, buffers, grep, marks, registers. It
uses the fzf binary zinit already installs for the shell's `fzf-tab`, so the picker looks and
behaves like the one in your terminal, and matches the Vim config key for key.

**snacks.picker keeps what it is better at**: anything LSP-aware — `<leader>T` symbols,
`Alt+0` diagnostics — plus the dashboard and the explorer. `Ctrl+T` / `Ctrl+X` / `Ctrl+R` open
in a tab / split / vsplit in both.

fzf finds its binary on `$PATH`, which is the normal case from a shell. Launched without that
PATH, `after/plugin/fzf.vim` prepends zinit's bin directory rather than letting fzf prompt
"Download binary? (y/n)" — there is no `g:fzf_bin`; `fzf#exec()` checks only `$PATH` and the
plugin's own `bin/`.

## Code intelligence — native LSP

| Action | Key | Fallback |
|---|---|---|
| **Quick fix / intention** | **`Alt+Enter`** | `<leader>a`, `gra` |
| Go to declaration | `F12` | `gd` |
| Go to type / implementation | `Ctrl+Shift+B` | `gy` / `gi`, `gri` |
| Find usages | `Shift+F12` / `Alt+F7` | `gr`, `grr` |
| Rename | `F2` / `Shift+F6` | `<leader>rn`, `grn` |
| Format | `Ctrl+Alt+L` | `<leader>F`, `<leader>f` |
| Organize imports | `Ctrl+Alt+O` | `<leader>oi` |
| Next / prev problem | `F8` / `Shift+F8` | `]e` / `[e` |
| Error description | `Ctrl+F1` | — |
| Problems list | `Alt+0` | — |
| Hover documentation | `K` / `Ctrl+Q` | — |
| File / project symbols | `Ctrl+Shift+O`, `Alt+7`, `Ctrl+F12` / `Ctrl+Alt+Shift+N` | `<leader>o` / `<leader>O` |
| Refactor this | `Ctrl+Alt+Shift+T` | — |
| ESLint autofix | `Ctrl+Shift+S` | — |
| Toggle inlay hints | — | `<leader>ih` *(only where the server supports it)* |
| Trigger completion | `Ctrl+Space` | — |
| Accept completion | `Tab` | — |
| Accept **Copilot** suggestion | `Alt+L` | — |
| Snippet jump | `Ctrl+J` / `Ctrl+K` | — |

**Copilot does not own `Tab`.** copilot.vim maps `<Tab>` globally by default; blink maps it
buffer-locally on `InsertEnter`. Buffer-local beats global — but only on buffers blink has
reached, so ownership depended on timing rather than intent. `g:copilot_no_tab_map` is set, so
`Tab` is unambiguously blink's and Copilot suggestions are accepted with `Alt+L`.

**blink's keys will not show up in `:imap`.** It applies them with
`nvim_buf_set_keymap` on `InsertEnter`, deliberately, so that buffer-local mappings from
plugins like autopairs cannot override them. `maparg` on a fresh buffer reports nothing; that
is expected, not a fault.

`grn` `gra` `grr` `gri` are **Neovim 0.11 defaults**, kept alongside the spellings this config
has always used.

## Git — gitsigns

| Action | Key |
|---|---|
| Next / prev hunk | `]g` / `[g`, `Ctrl+Alt+Shift+Down` / `Up` |
| Preview hunk | `gs` |
| Rollback hunk | `Ctrl+Alt+Z`, `<leader>gu` |
| Blame line | `<leader>gb` |
| Hunk text object | `ig` / `ag` |
| Git status | `:Git` (fugitive) |

## Debugging — nvim-dap

Keys are **VSCode's**, because IntelliJ's F7/F8/Shift+F8 are already spell-check and problem
navigation here. Free IntelliJ spellings are bound as aliases.

| Action | Key | IntelliJ alias |
|---|---|---|
| Start / continue | `F5` | `Shift+F9` |
| Stop | `Shift+F5` | `Ctrl+F2` |
| Restart | `Ctrl+Shift+F5` | — |
| Toggle breakpoint | `F9` | `Ctrl+F8` |
| Conditional breakpoint | `<leader>dB` | — |
| Step over / into / out | `F10` / `F11` / `Shift+F11` | — |
| Evaluate | `<leader>de` | `Alt+F8` |
| Toggle UI / REPL | `<leader>du` / `<leader>dr` | — |
| Run last | `<leader>dl` | — |

Adapters: **JS/TS** (node + browser), **PHP** (Xdebug, with a Docker path mapping for
`portal`), **Python**. Rust is deliberately not configured.

## Editing

| Action | Key | Fallback |
|---|---|---|
| Comment line / selection | `Ctrl+/` | `gcc` / `gc` |
| Duplicate line | `Ctrl+D` | — |
| Delete line | `Ctrl+Y` | — |
| Move line / block | `Alt+Shift+Up/Down`, `Ctrl+Shift+Up/Down` | — |
| Select all | `Ctrl+A` | — |
| Save | `Ctrl+S` | — |
| Undo / redo | `Ctrl+Z` / `Ctrl+Shift+Z` | `u` / `Ctrl+R` |
| Undo tree | `<leader>u` | — |
| Replace in file | `Ctrl+Shift+H` | `<leader>h` |
| Join lines | `Ctrl+Shift+J` | `J` |
| Jump to bracket | `Ctrl+Shift+M` | `%` |
| New line below / above | `Shift+Enter` / `Ctrl+Alt+Enter` | `o` / `O` |
| Append semicolon | `Ctrl+Shift+L` / `Ctrl+Enter` | — |
| Copy file path | `Ctrl+Shift+C` | — |
| Fold / unfold / toggle | `Ctrl+-` / `Ctrl+=` / `Ctrl+.` | `zc` / `zo` / `za` |
| Multi-cursor: next / all | `Ctrl+N` / `Ctrl+Shift+L` | `Alt+J` / `Ctrl+Alt+Shift+J` |
| Multi-cursor: add above/below | `Ctrl+Alt+Up/Down` | — |
| Toggle value (`true`↔`false`) | `-` / `_` | — |
| Increment / decrement | `g Ctrl+A` / `g Ctrl+X` | — |
| Align | `ga` + char | — |
| Wrap in pair just typed | `Alt+E` | — |
| Strip trailing whitespace | — | `<leader>$` |
| Word yank | — | `<leader>y` |
| Live `:s` preview | — | automatic (`inccommand=split`) |

## Text objects

**Treesitter objects are buffer-local and only bind where a parser exists.** In `nginx.conf`,
`kitty.conf` and anything else unparsed they fall through to targets.vim — which is why
targets.vim and vim-indent-object are still installed.

| Object | Where a parser exists | Otherwise |
|---|---|---|
| `af` / `if` | function | — |
| `ac` / `ic` | class | — |
| `aa` / `ia` | parameter (treesitter) | argument (targets.vim) |
| `a/` | comment | — |
| `ai` / `ii` | — | indent block (vim-indent-object) |
| `ig` / `ag` | git hunk (gitsigns) | |
| `]f` / `[f` | jump to next / prev function | — |

## Workbench

| Action | Key | Fallback |
|---|---|---|
| File explorer | `Ctrl+B` / `Alt+1` | — |
| Close buffer | `Ctrl+W` | — |
| Terminal | ``Ctrl+` `` / `Alt+F12` | — |
| Next / prev buffer | `Ctrl+PageDown/Up` | `Alt+PageDown/Up` |
| Window commands | `<leader>w` + `hjkl/s/v/o/=` | — |
| Resize windows | `<leader>r` then `hjkl` | — |
| Split h / v | `<leader>-` / `<leader>\|` | — |
| Navigate splits & tmux panes | `Ctrl+H/J/K/L`, `Alt+arrows` | — |
| Spell check toggle | `F7` | — |
| Clear search highlight | `<leader><CR>` | — |
| Plugin manager | `:lua vim.pack.update()` | — |
| LSP server manager | `:Mason` | — |
| Project root | `:Root` / `:Rcd` | — |

---

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

In Neovim two more moved: flash's treesitter-select from `<leader>S` to `<leader>v`, and
flash's jump off `<leader>s` entirely (it shadowed the `<leader>sn`/`sp`/`sa`/`s?` spell maps).
The jump is `<leader><leader>`.

## Keys that must stay unmapped

Unchanged from the Vim config, and enforced by the test suite:

`y` `x` `s` `1` `2` `p` `P` `<Tab>` `<Esc>` `F` `H` `B` `T` `M` `S` `R`

Each was taken once and broke something structural. `s` and `S` matter especially here —
flash wants both by default and is explicitly configured not to take them.

## Known gaps

- `Ctrl+R` is IntelliJ's replace-in-file; not bound, because it is Vim's redo. Replace is
  `Ctrl+Shift+H`.
- `Ctrl+H` is pane navigation, not replace — it is wired through kitty's `pass_keys.py`,
  tmux, and vim-tmux-navigator.
- **Alt+Shift+arrows** and **Ctrl+Shift+W** are claimed by VSCode's integrated terminal, so
  inside it they never reach Neovim. They work in kitty.
- `<leader>ih` only appears when the attached server advertises `textDocument/inlayHint`.
  `jsonls`, for instance, does not.
- Buffer-local keys — gitsigns' hunk maps and the treesitter text objects — exist only once
  their provider has attached to that buffer. On a file outside a git repo, or a filetype
  with no parser, they are correctly absent.
