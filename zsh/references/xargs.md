# 🧠 xargs Cheat Sheet

## 🔍 Basic Usage

```bash
echo "one two three" | xargs echo          # Pass words as args: echo one two three
echo "one\ntwo\nthree" | xargs echo        # Newlines also split: echo one two three
echo "  hello  " | xargs                    # Trims whitespace: hello
cat urls.txt | xargs curl -O               # Download each URL listed in file
```

## ⚙️ Core Flags

```bash
xargs -n 1              # Pass one arg at a time (one per invocation)
xargs -n 3              # Pass three args per invocation
xargs -L 1              # One input line per invocation (preserves spaces in line)
xargs -I {}             # Replace {} with each input item (implies -L 1)
xargs -0                # Null-delimited input (handles spaces/newlines in names)
xargs -P 4              # Run up to 4 processes in parallel
xargs -t                # Print each command before executing (debug)
xargs -p                # Prompt before each execution (interactive)
xargs --no-run-if-empty # Skip execution if input is empty (GNU, -r on some systems)
```

## 📁 xargs + fd (find files, act on them)

```bash
fd -t f ".log"  | xargs rm                           # Delete all .log files
fd -t f ".bak"  | xargs -I {} mv {} {}.old           # Rename .bak to .bak.old
fd -t f ".ts" src/ | xargs wc -l                     # Count lines in all .ts files
fd -t f ".json" | xargs -n 1 jq ".version"           # Extract version from each JSON
fd -0 -t f ".tmp" | xargs -0 rm                      # Null-safe delete (spaces in names)
fd -t f -e png | xargs -P 4 -I {} convert {} {}.webp # Parallel image conversion
```

## 🔎 xargs + rg/grep (search results as input)

```bash
rg -l "TODO" | xargs sed -i "s/TODO/DONE/g"          # Replace TODO in matching files
rg -l "deprecated" | xargs -I {} head -5 {}           # Show first 5 lines of matches
rg -l "console.log" src/ | xargs wc -l                # Line count of files with console.log
grep -rl "old_func" . | xargs sed -i "s/old_func/new_func/g"  # Rename function across files
```

## 🔧 xargs + find (classic POSIX combo)

```bash
find . -name "*.log" -print0 | xargs -0 rm            # Null-safe delete
find . -name "*.sh" -print0 | xargs -0 chmod +x       # Make all .sh files executable
find . -type f -newer ref.txt | xargs ls -l            # List files newer than ref.txt
find . -empty -type d -print0 | xargs -0 rmdir         # Remove empty directories
```

## 📦 xargs + git

```bash
git diff --name-only | xargs wc -l                     # Line count of changed files
git diff --name-only | xargs -I {} git checkout -- {}   # Discard changes file-by-file
git ls-files -d | xargs git checkout --                 # Restore deleted tracked files
git log --format="%ae" | sort -u | xargs -I {} echo {}  # List unique committer emails
git stash list | grep -oP "stash@\{\d+\}" | head -5 | xargs -I {} git stash show {} # Show recent stashes
```

## 🐳 xargs + docker

```bash
docker ps -q | xargs docker stop                       # Stop all running containers
docker images -q -f dangling=true | xargs docker rmi   # Remove dangling images
docker volume ls -q | xargs -I {} docker volume inspect {} # Inspect all volumes
```

## 🌐 xargs + curl/wget

```bash
cat urls.txt | xargs -P 8 -I {} curl -sO {}            # Parallel download (8 at a time)
cat domains.txt | xargs -I {} dig +short {}             # DNS lookup for each domain
cat endpoints.txt | xargs -P 4 -I {} curl -sw "%{http_code} {}\n" -o /dev/null {} # Check HTTP status codes
```

## 📋 xargs + text processing

```bash
cat file.txt | xargs -n 1 | sort | uniq -c | sort -rn  # Word frequency count
echo "1 2 3 4 5" | xargs -n 1 | awk "{sum+=\$1} END {print sum}" # Sum numbers
ls *.csv | xargs -I {} sh -c 'echo "=== {} ===" && head -1 {}'    # Show header of each CSV
```

## 🧰 Advanced Patterns

```bash
# Batch rename: prepend "backup_" to all .conf files
fd -t f -e conf | xargs -I {} bash -c 'mv "$1" "$(dirname "$1")/backup_$(basename "$1")"' _ {}

# Parallel compression of large files
fd -t f -S +100M | xargs -P 4 -I {} gzip {}

# Run a command for each line, using the line as part of a URL
cat ids.txt | xargs -I {} curl -s "https://api.example.com/item/{}" | jq ".name"

# Multiple commands per input (use sh -c)
echo "a b c" | xargs -n 1 -I {} sh -c 'echo "Processing: {}" && touch {}.txt'

# Combine with tee to log and process
fd -t f ".log" | tee /dev/stderr | xargs wc -l   # See file list AND get line counts

# Cap total args to avoid "Argument list too long"
find . -name "*.tmp" -print0 | xargs -0 -n 100 rm  # Delete in batches of 100
```

## ⚠️ Gotchas

```bash
# Spaces in filenames break xargs — always use -0 with null-delimited input
fd -0 "pattern" | xargs -0 cmd         # Safe
find . -print0 | xargs -0 cmd          # Safe
# -I {} implies -L 1 (one line at a time) — no need to also pass -n 1
# GNU xargs: --no-run-if-empty / -r   macOS xargs: does nothing if empty by default
# -P (parallel) output may interleave — pipe through sort if order matters
```

