# config/nvim — Neovim, alongside Vim

**Status:** Tier-2 migration in progress. Started as a like-for-like port of the Vim config
in [`.vim/`](../../.vim/); now being converted to a native Neovim config one subsystem at a
time, keeping a working editor at every step.

| Subsystem | From | To | |
|---|---|---|---|
| plugin manager | vim-plug | `vim.pack` (0.12 built-in) | ✅ done |
| LSP + completion | coc.nvim | mason + lspconfig + blink.cmp | ✅ done |
| picker | fzf.vim | snacks.picker (+ dashboard) | ✅ done |
| statusline | lightline | lualine | ✅ done |
| explorer | NERDTree | snacks.explorer | ✅ done |
| syntax | js/jsx/php syntax plugins | treesitter | ✅ done |

**Tier 3 in progress.** AI chat, treesitter text objects and debugging are in.

**Tier 2 is complete.** What remains in vimscript is deliberate: options, autocmds and the
keymaps, which have no native-Lua advantage and would only churn a working, documented layer.
The Tier-1 state is recoverable from git (commit `a22243c`).

`vim` remains the daily driver. This exists so the two can be compared without either one's
breakage affecting the other.

## They share nothing at runtime

| | Vim | Neovim |
|---|---|---|
| config | `~/.vimrc` + `~/.vim/` | `~/.config/nvim/` |
| plugins | `~/.vim/plugged` | `~/.local/share/nvim/site/pack/core/opt` |
| manager | vim-plug | `vim.pack`, into `site/pack/core/opt` |
| lockfile | — | `config/nvim/nvim-pack-lock.json` (tracked) |
| state | `~/.local/share/vim/viminfo` | `~/.local/state/nvim/` (shada) |

Breaking one cannot break the other. `install.sh` provisions both.

**Do not point Neovim's shada at Vim's viminfo.** Carrying `set viminfo+=n…/vim/viminfo`
across is the single most damaging thing you can do here: the formats differ, so Neovim
fails with `E576: Failed to parse ShaDa file`, refuses to write, and leaves `viminfo.tmp.b`
behind. It happened once during this port; `00-xdg.vim` records it.

## What actually differs

Every divergence is commented in place and marked `DIVERGES`. Summary:

| File | Difference |
|---|---|
| `00-xdg.vim` | Almost entirely deleted. Neovim is XDG-native — `stdpath('state')` already holds undo/swap/backup/shada, so only `undofile`/`backup` policy remains. Also disables the perl/ruby/node providers. |
| `01-clipboard.vim` | ~80 lines deleted. `v:clipproviders` and `'clipmethod'` are Vim 9.1 APIs with no counterpart; Neovim finds `wl-copy` by itself (`:checkhealth` confirms). |
| `10-plugins.vim` | `packadd comment/editorconfig/hlyank` are gone — commenting and editorconfig are built in, `hlyank` becomes a `vim.hl.on_yank` autocmd. `cfilter` and `nohlsearch` remain real packages. vim-plug paths use `stdpath('data')`. |
| `20-options.vim` | `termencoding` removed (raises `E519`), `t_vb`/`t_ut` have no equivalent, `nocompatible` is a no-op. |
| `25-autocmds.vim` | Adds the `TextYankPost` → `vim.hl.on_yank` group replacing `hlyank`. |
| `31-keymap-ide.vim` | The `'keyprotocol'` block is **deleted** — Neovim negotiates the kitty protocol automatically. `Ctrl+/` maps to `gcc`/`gc` instead of `<Plug>(comment-toggle-line)`, which does not exist here. |
| `40-ui.vim` | The `has('gui_running')` block is dropped; Neovim has no built-in GUI. |

### coc.nvim → native LSP: what moved where

| coc extension | Replacement |
|---|---|
| tsserver, eslint, pyright, css, html, json, sh, docker, phpls, tailwindcss, emmet | 11 servers, installed by mason, enabled via `vim.lsp.enable` |
| coc-prettier | conform.nvim (`lua/plugins/format.lua`) |
| coc-git | gitsigns.nvim (`lua/plugins/git.lua`) |
| coc-snippets | blink.cmp + friendly-snippets |
| coc-highlight | built in — LSP document highlight on `CursorHold` |
| coc-yank | dropped; nothing in the keymap used it |

Two things did **not** carry over cleanly:

- **Snippets changed format.** `honza/vim-snippets` is UltiSnips format, which coc-snippets read
  directly; blink reads LSP-format. Rather than add LuaSnip purely to run a compatibility
  layer, honza was dropped for `rafamadriz/friendly-snippets`. There were no
  personally-written snippets to convert — if there ever are, that changes.
- **Formatting is no longer on the language servers.** conform owns it, and `ts_ls`/`html`/
  `cssls`/`jsonls` have their formatting capability disabled in `lua/plugins/lsp.lua`, or both
  would fight over the buffer.

Neovim 0.11+ also ships **default LSP mappings** — `grn` rename, `gra` code action, `grr`
references, `gri` implementation, `K` hover. Those are not redefined; the `gd`/`gy`/`gi`/`gr`
spellings this config used with coc are kept alongside them in
`after/plugin/lsp-keymaps.lua`.

### Deferred setup vs. the buffer that triggered it

Deferring a module to `BufReadPre` has a sharp edge: the plugin's `setup()` then runs
*during* that first buffer's own `BufReadPre`, so any autocommands it registers are too late
for the buffer that triggered them. It has bitten this config twice, in different disguises:

- **LSP** — `on_event` originally wrapped its callback in `vim.schedule()`, which pushed
  `vim.lsp.enable()` past `FileType`. Only Copilot attached, no diagnostics, no error.
- **gitsigns** — `setup()` registers gitsigns' own attach autocmds, so the first file of
  every session was never attached. Deceptively, gitsigns still set `b:gitsigns_head` from
  its repo scan, so the buffer *looked* attached while its cache entry was absent and every
  `on_attach` keymap — `]g`, `[g`, `gs`, `<leader>gu`, `Ctrl+Alt+Z` — silently did nothing.

`lua/plugins/git.lua` now attaches explicitly to already-open buffers on the next
`BufEnter`. Note `BufEnter`, not immediately: at `BufReadPre` the buffer is not loaded yet,
so an is-loaded guard skips it.

**If you defer a module, check the FIRST buffer specifically.** Everything after it works,
which is exactly what makes this class of bug survive casual testing.

### The trap worth knowing

A mapping whose right-hand side names a **non-existent `<Plug>`** is silently accepted.
`:nmap` reports it, `maparg()` returns it, and pressing the key does nothing. That is how
`Ctrl+/` survived the port looking correct while doing nothing at all.

To check for it:

```vim
:lua= vim.tbl_filter(function(m)
  local p = (m.rhs or ''):match('<Plug>%b()')
  return p and vim.fn.maparg(p, m.mode) == ''
end, vim.fn.maplist())
```

`coc-git-*` targets will show up in that list on a headless run — coc registers them lazily
from its node process, so they are absent until the extension activates. That is expected.

### treesitter: the `main`-branch trap

nvim-treesitter's `master` branch is frozen and does not work on 0.12; `main` is a ground-up
rewrite that shares no API with it, so nearly every guide you find online is for the wrong
one. Two consequences this config had to handle:

- **`main` requires the `tree-sitter` CLI** to build parsers (master used a bare C compiler).
  Without it every parser install fails with `ENOENT ... 'tree-sitter'` and Neovim silently
  falls back to regex syntax — no error surfaces in normal use. It is pinned in
  `config/mise/config.toml`.
- **Highlighting is per-buffer.** There is no `highlight = { enable = true }`; you call
  `vim.treesitter.start()` yourself from a `FileType` autocmd. See `lua/plugins/treesitter.lua`.

Parsers land in `~/.local/share/nvim/site/parser`, not inside the plugin directory.

## Beyond parity (Tier 3)

Things Neovim can do that Vim cannot, which is the point of having migrated:

| | |
|---|---|
| `codecompanion.nvim` | AI chat + inline assist, on the **Copilot** adapter — no new API key or subscription, it reuses copilot.vim's existing token. `Ctrl+Alt+I` matches this machine's VSCode binding for Copilot Chat. |
| `nvim-treesitter-textobjects` | `af`/`if` function, `ac`/`ic` class, `aa`/`ia` parameter, `a/` comment; `]f`/`[f` to jump between functions. Registered **per buffer, only where a parser exists** — see below. |
| `nvim-dap` + `dap-ui` | Debugging. Adapters chosen from what `~/Projects` actually holds — see below. |

### Why targets.vim and vim-indent-object are still here

They are the fallback for filetypes with no treesitter parser, not duplication — which is
also why they were not replaced by `mini.ai`.

The treesitter text objects were mapped **globally** at first, and that silently broke
targets: `aa`/`ia` are its argument objects, and a global mapping shadowed them everywhere,
including `nginx.conf` and `kitty.conf`. In those buffers `daa` was bound, `maparg` reported
it, and it did nothing at all — the same exists-but-does-nothing shape as the `<Plug>` trap.
They are now registered buffer-locally from the `FileType` autocmd, and only after
`vim.treesitter.start()` has actually succeeded for that buffer.

### Retiring vimscript plugins

| Out | In | |
|---|---|---|
| `easymotion` + `clever-f.vim` | `flash.nvim` | two plugins for one: `char` mode gives f/F/t/T that repeat on the same key, `jump` gives labelled motion |
| `mbbill/undotree` | 0.12's bundled `nvim.undotree` | `packadd`, no plugin |
| `markonm/traces.vim` | **built-in `'inccommand'`** | live `:s` preview has been native since 0.1; the plugin was pure duplication |
| `airblade/vim-rooter` | **built-in `vim.fs.root()`** | native since 0.10; `lua/plugins/rooter.lua` is 20 lines and no dependency |
| `luochen1990/rainbow` | `rainbow-delimiters.nvim` | colours by treesitter node instead of regex, so it stops mis-colouring inside strings |
| `alvan/vim-closetag` | `nvim-ts-autotag` | closes *and renames* tag pairs, which closetag could not do |
| `cohama/lexima.vim` | `nvim-autopairs` | decides from the syntax tree at the keystroke instead of a rule table built at startup |

**`<CR>` is the delicate part of the autopairs swap**, because three things want that key:
blink (accept the completion), autopairs (split a fresh pair onto its own line), and Vim
(newline). It resolves without an arbiter *only* because blink is mapped
`['<CR>'] = { 'accept', 'fallback' }` — `fallback` hands the key on when the menu is closed.
Remove either that `fallback` or autopairs' `map_cr` and one of the two behaviours breaks
silently. All three cases are tested in `lua/plugins/pairs.lua`'s companion checks.

What `check_ts` actually buys, measured rather than assumed:

```
x = "he'   ->  x = "h'e"     apostrophe inside a string: not paired
y = '      ->  y = ''        the same key in code:       paired
```

It does **not** suppress pairing inside comments — `-- note (` still becomes `-- note ()`,
which is intended and matches what lexima did.

Two of those are replaced by **built-ins rather than other plugins**, which is the better
trade. `vim-rooter`'s auto-chdir is deliberately not reproduced: it moved the working
directory on every buffer switch, which quietly breaks a running `:terminal`, a `jobstart`,
or an LSP started in the old cwd. `:Root` prints the root, `:Rcd` changes to it when you
actually want that.

Measured with an interleaved A/B (alternating stashed/unstashed runs, so drifting machine
load cancels rather than being attributed to the change): **102ms → 68ms**.

**flash's default keys are deliberately not used.** It wants `s` for jump and `S` for
treesitter select, and both must stay unmapped here — they were reclaimed once already and
are on the must-stay-unmapped list in `CLAUDE.md`. Jump is on `<leader><leader>`, matching
the easymotion spelling this config always had.

The command rename bit once: `<leader>u` still said `:UndotreeToggle` (mbbill's name) after
the swap, while the bundled package provides `:Undotree`. The mapping existed, `maparg`
reported it, and it would have failed on use — the same class of bug as the `<Plug>` trap
above. There is now a check for it: every `<cmd>Foo<cr>` mapping must name a command that
exists.

### Debug adapters, chosen from ~/Projects

A survey of 74 project directories, rather than a starter template:

| | |
|---|---|
| **JS/TS** | every recent project bar one — react, vite, next, nestjs, vue, react-native/expo. `js-debug` covers node *and* browser, so one adapter serves all of it. Four configs: launch file (via `tsx`, so TypeScript runs without a build), attach to process, and browser against vite's :5173 / next's :3000. |
| **PHP** | 1070 files, of which **1014 are one project** (`portal`, Laravel in Docker). Xdebug connects *to* the editor, so the config listens rather than launches — and carries a `/var/www/html` → `${workspaceFolder}` path mapping, without which it stops on the right line of a non-existent file and looks broken. |
| **Python** | ~130 files, scattered. Cheap to support, so supported. |
| **Rust** | two projects, neither touched recently. **Deliberately not configured** — codelldb is heavy and nothing here justifies it yet. |

**Keys are VSCode's, not IntelliJ's.** IntelliJ debugging is F7/F8/Shift+F8, but this config
already uses F7 for spell-check and F8/Shift+F8 for problem navigation — all used far more
often than a debugger. VSCode's F5/F9/F10/F11 set is free by comparison. The free IntelliJ
forms (Ctrl+F8, Ctrl+F2, Alt+F8) are bound as aliases. One displacement: **F5 was
UndotreeToggle, now `<leader>u`**.

**Why CodeCompanion and not avante.nvim:** avante's Copilot support is widely reported as
unreliable, and Copilot is the whole point here — it is already paid for and already
authenticated. CodeCompanion is also far better maintained (single-digit open issues against
avante's ~200) and keeps its chat in a real, editable buffer rather than reimplementing
Cursor's sidebar.

**Data egress:** prompts and attached buffers go to GitHub Copilot — the same destination
copilot.vim's completions already use, so no new one, but worth being deliberate about.

targets.vim and vim-indent-object stay alongside the treesitter objects: they still cover the
filetypes with no parser (nginx.conf, kitty.conf).

## What this port is NOT

Neovim 0.12 ships things this config deliberately does not use, because using them would stop
it being a like-for-like port:

- `:Undotree`, `:DiffTool` — 0.12 ships both; `mbbill/undotree` is still used
- `'autocomplete'` — 0.12's native insert-mode completion; blink.cmp is used instead
- `vim.pack`'s `load` hook — plugins still all land on 'runtimepath' at startup. What is
  deferred is the *setup* work, which is where the cost actually was (see below).

## Startup

**~57ms**, against ~82ms for the Vim config and ~97ms before deferral.

vim.pack has no lazy-loading, and sourcing a plugin's `plugin/` file is cheap anyway. The
expense was the setup each module ran: mason scanning its registry (16.5ms), blink building
its keymaps (10ms), lexima materialising several hundred rules (8.8ms), the treesitter parser
scan (4.9ms), gitsigns (4.1ms) — 44ms of a 97ms startup, none of it needed before the first
keystroke. `lua/util/lazy.lua` defers those to the earliest event that could need them:

| Trigger | Loads |
|---|---|
| `BufReadPre` / `BufNewFile` | LSP, gitsigns |
| `InsertEnter` | blink.cmp, lexima's rule table |
| UI settled | treesitter parser install scan |
| first `:CodeCompanion*` | codecompanion (via command stubs) |
| eager | statusline, picker, format, treesitter's `FileType` autocmd, AI keymaps |

The eager set is not arbitrary. The statusline is visible in the first frame; picker and
format define user commands (`:ProjectFiles`, `:Find`, `:Format`) that the vimscript keymaps
call by name, so deferring them leaves a window where `Ctrl+P` raises `E492`; and
treesitter's `FileType` autocmd must be registered before the first `FileType` fires or a
file opened from the command line is never highlighted.

**The trap:** deferring with `vim.schedule()` from `BufReadPre` pushes the callback past
`FileType`, so `vim.lsp.enable()` had not run when the first buffer tried to attach. Only
Copilot attached, no diagnostics appeared, and nothing errored. `on_event` therefore runs
synchronously — see the comment in `lua/util/lazy.lua`.

## Verifying

```sh
nvim --headless -c 'qa!'          # must print nothing
nvim --headless -c 'checkhealth vim.lsp' -c 'qa!'
:Mason                            # server install status, interactively
nvim --headless -c 'checkhealth vim.provider' -c 'qa!'
nvim -c 'PlugInstall --sync' -c 'qa!'
```
