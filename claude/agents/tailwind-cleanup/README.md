# tailwind-cleanup

Portable Tailwind CSS class standardization toolkit.

Audits arbitrary `[bracket]` utility values across a project and snaps them to a fixed ladder of named tokens defined in the project's `main.css`. Project-agnostic: every snap rule, RGB triplet, and token name lives in a per-project `tailwind-cleanup.config.json`, not in script bodies.

## Installation

```sh
# The toolkit lives at ~/.config/claude/tailwind-cleanup/. Add the CLI to PATH:
export PATH="$HOME/.config/claude/tailwind-cleanup/bin:$PATH"
```

Append that line to your shell rc (`~/.bashrc`, `~/.zshrc`) to make it permanent.

To make the bundled subagent discoverable by Claude Code:

```sh
mkdir -p ~/.claude/agents
ln -s ~/.config/claude/tailwind-cleanup/agent/tailwind-cleanup.md ~/.claude/agents/tailwind-cleanup.md
```

## Per-project setup

```sh
cd /path/to/your/project
tw-cleanup init                # writes tailwind-cleanup.config.json + adds report dir to .gitignore
$EDITOR tailwind-cleanup.config.json   # fill in your scales / token names / RGB map
tw-cleanup audit:all           # first report
```

## Commands

| Command | Purpose |
|---|---|
| `tw-cleanup init` | Write a stub config and ignore the report directory |
| `tw-cleanup audit:arbitrary` | Distribution scan over `*-[…]` matches; report by utility prefix |
| `tw-cleanup audit:duplicates` | className duplicates report (Python; near-numeric clustering) |
| `tw-cleanup audit:all` | Both audits |
| `tw-cleanup standardize:typography` | text + tracking + leading |
| `tw-cleanup standardize:spacing` | m/p/gap/w/h + positioning + translate |
| `tw-cleanup standardize:borders-radii` | border-width + rounded |
| `tw-cleanup standardize:colors` | rgba slash-alpha + numeric-color rename |
| `tw-cleanup standardize:misc` | z-index + duration |
| `tw-cleanup standardize:breakpoints` | max-/min-[Npx] |
| `tw-cleanup standardize:all` | All six, in canonical order |
| `tw-cleanup verify` | Runs `verify.command` from config (default `npm run build`) |
| `tw-cleanup version` | Print toolkit semver |

Common flags: `--dry` (no writes), `--report json|md|both`, `--paths a,b` (override scan paths), `--config <path>`.

## Config schema

See [`schema/tailwind-cleanup.config.schema.json`](schema/tailwind-cleanup.config.schema.json) and the seeded example at [`templates/tailwind-cleanup.config.example.json`](templates/tailwind-cleanup.config.example.json).

## Design

- **Project-agnostic** — every snap rule and token name is config-driven
- **Idempotent** — re-running on a clean codebase is a no-op
- **Skips design-system files** — `src/styles/` is excluded by default; CSS-mode rewrites are opt-in (`scan.css.include=true`) and restricted to `@apply` inside recipes, never `:root` or `@theme`
- **Reports first** — the bundled subagent orchestrates scripts and surfaces reports; it never substitutes class strings itself

## Subagent

The bundled subagent at [`agent/tailwind-cleanup.md`](agent/tailwind-cleanup.md) is intended for symlinking into `~/.claude/agents/`. Its job is to run audits, present the findings, ask which transformations to apply, and run the relevant scripts. It does not directly edit source files — that's what the scripts are for.
