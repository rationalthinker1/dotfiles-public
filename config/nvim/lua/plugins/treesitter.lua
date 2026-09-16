-- lua/plugins/treesitter.lua — real parsers, replacing three syntax plugins.
--
-- Replaces StanAngeloff/php.vim, yuezk/vim-js and chemzqm/vim-jsx-improve.
-- chr4/nginx.vim and fladson/vim-kitty stay: no treesitter parser exists for
-- nginx.conf or kitty.conf.
--
-- THIS IS THE `main` BRANCH API, which shares nothing with the master-branch
-- API most guides still show. There is no require('nvim-treesitter.configs')
-- and no `highlight = { enable = true }` table. main is deliberately
-- lower-level: you install parsers, then start treesitter per buffer yourself.
-- master is frozen and does not work on 0.12 at all.
--
-- REQUIRES THE tree-sitter CLI. main shells out to it to build each parser;
-- master compiled with a bare C compiler, so most guides do not mention it.
-- Without the CLI every install fails with an ENOENT on 'tree-sitter' and
-- Neovim quietly falls back to regex syntax. It is pinned in
-- config/mise/config.toml alongside neovim itself.
--
-- (jsonc is deliberately absent from the list below: nvim-treesitter reports
-- it as an unsupported language, and json covers those buffers.)

local ts = require('nvim-treesitter')

-- Parsers to install. Neovim already bundles c, lua, vim, vimdoc, query and
-- markdown, so those are not repeated here.
local parsers = {
  'javascript', 'typescript', 'tsx', 'jsdoc',
  'php', 'phpdoc',
  'html', 'css', 'scss',
  'json', 'yaml', 'toml',
  'bash', 'dockerfile',
  'python',
  'git_config', 'gitcommit', 'gitignore', 'diff',
  'regex',
}

--- Text objects, from nvim-treesitter-textobjects (also `main` branch).
---
--- REGISTERED PER BUFFER, and only where a parser actually exists.
---
--- They were global at first, which silently broke targets.vim: `aa`/`ia` are
--- targets' argument objects, and a global treesitter mapping shadowed them
--- everywhere — including nginx.conf and kitty.conf, which have no parser. In
--- those buffers `daa` was bound, reported by maparg, and did nothing at all.
---
--- Buffer-local mappings mean parsed filetypes get the (better) syntax-tree
--- objects and everything else falls through to targets.vim as before. This is
--- also why targets.vim and vim-indent-object are still installed rather than
--- replaced by mini.ai: they are the fallback, not duplication.
local ts_objects = {
  ['af'] = '@function.outer',
  ['if'] = '@function.inner',
  ['ac'] = '@class.outer',
  ['ic'] = '@class.inner',
  ['a/'] = '@comment.outer',
  ['aa'] = '@parameter.outer',
  ['ia'] = '@parameter.inner',
}

local function attach_textobjects(buf)
  local ok, ts_select = pcall(require, 'nvim-treesitter-textobjects.select')
  if not ok then
    return
  end
  for lhs, capture in pairs(ts_objects) do
    vim.keymap.set({ 'x', 'o' }, lhs, function()
      ts_select.select_textobject(capture, 'textobjects')
    end, { buffer = buf, desc = 'treesitter ' .. capture })
  end

  local move = require('nvim-treesitter-textobjects.move')
  vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
    move.goto_next_start('@function.outer', 'textobjects')
  end, { buffer = buf, desc = 'Next function' })
  vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
    move.goto_previous_start('@function.outer', 'textobjects')
  end, { buffer = buf, desc = 'Previous function' })
end

local TS_FOLDEXPR = 'v:lua.vim.treesitter.foldexpr()'

--- `:setlocal` for a window option. NOT vim.wo[win], which is `:set`.
---
--- This is the second half of the fold bug and the nastier one. Despite the
--- name, `vim.wo[win].foldmethod = 'expr'` writes the GLOBAL value as well as
--- the window's — measured, not assumed:
---
---   :set foldmethod=indent | lua vim.wo[0].foldmethod = 'expr'
---   -> vim.go.foldmethod == 'expr'
---
--- So the original `vim.wo.foldmethod = 'expr'` did not merely leave one window
--- set up for treesitter: it replaced the `foldmethod=indent` that
--- 20-options.vim establishes for the whole session, from the first parsed file
--- onwards. Every later window and buffer inherited treesitter's foldexpr as
--- its DEFAULT, including the ones with no parser, where that expression
--- returns 0 for every line. nvim_set_option_value with an explicit local scope
--- is the only form that stays in the window.
local function set_win(win, name, value)
  vim.api.nvim_set_option_value(name, value, { scope = 'local', win = win })
end

local function get_win(win, name)
  return vim.api.nvim_get_option_value(name, { scope = 'local', win = win })
end

--- Point every window showing `buf` at treesitter's foldexpr — or away from it.
---
--- 'foldexpr' and 'foldmethod' are WINDOW-local, so the obvious `vim.wo.…`
--- writes them to whatever window is current, which is not necessarily one
--- showing `buf`. For a buffer force-loaded by bufload() — an LSP rename across
--- files (runtime/lua/vim/lsp/util.lua), snacks' picker preview — the current
--- window is the throwaway autocommand window, and the write is discarded with
--- it. FileType never fires for that buffer again, so the folds never arrive.
---
--- The reset branch matters just as much. Without it a window that once held a
--- parsed buffer keeps treesitter's foldexpr for every buffer after it, and
--- with no parser attached vim.treesitter.foldexpr() returns 0 for every line
--- (runtime/lua/vim/treesitter/_fold.lua). So kitty.conf or nginx.conf — the
--- two filetypes this config deliberately keeps parser-less — opened in that
--- window got NO folds at all, and the IntelliJ fold keys in 31-keymap-ide.vim
--- became the no-ops that 20-options.vim's foldmethod=indent exists to prevent.
--- It only resets OUR foldexpr, so a 'foldmethod' the user or an ftplugin chose
--- (kitty.conf's `marker`, say) is left alone.
local function apply_folds(buf)
  local started = vim.b[buf].ts_lang ~= nil
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if started then
      set_win(win, 'foldexpr', TS_FOLDEXPR)
      set_win(win, 'foldmethod', 'expr')
    elseif get_win(win, 'foldexpr') == TS_FOLDEXPR then
      -- Restore the session default rather than hardcoding 'indent', so
      -- 20-options.vim stays the single place that decides it.
      set_win(win, 'foldmethod', vim.go.foldmethod)
      set_win(win, 'foldexpr', vim.go.foldexpr)
    end
  end
end

--- Start treesitter for `buf`, if it is ready for one and does not have one.
---
--- Highlighting is per-buffer on main: nothing happens without this. Guarded
--- with pcall because the parser may still be installing on first run, and an
--- un-started treesitter must not break the buffer.
local function attach(buf)
  -- Never act on a buffer that is not loaded yet. `syntax enable` used to pull
  -- in runtime/filetype.lua from 40-ui.vim, which runs `doautoall
  -- filetypedetect BufRead` -- so FileType fired for the command-line
  -- argument's buffer while it was still unloaded, during init.
  -- vim.treesitter.start() needs text, so it would bufload() it there and then.
  -- Nvim would then find the buffer already loaded when it finally edits the
  -- file, take the "no read needed" path in do_ecmd(), and skip applying
  -- 'foldlevelstart' -- leaving 'foldlevel' at 0 against treesitter's folds,
  -- i.e. the whole file folded shut on open. The real FileType fires again once
  -- the buffer is loaded. 40-ui.vim no longer calls `syntax enable`, but
  -- anything else reaching filetype detection early would do the same.
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  -- get_lang() returns `ft_to_lang[ft] or ft`, so it is never nil for a real
  -- filetype and is not a usable "no parser" test -- the pcall below is. An
  -- empty filetype is worth skipping before we get there.
  local ft = vim.bo[buf].filetype
  if ft == '' then
    return
  end
  local lang = vim.treesitter.language.get_lang(ft) or ft
  -- Idempotent per LANGUAGE, not per buffer: FileType fires again for a `:e`
  -- and for a `:setf`, and the second of those is a real change that has to
  -- re-run. Keying on a boolean would have pinned a buffer to whatever it was
  -- first detected as.
  if vim.b[buf].ts_lang == lang then
    return
  end
  if not pcall(vim.treesitter.start, buf, lang) then
    return
  end
  vim.b[buf].ts_lang = lang

  -- Only now, with a parser confirmed for THIS buffer.
  attach_textobjects(buf)

  -- A working parser does NOT imply an indents query. Queries live beside the
  -- parsers in ~/.local/share/nvim/site/queries, installed by nvim-treesitter
  -- -- so the languages Neovim BUNDLES (c, lua, markdown, query, vim, vimdoc)
  -- have no nvim-treesitter queries at all, and of the installed ones diff,
  -- dockerfile, gitcommit, gitignore, git_config, jsdoc, phpdoc and regex ship
  -- no indents.scm.
  --
  -- That matters because of how the miss fails. nvim-treesitter's indent.lua
  -- returns an empty capture map when the query is absent, and get_indent()
  -- then falls through returning 0 -- column 0, not -1 ("keep the previous
  -- indent"). Setting 'indentexpr' regardless also overrode Neovim's own
  -- runtime/indent/*.vim, which is the better answer for exactly those
  -- languages: `o` or `==` inside a function in this repo's own .vim files
  -- snapped the line to column 0, and `=G` flattened the file.
  local ok_query, indents = pcall(vim.treesitter.query.get, lang, 'indents')
  if ok_query and indents then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

local group = vim.api.nvim_create_augroup('nvim_treesitter_start', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function(args)
    attach(args.buf)
    apply_folds(args.buf)
  end,
})

-- FileType does not re-fire for an already-loaded buffer, so a buffer shown in
-- a second window (`:vsplit | :b main.ts`) never got the treesitter folds, and
-- a window that had them kept them for the next buffer. Both are window events,
-- not buffer events, so they belong here rather than on FileType.
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = group,
  callback = function(args)
    apply_folds(args.buf)
  end,
})

-- install() is async and a no-op for parsers already present, but it still
-- scans and costs ~5ms on every start. A missing parser falls through to regex
-- syntax, so nothing in the first frame depends on it — it waits for the UI.
-- The FileType autocmd above is NOT deferred: it has to be registered before
-- the first FileType fires, or a file opened from the command line is never
-- highlighted.
--
-- The sweep afterwards is not cosmetic. On a fresh machine the parsers arrive
-- seconds AFTER that first FileType has already failed its pcall, and FileType
-- does not fire again for a loaded buffer — so the file you opened to trigger
-- the install had no highlighting, no folds and no af/if/ac/ic/aa/ia/]f/[f for
-- its entire lifetime, until you reloaded it by hand.
require('util.lazy').on_idle(function()
  ts.install(parsers):await(vim.schedule_wrap(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      attach(buf)
      apply_folds(buf)
    end
  end))
end)
