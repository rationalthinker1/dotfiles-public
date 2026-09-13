# PowerShell 7 configuration

A PowerShell counterpart to the ZSH configuration in `config/zsh/`. The goal is **pwsh
usable** — a native Windows shell that feels familiar when you drop into it — not a full
port of the 40-plugin ZSH setup.

The alias and helper layer is now a fairly complete port (see **Ported helpers** below);
what is deliberately *not* ported is everything platform-bound: no plugin manager, no
forgit, no `apt`/`systemctl`/`dock`, no zsh language features that PowerShell lacks.

## What this is

Most of the value in `config/zsh/` is not ZSH at all: it is the ~40 binaries zi fetches from
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
| zi | winget, falling back to scoop (see `install.ps1`) |
| `aliases.zsh` | `aliases.ps1` — mostly *functions*, see below |

## Install

From a native Windows PowerShell 7 session — **not** pwsh inside WSL:

```powershell
pwsh -ExecutionPolicy Bypass -File \\wsl.localhost\<Distro>\home\<user>\.dotfiles\powershell\install.ps1
```

`-ExecutionPolicy Bypass` is required only while running the installer *from the repo*: a
UNC path is the Internet zone, so the script is refused as "not digitally signed". Once
installed, the profile runs from local disk and needs no such flag. If the repo is already
on a Windows drive, plain `pwsh -File .\powershell\install.ps1` is enough.

Idempotent — safe to re-run. `-SkipTools` skips the package-install step.

Each tool carries an id for **both** package managers: winget is tried first, scoop
picks up whatever winget could not supply (`ouch` is scoop-only; `lazygit` needs the
`extras` bucket, which is added on demand). A tool already on PATH from any source —
chocolatey, mise, a manual install — is left alone.

It installs modules and CLI tools, then **copies** the profile to
`%LOCALAPPDATA%\dotfiles\` and points `$PROFILE.CurrentUserAllHosts` there. Symlinking
needs Developer Mode or an elevated shell; when unavailable it writes a stub that
dot-sources the deployed copy instead, which works the same way.

### Why a copy, not a link into the repo

When the repo lives in WSL, pointing `$PROFILE` at it over `\\wsl.localhost\` breaks in
three separate ways — and all three are silent or misleading:

1. **`wsl --shutdown` kills the shell's config.** The profile simply cannot be read.
2. **Execution policy refuses it.** A UNC path is the *Internet* zone, so every fragment
   is rejected as "not digitally signed" no matter how much you trust the repo.
3. **It is slow.** Every shell start pays 9p/UNC round-trips for five files.

So after install nothing the profile touches lives in WSL — the fragments *and* the
shared tool configs (`atuin`, `mise`, `ripgrep`, the `ref` cheat sheets) are all copied
to local disk. `%LOCALAPPDATA%` is chosen over `Documents\PowerShell` because Documents
is often OneDrive-redirected, which adds cloud sync and placeholder files to something
that must always just be readable.

The trade-off is that repo edits are not live. After changing `powershell/*.ps1`:

```powershell
dotsync    # re-copy from the repo (needs WSL running)
reload     # apply to the current session
```

`dotsync` reads `%LOCALAPPDATA%\dotfiles\.source`, written at install time. `local.ps1`
is never overwritten — it is machine-specific and lives only in the deployed directory.

**From the WSL side, `update-all` (`maintain`) does this for you.** On WSL it refreshes an
existing deployment in phase 2, so the two shells do not drift just because you only ever
run maintenance from zsh. It performs the copy in zsh rather than calling `dotsync`,
deliberately: `dotsync` is *defined by* the profile being synced, so a bad edit that
breaks the profile also removes the one command that could repair it. It only refreshes a
deployment that already exists — creating one is `install.ps1`'s job, since linking
`$PROFILE` is part of that.

The Windows side has its own `maintain` / `update-all` whose phase 4 does the same sync
from this end — see **Maintenance** below. Whichever shell you run maintenance from, the
other one stops drifting.

## Layout

| File | Role |
|---|---|
| `profile.ps1` | Entry point. Helpers, then sources the fragments below. |
| `psreadline.ps1` | Autosuggestions, key bindings, history filtering. |
| `tools.ps1` | zoxide / atuin / PSFzf / oh-my-posh / completers, shared tool env. |
| `aliases.ps1` | Aliases and helper functions. |
| `maintain.ps1` | `maintain` / `update-all` — the six-phase maintenance run. |
| `hooks.ps1` | Directory hooks — the `chpwd` equivalent. Sourced last. |
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

**There is no zi-turbo.** Nothing defers module loading for you. Three deliberate choices
keep startup down:

- `Test-Command` enumerates `$PATH` **once** into a lookup map. The obvious
  `Get-Command -CommandType Application` rescans every `$PATH` directory on every call;
  with ~25 probes that alone measured ~615ms.
- PSFzf (~330ms) and posh-git (~290ms) are loaded on first use — the first `Ctrl+T` and
  the first `git <tab>` respectively — not at startup.
- `Get-ToolInitScript` caches `zoxide init` / `atuin init` / `oh-my-posh init` output,
  keyed on the binary's mtime+size, so an upgrade invalidates it automatically. Without
  it every shell start pays a process spawn per tool.

Measured on this machine: **~490ms** of profile work (802ms median for a full
`pwsh -Command`, of which ~308ms is process start). That is up from the ~220ms this file
used to quote — the tool set and function count have both grown since, and installing
scoop added a shim directory that the `$PATH` map must enumerate. The cause was not
isolated, so treat 490ms as a current measurement, not a budget.

**`$PSScriptRoot` follows the symlink, not its target.** `$PROFILE` is a link (or stub)
pointing at the deployed `profile.ps1`, so the file resolves its own link before looking
for the fragments; otherwise it searches beside the *link* and silently finds nothing.

**`ResolveLinkTarget($true)` is wrong for UNC targets — do not "simplify" back to it.**
The `$true` overload means "return the final target" and looks like the obviously correct
call. For a link whose target is a UNC path it splices the raw reparse data
(`\??\UNC\server\share\…`) onto the link's *own* directory:

```
target:   \\wsl.localhost\Ubuntu\home\u\.dotfiles\powershell\profile.ps1
returned: \\wsl.localhost\Ubuntu\home\u\.dotfiles\UNC\wsl.localhost\…\profile.ps1
```

`ProfileDir` then points somewhere that exists in name only, every fragment `Test-Path`
fails, and the profile completes having done **nothing** — no aliases, no prompt, no
keybindings, and not a word logged. `LinkTarget` and `ResolveLinkTarget($false)` both
return the correct path, so `profile.ps1` tries the raw target first and **verifies each
candidate** against a known sibling file before trusting it. It also warns when zero
fragments load, because that silence is what made the bug invisible.

**`Get-Module -ListAvailable <Name>` is unreliable until the module analysis cache is
warm.** It can return nothing for a module that is definitely installed — lookup by
explicit *path* still works, and a full unfiltered enumeration repopulates the cache.
OneDrive-redirected `Documents` (where user-scope modules land) widens that window.
Practical effect: on a cold cache the PSFzf and posh-git gates in `tools.ps1` can
false-negative, so `Ctrl+T` or `git <tab>` quietly do not wire up. It self-heals on a
later shell start.

**There is no `chpwd`, but there is an equivalent.**
`$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction` fires on every
location change, including zoxide's `cd`. `hooks.ps1` uses it for the two things
`config/zsh/hooks.zsh` does: auto-activating a `.venv` and trust-checked `.dirrc`
sourcing. Handlers are held in a list and dispatched inside a `try`, so one bad
`.dirrc.ps1` cannot break every subsequent `cd`.

## Ported helpers worth knowing

`killport` and `lsp` mirror the zsh functions of the same name. `killport 3000` kills
whatever listens on that port; `killport` with no argument opens an fzf picker over the
listening sockets (Tab to multi-select). On Windows the listener list comes from
`Get-NetTCPConnection`; under pwsh-in-WSL it falls back to `lsof`, parsed the same way
the zsh helper does. `killp` is the process-wide counterpart.

`ref` reads the same `config/zsh/references/*.md` cheat sheets the zsh function does —
`ref rg`, `ref -e jq`, `ref --list`.

`ghard` exists here, unlike in earlier versions, because `git_reset` was ported with it:
the confirmation prompt and dropped-commit summary are the point, so the guard came over
rather than the bare `git reset --hard`.

`extract` prefers `ouch` and otherwise uses the **Windows** toolbox — `tar` (ships with
Windows 10+), `Expand-Archive`, then 7-Zip — not the Unix per-format chain from zsh.

`genpass` uses .NET's CSPRNG rather than shelling out to `openssl`, which is not standard
on Windows.

The **npm/yarn/pnpm** aliases came over wholesale (`ni nid nig nrd nrb nrs nrt nrl nrf
nci ncc nou nup`, `yi yag yrm yup yui yout ycc yd yb`, `pi pna pnad pr`, `pkg pkgj`), plus
`run`, which picks the package manager from the lock file — bun first, since bun projects
often still carry a stale `package-lock.json`. Note `ni` is a **built-in alias for
`New-Item`** and had to be added to the removal loop; anything similar must be too.

Also ported: `serve` `note` `dirsize` `replace-in-files` `unzipd` `bak` `bakt` `psg`
`hgrep` `ports` `myip_local`, the `llt`/`lllt`/`llllt` tree ladder and `l.`, and the git
helpers `gse` `git-clone` `gpuf` `cc`.

`dotsync` re-copies the repo into the deployed directory (see **Why a copy** above);
`dotfiles` cd's to the git repo when WSL is up, and warns and opens the deployed copy when
it is not.

**Deliberately absent:** `gco` and `grs` (forgit owns those names in zsh — see the reserved
list at `config/zsh/aliases.zsh:886-906`), and everything Linux-only — `dock`, `zi-audit`,
the `apt` and `systemctl` blocks, suffix and global aliases (no PowerShell
equivalent exists), and the WSL `subl`/`code` shims, which are unnecessary because both
binaries are already on PATH natively.

## Maintenance — `maintain` (alias `update-all`)

`maintain.ps1` is the pwsh counterpart of `config/zsh/functions/maintain.zsh`. Same name,
same alias, same contract; a different six phases, because apt, snap, flatpak and zinit do
not exist here.

| Phase | What runs |
|---|---|
| 1. Package managers | `winget upgrade --all --include-unknown`, `scoop update`/`update *`/`cleanup *`, `choco upgrade all` |
| 2. Runtimes & modules | PowerShell modules, `mise upgrade`, `rustup update`, `gh extension upgrade --all`, `claude update` |
| 3. Global packages | npm, pnpm, uv (self + tools), pipx, `cargo install-update`, `atuin sync` |
| 4. Dotfiles deployment | `dotsync` — refresh `%LOCALAPPDATA%\dotfiles` from the repo |
| 5. Cleanup & caches | scoop/npm/pnpm/yarn/uv/pip/go caches, `%TEMP%` entries older than 30 days |
| 6. Health & integrity | PATH shadows, dead PATH entries, pending reboot, disk report |

```powershell
maintain              # or: update-all
maintain -Install     # run install.ps1 first (needs WSL up — the repo lives there)
maintain -Elevate     # one UAC prompt for winget + chocolatey, no question asked
maintain -NoElevate   # never elevate (chocolatey is then skipped)
maintain -SkipCleanup # skip phase 5, the only phase that deletes anything
maintain -Help
```

### One UAC prompt, not one per package

Unelevated, `winget upgrade --all` prints *"The installer will request to run as
administrator. Expect a prompt."* against every machine-scope package, and you sit
through a dialog for each.

**Windows has no sudo credential cache.** The zsh side primes `sudo -v` once and holds it
with a keep-alive loop; there is no equivalent here. UAC consent is granted per *process*,
at creation, and cannot be held or renewed. Microsoft's `sudo.exe` (Windows 11 24H2+,
off by default behind Settings ▸ System ▸ For developers) is a launcher, not a cache — it
prompts every invocation. Only third-party gsudo has a real cache.

So the only way to collapse N prompts into one is to elevate **one** process and do all
the privileged work inside it. That is what phase 1 does: winget and chocolatey are
collected into a single elevated pwsh child — one UAC dialog — which tees its output so
you watch it live and the parent replays the capture into the transcript. Per-step exit
codes come back through a JSON file, because one process has only one exit code.

The dialog is raised **before** the phases start, alongside the `-Install` question, so it
never appears minutes into a run you walked away from. It is the one prompt here that
defaults to **Y**: declining does not save you a dialog, it multiplies one into
one-per-package. Cancelling the UAC dialog is treated as an answer, not a failure — the
same commands then run unelevated.

**scoop is never elevated.** It is a per-user install by design; run as admin it writes
files owned by the admin token into `~\scoop`, and later user-mode updates fail on them.
That is why elevation is scoped to winget and chocolatey rather than applied to the whole
run — and why `maintain` should not be launched from an already-elevated shell if you can
avoid it.

**scoop runs concurrently with the elevated window**, rather than waiting behind it. The
elevated child is started with `-PassThru` and *not* `-Wait`; scoop's bucket refresh and
app upgrades run in the parent meanwhile, and the wait happens after. Phase 1 then costs
roughly the longer of the two instead of their sum — measured at 2.20s vs 2.89s on a
synthetic 2s/0.9s split, i.e. scoop's time is absorbed almost entirely.

That overlap is safe because the two managers share nothing: winget writes Program Files
/ WindowsApps and the machine PATH, scoop writes `~\scoop` and the user PATH — different
stores, different registry values, no common lock. The one shared resource that could
bite is Windows Installer's global `_MSIExecute` mutex (only one MSI machine-wide; the
loser gets 1618, "another installation is already in progress"). winget hits MSIs
constantly, scoop almost never — all 23 apps installed here are portable archives — so
this is safe in practice rather than by guarantee. If it ever fires it surfaces as an
ordinary failed scoop step, recorded not fatal, and a re-run clears it.

What it inherits from the zsh version is the contract, not the step list: a missing tool
is skipped with a reason, a failing step is **recorded and never fatal**, and the run ends
with reclaimed disk plus every failure, returning `$false` if any occurred. Each run is
transcribed to `%LOCALAPPDATA%\dotfiles\logs\maintain\` (10 kept).

Three details worth knowing:

- **Phase 4 is the one with no zsh equivalent**, and the reason this exists on Windows at
  all: the profile is a *copy*, so repo edits are invisible until something syncs them.
  From WSL, `update-all`'s phase 2 does it; this does it from the Windows side. It calls
  `dotsync` rather than re-implementing the copy — the zsh side's reason for not doing
  that (dotsync is defined by the profile it syncs) does not apply, since `maintain`
  itself lives in that same profile.
- **`-Install` shells out with `-ExecutionPolicy Bypass`.** It runs the *repo* copy of
  `install.ps1`, which is reached over `\\wsl.localhost\` — the Internet zone, so without
  the flag pwsh refuses it as "not digitally signed". Same flag and same reason as the
  install command in **Install** above; you do not pass it yourself.
- **winget's exit code is not a boolean.** `0x8A150014` (nothing matched) and `0x8A15002B`
  (nothing applicable) are routine and are allowlisted; everything else, including
  `0x8A15002C` (some package in `--all` failed), is reported as a failure.
- **Only user-installed modules are updated.** `Get-Module -ListAvailable` also returns the
  copy bundled with pwsh and the Windows PowerShell 5.1 copy under `Program
  Files\WindowsPowerShell\Modules`; `Update-PSResource -Scope CurrentUser` cannot touch
  either and fails on both. So the *package manager* is asked what it installed
  (`Get-PSResource` / `Get-InstalledModule`), not the module loader. Without that,
  PSReadLine reports a failure on every stock machine.

The phase-6 PATH audit is read-only and mirrors `maintain::path_dupes` — it prints
commands that resolve from more than one PATH directory (the classic case: a Store
execution-alias stub or an old chocolatey shim winning over the real install) and never
reorders or deletes anything. Its allowlist starts empty on purpose; add entries with
their reason attached as you verify each shadow is deliberate.

## Shared with the ZSH side

`config/atuin/`, `config/git/aliases.gitconfig`, `config/ripgrep/.ripgreprc`,
`config/mise/config.toml` and `config/zsh/references/` are shell-agnostic and used by
both. `tools.ps1` mirrors the `FZF_*` and `BAT_THEME` values from `.zshrc` so search
behaviour matches in either shell.

"Shared" means *same tracked source*, not same file at runtime. zsh reads these in place;
Windows reads the copies under `%LOCALAPPDATA%\dotfiles\config\` that `install.ps1` and
`dotsync` deploy — otherwise the profile would reach into WSL again and reintroduce every
problem the copy exists to avoid. **They therefore drift until you run `dotsync`.**

Sharing a *file* is not enough on its own either: atuin and mise look in `%APPDATA%` on
Windows, so `tools.ps1` points `ATUIN_CONFIG_DIR` and `MISE_CONFIG_FILE` at the deployed
copies the way `.zshenv` points zsh at the tracked ones. Without that the two shells read
different configs while appearing to share one.

The rest of `.zshenv`'s XDG remapping (`NPM_CONFIG_*`, `GOPATH`, `PYTHONSTARTUP`, …) is
deliberately **not** mirrored — that is Unix hygiene, and forcing XDG paths on Windows
tools fights the platform.
