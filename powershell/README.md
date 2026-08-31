# PowerShell 7 configuration

A deliberately small PowerShell counterpart to the ZSH configuration in `zsh/`. The goal
is **pwsh usable** — a native Windows shell that feels familiar when you drop into it —
not a full port of the 40-plugin ZSH setup.

## What this is

Most of the value in `zsh/` is not ZSH at all: it is the ~40 binaries zi fetches from
GitHub releases (fd, rg, bat, eza, fzf, zoxide, delta, lazygit, atuin, …). Those are
cross-platform and run natively on Windows, so this side only needs to replace the thin
shell-specific layer on top of them.

| ZSH | Here |
|---|---|
| zsh-autosuggestions, zsh-syntax-highlighting, history search | PSReadLine (ships with PS7) |
| fzf + fzf-tab | PSFzf (lazy-loaded) |
| zoxide, atuin | same binaries — both support PowerShell natively |
| powerlevel10k | oh-my-posh |
| compinit + zstyle | `Register-ArgumentCompleter`, tool-generated completers |
| zi | winget (see `install.ps1`) |
| `aliases.zsh` | `aliases.ps1` — mostly *functions*, see below |

## Install

From a native Windows PowerShell 7 session:

```powershell
pwsh -File .\powershell\install.ps1
```

Idempotent — safe to re-run. `-SkipTools` skips the winget step.

It installs modules and CLI tools, then links `$PROFILE.CurrentUserAllHosts` to
`profile.ps1`. Symlinking needs Developer Mode or an elevated shell; when unavailable it
writes a stub that dot-sources the repo copy instead, which works the same way.

## Layout

| File | Role |
|---|---|
| `profile.ps1` | Entry point. Helpers, then sources the fragments below. |
| `psreadline.ps1` | Autosuggestions, key bindings, history filtering. |
| `tools.ps1` | zoxide / atuin / PSFzf / oh-my-posh / completers. |
| `aliases.ps1` | Aliases and helper functions. |
| `local.ps1` | Machine-specific, gitignored. Copy from `local.example.ps1`. |

## Things that surprise people coming from ZSH

**Aliases cannot take arguments.** `alias ll='eza -la'` has no direct translation —
`Set-Alias` maps one name to one command, full stop. Anything carrying flags has to be a
function, which is why `aliases.ps1` is nearly all functions.

**Aliases resolve *before* functions.** PowerShell ships built-in aliases for `ls`, `cat`,
`gc`, `gl`, `h`, `ps` and more. Defining `function gc { git commit }` does nothing at all
until the built-in alias is removed — see the removal loop at the top of `aliases.ps1`.

That loop is deliberately *not* wrapped in a helper function. `cp` is an **AllScope**
alias, so every scope holds its own copy: a removal issued from inside a helper drops
only that call's copy, and the global one survives to keep shadowing `function cp` — even
with `-Scope Global`. Removal has to run in the scope the functions are defined in.

**There is no `.zshenv` / `.zshrc` split.** PowerShell has profile *variants* (per-host,
per-user) but no login/interactive distinction. Environment variables that must exist for
non-interactive sessions belong in the machine environment, not in this profile.

**There is no zi-turbo.** Nothing defers module loading for you. Two deliberate choices
keep a cold start at roughly 220ms rather than ~950ms:

- `Test-Command` enumerates `$PATH` **once** into a lookup map. The obvious
  `Get-Command -CommandType Application` rescans every `$PATH` directory on every call;
  with ~25 probes that alone measured ~615ms.
- PSFzf (~330ms) and posh-git (~290ms) are loaded on first use — the first `Ctrl+T` and
  the first `git <tab>` respectively — not at startup.

**`$PSScriptRoot` follows the symlink, not its target.** Because `$PROFILE` is a symlink
into this repo, `profile.ps1` resolves its own link before looking for the fragments;
otherwise it would search `~/.config/powershell` and silently find nothing.

## Ported helpers worth knowing

`killport` and `lsp` mirror the zsh functions of the same name. `killport 3000` kills
whatever listens on that port; `killport` with no argument opens an fzf picker over the
listening sockets (Tab to multi-select). On Windows the listener list comes from
`Get-NetTCPConnection`; under pwsh-in-WSL it falls back to `lsof`, parsed the same way
the zsh helper does.

## Shared with the ZSH side

`atuin/`, `git/aliases.gitconfig`, `ripgrep/.ripgreprc` and `mise/config.toml` are
shell-agnostic and used by both. `tools.ps1` mirrors the `FZF_*` and `BAT_THEME` values
from `.zshrc` so search behaviour matches in either shell.
