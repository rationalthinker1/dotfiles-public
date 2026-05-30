# 🧠 fd Cheat Sheet

## 🔍 Basic Usage

```bash
fd                                  # List all files recursively (respects .gitignore)
fd "pattern"                        # Find files matching pattern (regex by default)
fd -g "pattern"                     # Use glob pattern instead of regex
fd "pattern" path/                  # Search in specific directory
fd -F "exact-name"                  # Match fixed string (no regex)
fd --follow "pattern"               # Follow symlinks when traversing directories
```

## 📁 File Type Filters

```bash
fd -t f                             # Files only
fd -t d                             # Directories only
fd -t l                             # Symlinks only
fd -t x                             # Executable files only
fd -t e                             # Empty files and directories
fd -e py                            # Files with .py extension
fd -e py -e js                      # Files with .py or .js extension
fd -E "*.min.js"                    # Exclude files matching pattern
fd -E node_modules                  # Exclude specific directory
```

## 🧹 Output Control

```bash
fd --color always                   # Force color output (useful when piping)
fd -a                               # Show absolute paths
fd -0                               # Null-separated output (safe for xargs -0)
fd -l                               # Long listing format (like ls -l)
fd -1                               # Print only the first match and exit
fd --format "{/}"                   # Print filename only (no path)
fd --format "{//}"                  # Print parent directory only
fd --format "{.}"                   # Print path without extension
```

## 📏 Size and Date Filters

```bash
fd -S +1M                           # Files larger than 1 MB
fd -S -10k                          # Files smaller than 10 KB
fd --changed-within 1d              # Modified in the last day
fd --changed-within 2h              # Modified in the last 2 hours
fd --changed-before "2024-01-01"    # Modified before a specific date
```

## 🔒 Hidden and Ignored Files

```bash
fd -H                               # Include hidden files/dirs (dotfiles)
fd -I                               # Include gitignored files
fd -HI                              # Include everything (hidden + ignored)
fd -u                               # Alias for -HI (unrestricted)
```

## 🧰 Advanced

```bash
fd --max-depth 2                    # Limit search depth
fd --min-depth 2                    # Skip top-level results
fd --prune                          # Don't descend into matched directories
fd --follow                         # Follow symlinks
fd --no-ignore-vcs                  # Ignore .gitignore but respect .fdignore
fd --threads 4                      # Limit number of threads
fd --show-errors                    # Show filesystem errors (permission denied, etc.)
```

## ⚡ Exec and Batch Actions

```bash
fd -e log -x rm {}                  # Delete each .log file one at a time
fd -e jpg -x convert {} {.}.png     # Convert each .jpg to .png
fd -e rs -X wc -l                   # Count lines across all .rs files (single invocation)
fd -e bak -x mv {} {.}             # Remove .bak extension from each file
fd "test" -x echo {/}              # Print only filenames of matches

# Placeholders for -x / -X:
#   {}   Full path          (src/lib/foo.rs)
#   {/}  Filename only      (foo.rs)
#   {//} Parent directory   (src/lib)
#   {.}  Path sans ext      (src/lib/foo)
#   {/.} Filename sans ext  (foo)
```

## 🔗 Common Combos

```bash
fd -e tmp -0 | xargs -0 rm                   # Null-safe delete of all .tmp files
fd -t f -e js | head -20                      # Preview first 20 JS files found
fd -t d -e "" "node_modules" -x rm -rf {}     # Remove all node_modules dirs
fd -H "^\.env" --max-depth 2                  # Find .env files near project root
fd -e go -X wc -l | tail -1                   # Total line count of all Go files
fd -t f --changed-within 30m                  # Files you touched in the last 30 minutes
fd -e py -x grep -l "import os" {}            # Find Python files that import os
```

