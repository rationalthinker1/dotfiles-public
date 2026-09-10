-- lua/plugins/picker.lua — snacks.nvim: picker and dashboard.
--
-- Replaces three plugins: junegunn/fzf + fzf.vim (picker) and mhinz/vim-startify
-- (start screen).
--
-- The fzf BINARY is untouched and still installed by this repo's zsh/mise setup
-- — snacks does not use it, but the shell still does. Only the Vim plugins go.
--
-- Command-for-command, what the old after/plugin/fzf.vim defined:
--
--   :ProjectFiles  -> Snacks.picker.files()      rooted at the project root
--   :Find <pat>    -> Snacks.picker.grep()       ripgrep, same ignore globs
--   :History       -> Snacks.picker.recent()
--   :Buffers       -> Snacks.picker.buffers()
--   :Commands      -> Snacks.picker.commands()
--   :Marks         -> Snacks.picker.marks()
--   :Registers     -> Snacks.picker.registers()
--
-- The keys those were bound to are unchanged; see config/31-keymap-ide.vim.

require('snacks').setup({
  picker = {
    enabled = true,
    -- fzf.vim used ctrl-t/x/r for tab/split/vsplit; keep that muscle memory
    -- rather than snacks' defaults.
    win = {
      input = {
        keys = {
          ['<C-t>'] = { 'tab', mode = { 'n', 'i' } },
          ['<C-x>'] = { 'split', mode = { 'n', 'i' } },
          ['<C-r>'] = { 'vsplit', mode = { 'n', 'i' } },
        },
      },
    },
    sources = {
      files = { hidden = true, follow = true },
      grep = { hidden = true, follow = true },
    },
  },

  -- Replaces vim-startify. Same idea: recent files, sessions, and the cwd.
  dashboard = {
    enabled = true,
    preset = {
      keys = {
        { icon = ' ', key = 'p', desc = 'Project files', action = function() Snacks.picker.files() end },
        { icon = ' ', key = 'e', desc = 'Recent files', action = function() Snacks.picker.recent() end },
        { icon = ' ', key = '/', desc = 'Find in project', action = function() Snacks.picker.grep() end },
        { icon = ' ', key = 'g', desc = 'Git status', action = ':Git' },
        { icon = ' ', key = 'n', desc = 'New file', action = ':enew' },
        { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
      },
    },
  },

  -- File explorer, replacing NERDTree + nerdtree-git-plugin. Git status marks
  -- come free, which is the whole reason nerdtree-git-plugin existed.
  explorer = { enabled = true, replace_netrw = true },

  -- Everything else snacks offers is left off: this is a picker/dashboard/
  -- explorer swap, not an invitation to adopt the whole suite. bigfile is the
  -- one exception — it disables syntax and LSP on very large files, free.
  bigfile = { enabled = true },
})

-- The file-shaped picker commands — :ProjectFiles :Find :History :Buffers
-- :Marks :Registers :Commands — belong to fzf.vim now and are defined in
-- after/plugin/fzf.vim.
--
-- They are deliberately NOT defined here as well. This file is required from
-- init.lua; after/plugin/ loads later, so whichever defines a command last
-- wins. Defining them in both places would mean fzf.vim quietly overrides
-- snacks and the snacks code would sit here looking live but never running.
--
-- snacks keeps what it is genuinely better at: the LSP-aware pickers
-- (lsp_symbols behind <leader>T, diagnostics behind Alt+0), the dashboard, and
-- the explorer below.

local function project_root()
  return require('plugins.rooter').root()
end

-- Explorer toggle, bound to Ctrl+B (VSCode sidebar) and Alt+1 (IntelliJ project
-- tool window) in config/31-keymap-ide.vim.
--
-- Reveals the current file the way the old s:NERDTreeToggle did, rather than
-- opening at the cwd root: snacks.explorer() focuses an already-open explorer,
-- so the toggle-closed half is handled explicitly.
vim.api.nvim_create_user_command('ExplorerToggle', function()
  local found = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'snacks_picker_list' then
      vim.api.nvim_win_close(win, false)
      found = true
    end
  end
  if not found then
    Snacks.explorer({ cwd = project_root() })
  end
end, { desc = 'Toggle file explorer' })
