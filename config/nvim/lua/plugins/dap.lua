-- lua/plugins/dap.lua — debugging.
--
-- ADAPTERS CHOSEN FROM ~/Projects, not from a starter template. A survey of 74
-- project directories:
--
--   TypeScript/JS   every recent project bar one — react, vite, next, nestjs,
--                   vue, react-native/expo. This is the daily driver.
--   PHP             1070 files, of which 1014 are ONE project (`portal`, a
--                   Laravel app that runs in Docker). Second-most-recent, so
--                   actively worked on.
--   Python          ~130 files, scattered. Cheap to support, so supported.
--   Rust            two projects, neither touched recently. Deliberately NOT
--                   configured: codelldb is a heavy adapter and nothing here
--                   justifies it yet.
--
-- Adapters are installed by mason (mason-nvim-dap), the same way the language
-- servers are, so there is nothing extra to provision in install.sh.

local dap = require('dap')
local dapui = require('dapui')

require('mason-nvim-dap').setup({
  ensure_installed = { 'js', 'php', 'python' },
  -- Let this module own the configurations below rather than having
  -- mason-nvim-dap write its own defaults over them.
  automatic_installation = true,
  handlers = {},
})

--==========================================================================
-- JavaScript / TypeScript
--==========================================================================
-- One adapter (vscode-js-debug) serves node, the browser and everything built
-- on them. `pwa-node` attaches to or launches a node process; `pwa-chrome`
-- drives a browser, which is what the vite/react/vue projects need.
local mason_bin = vim.fn.stdpath('data') .. '/mason/bin/'

for _, adapter in ipairs({ 'pwa-node', 'pwa-chrome' }) do
  dap.adapters[adapter] = {
    type = 'server',
    host = 'localhost',
    port = '${port}',
    executable = {
      command = mason_bin .. 'js-debug-adapter',
      args = { '${port}' },
    },
  }
end

local js_config = {
  {
    type = 'pwa-node',
    request = 'launch',
    name = 'Launch current file',
    program = '${file}',
    cwd = '${workspaceFolder}',
    -- Run TypeScript directly rather than requiring a build first.
    runtimeArgs = { '--import', 'tsx' },
    sourceMaps = true,
    protocol = 'inspector',
    skipFiles = { '<node_internals>/**', '**/node_modules/**' },
  },
  {
    type = 'pwa-node',
    request = 'attach',
    name = 'Attach to process',
    processId = require('dap.utils').pick_process,
    cwd = '${workspaceFolder}',
    sourceMaps = true,
    skipFiles = { '<node_internals>/**', '**/node_modules/**' },
  },
  {
    -- For the vite/react/vue projects: start the dev server yourself, then
    -- attach the debugger to the browser.
    type = 'pwa-chrome',
    request = 'launch',
    name = 'Launch browser against localhost:5173 (vite)',
    url = 'http://localhost:5173',
    webRoot = '${workspaceFolder}',
    sourceMaps = true,
  },
  {
    type = 'pwa-chrome',
    request = 'launch',
    name = 'Launch browser against localhost:3000 (next)',
    url = 'http://localhost:3000',
    webRoot = '${workspaceFolder}',
    sourceMaps = true,
  },
}

for _, ft in ipairs({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'vue' }) do
  dap.configurations[ft] = js_config
end

--==========================================================================
-- PHP — the `portal` Laravel app
--==========================================================================
-- Xdebug connects TO the editor rather than the other way round, so the only
-- sane configuration is "listen and wait". Nothing is launched from here.
dap.adapters.php = {
  type = 'executable',
  command = 'node',
  args = { vim.fn.stdpath('data') .. '/mason/packages/php-debug-adapter/extension/out/phpDebug.js' },
}

dap.configurations.php = {
  {
    type = 'php',
    request = 'launch',
    name = 'Listen for Xdebug',
    port = 9003,
  },
  {
    -- portal runs in Docker, so the paths Xdebug reports are container paths.
    -- Without this mapping the debugger stops on the right line of the wrong
    -- (non-existent) file and looks broken.
    type = 'php',
    request = 'launch',
    name = 'Listen for Xdebug (Docker: /var/www/html)',
    port = 9003,
    pathMappings = {
      ['/var/www/html'] = '${workspaceFolder}',
    },
  },
}

--==========================================================================
-- Python
--==========================================================================
dap.adapters.python = {
  type = 'executable',
  command = mason_bin .. 'debugpy-adapter',
}
dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = 'Launch current file',
    program = '${file}',
    cwd = '${workspaceFolder}',
    console = 'integratedTerminal',
    justMyCode = true,
  },
}

--==========================================================================
-- UI
--==========================================================================
dapui.setup({
  icons = { expanded = '▾', collapsed = '▸', current_frame = '▸' },
  layouts = {
    {
      elements = {
        { id = 'scopes', size = 0.35 },
        { id = 'breakpoints', size = 0.15 },
        { id = 'stacks', size = 0.25 },
        { id = 'watches', size = 0.25 },
      },
      size = 40,
      position = 'left',
    },
    { elements = { { id = 'repl', size = 0.5 }, { id = 'console', size = 0.5 } }, size = 10, position = 'bottom' },
  },
})

require('nvim-dap-virtual-text').setup({ commented = true })

-- Open the UI when a session starts, close it when it ends. Without this the
-- debugger works but is invisible, which reads as "DAP is broken".
dap.listeners.after.event_initialized['dapui'] = function() dapui.open() end
dap.listeners.before.event_terminated['dapui'] = function() dapui.close() end
dap.listeners.before.event_exited['dapui'] = function() dapui.close() end

-- Breakpoint signs; the gutter is already reserved ('signcolumn=yes').
vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DiagnosticError' })
vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DiagnosticWarn' })
vim.fn.sign_define('DapLogPoint', { text = '◇', texthl = 'DiagnosticInfo' })
vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DiagnosticOk', linehl = 'Visual' })
