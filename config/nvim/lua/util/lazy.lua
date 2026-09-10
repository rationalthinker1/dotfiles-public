-- lua/util/lazy.lua — defer setup work off the startup path.
--
-- WHY THIS EXISTS
--
-- vim.pack has no lazy-loading of its own: add() puts every plugin on
-- 'runtimepath' and packloadall sources all of them at the end of startup.
-- That is fine for the plugins themselves (sourcing a plugin/ file is cheap);
-- what is not fine is the *setup* work this config then does — mason scanning
-- its registry, blink building its keymap tables, lexima materialising several
-- hundred rules. Measured, that was 44ms of a 97ms startup, none of it needed
-- before the first keystroke.
--
-- So this defers the require+setup, not the plugin load. Each helper runs its
-- function exactly once, on the earliest event that could possibly need it.
--
-- The rule when choosing a trigger: pick an event that fires BEFORE the feature
-- is observable, not when it is first used. gitsigns on BufReadPre, not on the
-- first ]g. Otherwise the first invocation is a no-op and looks like a bug.

local M = {}

local group = vim.api.nvim_create_augroup('lazy_setup', { clear = true })

--- Run `fn` once, on the first of `events`.
---
--- Runs SYNCHRONOUSLY inside the autocommand, deliberately. An earlier version
--- wrapped this in vim.schedule() to let the triggering event finish first,
--- which silently broke LSP: scheduling from BufReadPre pushes the callback
--- past the FileType event, so vim.lsp.enable() had not been called yet when
--- the first buffer tried to attach. Only Copilot attached, no diagnostics
--- appeared, and nothing errored. If a future caller genuinely needs to yield,
--- give it its own vim.schedule() rather than making it the default here.
---
--- @param events string|string[]
--- @param fn fun()
--- @param opts? { pattern?: string|string[], desc?: string }
function M.on_event(events, fn, opts)
  opts = opts or {}
  local done = false
  vim.api.nvim_create_autocmd(events, {
    group = group,
    pattern = opts.pattern,
    desc = opts.desc,
    callback = function()
      if done then
        return
      end
      done = true
      fn()
    end,
  })
end

--- Run `fn` once the UI has settled — for things the user cannot observe in the
--- first few milliseconds (installers, registries, chat clients).
---
--- Listens for UIEnter AND VimEnter, whichever comes first, and runs
--- immediately if startup is already over. The earlier version keyed off
--- UIEnter alone with a `#nvim_list_uis() == 0` check to add a VimEnter
--- fallback for headless — but that check runs during init, when the UI has not
--- attached yet, so it took the headless branch even for a real session. Using
--- both events with once=true removes the guesswork entirely.
---
--- Note `-c` commands execute BEFORE VimEnter, so a `nvim --headless -c '...'`
--- one-liner still observes this as not-yet-run. That is correct behaviour, not
--- a bug: tests have to assert from inside a VimEnter callback.
---
--- @param fn fun()
function M.on_idle(fn)
  if vim.v.vim_did_enter == 1 then
    vim.schedule(fn)
    return
  end
  vim.api.nvim_create_autocmd({ 'UIEnter', 'VimEnter' }, {
    group = group,
    once = true,
    callback = function()
      vim.defer_fn(fn, 50)
    end,
  })
end

--- Register placeholder user commands that load the real thing on first use.
---
--- Solves the conflict between "the command must exist from the first frame,
--- because a keymap calls it by name" and "loading it costs 17ms nobody has
--- asked to spend". The stub replaces itself: on first invocation it deletes
--- every stub in the set, runs `loader`, then re-dispatches the original
--- command — which by then is the real one.
---
--- Deleting ALL of them, not just the invoked one, matters: `loader` typically
--- defines the whole set, and a leftover stub would shadow the real command.
---
--- @param names string[] commands to stub
--- @param loader fun() loads and configures the plugin
function M.on_cmd(names, loader)
  local loaded = false
  for _, name in ipairs(names) do
    vim.api.nvim_create_user_command(name, function(cmd)
      if not loaded then
        loaded = true
        for _, n in ipairs(names) do
          pcall(vim.api.nvim_del_user_command, n)
        end
        loader()
      end
      vim.cmd({
        cmd = name,
        args = cmd.fargs,
        bang = cmd.bang,
        range = cmd.range > 0 and { cmd.line1, cmd.line2 } or nil,
      })
    end, {
      nargs = '*',
      range = true,
      bang = true,
      desc = 'lazy-load ' .. name,
    })
  end
end

return M
