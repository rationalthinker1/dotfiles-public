-- lua/plugins/rooter.lua — project root detection, replacing airblade/vim-rooter.
--
-- vim.fs.root() has done this natively since Neovim 0.10, so the plugin was
-- carrying twenty lines of logic the runtime already has. The marker list is
-- the same one g:rooter_patterns held.
--
-- Deliberately NOT auto-chdir. vim-rooter changed the working directory on
-- every buffer switch (g:rooter_silent_chdir), which quietly breaks anything
-- holding a relative path — a running :terminal, a jobstart, an LSP started in
-- the old cwd. Neovim's LSP finds its own root from the server's root markers
-- and does not need the shell's cwd moved underneath it. Callers ask for the
-- root when they want it instead; :cd stays under your control.

local M = {}

M.markers = {
  '.git',
  'package.json',
  'composer.json',
  'Cargo.toml',
  'go.mod',
  'pyproject.toml',
}

--- The project root for a buffer, or the cwd if there is no marker above it.
--- @param bufnr? integer defaults to the current buffer
--- @return string
function M.root(bufnr)
  return vim.fs.root(bufnr or 0, M.markers) or vim.uv.cwd()
end

-- :Root prints it; :Rcd changes to it, for when you do want the old behaviour.
vim.api.nvim_create_user_command('Root', function()
  vim.print(M.root())
end, { desc = 'Print the project root' })

vim.api.nvim_create_user_command('Rcd', function()
  local root = M.root()
  vim.cmd.tcd(vim.fn.fnameescape(root))
  vim.notify('cwd -> ' .. root)
end, { desc = 'cd to the project root (tab-local)' })

return M
