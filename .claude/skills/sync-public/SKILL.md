---
name: sync-public
description: Publish master to the public dotfiles repo with ./scripts/sync-public. Use
  whenever public needs catching up, the post-commit hook printed "Could not checkout
  public branch" or "Cherry-pick failed", a commit was skipped as sensitive, or someone
  asks to sync/publish/push to public. Covers which of the two modes to use, the
  already-applied false positive that must never be hand-resolved, and what never syncs.
---

# sync-public

`./scripts/sync-public` replays master onto the `public` branch, which pushes to the
public repo's `master`. It is the catch-up path for `git-hooks/post-commit`, which is
per-commit and fire-and-forget: when it fails it prints into the tail of `git commit`
output, gives up, and nothing ever retries.

**The hook's most common failure needs no bad luck.** `git checkout public` refuses a
dirty tree, which it usually is when you commit one file out of several. Commit or stash
everything first — including untracked files — or every mode below refuses too.

## Pick the mode by the size of the gap

Run the dry form first. Both default to a dry run; `--go` executes.

| Gap | Command |
|---|---|
| A few commits | `./scripts/sync-public` → `--go` |
| Large / months behind | `./scripts/sync-public --snapshot` → `--go --snapshot` |

Replay cherry-picks each missing commit oldest-first. It only works while public's tree
still resembles the one those patches were written against.

Snapshot publishes master's **content** as one commit instead of its history. It cannot
conflict, because nothing is merged: every safe path is overwritten from master, every
path master no longer carries is deleted, and the result is committed as-is.

Other flags: `--no-push` applies locally and leaves the push to you; `--all` also
considers commits predating the public branch (~700 here — you almost never want this).

## Conflicts during replay: check before resolving

**A conflict usually means the commit is already applied, not that it needs merging.**

`git cherry` compares patch-ids. When a later commit edited or deleted the same lines,
the old patch-id can never match again, so the commit is reported missing forever even
though its effect is on public verbatim.

Hand-resolving one of these **regresses public** — it reintroduces whatever the later
commit removed.

So before touching a conflict:

```zsh
git show <sha>                          # what did it actually change?
git show public:<file> | grep -n '<the change>'   # is that already there?
```

Already there → skip it. Not there → resolve, or fall back to `--snapshot`.

Worked example, `14b406e` "Don't abort install.sh if wslu install fails": it added a
`|| echo "⚠ wslu install failed …"` guard *and* touched PPA lines that a later commit
deleted in favour of distro repos. The guard is on public; the PPA is deliberately gone.
Cherry-picking it would put the PPA back.

When several commits in a backlog are this shape, stop replaying and snapshot.

## Never syncs, by design

The list lives in `git-hooks/sensitive-paths.zsh` and is shared with the hook, so the two
cannot drift. Two forms: `SENSITIVE_COMMIT_PATTERNS` ("may this commit be replayed?") and
`SENSITIVE_TREE_REGEX` ("did anything sensitive end up tracked on public?").

`.gitconfig` · root `CLAUDE.md` · `.ssh/` · `config/.aws/` · `config/password-store/` ·
`wsl/windows-terminal/settings.json` · `config/zsh/references/aws.md` ·
`config/zsh/local.zsh` · `powershell/local.ps1` · `config/gh/hosts.yml` ·
`.vim/config/90-local.vim` · `config/atuin/{key,session}` · any `.env` `.netrc` `.npmrc`
`.pgpass`

Also excluded from snapshot, and skipped by the hook as *commits*: **`.gitignore` and
`git-hooks/`**. These legitimately differ between branches and belong to public.

Consequence worth remembering: the hook skips whole **commits**, so a commit mixing a
sensitive file with public-safe work syncs *neither* part. Split them.

## Why it is safe to run

It fails closed at every step — repo sanity, clean tree, public is current, per-commit
sensitive check, then a rescan of the whole tracked tree **after** applying and **before**
pushing. Snapshot additionally filters sensitive paths out of the file list before writing
anything (`scripts/sync-public:144`), so they never enter the tree to begin with. Any hit
on the post-apply scan hard-resets to `public/master` and pushes nothing.

`.gitignore` is **not** what protects public — it only blocks *untracked* files from
`git add`. A cherry-pick force-applies any file named in the operation, bypassing it
entirely. The skip list plus the tree scan are the real guard.

## Reconciling by hand

Don't bulk cherry-pick. Take only vetted non-sensitive files
(`git checkout master -- <safe files>`, no merge, no conflict), then re-run the anchored
sensitive-path grep as a hard gate before pushing. `--snapshot` does exactly this, gated,
and is preferable to doing it by hand.
