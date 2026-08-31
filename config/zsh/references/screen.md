# 🧠 screen Cheat Sheet

## 🔍 Basic Usage

```bash
screen                                          # Start a new session
screen -S myname                                # Start a named session
screen -ls                                      # List all sessions
screen -r                                       # Reattach to last session
screen -r myname                                # Reattach to named session
screen -d -r myname                             # Detach elsewhere and reattach here
screen -x myname                                # Attach to session (shared/multi-display)
screen -d myname                                # Detach a session remotely
```

## ⌨️ Key Bindings (prefix: Ctrl+A)

```bash
# All commands below start with Ctrl+A (shown as C-a):

# Session Control
C-a d                                           # Detach from session (session keeps running)
C-a \                                           # Kill all windows and terminate session
C-a :quit                                       # Quit screen (same as above)

# Window Management
C-a c                                           # Create new window
C-a n                                           # Next window
C-a p                                           # Previous window
C-a 0-9                                         # Switch to window 0-9
C-a "                                           # List all windows (interactive selector)
C-a A                                           # Rename current window
C-a k                                           # Kill current window (with confirmation)
C-a w                                           # Show window list in status bar

# Split Panes
C-a S                                           # Split horizontal
C-a |                                           # Split vertical (requires screen 4.1+)
C-a Tab                                         # Switch between split regions
C-a X                                           # Close current region
C-a Q                                           # Close all regions except current

# Copy and Scroll (scrollback mode)
C-a [                                           # Enter scrollback/copy mode (navigate with arrows/vim keys)
C-a ]                                           # Paste from buffer
# In copy mode: Space to start selection, Space again to copy, then C-a ] to paste
C-a Esc                                         # Enter copy mode (same as C-a [)
C-a h                                           # Write scrollback to file (hardcopy)
C-a H                                           # Toggle logging to file (screenlog.N)

# Misc
C-a ?                                           # Show key bindings help
C-a :                                           # Enter command mode
C-a i                                           # Show window info
C-a m                                           # Monitor window for activity
C-a _                                           # Monitor window for silence (30s)
C-a x                                           # Lock screen (requires password)
```

## 📋 Session Management from CLI

```bash
screen -S work                                  # Create named session "work"
screen -S work -X stuff "ls -la\n"              # Send command to session (non-interactive)
screen -S work -X quit                          # Kill session from outside
screen -S work -p 0 -X stuff "deploy.sh\n"      # Send command to specific window (0)
screen -wipe                                    # Clean up dead sessions
screen -S work -X hardcopy /tmp/screen.txt      # Dump current screen to file
```

## ⚙️ Useful .screenrc Options

```bash
# Put these in ~/.screenrc:
# defscrollback 10000                           # Increase scrollback buffer (default 100)
# startup_message off                           # Disable splash screen
# shell -$SHELL                                 # Use login shell
# hardstatus alwayslastline "%w"                # Show window list at bottom
# caption always "%{= kG} %H | %{= kw}%-w%{= BW}%n %t%{-}%+w %= | %c"  # Status bar
# termcapinfo xterm* ti@:te@                    # Enable mouse scrolling in xterm
# bind s                                        # Unbind xoff (C-a s freezes terminal)
# mousetrack on                                 # Enable mouse support
```

## 🔗 Common Combos

```bash
# Start a long-running command in a detached session
screen -dmS backup tar -czf /backup/full.tar.gz /var/www

# Run multiple persistent services
screen -S services
# C-a c → start redis, C-a c → start worker, C-a c → start logs
# C-a " → switch between them, C-a d → detach

# Reconnect after SSH drops
ssh user@host
screen -d -r                                    # Reattach to orphaned session

# Quick logging of a session
screen -L -S logged                             # Auto-log everything to screenlog.0

# Share screen with another user (pair programming)
screen -S shared                                # User 1 starts session
screen -x shared                                # User 2 attaches to same session
```

## 🆚 screen vs tmux

```bash
# screen — everywhere, simple, single config file, lighter
# tmux   — scriptable, better splits, status bar, mouse support, active development
# Use screen when: tmux isn't installed, quick throwaway sessions, legacy servers
# Use tmux when: daily driver, complex layouts, team workflows
```

## ⚠️ Gotchas

```bash
# C-a S splits but doesn't create a shell — press C-a c in the new region
# C-a s (lowercase) sends XOFF and freezes terminal — press C-a q to unfreeze
# screen -r fails if session is attached elsewhere — use screen -d -r to force
# Copy mode uses vi or emacs keys depending on $EDITOR
# Scrollback default is only 100 lines — set defscrollback in .screenrc
# screen sessions survive SSH disconnect but NOT server reboot
```

