# 🧠 find Cheat Sheet

## 🔍 Basic Usage

```bash
find .                                          # List all files recursively
find /var/log                                   # List all files under /var/log
find . -name "*.log"                            # Find files by name (case-sensitive)
find . -iname "*.jpg"                           # Find files by name (case-insensitive)
find . -path "*/src/*.js"                       # Match against full path
```

## 📁 Type Filters

```bash
find . -type f                                  # Files only
find . -type d                                  # Directories only
find . -type l                                  # Symbolic links only
find . -type f -name "*.py"                     # Python files only
```

## 📏 Size Filters

```bash
find . -size +100M                              # Files larger than 100 MB
find . -size -10k                               # Files smaller than 10 KB
find . -size 0                                  # Empty files (zero bytes)
find . -empty                                   # Empty files AND empty directories
find . -type f -size +1G                        # Files over 1 GB
```

## ⏱️ Time Filters

```bash
find . -mtime -1                                # Modified in last 24 hours
find . -mtime +30                               # Modified more than 30 days ago
find . -mmin -60                                # Modified in last 60 minutes
find . -atime -7                                # Accessed in last 7 days
find . -newer reference.txt                     # Modified after reference.txt
find . -newermt "2024-01-01"                    # Modified after date (GNU find)
```

## 🔒 Permission and Ownership

```bash
find . -perm 755                                # Exact permission match
find . -perm -u+x                               # User has execute permission
find . -perm /u+x,g+x                           # User OR group has execute
find . -user raza                               # Owned by user
find . -group www-data                          # Owned by group
find . -nouser                                  # Files with no matching user (orphaned)
find . -nogroup                                 # Files with no matching group
```

## 🚫 Excluding and Pruning

```bash
find . -not -name "*.log"                       # Exclude by name
find . ! -name "*.tmp"                          # Same as -not (alternate syntax)
find . -name "*.js" -not -path "*/node_modules/*"           # Exclude directory from results
find . -path "*/node_modules" -prune -o -name "*.js" -print # Prune directory (faster, stops descent)
find . \( -path "./.git" -o -path "./node_modules" \) -prune -o -type f -print  # Prune multiple dirs
```

## 📊 Depth Control

```bash
find . -maxdepth 1                              # Current directory only (no recursion)
find . -maxdepth 2                              # At most 2 levels deep
find . -mindepth 2                              # Skip top-level results
find . -mindepth 1 -maxdepth 1 -type d         # Immediate subdirectories only
```

## ⚡ Actions (-exec, -delete, -print)

```bash
find . -name "*.tmp" -delete                    # Delete matching files
find . -name "*.sh" -exec chmod +x {} \;        # Run command on each match (one at a time)
find . -name "*.log" -exec rm {} +              # Run command in batches (faster, like xargs)
find . -type f -exec grep -l "TODO" {} +        # Find files containing "TODO"
find . -name "*.bak" -exec mv {} /tmp/ \;       # Move all .bak files to /tmp
find . -type f -name "*.txt" -exec wc -l {} +   # Count lines in all .txt files
find . -name "*.jpg" -execdir convert {} {}.png \;  # Run in file's directory (not cwd)
```

## 🖨️ Output Formatting

```bash
find . -type f -printf "%s %p\n"                # Print size and path (GNU find)
find . -type f -printf "%T@ %p\n" | sort -rn    # Sort by modification time (newest first)
find . -type f -printf "%u %p\n"                # Print owner and path
find . -print0                                  # Null-delimited output (for xargs -0)
find . -ls                                      # ls-style output (permissions, size, date)
```

## 🔗 Common Combos

```bash
# Find and delete all .log files older than 7 days
find /var/log -name "*.log" -mtime +7 -delete

# Find large files sorted by size
find . -type f -size +10M -printf "%s %p\n" | sort -rn | head -20

# Null-safe piping to xargs
find . -name "*.tmp" -print0 | xargs -0 rm

# Find duplicate filenames
find . -type f -printf "%f\n" | sort | uniq -d

# Find files modified today
find . -type f -daystart -mtime 0

# Find broken symlinks
find . -type l ! -exec test -e {} \; -print

# Find world-writable files (security audit)
find / -type f -perm -o+w 2>/dev/null

# Find setuid binaries (security audit)
find / -type f -perm -4000 2>/dev/null

# Find and replace text across files
find . -name "*.py" -exec sed -i 's/old_func/new_func/g' {} +

# Cleanup empty directories recursively (bottom-up)
find . -type d -empty -delete

# Copy directory structure without files
find src/ -type d -exec mkdir -p dest/{} \;
```

## 🆚 find vs fd

```bash
# find — POSIX, available everywhere, complex but powerful
# fd   — faster, simpler syntax, respects .gitignore, colored output
# Use find for: scripts, servers without fd, complex predicates (-perm, -user, -newer)
# Use fd for: interactive use, quick searches, modern systems
```

## ⚠️ Gotchas

```bash
# -exec {} \; runs one process per file — -exec {} + batches (much faster)
# -delete implies -depth (processes children before parents)
# Always test with -print before -delete or -exec rm
# -name uses shell glob patterns (not regex) — use -regex for regex
# -prune stops descent into directory — must come before other tests in expression
# GNU find vs BSD find (macOS): -printf, -regex, -daystart are GNU extensions
```

