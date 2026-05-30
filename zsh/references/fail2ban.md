# 🧠 fail2ban Cheat Sheet

## 🔍 Service Control

```bash
sudo systemctl start fail2ban                   # Start fail2ban
sudo systemctl stop fail2ban                    # Stop fail2ban
sudo systemctl restart fail2ban                 # Restart (reloads all config)
sudo systemctl reload fail2ban                  # Reload config (graceful)
sudo systemctl status fail2ban                  # Check service status
sudo systemctl enable fail2ban                  # Enable on boot
```

## 📋 Status and Monitoring

```bash
sudo fail2ban-client status                     # List all active jails
sudo fail2ban-client status sshd                # Show status of sshd jail (banned IPs, stats)
sudo fail2ban-client banned                     # List all currently banned IPs across all jails
sudo fail2ban-client get sshd banip             # List banned IPs for specific jail
sudo fail2ban-client get sshd currentlyban      # Count of currently banned IPs
sudo fail2ban-client get sshd totalban          # Total bans since start (including expired)
```

## 🔒 Ban and Unban

```bash
sudo fail2ban-client set sshd banip 1.2.3.4    # Manually ban an IP
sudo fail2ban-client set sshd unbanip 1.2.3.4  # Unban an IP
sudo fail2ban-client unban 1.2.3.4             # Unban IP from all jails
sudo fail2ban-client unban --all               # Unban ALL IPs from all jails
```

## 📁 Key Paths

```bash
# Config files:
/etc/fail2ban/fail2ban.conf                     # Main daemon config (don't edit)
/etc/fail2ban/jail.conf                         # Default jail definitions (don't edit)
/etc/fail2ban/jail.local                        # YOUR overrides (create this)
/etc/fail2ban/jail.d/                           # Drop-in jail configs (override jail.conf)

# Filters:
/etc/fail2ban/filter.d/                         # Regex filter definitions (one per service)
/etc/fail2ban/filter.d/sshd.conf                # SSH filter rules
/etc/fail2ban/filter.d/nginx-http-auth.conf     # Nginx basic auth filter

# Actions:
/etc/fail2ban/action.d/                         # Ban actions (iptables, firewalld, etc.)

# Logs:
/var/log/fail2ban.log                           # Fail2ban's own log (bans, unbans, errors)
```

## ⚙️ Jail Configuration

```bash
# Create /etc/fail2ban/jail.local for overrides:

# [DEFAULT]
# bantime  = 1h                                 # Ban duration (default: 10m)
# findtime = 10m                                # Window to count failures
# maxretry = 5                                  # Max failures before ban
# banaction = iptables-multiport                # How to ban (iptables/nftables/firewalld)
# ignoreip = 127.0.0.1/8 ::1 192.168.1.0/24    # Never ban these IPs/CIDRs

# [sshd]
# enabled  = true
# port     = ssh                                # Or specific: port = 22,2222
# logpath  = /var/log/auth.log                  # Log file to watch
# maxretry = 3                                  # Override default for SSH
# bantime  = 24h                                # Ban for 24 hours

# [nginx-http-auth]
# enabled  = true
# port     = http,https
# logpath  = /var/log/nginx/error.log
# maxretry = 5

# [nginx-botsearch]
# enabled  = true
# port     = http,https
# logpath  = /var/log/nginx/access.log
# maxretry = 2
```

## 🧪 Testing Filters

```bash
# Test a filter regex against a log file:
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf

# Test with specific filter lines:
sudo fail2ban-regex /var/log/auth.log "Failed password .* from <HOST>"

# Test filter with verbose output:
sudo fail2ban-regex --print-all-matched /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf

# Test against a single log line:
echo 'Failed password for root from 1.2.3.4 port 22 ssh2' | sudo fail2ban-regex - /etc/fail2ban/filter.d/sshd.conf
```

## 🔧 Jail Management

```bash
sudo fail2ban-client start sshd                 # Start a specific jail
sudo fail2ban-client stop sshd                  # Stop a specific jail
sudo fail2ban-client reload sshd                # Reload a specific jail
sudo fail2ban-client add myjail                 # Add a new jail at runtime
sudo fail2ban-client get sshd maxretry          # Get jail setting
sudo fail2ban-client set sshd maxretry 3        # Change jail setting at runtime
sudo fail2ban-client get sshd bantime           # Get ban duration
sudo fail2ban-client set sshd bantime 86400     # Set ban to 24h (in seconds)
sudo fail2ban-client get sshd findtime          # Get failure counting window
sudo fail2ban-client get sshd ignoreip          # List whitelisted IPs
```

## 📊 Log Analysis

```bash
# Recent bans
sudo tail -50 /var/log/fail2ban.log | grep "Ban"

# Recent unbans
sudo tail -100 /var/log/fail2ban.log | grep "Unban"

# Count bans per IP (all time)
sudo grep "Ban" /var/log/fail2ban.log | awk '{print $NF}' | sort | uniq -c | sort -rn | head -20

# Count bans per jail
sudo grep "Ban" /var/log/fail2ban.log | awk '{print $6}' | tr -d '[]' | sort | uniq -c | sort -rn

# Bans today
sudo grep "$(date +%Y-%m-%d)" /var/log/fail2ban.log | grep "Ban"

# Watch bans in real-time
sudo tail -f /var/log/fail2ban.log | grep --line-buffered "Ban"

# Check auth log for failed SSH attempts
sudo grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -20
```

## 🛡️ Common Jail Recipes

```bash
# Aggressive SSH protection:
# [sshd]
# enabled  = true
# maxretry = 3
# bantime  = 7d
# findtime = 1h

# Incremental ban (ban longer each time):
# [DEFAULT]
# bantime.increment = true                      # Enable incremental bans
# bantime.factor    = 2                         # Double ban time each offense
# bantime.maxtime   = 4w                        # Cap at 4 weeks
# bantime           = 1h                        # Start at 1 hour

# Nginx rate limit / bot protection:
# [nginx-limit-req]
# enabled  = true
# port     = http,https
# logpath  = /var/log/nginx/error.log
# maxretry = 10
# findtime = 1m

# Recidive jail (ban repeat offenders across all jails):
# [recidive]
# enabled  = true
# logpath  = /var/log/fail2ban.log
# bantime  = 4w
# findtime = 1d
# maxretry = 5
```

## 🔗 Common Combos

```bash
# Quick setup from scratch
sudo apt install fail2ban && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local && sudo vim /etc/fail2ban/jail.local

# Check if IP is currently banned (across all jails)
sudo fail2ban-client banned | grep "1.2.3.4"

# Unban IP and whitelist it permanently
sudo fail2ban-client unban 1.2.3.4 && echo "# Add to jail.local [DEFAULT] ignoreip"

# Full status overview
sudo fail2ban-client status && echo "---" && sudo fail2ban-client status sshd

# Check if fail2ban is actually blocking (verify iptables rules)
sudo iptables -L f2b-sshd -n 2>/dev/null || sudo iptables -L -n | grep -i fail2ban

# Verify filter is matching current log format
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf --print-all-matched | tail -20
```

## ⚠️ Gotchas

```bash
# NEVER edit jail.conf or fail2ban.conf — always use jail.local or jail.d/ overrides
# jail.local overrides jail.conf — if you define [sshd] in jail.local, all settings must be there
# ignoreip: ALWAYS whitelist your own IP — you can lock yourself out via SSH
# bantime, findtime accept suffixes: s (seconds), m (minutes), h (hours), d (days), w (weeks)
# fail2ban-regex tests filters but doesn't actually ban — use it for debugging only
# Bans use iptables by default — on systems with nftables/firewalld, change banaction
# After editing jail.local: sudo fail2ban-client reload (not just systemctl reload)
# Check log rotation: if logs rotate, fail2ban may stop monitoring — ensure logpath is correct
```

