# 🧠 grep Cheat Sheet

## 🔍 Basic Usage

```bash
grep "pattern" file.txt              # Search for pattern in a file
grep "pattern" file1 file2           # Search in multiple files
grep "pattern" *.log                 # Search in all .log files
cat file.txt | grep "pattern"        # Search from stdin
```

## ⚙️ Core Flags

```bash
grep -i "pattern" file               # Case-insensitive search
grep -w "pattern" file               # Match whole words only
grep -x "pattern" file               # Match whole lines only
grep -F "literal.string" file        # Fixed string (no regex interpretation)
grep -E "ext(ended|ra)" file         # Extended regex (egrep equivalent)
grep -P "\d{3}-\d{4}" file           # Perl-compatible regex (GNU only)
grep -v "pattern" file               # Invert match (lines NOT matching)
grep -c "pattern" file               # Count matching lines
grep -m 5 "pattern" file             # Stop after first 5 matches
```

## 📁 Recursive Search

```bash
grep -r "pattern" dir/               # Recursive search in directory
grep -R "pattern" dir/               # Recursive, follows symlinks
grep -r --include="*.py" "def " .    # Only search Python files
grep -r --exclude="*.log" "err" .    # Skip log files
grep -r --exclude-dir=node_modules "TODO" .  # Skip directories
grep -r --include="*.list" chrome /etc/apt/  # Search apt sources for chrome
```

## 🧹 Output Control

```bash
grep -n "pattern" file               # Show line numbers
grep -H "pattern" file               # Show filename (default for multi-file)
grep -h "pattern" dir/*              # Hide filenames
grep -l "pattern" *.txt              # List filenames with matches only
grep -L "pattern" *.txt              # List filenames WITHOUT matches
grep -o "pattern" file               # Show only the matched part
grep --color=always "pattern" file   # Force color output (useful when piping)
```

## 🧪 Context Lines

```bash
grep -C 3 "pattern" file             # 3 lines before and after match
grep -B 2 "pattern" file             # 2 lines before match
grep -A 2 "pattern" file             # 2 lines after match
```

## 🧰 Advanced Patterns

```bash
grep "^start" file                   # Lines starting with "start"
grep "end$" file                     # Lines ending with "end"
grep "^$" file                       # Empty lines
grep -E "err|warn|fail" file         # Match any of multiple patterns
grep -e "pat1" -e "pat2" file        # Multiple patterns (OR logic)
grep "pat1" file | grep "pat2"       # Both patterns on same line (AND logic)
grep -P "(?<=@)\w+" file             # Perl lookbehind: word after @
grep -cP "\t" file                   # Count lines containing tabs
```

## 🔗 Common Combos

```bash
grep -r "TODO" . | wc -l                         # Count all TODOs in project
grep -rl "old_func" . | xargs sed -i "s/old_func/new_func/g"  # Rename across files
ps aux | grep "[n]ginx"                           # Find process (excludes grep itself)
grep -rn "FIXME\|TODO\|HACK" --include="*.py" .  # Find all code annotations
history | grep "docker"                           # Search command history
env | grep -i proxy                               # Check proxy environment vars
dmesg | grep -i "error\|fail"                     # Find kernel errors
```

## ⚠️ Gotchas

```bash
# grep uses BRE by default — use -E for extended regex or -P for Perl regex
# On macOS, grep -P is not available — install GNU grep via: brew install grep
# Use grep -F for literal strings containing regex chars like . * [ ]
# Prefer rg (ripgrep) for large codebases — it's faster and respects .gitignore
```

