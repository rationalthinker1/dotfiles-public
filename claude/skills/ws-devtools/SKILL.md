---
name: ws-devtools
description: Runbook for driving a live browser tab via the ws-devtools MCP tools (mcp__ws-devtools__url / snapshot / click / …). Load BEFORE the first ws-devtools call in a session, and whenever the bridge misbehaves (DEGRADED, browserAttached false, connection closed) — covers triage, devcontainer/WSL2 port-forward traps, arming, and battle-tested driving rules for any web app.
---

# ws-devtools — runbook & battle-tested fixes

Driving a live browser tab via the **ws-devtools MCP tools**
(`mcp__ws-devtools__url` / `snapshot` / `screenshot` / `click` / …), from any project —
plain host or devcontainer. Merged from long debugging sessions; current for the
2026-07-23 build (`8071a75`; package version still 0.1.2 — these fixes are in git,
not yet on npm, so a `npx -y ws-devtools` install predates them). Generic usage
reference:
`/home/razaf/Projects/ws-devtools/docs/using-from-another-project.md` (in devcontainers
this is typically a read-only bind mount). Ignore any vendored `debug/ws-devtools/`
copy inside a project — stale, not docs.

## TL;DR — the golden path

1. **Call `mcp__ws-devtools__status` FIRST** — it answers in every state and tells you
   which section below you're in.
2. **Human arms the tab** (MV3 extension toolbar click). An agent can NEVER arm it.
3. `url` returns the page → you're driving.

| `status` reports | State | Go to |
|---|---|---|
| `listening: true, browserAttached: true` | healthy | drive |
| `proxied: true` + `ownerPid`/`proxyPid` | lost the :9999 race, **transparently proxying** through the owner | drive — no cleanup needed (§3) |
| `listening: true, browserAttached: false` | bridge fine, no tab feeding it | §4 (arm); if user says the tab IS armed → §2 (host collision) |
| tool errors "DEGRADED … found no bridge owner to proxy through" | port held by something with no usable file API | §3 — kill duplicates |
| `MCP error -32000: Connection closed` | bridge process died mid-call | call `status` — the harness respawns the server — then re-triage |

## Architecture (why it's fiddly in containers)

```
  HOST browser  ──ws──►  host localhost:9999  ══forwardPorts══►  container :9999
  (MV3 extension)                                                      ▲
  Claude Code (in container) ──stdio──►  ws-devtools mcp.mjs  ─────────┘  (same process!)
```

- The MCP server self-starts the bridge on `:9999` (hard-coded in the extension).
  On a plain host setup the extension talks to it directly; in a devcontainer,
  `forwardPorts` in `.devcontainer/devcontainer.json` must bridge host:9999 to the
  container.
- The extension dials a **candidate list** — `ws://127.0.0.1:9999` first, then
  `ws://[::1]:9999` — rotating on refusal or a 4 s connect watchdog, sticky once one
  succeeds (this is what makes both WSL2 personalities work).
- **Invariant, softened:** your session's `mcp.mjs` no longer has to own :9999 — a
  loser proxies through the owner (§3). What must still hold is that the bridge the
  **extension** attached to is the one your tools reach (§2).
- Devcontainers add two failure points vs. a plain host setup: the **VS Code
  forward** and **host-side ws-devtools instances** (other projects competing for
  host:9999).

## §1. Registration (once)

```bash
claude mcp add ws-devtools -s user -- npx -y -p ws-devtools ws-devtools-mcp
# or pinned to a local checkout:
claude mcp add ws-devtools -s user node /home/razaf/Projects/ws-devtools/dist/mcp.mjs
claude mcp list   # → ws-devtools … ✔ Connected
```

- Use **`-s user` after the server name**; the long `--scope` form is rejected in
  some positions on some `claude` builds.
- Two bins — `ws-devtools` (CLI/file-API bridge) vs **`ws-devtools-mcp`** (the MCP
  server; the one you want).
- History: ≤ 0.1.1 the bin silently failed the stdio handshake via any symlinked
  launch (fixed 0.1.2); 0.1.2's npm build hardcodes `serverInfo.version` "0.1.0"
  (fixed 0.1.3).

## §2. Bridge up but `browserAttached: false` with an armed tab → host collision

(Devcontainer scenario.) The extension is talking to **something** (page console shows
`[ws-devtools] connected`), just not your container. A host-side ws-devtools is
squatting host:9999, so the VS Code forward silently failed. Container-side `status`
**cannot** detect this — it only sees its own namespace.

**Confirm it in one look:** the SW console logs
`[ws-devtools] connected to bridge pid <n> port <p> dir <d> (v<version>)` — from the
server's `__hello` identity frame — and mirrors pid + dir into the extension's toolbar
title. A `dir`/`pid` that isn't the one `status` reports = attached to the wrong
bridge, which is this section, not §4.

Fix — user runs on the **HOST** (real host terminal, not the devcontainer one):
```bash
pkill -f 'ws-devtools/dist'   # kill host-side instances
lsof -i :9999                 # expect nothing (or only VS Code's forward)
```
Then VS Code **PORTS panel**: `9999` must be forwarded to `localhost:9999`.
- The forward can be **remapped, not missing**: if host 9999 was busy, VS Code
  silently picks another local port — the extension hard-codes 9999, so remap =
  unreachable. Free the port, remove and re-add the forward.
- **Killing/restarting the container bridge can also make VS Code drop the forward**
  — re-check the panel after any §3 cleanup.
Finally re-click the extension icon / refresh the tab.

### §2a. WSL2 trap: which machine is "the host"?
The forward lands on the **Windows** side (where VS Code UI + browser live), not the
WSL distro. `curl localhost:9999` from a WSL shell returning `000` is a red herring.
The PORTS panel is authoritative: `localhost:9999` + Running Process = the container's
`node …/dist/mcp.mjs` (pid matching `status`) ⇒ the forward is live; stop debugging
it and give the extension a moment (or a re-click).

### §2b. WSL2 IPv4/IPv6 split-brain (mostly fixed — read if the attach lands wrong)
The VS Code forward listens on **127.0.0.1 (IPv4)**; a ws-devtools running inside the
WSL distro is relayed to Windows by `wslrelay.exe` on **[::1] (IPv6)** only. Endpoint
rotation means a refused family no longer wedges the extension — but if BOTH are
listening it attaches to whichever answers first, possibly the wrong bridge. Diagnose
with the `__hello` line (§2), then from PowerShell:
```
netstat -ano | findstr :9999
tasklist /FI "PID eq <pid>"      # a [::1]:9999 owner named wslrelay.exe = WSL-side instance
```
Fix: kill the WSL-side instance (broad `pkill -f ws-devtools` in a host WSL terminal).

## §3. Duplicate servers → normally invisible (proxy-to-owner)

If another `mcp.mjs` already owns :9999, your session's server **forwards every tool
call through the owner's file API** instead of failing. `status` returns the owner's
real report plus `proxied: true, ownerPid, proxyPid`; every tool works, screenshots
included. **Killing duplicates is optional cleanup, not a prerequisite** — and the
takeover loop keeps running, so if the owner exits your instance claims the port.

You only get a hard error — **"DEGRADED mode: … found no bridge owner to proxy
through"** — when the port is held by something with no usable file API (a foreign
process, a pre-2026-07-23 build). **Do NOT ask the user to re-arm — that's not the
problem.** From your environment (container if containerized):
```bash
pgrep -fa ws-devtools                     # see every instance
kill <ownerPid from the error>            # targeted…
pkill -9 -f 'ws-devtools/dist/mcp.mjs'    # …or all instances
```
The survivor takes the port automatically; if you killed everything, the harness
respawns your session's server **on the next tool call** — just call `status` again.
Then the user re-clicks the extension icon (the tab was bound to the dead server).

> Port probes in a container: `ss -ltnp | grep 9999` often shows nothing even when
> the port is up (namespace quirk). Trust `status`, or
> `curl -s -o /dev/null -w "%{http_code}" http://localhost:9999/` → `426` = bridge up
> (WebSocket-only; every HTTP path returns 426, there is no `/status` endpoint).

## §4. Arming the tab (human-only)

1. Once: `chrome://extensions` → Developer mode → Load unpacked →
   `/home/razaf/Projects/ws-devtools/dist/extension`.
2. Open the target page, click the toolbar button to arm **that tab**.
3. Auto-reconnects when the bridge (re)appears and survives navigation. Since the
   connect watchdog landed, a bridge restart is picked up in **~1 s** with no human
   action (a stuck CONNECTING attempt is force-closed after 4 s and retried). If it's
   still dark after ~10 s, the SW console says why — `connect attempt #N → <url>` per
   try. `clients: 2–3` in `status` is normal (extension + page transports);
   `clients: 0` means nothing is attached.
4. **Arm click not landing although the whole chain checks out** (bridge listening,
   forward correct, host-side `curl` to `localhost:9999` → 426): the MV3 service
   worker is asleep. Fix: **refresh the page (F5), then click the extension icon** —
   that combination reliably re-attaches.

## Quick diagnosis flowchart

```
status → "no bridge owner to proxy through"? ──yes──►  §3 (kill pid; next call respawns)
      │no
      ▼
proxied: true?                       ──yes──►  drive normally (owner's browser)
      │no
      ▼
browserAttached: true?               ──yes──►  drive (url first to confirm the page)
      │no
      ▼
User says tab is armed?              ──no───►  §4 (ask user to arm; you cannot)
      │yes
      ▼
SW/toolbar hello names a foreign pid/dir? ──yes──► §2b (wrong bridge)
      │no
      ▼
§2 (host :9999 collision / dropped forward — user fixes on HOST; §2a on WSL2)
```

## Driving rules (learned the hard way)

- **`status` → `url` → act.** Never trust page reads before `url` confirms the page.
- **Arg names are NOT validated — a typo returns a plausible lie.** (Open issue,
  2026-07-23.) `eval` takes `code`; pass `expression` (the Playwright/CDP spelling)
  and the call is *accepted*, evaluates `undefined`, and answers `"undefined"` to
  every expression — reads exactly like "eval is broken". Same silent-accept for every
  tool with a required arg (`check` given an expression → `No element: undefined`).
  If a tool returns a suspiciously empty/`undefined` result, **check the arg name
  first**, don't go hunting a regression.
- **`navigate` is commit-verified**: it replies with the **landed URL** and errors
  naming where the tab still is if nothing committed within 5 s — an `ok` reply means
  it really happened (redirects stay legitimate; commit, not URL equality, is the
  criterion). The follow-up read can still race the re-inject by a beat; retry `url`
  once if it times out.
- **Text reads over screenshots**: `text body` / `dom_text` / `snapshot --lean` /
  `role` — a screenshot is ~20–50× the tokens. Screenshot only to confirm layout.
- **Re-`snapshot` before ref-based clicks** — `@ref`s go stale as the page mutates.
  `role <role> <name>` is the fastest path to one element.
- **`eval` takes an expression, not statements** — wrap in an IIFE:
  `(() => { foo(); return 'done'; })()`.
- Fixed, so stop working around them: the **first command after (re)attach** no longer
  times out (per-tab readiness gate), and `waitfor` answering `Unknown command` right
  after a reconnect was a stale client — re-arm rather than polling via `eval`.
- **`viewport_set` reset** restores the real window size, which may be narrow with
  DevTools docked — emulate an explicit width (e.g. 1400) to verify responsive
  (`lg:`-style) breakpoints.
- **HMR applies CSS live but not always template edits** (observed with Vue) — if
  styles update but markup is stale, reload the page.

## Tool picks (verified in real sessions)

- **`read`** — page main content as Markdown; the lowest-token full-page read. It even
  surfaces open wizard/dialog state (steps, selected counts) that `snapshot` misses.
  First choice for "what is on this page right now".
- **`screencast_start` → act → `screencast_frame settle:<ms>`** — the best act→verify
  loop: ~620-token frames (vs ~1.5k+ for `screenshot`), `settle` replaces guessed
  sleeps, `unchanged:true` costs nothing. The stream is now **re-issued on every
  committed navigation**, so cross-site hops no longer freeze it; a genuinely stuck
  stream still falls back to `screenshot` (always current) or a restart.
- **`state <sel|@ref>`** — visible/enabled/checked bundle; the clean way to assert a
  radio/checkbox actually toggled after a click.
- **`elements` / `eval`** — the escape hatch for non-ARIA custom widgets (some sites'
  checkboxes expose no roles/inputs). Find by text with `eval`, click, then **verify
  visually** — a label `.click()` can double-toggle through framework handlers
  (observed: 2 clicks in one eval left one box unchecked). One toggle per eval call,
  screenshot to confirm.
- **Portal dropdowns** (React/Vue selects rendered in a portal) mount OUTSIDE
  `div[role="dialog"]` — scope snapshots to `[role="listbox"]`/`[role="menu"]` or go
  global, not to the dialog.
- **`batch`** — several file-API-style steps in one round-trip (multi-field fills,
  act-then-waitfor). Don't put `navigate`/`screenshot` in a batch.
- **`events`** — drains buffered console history (shows arming timeline; network only
  after `netlog on`). Good first look when "nothing happened".
- **Polling from bash via the file API** (in the server's dir): write `status` to
  `cmd.txt`, read `cmd-result.txt`. The server now deletes the result file before each
  command and stamps `ts`, so the old "stale result fakes a successful attach" trap is
  gone — no manual `rm`. For concurrent callers, prefix the line with `#<id>` and match
  `reqId` in the result.

## Driving a local dev app

- Figure out the URL **as seen from the host browser** (the armed tab lives on the
  host): in a devcontainer that's the forwarded/proxied port (check the PORTS panel
  or an nginx/proxy config), not necessarily the dev server's own port (HMR often
  runs on a separate port, e.g. Vite's 5173). The app port working proves forwarding
  works in general — the bridge port can still be blocked independently (§2).
- SPA routes are often **auth-guarded** → logged-out hits redirect to
  `/login?redirect=…`. You cannot log in for the user; ask them to, then
  re-`navigate`.
- Deep-link with query params where the app supports it (report pages with
  `start_date`/`end_date` etc.) instead of clicking through filters.
- Framework inspectors (`pinia`/`vue`/redux hooks like `window.__WS_DEVTOOLS_PINIA__`)
  need the dev build's adapters — absent on prod builds.

## Driving real third-party / production sites

- Works with the armed extension, including `eval` (CSP-safe CDP path). Prefer text
  reads anyway.
- Logged-in sessions are the user's REAL accounts: reads and dropdown/tab/navigation
  clicks are fine; **creates/deletes/submits/confirmations stay with the user** (or
  get explicit consent per action).
- Heavy dashboards (e.g. ad managers) render slowly: `waitfor body` then `text body`
  beats guessing selectors. Dropdowns: `role combobox <name>` → `click` →
  `snapshot [role="listbox"]` → click the option.
