-- lua/plugins/init.lua — plugin declarations, via Neovim 0.12's built-in vim.pack.
--
-- Replaces vim-plug. Three things behave differently and are worth knowing:
--
-- 1. INSTALL LOCATION is fixed: stdpath('data')/site/pack/core/opt. vim.pack
--    assumes it owns that directory entirely, so nothing else may write there.
--    The old ~/.local/share/nvim/plugged (vim-plug) is now dead and can go.
--
-- 2. LOAD TIMING. During init.lua, add() defaults to `load = false`, i.e. it
--    behaves like `:packadd!` — the plugin joins 'runtimepath' but its plugin/
--    files are not sourced until Neovim's normal packloadall at the end of
--    startup. That is exactly the ordering this config already depends on:
--    05-plugin-vars.vim runs BEFORE any plugin reads its variables, and
--    after/plugin/ runs after. vim-plug's plug#end() sourced plugin files
--    immediately, so this is if anything a cleaner fit.
--
-- 3. LOCKFILE. vim.pack writes nvim-pack-lock.json into stdpath('config'),
--    which is this directory — so it lands in the repo and IS TRACKED on
--    purpose. Upstream advises treating it as part of the config: with it
--    present every plugin installs at the pinned revision instead of drifting
--    to whatever the branch tip is. Do not edit it by hand; use
--    :lua vim.pack.update() and commit the result.
--
-- Updating:   :lua vim.pack.update()   -> review the diff buffer, :write to
--                                         confirm or :quit to discard.
-- Removing:   delete the spec here, restart, then :lua vim.pack.del({'name'}).

local function gh(repo)
  return 'https://github.com/' .. repo
end

vim.pack.add({
  --- Language support ------------------------------------------------------
  -- treesitter replaces the js/jsx/php syntax plugins with real parsers. It
  -- MUST be the `main` branch: master is frozen, incompatible with 0.12, and a
  -- completely different plugin — main is a ground-up rewrite, not an upgrade.
  { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
  -- Function/class text objects. Must ALSO be the `main` branch — it tracks
  -- nvim-treesitter's rewrite, and the master version does not work with it.
  { src = gh('nvim-treesitter/nvim-treesitter-textobjects'), version = 'main' },
  -- Kept: no treesitter parser exists for either of these filetypes.
  gh('chr4/nginx.vim'),
  gh('fladson/vim-kitty'),

  --- LSP, completion, formatting -------------------------------------------
  -- Replaces coc.nvim and its 16 extensions. See lua/plugins/lsp.lua for the
  -- extension-by-extension mapping.
  gh('mason-org/mason.nvim'),          -- installs the language servers
  gh('neovim/nvim-lspconfig'),         -- server definitions for vim.lsp.config
  gh('mason-org/mason-lspconfig.nvim'),-- bridges the two, auto-enables servers
  -- blink.cmp ships a Rust fuzzy matcher as a prebuilt binary attached to
  -- tagged releases, so it is pinned to a release tag rather than the branch
  -- tip (vim.pack has no build hook to compile it).
  --
  -- The range is '1', NOT '1.0'. vim.version.range('1.0') means 1.0.0 - 1.1.0
  -- and pinned v1.0.0 — the OLDEST 1.x — where '1' means 1.0.0 - 2.0.0 and
  -- gets the newest. Easy to get backwards; check with
  --   :lua =vim.version.range('1')
  { src = gh('saghen/blink.cmp'), version = vim.version.range('1') },
  gh('rafamadriz/friendly-snippets'),  -- LSP-format snippets; blink's source
  gh('stevearc/conform.nvim'),         -- replaces coc-prettier
  gh('lewis6991/gitsigns.nvim'),       -- replaces coc-git
  gh('github/copilot.vim'),
  -- AI chat + inline assist. This is the capability that was the actual reason
  -- to be on Neovim at all — there is no Vim equivalent. See lua/plugins/ai.lua.
  gh('nvim-lua/plenary.nvim'),         -- codecompanion dependency
  gh('olimorris/codecompanion.nvim'),

  --- Debugging -------------------------------------------------------------
  -- Adapters chosen from what ~/Projects actually contains, not from a
  -- template: JS/TS everywhere, PHP for the Laravel app, a little Python.
  -- See lua/plugins/dap.lua.
  gh('mfussenegger/nvim-dap'),
  gh('rcarriga/nvim-dap-ui'),
  gh('nvim-neotest/nvim-nio'),         -- nvim-dap-ui dependency
  gh('theHamsta/nvim-dap-virtual-text'),
  gh('jay-babu/mason-nvim-dap.nvim'),

  --- Editing ---------------------------------------------------------------
  gh('tpope/vim-surround'),
  gh('tpope/vim-repeat'),
  gh('tpope/vim-abolish'),
  gh('tpope/vim-eunuch'),
  gh('tpope/vim-sleuth'),
  gh('tpope/vim-fugitive'),
  gh('junegunn/vim-easy-align'),
  gh('windwp/nvim-ts-autotag'),
  gh('windwp/nvim-autopairs'),         -- treesitter-aware; replaces cohama/lexima.vim
  gh('AndrewRadev/switch.vim'),
  gh('ntpeters/vim-better-whitespace'),
  gh('mg979/vim-visual-multi'),
  -- (traces.vim removed: Neovim's built-in 'inccommand' does live :s preview,
  --  set in config/20-options.vim. It was pure duplication here.)
  gh('matze/vim-move'),

  --- Text objects / motions ------------------------------------------------
  gh('wellle/targets.vim'),
  gh('michaeljsmith/vim-indent-object'),
  gh('andymass/vim-matchup'),
  gh('kana/vim-smartword'),
  gh('haya14busa/vim-asterisk'),
  -- flash replaces BOTH easymotion (jump-to-label) and clever-f (f/F/t/T that
  -- repeat on the same key). One Lua plugin for two vimscript ones.
  gh('folke/flash.nvim'),

  --- Navigation / UI -------------------------------------------------------
  -- (NERDTree + nerdtree-git-plugin replaced by snacks.explorer)
  -- fzf.vim for the file-shaped pickers (files, recent, buffers, grep, marks,
  -- registers). snacks keeps the dashboard, the explorer, and the LSP-aware
  -- pickers where it is genuinely better — see lua/plugins/picker.lua.
  --
  -- junegunn/fzf here is the vim PLUGIN only. The fzf BINARY comes from zinit
  -- (~/.local/share/zinit/plugins/junegunn---fzf/bin/fzf), which is what the
  -- shell already uses for fzf-tab. vim.pack has no `do:` hook to run
  -- fzf#install(), and it does not need one.
  gh('junegunn/fzf'),
  gh('junegunn/fzf.vim'),
  gh('folke/snacks.nvim'),
  -- lualine replaces BOTH lightline and lightline-bufferline: its tabline
  -- section renders the buffer list, so the two-plugin split is not needed.
  gh('nvim-lualine/lualine.nvim'),
  gh('nvim-tree/nvim-web-devicons'),
  gh('kshenoy/vim-signature'),
  -- (mbbill/undotree replaced by Neovim 0.12's bundled nvim.undotree package,
  --  packadd'ed at the bottom of this file.)
  -- (vim-rooter removed: vim.fs.root() has done this natively since 0.10;
  --  see lua/plugins/rooter.lua, which is 20 lines and no dependency.)
  gh('simeji/winresizer'),
  gh('psliwka/vim-smoothie'),
  gh('farmergreg/vim-lastplace'),
  gh('HiPhish/rainbow-delimiters.nvim'), -- treesitter-based; replaces luochen1990/rainbow
  gh('christoomey/vim-tmux-navigator'),

  --- Colourschemes ---------------------------------------------------------
  gh('rationalthinker1/cyberpunk.vim'), -- active, see config/40-ui.vim
  gh('joshdick/onedark.vim'),
  gh('rakr/vim-one'),
  -- vim-plug's `as: 'dracula'`; vim.pack spells it `name`.
  { src = gh('dracula/vim'), name = 'dracula' },
  gh('evturn/cosmic-barf'),
  gh('micke/vim-hybrid'),
  gh('hzchirs/vim-material'),
  gh('simonsmith/material.vim'),
  gh('daylerees/colour-schemes'),
  gh('effkay/argonaut.vim'),
  { src = gh('DankNeon/vim'), name = 'dankneon' },
})

-- daylerees/colour-schemes keeps its schemes in a vim/ subdirectory. vim-plug
-- handled that with `rtp: 'vim/'`; vim.pack has no such option, so the path is
-- appended by hand. Guarded, so a failed install cannot break startup.
local colour_schemes = vim.fn.stdpath('data') .. '/site/pack/core/opt/colour-schemes/vim'
if vim.uv.fs_stat(colour_schemes) then
  vim.opt.runtimepath:append(colour_schemes)
end

-- Neovim still ships these two as optional packages (the Vim config packadd's
-- five; commenting, editorconfig and hlyank are built in here instead).
vim.cmd.packadd({ 'cfilter', bang = true })
vim.cmd.packadd({ 'nohlsearch', bang = true })
-- 0.12 ships an undo-tree viewer, so mbbill/undotree is no longer carried.
-- Same :Undotree command, so the <leader>u mapping is unchanged.
vim.cmd.packadd({ 'nvim.undotree', bang = true })
