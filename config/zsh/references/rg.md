# 🧠 Ripgrep (rg) Cheat Sheet

## 🔍 Basic Usage

```bash
rg "pattern"                # Search for pattern in current directory
rg "pattern" path/          # Search in specific path
rg -i "pattern"             # Case-insensitive search
rg -w "pattern"             # Match whole word
rg -F "pattern"             # Treat pattern as literal string
rg -uuu "pattern"           # Search absolutely everything
```

## 📁 File and Directory Control

```bash
rg --files                 # List all files ripgrep would search
rg --type js "pattern"     # Search only JavaScript files
rg --type-add 'foo:*.foo' -tfoo "pattern"  # Define custom type and use it (not persistent)
rg --hidden "pattern"      # Include hidden files
rg --no-ignore "pattern"   # Ignore .gitignore and .ignore
```

## 🧹 Output Control

```bash
rg -n "pattern"            # Show line numbers
rg -H "pattern"            # Show filename
rg -o "pattern"            # Show only matched text
rg -v "pattern"            # Invert match (exclude pattern)
rg -l "pattern"            # List matching files only
rg -c "pattern"            # Count matching lines per file
rg --count-matches "pat"   # Count individual matches per file
rg --color always "pat"    # Force color output
```

## 🧪 Regex and Context

```bash
rg "^start"                # Match lines starting with "start"
rg "end$"                  # Match lines ending with "end"
rg -C 3 "pattern"          # Show 3 lines of context around match
rg -B 2 "pattern"          # Show 2 lines before match
rg -A 2 "pattern"          # Show 2 lines after match
```

## 🧰 Advanced

```bash
rg --debug "pattern"       # Show debug info
rg --stats "pattern"       # Show search stats
rg --threads 4 "pattern"   # Limit number of threads
rg --max-filesize 1M "pat" # Skip files larger than 1MB
rg --glob "*.js" "pattern"      # Include only .js files
rg --glob "!*.test.js" "pattern" # Exclude test files
```

## ⚙️ Active Defaults (from $RIPGREP_CONFIG_PATH = ~/.config/ripgrep/.ripgreprc)

```bash
# These are always ON — no need to pass them manually:
--smart-case          # Case-sensitive only when pattern has uppercase
--hidden              # Include hidden files/dirs
--follow              # Follow symlinks
--trim                # Strip leading whitespace from each output line
--one-file-system     # Don't cross filesystem boundaries (safe in WSL)
--max-columns=150     # Truncate long lines (preview shown instead)
--max-columns-preview # Show truncated line preview when limit hit
```

## 📦 Custom Types (from $RIPGREP_CONFIG_PATH)

```bash
rg --type web "pattern"     # *.{html,css,scss,js,ts,tsx,jsx,vue}
rg --type config "pattern"  # *.{json,yaml,yml,toml,ini,env}
rg --type log "pattern"     # *.{log,logs,out}
```

## 🚫 Auto-Excluded Globs (from $RIPGREP_CONFIG_PATH)

```bash
# Always skipped: .git, node_modules, bower_components, vendor, build,
# bundle, oh-my-zsh, antigen, .npm, .cache, dist, coverage,
# .next, .nuxt, .yarn, .pnp.*, __pycache__, .venv
# Also: *.bak, *.zip, *.min.js, *.min.css, *.min.map, .tags,
#        package-lock.json, *.{lock,svg,jpg,png,pdf,gif}, *.pyc
```

