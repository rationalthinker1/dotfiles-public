-- ~/.config/nvim/init.lua — loader only.
--
-- TIER 3. The vimscript port (see README.md) is a native Neovim config, now
-- gaining what Neovim can do that Vim cannot. What was converted:
--
--   [x] plugin manager   vim-plug          -> vim.pack        (0.12 built-in)
--   [x] LSP + completion coc.nvim          -> mason + lspconfig + blink.cmp
--   [x] picker           fzf.vim           -> snacks.picker (+ dashboard)
--   [x] statusline       lightline         -> lualine
--   [x] explorer         NERDTree          -> snacks.explorer
--   [x] syntax           3 syntax plugins  -> treesitter
--
-- Everything not yet converted is still the vimscript from the Tier-1 port,
-- sourced below in the same order as before. The ordering contract is unchanged
-- and still load-bearing:
--
--   VARIABLES  ->  config/05-plugin-vars.vim, before plugins are added
--   MAPPINGS   ->  after/plugin/, after the plugins have loaded
--
-- vim.pack.add() defaults to `load = false` while init.lua is sourcing, so
-- plugins join 'runtimepath' here but their plugin/ files are not sourced until
-- packloadall at the end of startup. That preserves the contract for free.

-- The leader must exist before any mapping that uses it.
vim.g.mapleader = ','
vim.g.maplocalleader = ','

local cfg = vim.fn.stdpath('config') .. '/config/'

--- Source one of the not-yet-converted vimscript fragments.
local function source(name)
  local path = cfg .. name
  if vim.uv.fs_stat(path) then
    vim.cmd.source(vim.fn.fnameescape(path))
  end
end

-- 1. On-disk state, then the clipboard note — both before anything can write
--    state or touch a register.
source('00-xdg.vim')
source('01-clipboard.vim')

-- 2. Plugin variables. MUST precede the vim.pack.add() below: most plugins read
--    their configuration once, as they load, and a variable set afterwards is
--    silently ignored while the plugin's own defaults win. See the header of
--    05-plugin-vars.vim for the four collisions this caused when it was wrong.
source('05-plugin-vars.vim')

-- 3. Plugins, then the Lua subsystems.
--
-- vim.pack has no lazy-loading, so the plugins themselves all land on
-- 'runtimepath' here. What IS deferred is the setup work each module does —
-- see lua/util/lazy.lua for why, and each module for its trigger. Measured:
-- 97ms -> see README. Only the two things visible in the first frame
-- (statusline, colours) stay on the startup path.
require('plugins')

local lazy = require('util.lazy')

-- Visible immediately; must not be deferred or the first frame is unstyled.
require('plugins.statusline')

-- Needed before a language server could attach. BufReadPre fires before
-- FileType, which is what triggers LspAttach, so this is early enough.
lazy.on_event({ 'BufReadPre', 'BufNewFile' }, function()
  require('plugins.lsp')
  require('plugins.git')
  -- treesitter-backed UI; pointless before a buffer exists to decorate.
  require('plugins.ui-extras')
end, { desc = 'LSP + gitsigns + treesitter UI' })

-- ...but mason's :Mason* commands are created by mason.setup(), which the above
-- defers until a buffer is read. On the dashboard, before opening anything,
-- :MasonInstall simply did not exist. Stubs make them reachable from the first
-- frame; invoking one loads the real thing.
lazy.on_cmd({
  'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll', 'MasonLog', 'MasonUpdate',
}, function()
  require('plugins.lsp')
end)

-- Nothing can complete or auto-pair before insert mode.
lazy.on_event('InsertEnter', function()
  require('plugins.completion')
  -- Must load in the SAME handler as blink and after it: autopairs maps <CR>,
  -- and blink's <CR> has to be the outer one so its `fallback` can hand off.
  require('plugins.pairs')
end, { desc = 'blink.cmp + autopairs' })


-- Eager, deliberately. Both measured under 2ms, and both define user commands
-- (:ProjectFiles, :Find, :ExplorerToggle, :Format) that the vimscript keymaps
-- call by name — deferring them would leave a window where Ctrl+P raises E492.
require('plugins.picker')
require('plugins.format')
-- Same reasoning: :CodeCompanionChat and friends are called by name from the
-- keymaps, so the commands have to exist from the first frame.
require('plugins.ai')

-- treesitter is split: registering the FileType autocmd is cheap and MUST
-- happen before the first FileType fires, or a file opened on the command line
-- never gets highlighted. Only the parser install scan is deferred.
require('plugins.treesitter')
require('plugins.motions')
require('plugins.rooter')

-- 4. Options, autocommands, keymaps, colours.
source('20-options.vim')
source('25-autocmds.vim')
source('30-keymap-core.vim')
source('31-keymap-ide.vim')
source('40-ui.vim')

-- 5. Machine-specific overrides, gitignored, sourced last if present.
source('90-local.vim')
