# 🧠 watch Cheat Sheet

## 🔍 Basic Usage

```bash
watch ls -la                                    # Run ls -la every 2 seconds (default)
watch date                                      # Watch the clock update
watch "ps aux | grep nginx"                     # Watch a piped command (must quote)
watch "df -h"                                   # Monitor disk usage in real-time
```

## ⚙️ Core Flags

```bash
watch -n 5 command                              # Run every 5 seconds (custom interval)
watch -n 0.5 command                            # Run every 0.5 seconds (fast refresh)
watch -d command                                # Highlight differences between updates
watch -d=cumulative command                     # Highlight all changes since start (persistent)
watch -t command                                # Hide the header (title bar)
watch -g command                                # Exit when output changes (trigger mode)
watch -e command                                # Exit on error (non-zero exit code)
watch -b command                                # Beep on error
watch -p command                                # Precise timing (try to run exactly on interval)
watch -c command                                # Interpret ANSI color sequences
watch -x command arg1 arg2                      # Pass args directly (no shell interpretation)
```

## 🔧 System Monitoring

```bash
watch -n 1 "free -h"                            # Memory usage every second
watch -n 1 "uptime"                             # Load average every second
watch -d "df -h"                                # Disk usage with changes highlighted
watch -n 2 "ss -tuln"                           # Open ports and listeners
watch -n 5 "systemctl status nginx"             # Service status
watch -n 1 "cat /proc/loadavg"                  # CPU load average
watch -n 2 "ls -la /tmp/"                       # Watch a directory for changes
watch -n 1 "who"                                # Watch logged-in users
```

## 📦 Process and Service Monitoring

```bash
watch -n 1 "ps aux --sort=-%mem | head -15"     # Top 15 processes by memory
watch -n 1 "ps aux --sort=-%cpu | head -15"     # Top 15 processes by CPU
watch -n 2 "docker ps"                          # Watch running containers
watch -n 5 "docker stats --no-stream"           # Docker resource usage snapshot
watch -n 3 "systemctl list-units --failed"      # Watch for failed services
watch -n 2 "pgrep -a node"                      # Watch Node.js processes
```

## 🌐 Network Monitoring

```bash
watch -n 1 "ss -s"                              # Socket statistics summary
watch -n 5 "curl -so /dev/null -w '%{http_code}' https://example.com"  # HTTP health check
watch -n 2 "netstat -tulanp 2>/dev/null | grep ESTABLISHED | wc -l"    # Active connection count
watch -d -n 5 "dig +short example.com"          # Watch DNS resolution changes
```

## 📁 File and Log Watching

```bash
watch -n 1 "wc -l /var/log/syslog"              # Watch log file growth
watch -n 2 "ls -lt /path/dir/ | head -10"       # Watch newest files in directory
watch -d -n 5 "du -sh /var/log/*"               # Watch directory sizes change
watch -g "md5sum file.txt"                       # Exit when file content changes
watch -n 1 "find . -newer marker -type f"       # Watch for new files since marker
```

## 🔗 Common Combos

```bash
# Watch with color output preserved
watch -c "ls --color=always -la"

# Trigger action when output changes
watch -g "ls /path/" && echo "Directory changed!"

# Monitor build output
watch -n 3 "tail -5 build.log"

# Watch queue length (Redis)
watch -n 1 "redis-cli LLEN myqueue"

# Watch database connections
watch -n 2 "mariadb -u root -p -e 'SHOW PROCESSLIST' --batch | wc -l"

# Watch git status for changes
watch -n 5 -d "git status --short"
```

## 🆚 watch vs alternatives

```bash
# watch          — simple, available everywhere, fixed interval
# viddy          — modern watch with history, paging, diff mode
# entr           — runs command when files change (event-driven, not polling)
# tail -f        — follow file appends (better for logs than watch)
# inotifywait    — Linux file event watcher (event-driven, zero CPU when idle)
```

## ⚠️ Gotchas

```bash
# Piped commands must be quoted: watch "cmd1 | cmd2" (not watch cmd1 | cmd2)
# watch runs command via sh, not zsh — ZSH-specific syntax won't work
# -n accepts decimals on GNU watch but not all implementations
# -g only checks stdout — stderr changes are ignored
# watch -c may not work if command doesn't force color (use --color=always)
# On macOS: brew install watch (not installed by default)
```

