# Zinit Update Mechanics — Why the Wipe Exists, and When It Is Actually Needed

**Last Updated:** 2026-08-31
**Verified against:** zinit v3.15.3, WSL 2, 53 registered plugins
**Status:** empirical — every claim below was measured on this machine, not inferred

---

## Why this document exists

`config/zsh/functions/zinit-reset` deletes every installed plugin (~400MB) and reinstalls from
scratch. That is expensive, and the obvious question recurs every few months:

> Can't we just check which packages changed and update only those?

The answer is **partly yes, and the intuitive version of it is wrong in a way that
silently reintroduces the original bug.** This file records the measurements so the
question does not have to be re-derived from scratch again.

The short version: the wipe was never about *download volume*. `zi update` already
skips packages that have not moved. The wipe exists to rewrite **ice metadata**, and
only one of the available update paths can do that — incompletely.

---

## Table of Contents

1. [How ice metadata is stored](#how-ice-metadata-is-stored)
2. [Verified behaviour of each update path](#verified-behaviour-of-each-update-path)
3. [The decisive experiment](#the-decisive-experiment)
4. [What this means for maintenance](#what-this-means-for-maintenance)
5. [Traps](#traps)
6. [Not tested](#not-tested)
7. [Reproducing any of this](#reproducing-any-of-this)

---

## How ice metadata is stored

Each installed plugin carries `<plugin-dir>/._zinit/` — **one plain text file per ice**,
named after the ice, containing its value:

```
plugins/BurntSushi---ripgrep/._zinit/
  as = command      from = gh-r      pick = */rg      wait = 2      nocompile = !
  is_release = /burntsushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-….tar.gz
  url        = https://github.com/burntsushi/ripgrep/releases/download/15.2.0/….tar.gz
  teleid     = BurntSushi/ripgrep
```

Three properties follow, all confirmed:

- **It is externally writable.** Hand-copying the files back in is fully honoured — after
  a manual restore, `zi update` immediately reported
  `[gh-r] latest version (v0.17.0) already installed`. No checksums, no index, no locking.
- **`is_release` / `url` are zinit's own bookkeeping**, not declared ices. They hold the
  installed version, which is why a "compare installed vs latest" script is unnecessary —
  see below.
- **Values are normalised.** `.zshrc` declares `as'program'`; the file stores
  `as = command` (they are synonyms). **Never text-diff declared ices against saved ices** —
  it reports drift that is not there.

**Loading does not read `._zinit/` at all.** With the directory deleted outright, both a
gh-r plugin (`hexyl`) and a git plugin (`dua-cli`) still loaded and resolved to the correct
binary. Your interactive shells are built from `.zshrc` and are never drifted. Drift is
exclusively an *update-path* phenomenon.

---

## Verified behaviour of each update path

Method: instrument a plugin's saved `wait` ice to a value the config does not declare
(`99` vs the declared `2`), run the path, read the file back.

| Path | Plugin loaded in that shell? | Refreshes `._zinit/`? |
|------|------------------------------|------------------------|
| `zi update --all --parallel` | yes (fully bursted) | **No** — stayed `99` |
| `zi update <plugin>` | no | **No** — stayed `99` |
| `zi update <plugin>` | yes | **Yes** — `99` → `2`, for **both** git and gh-r |

Bulk mode dispatches each plugin into a background subshell
(`.zinit-update-or-status update "$user" "$plugin" &`) while walking the *plugins
directory*, so it has no session ice context and bursting first does not help it. This is
the behaviour the `zinit-reset` header describes — and it is accurate **for `--all`**, but
too broad as a statement about `zi update` in general.

Supporting facts:

- `zsh -ic '@zinit-scheduler burst'` registers **all 53 plugins synchronously in ~0.66s**
  (nothing to download). No pty needed. `$ZINIT_REGISTERED_PLUGINS` afterwards *is* the
  declared plugin list — so the orphan set (directories not in that array) comes free, and
  no `.zshrc` parsing is ever required.
- A targeted update costs **~0.65s/plugin**, so a serial loop over all 53 is ~40s.
- **Bulk update genuinely updates.** With `hexyl` faked back to `v0.15.0`, a plain
  non-interactive `zi update --all --parallel --no-pager` logged
  `Requesting hexyl-v0.17.0-… Current version: v0.15.0`, downloaded, extracted, and
  corrected `is_release`. The ordinary "just update everything" path needs no burst and no
  special handling.

---

## The decisive experiment

The failure that motivated all of this — *"packages started compiling code and downloading
a binary, and it didn't follow the ice instructions"* — is a **migration from
build-from-source to prebuilt** (what happened to qsv and yazi). That is, by definition, a
change where ices are **removed** from the declaration.

Reproduced deliberately on `dua-cli`, from an identical starting state for both methods:

- **Config:** `from'gh-r'` + `bpick'dua-*-x86_64-unknown-linux-musl.tar.gz'`, `pick'*/dua'`
- **Saved `._zinit/`:** git-era ices — `atclone` build hook, `atpull'%atclone'`,
  `depth'1'`, `pick'dua'`, no `from`
- **On disk:** a real git clone with `.git`

(The `cargo build` in `atclone` was swapped for a marker command so the signal was free
rather than a one-minute compile.)

| | **A — wipe + reinstall** | **B — burst + targeted update** |
|---|---|---|
| stale `atclone` executed | no | **YES** |
| `atclone` in metadata after | gone | **still there** |
| `atpull` after | gone | **still there** |
| `depth'1'` (dropped from config) | gone | **still there** |
| old `.git` clone | removed | **still there** |
| new ices (`from`, `bpick`, `pick`) | correct | correct |
| net result | clean gh-r install | **downloaded the binary AND ran the build hook** |

### The conclusion that must not be lost

> **A targeted `zi update` MERGES ices. It writes new and changed keys, but never deletes
> keys the config has dropped — and never cleans up the previous install's shape.**

So every removed ice survives and keeps firing forever. The bottom-right cell above *is*
the original bug, reproduced exactly. **The drift class that actually bites — switching a
plugin to a prebuilt binary — is precisely the class a targeted update cannot repair.**

Any future proposal of the form "just run `zi update` per plugin instead of wiping" is
wrong for this reason. It fixes changed values and looks like it works, right up until
someone removes an ice.

---

## What this means for maintenance

Drift is possible **only when a plugin's declaration in `.zshrc` changes.** If a
declaration is untouched since install, its saved ices are correct by construction, and
bulk update's inability to refresh them is irrelevant.

### What maintain actually does now (implemented)

Before this, the step was all-or-nothing and the "nothing" was the default: `run_zinit`
defaulted to 0 and the prompt defaulted to N, so an ordinary `update-all` run **never
touched the plugins at all**. The only way to update was to accept the ~400MB wipe.

The default path now has three parts, and only the wipe stays opt-in:

1. `zi update --all --parallel --no-pager` — correct *and* fast for every plugin whose
   declaration is unchanged since install, because its saved ices then match `.zshrc` by
   construction. `--no-pager` is mandatory or it blocks forever on a pipe.
2. `zi-audit --ids` — names the plugins whose on-disk metadata no longer matches `.zshrc`.
3. Those get wiped and reinstalled via `zsh -ic '@zinit-scheduler burst'`, then re-audited.

`--zinit` remains the full-wipe hammer. This replaces the earlier git-stamp/hunk-mapping
idea: `zi-audit` detects drift directly and more precisely, with no stamp file.

**Why `--ids` excludes some findings.** `unknown-ice` and `pick-no-match` are *declaration*
bugs — a reinstall cannot fix them, so feeding them to the repair loop would reinstall the
same plugin on every run, forever. `--ids` reports only findings a wipe actually repairs;
the rest surface in the normal report for a human to fix in `.zshrc`.

**Blind spot.** `zi-audit` compares ice **names**, not values, because declared values
contain unevaluated command substitution (`bpick"$(gh_asset …)"`) that cannot be compared
against the stored, evaluated result — and `as'program'` normalises to `command`. Adding or
removing an ice is caught automatically; **editing one in place is not** — for that, run
`--zinit`, or wipe that plugin by hand.

Orphan deletion is deliberately *not* automated: a plugin temporarily commented out of
`.zshrc` would be destroyed. `zi-audit` reports orphans; removing them stays manual.

### "Does bulk update compile things and download packages?"

Yes to both, and that is not the bug. Keep these separate:

- **Downloading is the point.** A new upstream version means a download. Verified: a plugin
  faked back to an older release was detected and upgraded by a plain bulk run.
- **Compiling is declared.** Any plugin with `atpull'%atclone'` over a build command
  rebuilds when upstream moves. As of this writing that is `junegunn/fzf`
  (`./install --bin`) and `tj/git-extras` (`make … install`). That is `.zshrc` asking for
  it. (`Byron/dua-cli` was on this list until it moved to `gh-r` — the very migration the
  experiment below models.)
- **The bug was doing the *wrong* thing** — compiling from source while the config declared
  a prebuilt binary, and doing both in one run. That happens only when `._zinit/` disagrees
  with `.zshrc`.

So the objective is never "never build, never download". It is **"do exactly what `.zshrc`
declares"**. Bulk update satisfies that if and only if the saved ices match — and it stops
satisfying it, silently, the moment a declaration is edited. Bulk update is not
self-correcting: it will reproduce a drifted plugin's wrong behaviour on every run until
that plugin is wiped.

To check whether this machine is currently drifted, look for the contradictory shape —
a build hook alongside `from = gh-r`, or a `.git` clone inside a `from = gh-r` plugin:

```zsh
ZH="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
for d in "${ZH}/plugins/"*/; do
    [[ -d "${d}/._zinit" ]] || continue
    local from="$(<"${d}/._zinit/from")" 2>/dev/null
    [[ "${from}" == "gh-r" && -d "${d}/.git" ]] && print -r -- "drifted: ${d:t}"
done
```

### Bulk update against complex plugins (measured)

Six plugins with non-trivial ices were faked back one release, then a single
`zi update --all --parallel --no-pager` was run non-interactively:

| plugin | shape | result |
|--------|-------|--------|
| `dathere/qsv` | computed `bpick`, `atclone'rm -rf ._backup; …'` | upgraded; `._backup` pruned by its atclone |
| `sxyazi/yazi` | computed `bpick`, `pick'*/yazi'` | upgraded, binary executable |
| `atuinsh/atuin` | `atclone` generates `init.zsh` + `_atuin`, `mv`, `src` | upgraded; **both artifacts regenerated** |
| `ajeetdsouza/zoxide` | `atclone` generates `init.zsh`, `src` | upgraded; artifact regenerated |
| `cloudflare/cloudflared` | `mv`, `atclone'… chmod +x'` | upgraded, executable |
| `jqlang/jq` | `extract''` + `mv'jq* -> jq'` | **upgraded but left NON-EXECUTABLE** |

So bulk update handles computed `bpick`, `mv`, `src` and — importantly — **does re-run
`atpull'%atclone'` hooks**, regenerating `init.zsh` and completion files correctly. It is
sound for ordinary updating when the saved ices are right.

#### Bug: `extract''` loses the executable bit on update

`jq` declares `extract''` to skip extraction (the asset is a bare binary). `ziextract` is
what normally performs the `chmod +x` — so with extraction disabled nothing sets it.
Measured: **fresh install → `-rwxr-xr-x`; after an update → `-rw-r--r--`.** The plugin
silently stops working the next time jq cuts a release.

`cloudflare/cloudflared` has the same bare-binary shape and is unaffected only because its
declaration carries an explicit `atclone'… chmod +x cloudflared'`.

**Fixed** (2026-08-31) — `jq` now carries `atclone'chmod +x jq' atpull'%atclone'`. Verified:
faked back to jq-1.7.1, updated to jq-1.8.2, and the binary stayed `-rwxr-xr-x`.

#### Bug: an unrecognised ice silently discards every ice after it

`zinit.zsh:2335` parses the ice list as:

```zsh
[[ $bit = (#b)(--|)(${~ZINIT[ice-list]}${~exts})(*) ]] && ZINIT_ICES[…]+="…" || break
```

The `|| break` means an unknown ice does not get skipped — it **aborts the parse loop**,
dropping itself *and everything declared after it*. `sbin` is not in zinit's core
`ice-list`; it comes from `zinit-annex-bin-gem-node` via `${~exts}`. With no annex
installed, every ice following `sbin` in a declaration is silently lost:

| plugin | declared | actually registered | lost |
|--------|----------|---------------------|------|
| `eza-community/eza` | `lucid from as sbin atclone nocompile` | `lucid from as` | `sbin`, **`atclone`**, `nocompile` |
| `ast-grep/ast-grep` | `wait lucid from as sbin nocompile` | `wait lucid from as` | `sbin`, `nocompile` |

Consequence: eza never gets its `_eza` completions, and ast-grep is byte-compiled despite
`nocompile'!'`. Both binaries still work, because `as'program'` puts the directory on PATH.

**This is not drift, and a wipe does not fix it** — verified by wiping eza and reinstalling
from scratch: the ices came back missing exactly the same way. Only editing the declaration
fixes it.

**Fixed** (2026-08-31) — `sbin` dropped from both declarations rather than installing the
annex, since `as'program'` already puts the plugin dir on PATH and both assets drop their
binaries at the root (`eza`; `ast-grep` + `sg`). `nocompile'!'` now registers on both.
eza's `atclone'cp -vf completions/eza.zsh _eza'` was removed rather than revived: the
binary tarball has no `completions/` directory, so it could never have worked — upstream
ships completions as a separate `completions-<ver>.tar.gz` asset. Wiring those up is
possible but is a separate change, and eza currently has no zsh completions.

The general lesson: **ice order is load-bearing.** Put anything annex-provided last, or a
typo'd ice will silently eat the rest of the line.

### Ideas that were evaluated and rejected

| Idea | Why not |
|------|---------|
| Script comparing installed vs latest versions | Solves a non-problem — `zi update` already skips what has not moved (`latest version already installed`). Downloading was never the waste. |
| Diff declared ices against saved ices | Value normalisation (`as'program'` → `command`) produces false drift. |
| Delete `._zinit/` and let it regenerate | It does not regenerate on load. On gh-r it breaks `zi update` outright (`fatal: not a git repository`, since `from`/`is_release` are gone). |
| Burst, then bulk `zi update --all --parallel` | Bulk never refreshes ices regardless of what is loaded. Measured. |
| Serial targeted update over every plugin | ~40s and refreshes changed ices, but **cannot remove dropped ices** — reintroduces the original bug. |

---

## The audit script

`config/zsh/functions/zi-audit.zsh` defines `zi-audit`, which encodes every failure mode in this
document as a check. Run it from an interactive shell (it needs zinit loaded):

```zsh
zi-audit            # audit every declared plugin
zi-audit --quiet    # only plugins with findings
zi-audit sharkdp/fd # one plugin
```

It is read-only and exits non-zero on any finding. Two design points matter:

- It validates ice names against zinit's **own** `${ZINIT[ice-list]}` at runtime, not a
  hardcoded copy, so it stays correct if an annex is ever installed to extend that list.
- It compares ice **names only**, never values — which sidesteps zinit's value
  normalisation (`as'program'` is stored as `as = command`) that makes a naive
  declared-vs-saved text diff report drift that is not there.

Declarations are tokenised with `${(z)…}`, zsh's own shell-word splitter, because ice
values routinely contain spaces, quotes and command substitution (`mv'jq* -> jq'`,
`bpick"$(gh_asset …)"`). A regex cannot survive those.

### Registration vs. effect

Two different questions, and the script answers both:

- **Was the ice registered?** `unknown-ice`, `ice-dropped`, `ice-stale` — this is the
  silent-truncation class (`sbin`, `branch`).
- **Did the ice actually do anything?** `mv`/`cp-not-applied` (the `A -> B` destination
  exists), `bpick-mismatch` (the downloaded asset matches the pattern), `ver-not-applied`
  (HEAD is on the named ref), `depth-not-applied` (the clone is really shallow),
  `nocompile-ignored` (no `.zwc` was produced), plus `pick`/`src`/payload.

Registration does not imply effect, so both are needed. Each effect check was verified by
fault injection — planting a `.zwc` in a `nocompile` plugin, renaming an `mv` destination
away, and setting `ver'no-such-branch'` were all caught.

### Three false positives it must suppress (each cost real debugging)

- **`wait` is written for every plugin**, empty when turbo was not requested. The file is
  **1 byte — a bare newline** — so `[[ -s ]]` calls it non-empty. Use `$(<file)`, which
  strips the trailing newline and yields `""`.
- **A failed `pick` is usually not fatal.** `as'command'` puts the plugin directory on
  PATH by itself, so the binary still resolves and the pick is merely a dead no-op.
- **zinit lowercases the whole URL** before storing it — which is why `Byron/dua-cli` is
  recorded as `byron/dua-cli`. Comparing a stored asset name against `bpick` therefore has
  to be case-insensitive, or every mixed-case asset (`gping-Linux-musl-…`) reports a
  phantom mismatch.

### Where .zwc files must live

Not a preference — a constraint. **zsh only ever looks for `<source>.zwc`, adjacent to the
file being sourced**; there is no search path for wordcode. Demonstrated: a `.zwc` next to
its source (and newer) is used in place of the source, and the *same* file moved into a
cache directory is silently ignored. So `.zwc` cannot be relocated to `$XDG_CACHE_HOME` —
it would just never be found, and the optimisation would quietly do nothing. The one `.zwc`
that does live under the cache dir is the compdump's, for exactly the same reason: its
source lives there.

A corollary worth remembering: a `.zwc` **newer** than its source shadows it. That is why
`compile_if_needed` (.zshrc) and maintain's phase-5 step both gate on mtime.

### Findings on this machine (2026-08-31, 51 plugins)

| plugin | finding | impact |
|--------|---------|--------|
| `z-shell/zsh-fancy-completions` | `branch'main'` unknown → swallows `atpull'zi creinstall -q .'` | **real** — completions never reinstall on update |
| `wfxr/forgit` | `branch'main'` unknown, nothing after it | cosmetic — tracks the default branch, which is `main` |
| `Freed-Wu/fzf-tab-source` | `branch'main'` unknown, nothing after it | cosmetic — same |
| `muesli/duf` | `pick='*/duf'` matches nothing | none — binary extracts flat, resolves via `as'command'` |
| `ClementTsang/bottom` | `pick='*/btm'` matches nothing | none — same |

**`branch` is not an ice in zinit v3.15.3** — it is absent from `${ZINIT[ice-list]}` and
`ICE[branch]` appears nowhere in the source. `ver'…'` is the real ice for pinning a git
ref; `zinit-install.zsh:462` runs `git checkout "${ICE[ver]}"` for it.

**All five fixed** (2026-08-31): the three `branch'main'` became `ver'main'`, and the two
`pick='*/…'` became `pick='…'` to match the flat extraction. The five plugins were wiped
and reinstalled (a declaration change requires a wipe — an update only merges). Verified:
`atpull` now registers on zsh-fancy-completions, all three git plugins check out `main`
cleanly, `btm`/`duf`/forgit all load, and `zi-audit` reports **51 plugins, all clean**.

## Which ices can be dropped ("less is more")

Dropping an ice is **not free**: it changes the declaration, so the plugin needs a wipe to
clear the now-stale metadata (an update only merges). That asymmetry is the whole
cost/benefit — target ices that are provably dead *and* used on few plugins.

| ice | verdict | why |
|-----|---------|-----|
| `lucid` with no `wait` | **dropped** (2 sites) | `lucid` only suppresses `zle -M "Loaded <id>"` (zinit.zsh:2484), emitted for TURBO loads. With no `wait` the plugin loads during .zshrc, before zle exists — nothing to suppress. |
| `depth` on a `from'gh-r'` plugin | already clean (0) | `depth` is referenced only inside `:zinit-git-clone()` (zinit-install.zsh:433). Dead where there is no clone. |
| `nocompile` on gh-r `as'command'` | **KEEP** (28 sites) | see below |
| `atpull` with no `atclone` | not a finding | only `atpull'%atclone'` needs an `atclone`; a literal `atpull'zi creinstall -q .'` is valid alone. |
| `as'command'` vs `as'program'` | style only | exact synonyms — zinit stores both as `as = command`. Currently 25 vs 18; standardising removes nothing. |

### Why `nocompile` stays, despite looking like the big win

It is 28 sites and looks obviously dead. It is not safely droppable, and the reasoning is
easy to get wrong — two plausible-looking source sites point the wrong way:

- `zinit-install.zsh:977` and `:1068` gate compilation on `nocompile` **without** checking
  `as` — but both live in `.zinit-download-snippet()`, the SNIPPET path, which never runs
  for `zi load`.
- `zinit-autoload.zsh:1048` *does* test `${ICE[as]} != command` — but it is inside
  `.zinit-clear-completions()`, not the compile path either.

The real gate is `zinit-install.zsh:2384`, in `∞zinit-compile-plugin-hook`, which fires off
the atclone/atpull hook; `.zinit-compile-plugin` then scans the plugin **root** for
`*.plugin.zsh` / `*.zsh` / `init.zsh`. A gh-r tarball drops only a binary there, so nothing
matches and nothing compiles — confirmed by removing `nocompile'!'` from hexyl, wiping and
reinstalling: zero `.zwc`, no error, correct 0755.

But that is an **emergent property of the current asset layout, not a guarantee**. Any
upstream release that starts shipping a root-level `.zsh` (completions, an init file) would
silently begin byte-compiling it. The ice costs nothing to keep and 28 reinstalls to
remove. Keep it.

## Traps

- **`zi update` pages by default.** In a script with no stdin it blocks forever — this hung
  a run here for ten minutes with no output. Always pass `--no-pager`, and set
  `PAGER=cat GIT_PAGER=cat` as a second line of defence.
- **`zi delete --clean` deletes *currently-not-loaded* plugins.** After a partial burst that
  means live plugins. Only use it after verifying the registered count looks right, or
  derive the orphan set yourself from `$ZINIT_REGISTERED_PLUGINS`.
- **A burst can be incomplete.** In a pty session the scheduler trickles plugins in over
  several seconds; one measurement caught it at 15 of 53 and produced a misleading result.
  Check `${#ZINIT_REGISTERED_PLUGINS[@]}` before trusting anything derived from it.
  (`zsh -ic` is synchronous and does not have this problem.)
- **gh-r updates leave `._backup/<old-extraction>/` behind**, which accumulates. This is
  exactly why the qsv declaration carries `atclone'rm -rf ._backup; …'`.

---

## Not tested

- **Snippets.** Everything above concerns plugins.
- **Whether a hunk→plugin-id mapping can be made reliable.** It should fail conservative:
  if a change cannot be attributed to a specific plugin, wipe everything.
- **Whether an ice removed from `.zshrc` is ever cleaned up by any non-wipe path.** Every
  observation says no, but only the merge behaviour was directly measured.

---

## Reproducing any of this

The whole method is: make the saved metadata disagree with the config, run one path,
read the metadata back.

```zsh
ZH="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
D="${ZH}/plugins/sharkdp---hexyl"

cp -a "${D}" /tmp/hexyl.backup          # ALWAYS back up first

print -rn -- '99' >| "${D}/._zinit/wait"   # config declares wait'2'

PAGER=cat zsh -ic '@zinit-scheduler burst; zi update --no-pager sharkdp/hexyl'

cat "${D}/._zinit/wait"                 # 2 = refreshed, 99 = stale

rm -rf "${D}" && cp -a /tmp/hexyl.backup "${D}"   # restore
```

`wait` is a safe probe: it is pure scheduling metadata, so a wrong value cannot damage
anything. To test *hook* behaviour instead, replace `._zinit/atclone` with a marker such as
`touch /tmp/STALE_ICE_RAN` — that reveals which ice set actually executed, without paying
for a real compile.

Pick a small, non-critical plugin (`hexyl`, ~1.4MB) and check
`git -C <dir> rev-parse HEAD` against `git ls-remote origin HEAD` beforehand: if nothing is
behind upstream, no `atpull` can fire and no build can be triggered by accident.
