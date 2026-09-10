-- lua/plugins/ai.lua — CodeCompanion: AI chat and inline assist.
--
-- This is the one capability with no Vim equivalent, and the honest reason to
-- have migrated at all. copilot.vim (still installed) does completion only.
--
-- WHY CodeCompanion RATHER THAN avante.nvim
--
--   * Copilot works properly here. avante's Copilot support is widely reported
--     as unreliable, and Copilot is the point: it is already paid for and
--     already authenticated through copilot.vim, so this adds no API key, no
--     second subscription and no new billing surface.
--   * Far better maintained — single-digit open issues against avante's ~200.
--   * It behaves like Neovim (chat lives in a real buffer you can edit, yank
--     and save) rather than reimplementing Cursor's sidebar.
--
-- DATA EGRESS: prompts and the buffer context you attach are sent to GitHub
-- Copilot, exactly as they already are from VSCode and from copilot.vim's
-- completions. No new destination, but worth being deliberate about — use the
-- `q` (quick chat) flow rather than `<leader>ca` if a buffer should not leave
-- the machine.

local function setup()
    require('codecompanion').setup({
    adapters = {
      -- Reuses copilot.vim's existing OAuth token; nothing extra to configure.
      acp = {},
      http = {
        opts = { show_defaults = false },
        copilot = 'copilot',
      },
    },

    strategies = {
      chat = {
        adapter = 'copilot',
        roles = { llm = '  CodeCompanion', user = '  ' .. (vim.env.USER or 'me') },
        keymaps = {
          send = { modes = { n = '<CR>', i = '<C-s>' } },
          close = { modes = { n = 'q', i = '<C-c>' } },
        },
      },
      inline = { adapter = 'copilot' },
      cmd = { adapter = 'copilot' },
    },

    display = {
      chat = {
        window = { layout = 'vertical', width = 0.35 },
        show_settings = false,
      },
      -- Inline edits arrive as a diff to accept or reject rather than being
      -- applied silently — the one behaviour worth borrowing from Cursor.
      diff = { enabled = true, close_chat_at = 240, layout = 'vertical' },
    },

    opts = { log_level = 'ERROR' },
  })
end

-- The heavy part (17ms measured) waits for the first :CodeCompanion* command.
-- The commands themselves exist from the first frame, because the keymaps below
-- call them by name — see lua/util/lazy.lua for how the stubs work.
require('util.lazy').on_cmd({
  'CodeCompanion',
  'CodeCompanionChat',
  'CodeCompanionActions',
  'CodeCompanionCmd',
}, setup)

--- Keymaps.
---
--- Ctrl+Alt+I matches this machine's VSCode keybindings.json, which rebinds it
--- to workbench.panel.chat (Copilot Chat). That binding had no Vim equivalent
--- until now; see docs/VIM_KEYMAP.md, which listed it as a known gap.
local map = vim.keymap.set
map({ 'n', 'v' }, '<C-A-i>', '<cmd>CodeCompanionChat Toggle<cr>', { desc = 'AI chat' })
map({ 'n', 'v' }, '<leader>cc', '<cmd>CodeCompanionChat Toggle<cr>', { desc = 'AI chat' })
map('v', '<leader>ca', '<cmd>CodeCompanionChat Add<cr>', { desc = 'Add selection to AI chat' })
map({ 'n', 'v' }, '<leader>ci', '<cmd>CodeCompanion<cr>', { desc = 'AI inline assist' })
map({ 'n', 'v' }, '<leader>cp', '<cmd>CodeCompanionActions<cr>', { desc = 'AI action palette' })

-- `cc` as a command-line abbreviation, so :cc expands to :CodeCompanion.
vim.cmd([[cnoreabbrev <expr> cc (getcmdtype() ==# ':' && getcmdline() ==# 'cc') ? 'CodeCompanion' : 'cc']])
