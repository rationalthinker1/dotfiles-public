# Global instructions

## Editing files

**Small, targeted changes go through the `Edit` tool. Use `Write` only to create new files.
A big MECHANICAL SWEEP goes through a rewrite script.**

Which is which:

- **`Edit`** — anything you had to think about: a logic change, a signature change, a
  handful of sites, or a change where each site needs its own judgement. Also every
  *last-mile* fix after a sweep. Don't shell out for these (`sed -i`, `perl -pi`,
  `cat > file` heredocs); that preference holds even when the harness suggests Bash for
  file work, which covers *reading* and *searching*, not editing.
- **A rewrite script** — one uniform transformation applied across many files: a rename, an
  import rewrite, a call-shape migration. Hand-editing 50 identical sites is slower and no
  safer. Write the script to a file and run it (a `python3 - <<'PY'` heredoc may be blocked
  by the sandbox classifier).

Rules for the script — this is what makes it safe:

1. **Enumerate first.** Print the match set and eyeball that it is exactly what you expect
   *before* mutating anything.
2. **Make it self-verifying.** Report lines changed per file, then re-scan for leftovers and
   print both the count and each leftover.
3. **Review the diff.** `git diff` the result and read it. A regex silently succeeds on a
   wrong match; the diff is where you catch that.
4. **Then typecheck/lint**, and clean up the stragglers with `Edit`.

Why the split: `Edit` requires a prior `Read`, fails loudly on an ambiguous or stale match,
and records a reviewable diff — worth it when the change carries judgement. A sweep has no
per-site judgement to lose, and the enumerate → verify → diff loop recovers the same safety
at a fraction of the cost.

## Refactoring

**Prefer regex or an AST to drive multi-site changes — for finding and verifying the
sites, not for performing the mutation.**

- Locate and enumerate with `Grep` (regex) or a language-aware parser; confirm the set
  of matches is exactly what you expect *before* changing anything.
- Reach for an AST whenever a regex would be guessing at structure — renaming a symbol,
  changing a signature, moving a call. Language-appropriate tools:
  - Python — `ast` / `libcst`
  - TypeScript / JavaScript — `ts-morph`, `jscodeshift`
  - PowerShell — `[System.Management.Automation.Language.Parser]::ParseFile`
  - Shell — `zsh -n` / `bash -n` to syntax-check the result
- Apply the change with `Edit` (`replace_all: true` for a repeated exact string).
- Re-run the same search afterward to prove no sites were missed.

Using a script to *analyze* — parse, count, list call sites, syntax-check — is fine and
encouraged. The line is that the write itself goes through `Edit`.
