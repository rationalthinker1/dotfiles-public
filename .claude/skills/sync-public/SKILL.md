---
name: sync-public
description: Publish master to the public dotfiles repo with ./scripts/sync-public. Use
  whenever public needs catching up, the post-commit hook printed "public NOT synced",
  or someone asks to sync/publish/push to public. Covers the two modes (snapshot is the
  default and what the hook runs), the already-applied false positive that must never
  be hand-resolved in replay, and what never syncs.
---

# sync-public

`./scripts/sync-public` publishes master onto the `public` branch, which pushes to the
public repo's `master`. **`git-hooks/post-commit` runs it after every master commit** as
`--go --snapshot --message-from=HEAD`, so normally there is nothing to do by hand.

When the hook prints `public NOT synced` (offline, push rejected, …), just re-run
`./scripts/sync-public --go --snapshot`. It is idempotent: it pushes a local snapshot an
earlier run committed but failed to push, and the next commit's hook retries anyway.

## Modes

Run the dry form first. Both default to a dry run; `--go` executes.

| Mode | Command | Dirty tree |
|---|---|---|
| Snapshot (default, the hook's) | `./scripts/sync-public --snapshot` → `--go --snapshot` | fine |
| Replay (keeps per-commit history) | `./scripts/sync-public` → `--go` | refuses |

Snapshot publishes master's **content** as one commit instead of its history. It cannot
conflict, because nothing is merged: public's next tree is assembled in a throwaway
index from master's safe paths plus public's own `.gitignore`/`git-hooks/`, and the
branch is moved with `update-ref` — no checkout, so a dirty tree does not matter. With
`--message-from=REV` it reuses REV's message and author, but only when the snapshot is
exactly REV's change (REV is master's tip, public matched REV's parent, REV touches no
sensitive path); otherwise it uses a generic `🔄 chore(public): snapshot …` message.

Replay cherry-picks each missing commit oldest-first. It only works while public's tree
still resembles the one those patches were written against — and after any snapshot,
`git cherry` reports every pre-snapshot commit as missing forever. Prefer snapshot.

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

Also never taken from master: **`.gitignore` and `git-hooks/`**. These legitimately
differ between branches and belong to public; snapshot keeps public's own copies.

Snapshot filters by **path**, so a commit mixing a sensitive file with public-safe work
publishes the safe half (under the generic message — the commit's own message may
describe the secret). Replay still skips such commits whole.

## Why it is safe to run

It fails closed at every step — repo sanity, public is current, sensitive paths filtered
out of the tree before it is built (`_sp_snapshot_tree`), then a rescan of the built tree
**before** anything is committed or pushed. Replay adds a clean-tree check, a per-commit
sensitive check, and a post-apply rescan that hard-resets to `public/master` on a hit.

`.gitignore` is **not** what protects public — it only blocks *untracked* files from
`git add`. A cherry-pick force-applies any file named in the operation, bypassing it
entirely. The skip list plus the tree scan are the real guard.

## Reconciling by hand

Don't bulk cherry-pick. Take only vetted non-sensitive files
(`git checkout master -- <safe files>`, no merge, no conflict), then re-run the anchored
sensitive-path grep as a hard gate before pushing. `--snapshot` does exactly this, gated,
and is preferable to doing it by hand.
