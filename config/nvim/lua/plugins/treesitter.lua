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

-- install() is async and a no-op for parsers already present, but it still
-- scans and costs ~5ms on every start. Nothing observable depends on it having
-- finished — a missing parser falls through to regex syntax — so it waits for
-- the UI. The FileType autocmd below is NOT deferred: it has to be registered
-- before the first FileType fires, or a file opened from the command line is
-- never highlighted.
require('util.lazy').on_idle(function()
  ts.install(parsers)
end)

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

-- Highlighting is per-buffer on main: nothing happens without this autocmd.
-- Guarded with pcall because a parser may still be downloading on first run,
-- and an un-started treesitter must not break the buffer.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('nvim_treesitter_start', { clear = true }),
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    local lang = vim.treesitter.language.get_lang(ft)
    if not lang then
      return
    end
    -- Only start if the parser is actually installed, otherwise fall through to
    -- the regex syntax rather than erroring.
    local ok = pcall(vim.treesitter.start, args.buf, lang)
    if ok then
      -- Only now, with a parser confirmed for THIS buffer.
      attach_textobjects(args.buf)
      -- Treesitter-aware folding and indentation, for the filetypes that have
      -- a parser. 20-options.vim sets foldmethod=indent globally; this is
      -- strictly better where it applies.
      vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      vim.wo.foldmethod = 'expr'
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
