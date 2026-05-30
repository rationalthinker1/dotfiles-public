# Additional Portable Tools for Restricted Seedbox

This document lists additional portable tools that can be installed in the restricted seedbox environment (HOME="/", no sudo, no package managers). All tools install to `/.local/bin/` and work without system dependencies.

---

## File Transfer & Sync

### 1. **rclone** (already available via install.sh)
**Description:** Rsync for cloud storage - sync files with Google Drive, S3, Dropbox, etc.

**Installation:**
```bash
cd /tmp
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cp rclone-*/rclone /.local/bin/
chmod +x /.local/bin/rclone
```

**Usage:**
```bash
# Configure cloud storage
rclone config

# List files in remote
rclone ls remote:path

# Sync local to remote
rclone sync /local/path remote:path

# Mount remote as filesystem
rclone mount remote:path /mnt/point
```

**Why useful:** Transfer files between seedbox and cloud storage without using disk space.

---

### 2. **rsync** (system package - already installed)
**Description:** Fast incremental file transfer tool.

**Usage:**
```bash
# Sync directories
rsync -avz /source/ /destination/

# Sync to remote server
rsync -avz /local/path user@remote:/remote/path

# Dry run (show what would be transferred)
rsync -avzn /source/ /destination/
```

**Why useful:** Efficient file transfers with resume support.

---

## Archive & Compression

### 3. **zstd** (Zstandard)
**Description:** Fast compression algorithm (better than gzip, similar to xz).

**Installation:**
```bash
cd /tmp
wget https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-1.5.5-linux-x86_64.tar.gz
tar -xzf zstd-1.5.5-linux-x86_64.tar.gz
cp zstd-1.5.5-linux-x86_64/zstd /.local/bin/
chmod +x /.local/bin/zstd
```

**Usage:**
```bash
# Compress file
zstd file.txt

# Decompress
zstd -d file.txt.zst

# Ultra compression (slow but best ratio)
zstd -19 file.txt

# Compress tar archives
tar -I zstd -cf archive.tar.zst directory/
```

**Why useful:** Faster compression than gzip with better ratios. Great for compressing large files before transfer.

---

### 4. **pigz** (Parallel gzip)
**Description:** Multi-threaded gzip replacement.

**Installation:**
```bash
cd /tmp
wget https://zlib.net/pigz/pigz-2.8.tar.gz
tar -xzf pigz-2.8.tar.gz
cd pigz-2.8
# Compile (requires build tools)
make
cp pigz unpigz /.local/bin/
```

**Usage:**
```bash
# Compress using all CPU cores
pigz file.txt

# Decompress
unpigz file.txt.gz

# Compress with specific thread count
pigz -p 4 file.txt
```

**Why useful:** 3-4x faster compression than gzip on multi-core systems.

---

## Network Utilities

### 5. **mtr** (My Traceroute)
**Description:** Network diagnostic tool combining ping and traceroute.

**Installation:**
```bash
# Requires system package (not portable)
# Already available on most systems
mtr --version
```

**Usage:**
```bash
# Interactive traceroute
mtr google.com

# Report mode (10 cycles)
mtr -r -c 10 google.com

# No DNS resolution (faster)
mtr -n google.com
```

**Why useful:** Diagnose network issues and latency problems.

---

### 6. **nmap** (Network Mapper)
**Description:** Network scanning and security auditing tool.

**Installation:**
```bash
# Requires system package (not easily portable)
# May already be installed
nmap --version
```

**Usage:**
```bash
# Scan ports on host
nmap -p 1-65535 localhost

# Fast scan (common ports)
nmap -F localhost

# Detect OS and services
nmap -A localhost
```

**Why useful:** Check open ports on your seedbox, verify firewall rules.

---

### 7. **socat** (SOcket CAT)
**Description:** Advanced networking tool, like netcat on steroids.

**Installation:**
```bash
cd /tmp
wget http://www.dest-unreach.org/socat/download/socat-1.8.0.0.tar.gz
tar -xzf socat-1.8.0.0.tar.gz
cd socat-1.8.0.0
./configure --prefix=/.local
make && make install
```

**Usage:**
```bash
# Port forwarding
socat TCP-LISTEN:8080,fork TCP:localhost:80

# Simple HTTP server
socat TCP-LISTEN:8000,fork SYSTEM:'echo HTTP/1.1 200 OK; echo; echo "Hello"'

# Connect to serial device
socat /dev/ttyUSB0,raw,echo=0 STDOUT
```

**Why useful:** Advanced port forwarding and tunneling.

---

## Terminal & Multiplexers

### 8. **tmux** (already available)
**Description:** Terminal multiplexer - run multiple terminal sessions.

**Usage:**
```bash
# Create new session
tmux new -s mysession

# List sessions
tmux ls

# Attach to session
tmux attach -t mysession

# Detach from session
# Press: Ctrl+B, then D

# Split pane horizontally
# Press: Ctrl+B, then "

# Split pane vertically
# Press: Ctrl+B, then %
```

**Why useful:** Keep processes running after disconnect, work with multiple terminals.

---

### 9. **screen** (GNU Screen)
**Description:** Alternative to tmux, older but widely available.

**Installation:**
```bash
# Usually pre-installed
screen --version
```

**Usage:**
```bash
# Start new session
screen -S mysession

# Detach from session
# Press: Ctrl+A, then D

# List sessions
screen -ls

# Reattach to session
screen -r mysession
```

**Why useful:** Simpler than tmux, good for basic session management.

---

## Text Processing & Search

### 10. **ag** (The Silver Searcher)
**Description:** Code search tool, faster than ack.

**Installation:**
```bash
cd /tmp
wget https://github.com/ggreer/the_silver_searcher/archive/refs/tags/2.2.0.tar.gz
tar -xzf 2.2.0.tar.gz
cd the_silver_searcher-2.2.0
./configure --prefix=/.local
make && make install
```

**Usage:**
```bash
# Search for pattern in current directory
ag "TODO"

# Search specific file types
ag --python "def.*function"

# Case-insensitive search
ag -i "error"

# Show context (2 lines before/after)
ag -C 2 "pattern"
```

**Why useful:** Fast code search (faster than grep, but slower than ripgrep).

---

### 11. **ack**
**Description:** Grep-like tool optimized for programmers.

**Installation:**
```bash
cd /tmp
curl https://beyondgrep.com/ack-v3.7.0 > ack
chmod +x ack
mv ack /.local/bin/
```

**Usage:**
```bash
# Search in current directory
ack "pattern"

# Search specific file type
ack --python "import"

# List file types
ack --help-types
```

**Why useful:** Respects .gitignore, searches only source files by default.

---

### 12. **jless** (JSON viewer)
**Description:** Interactive JSON viewer for terminal.

**Installation:**
```bash
cd /tmp
wget https://github.com/PaulJuliusMartinez/jless/releases/download/v0.9.0/jless-v0.9.0-x86_64-unknown-linux-gnu.zip
unzip jless-v0.9.0-x86_64-unknown-linux-gnu.zip
cp jless /.local/bin/
chmod +x /.local/bin/jless
```

**Usage:**
```bash
# View JSON file
jless data.json

# View JSON from API
curl https://api.github.com/repos/cli/cli | jless

# Navigate with vim keys (j/k to scroll, / to search)
```

**Why useful:** Better JSON viewing than less or cat, especially for large files.

---

### 13. **miller** (mlr)
**Description:** Like awk/sed/cut/join for CSV, TSV, JSON files.

**Installation:**
```bash
cd /tmp
wget https://github.com/johnkerl/miller/releases/download/v6.10.0/miller-6.10.0-linux-amd64.tar.gz
tar -xzf miller-6.10.0-linux-amd64.tar.gz
cp miller-6.10.0/mlr /.local/bin/
chmod +x /.local/bin/mlr
```

**Usage:**
```bash
# Convert CSV to JSON
mlr --csv --json cat data.csv

# Filter CSV rows
mlr --csv filter '$age > 30' data.csv

# Statistics on CSV column
mlr --csv stats1 -a mean,sum -f price data.csv

# Pretty-print CSV
mlr --csv --opprint cat data.csv
```

**Why useful:** Swiss army knife for working with structured data.

---

## Database Tools

### 14. **sqlite3** (already available)
**Description:** Lightweight SQL database engine.

**Usage:**
```bash
# Create/open database
sqlite3 mydb.db

# Run SQL from command line
sqlite3 mydb.db "SELECT * FROM users;"

# Import CSV
sqlite3 mydb.db ".mode csv" ".import data.csv users"

# Export to CSV
sqlite3 -header -csv mydb.db "SELECT * FROM users;" > users.csv
```

**Why useful:** Manage local databases, query data files.

---

### 15. **usql** (Universal SQL CLI)
**Description:** Universal command-line interface for databases (PostgreSQL, MySQL, SQLite, etc.).

**Installation:**
```bash
cd /tmp
wget https://github.com/xo/usql/releases/download/v0.14.8/usql-0.14.8-linux-amd64.tar.bz2
tar -xjf usql-0.14.8-linux-amd64.tar.bz2
cp usql /.local/bin/
chmod +x /.local/bin/usql
```

**Usage:**
```bash
# Connect to SQLite
usql sqlite://mydb.db

# Connect to PostgreSQL
usql postgres://user:pass@host/dbname

# Execute query
usql sqlite://mydb.db -c "SELECT * FROM users;"
```

**Why useful:** One tool for all databases, better than individual CLIs.

---

## Version Control (Git Enhancements)

### 16. **tig**
**Description:** Text-mode interface for git.

**Installation:**
```bash
cd /tmp
wget https://github.com/jonas/tig/releases/download/tig-2.5.8/tig-2.5.8.tar.gz
tar -xzf tig-2.5.8.tar.gz
cd tig-2.5.8
./configure --prefix=/.local
make && make install
```

**Usage:**
```bash
# Browse git log
tig

# Show git status
tig status

# Show git blame for file
tig blame file.txt

# Show stash
tig stash
```

**Why useful:** Interactive git log browser, easier than lazygit for quick checks.

---

### 17. **git-filter-repo**
**Description:** Fast tool for rewriting git history.

**Installation:**
```bash
cd /tmp
wget https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo
chmod +x git-filter-repo
mv git-filter-repo /.local/bin/
```

**Usage:**
```bash
# Remove file from entire git history
git filter-repo --invert-paths --path secrets.txt

# Replace text in entire history
git filter-repo --replace-text replacements.txt

# Remove large files
git filter-repo --strip-blobs-bigger-than 10M
```

**Why useful:** Clean up git repos, remove sensitive data from history.

---

## Media & Format Conversion

### 18. **ffmpeg** (if available)
**Description:** Audio/video converter and processor.

**Installation:**
```bash
cd /tmp
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar -xJf ffmpeg-release-amd64-static.tar.xz
cp ffmpeg-*-amd64-static/ffmpeg /.local/bin/
cp ffmpeg-*-amd64-static/ffprobe /.local/bin/
chmod +x /.local/bin/ffmpeg /.local/bin/ffprobe
```

**Usage:**
```bash
# Convert video format
ffmpeg -i input.mkv output.mp4

# Extract audio from video
ffmpeg -i video.mp4 -vn audio.mp3

# Compress video
ffmpeg -i input.mp4 -vcodec libx265 -crf 28 output.mp4

# Get video info
ffprobe video.mp4
```

**Why useful:** Convert/compress media files on seedbox before download.

---

### 19. **imagemagick** (convert)
**Description:** Image manipulation tool.

**Installation:**
```bash
# Requires system package (not easily portable)
# Check if available
convert --version
```

**Usage:**
```bash
# Resize image
convert input.jpg -resize 800x600 output.jpg

# Convert format
convert input.png output.jpg

# Create thumbnail
convert input.jpg -thumbnail 200x200 thumb.jpg

# Combine images
convert img1.jpg img2.jpg +append combined.jpg
```

**Why useful:** Batch process images, create thumbnails.

---

## Security & Encryption

### 20. **age**
**Description:** Simple, modern encryption tool (alternative to GPG).

**Installation:**
```bash
cd /tmp
wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar -xzf age-v1.1.1-linux-amd64.tar.gz
cp age/age age/age-keygen /.local/bin/
chmod +x /.local/bin/age /.local/bin/age-keygen
```

**Usage:**
```bash
# Generate key pair
age-keygen -o key.txt

# Encrypt file
age -r $(cat key.txt | grep public) file.txt > file.txt.age

# Decrypt file
age -d -i key.txt file.txt.age > file.txt

# Encrypt with passphrase
age -p file.txt > file.txt.age
```

**Why useful:** Simpler than GPG, great for encrypting backups.

---

### 21. **sops** (Secrets OPerationS)
**Description:** Encrypt specific values in YAML/JSON files.

**Installation:**
```bash
cd /tmp
wget https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64
mv sops-v3.8.1.linux.amd64 /.local/bin/sops
```

**Usage:**
```bash
# Encrypt YAML file
sops -e secrets.yaml > secrets.enc.yaml

# Decrypt YAML file
sops -d secrets.enc.yaml > secrets.yaml

# Edit encrypted file
sops secrets.enc.yaml
```

**Why useful:** Encrypt config files while keeping them readable/diffable.

---

## Development Tools

### 22. **direnv**
**Description:** Load/unload environment variables based on directory.

**Installation:**
```bash
cd /tmp
wget https://github.com/direnv/direnv/releases/download/v2.33.0/direnv.linux-amd64
chmod +x direnv.linux-amd64
mv direnv.linux-amd64 /.local/bin/direnv
```

**Setup:**
```bash
# Add to .bashrc
eval "$(direnv hook bash)"
```

**Usage:**
```bash
# Create .envrc in project directory
echo 'export DATABASE_URL=postgresql://localhost/mydb' > .envrc

# Allow .envrc
direnv allow

# Variables auto-load when entering directory
cd project/
echo $DATABASE_URL  # Shows value

# Auto-unload when leaving
cd ..
echo $DATABASE_URL  # Empty
```

**Why useful:** Per-project environment variables without polluting global env.

---

### 23. **watchexec**
**Description:** Run commands when files change.

**Installation:**
```bash
cd /tmp
wget https://github.com/watchexec/watchexec/releases/download/v1.24.1/watchexec-1.24.1-x86_64-unknown-linux-musl.tar.xz
tar -xJf watchexec-1.24.1-x86_64-unknown-linux-musl.tar.xz
cp watchexec-1.24.1-x86_64-unknown-linux-musl/watchexec /.local/bin/
chmod +x /.local/bin/watchexec
```

**Usage:**
```bash
# Run tests when files change
watchexec pytest

# Watch specific files
watchexec -w src/ -w tests/ npm test

# Run multiple commands
watchexec -w . 'make clean && make build'

# Clear screen before each run
watchexec -c pytest
```

**Why useful:** Auto-run tests, rebuild projects on file changes.

---

### 24. **entr**
**Description:** Run arbitrary commands when files change (lighter than watchexec).

**Installation:**
```bash
cd /tmp
wget https://eradman.com/entrproject/code/entr-5.5.tar.gz
tar -xzf entr-5.5.tar.gz
cd entr-5.5
./configure
make && make install PREFIX=/.local
```

**Usage:**
```bash
# Watch files and run command
ls *.py | entr pytest

# Restart server on change
ls *.js | entr -r node server.js

# Run shell command
find . -name '*.py' | entr sh -c 'pytest && echo "Tests passed"'
```

**Why useful:** Simpler than watchexec, lower resource usage.

---

### 25. **just** (command runner)
**Description:** Modern alternative to make for project tasks.

**Installation:**
```bash
cd /tmp
wget https://github.com/casey/just/releases/download/1.22.1/just-1.22.1-x86_64-unknown-linux-musl.tar.gz
tar -xzf just-1.22.1-x86_64-unknown-linux-musl.tar.gz
cp just /.local/bin/
chmod +x /.local/bin/just
```

**Usage:**
```bash
# Create justfile
cat > justfile << 'EOF'
# Run tests
test:
    pytest tests/

# Build project
build:
    cargo build --release

# Deploy
deploy: test build
    ./deploy.sh
EOF

# List available commands
just --list

# Run command
just test
```

**Why useful:** Simpler syntax than Makefiles, better for scripting.

---

## Miscellaneous Utilities

### 26. **fselect**
**Description:** Find files using SQL-like syntax.

**Installation:**
```bash
cd /tmp
wget https://github.com/jhspetersson/fselect/releases/download/0.8.5/fselect-x86_64-linux-musl.gz
gunzip fselect-x86_64-linux-musl.gz
chmod +x fselect-x86_64-linux-musl
mv fselect-x86_64-linux-musl /.local/bin/fselect
```

**Usage:**
```bash
# Find large files
fselect size, path from /downloads where size > 1GB

# Find recent files
fselect path, modified from . where modified > DATE('2024-01-01')

# Complex query
fselect name, size from . where name like '%.mp4' and size > 100MB order by size desc
```

**Why useful:** Find files with SQL queries instead of complex find commands.

---

### 27. **glow**
**Description:** Markdown renderer for terminal.

**Installation:**
```bash
cd /tmp
wget https://github.com/charmbracelet/glow/releases/download/v1.5.1/glow_1.5.1_linux_x86_64.tar.gz
tar -xzf glow_1.5.1_linux_x86_64.tar.gz
cp glow /.local/bin/
chmod +x /.local/bin/glow
```

**Usage:**
```bash
# Render markdown file
glow README.md

# Read from stdin
echo "# Hello" | glow -

# Pager mode
glow -p README.md
```

**Why useful:** Read markdown documentation in terminal with nice formatting.

---

### 28. **grex**
**Description:** Generate regex from test cases.

**Installation:**
```bash
cd /tmp
wget https://github.com/pemistahl/grex/releases/download/v1.4.5/grex-v1.4.5-x86_64-unknown-linux-musl.tar.gz
tar -xzf grex-v1.4.5-x86_64-unknown-linux-musl.tar.gz
cp grex /.local/bin/
chmod +x /.local/bin/grex
```

**Usage:**
```bash
# Generate regex from examples
grex "2024-01-01" "2024-12-31"
# Output: ^2024-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$

# Generate regex for file names
grex "file-001.txt" "file-042.txt" "file-999.txt"
```

**Why useful:** Create regex patterns without learning regex syntax.

---

### 29. **hexyl**
**Description:** Hex viewer with nice output.

**Installation:**
```bash
cd /tmp
wget https://github.com/sharkdp/hexyl/releases/download/v0.14.0/hexyl-v0.14.0-x86_64-unknown-linux-musl.tar.gz
tar -xzf hexyl-v0.14.0-x86_64-unknown-linux-musl.tar.gz
cp hexyl-v0.14.0-x86_64-unknown-linux-musl/hexyl /.local/bin/
chmod +x /.local/bin/hexyl
```

**Usage:**
```bash
# View file in hex
hexyl file.bin

# Show specific byte range
hexyl --skip 100 --length 50 file.bin

# No colors
hexyl --plain file.bin
```

**Why useful:** Inspect binary files, debug file formats.

---

### 30. **xsv**
**Description:** Fast CSV command line toolkit (alternative to miller).

**Installation:**
```bash
cd /tmp
wget https://github.com/BurntSushi/xsv/releases/download/0.13.0/xsv-0.13.0-x86_64-unknown-linux-musl.tar.gz
tar -xzf xsv-0.13.0-x86_64-unknown-linux-musl.tar.gz
cp xsv /.local/bin/
chmod +x /.local/bin/xsv
```

**Usage:**
```bash
# Show CSV statistics
xsv stats data.csv

# Select specific columns
xsv select name,age data.csv

# Search in CSV
xsv search "pattern" data.csv

# Convert to JSON
xsv fmt -t json data.csv

# Join two CSV files
xsv join id file1.csv id file2.csv
```

**Why useful:** Blazing fast CSV processing, simpler than miller for basic tasks.

---

### 31. **pv** (Pipe Viewer)
**Description:** Monitor progress of data through pipes.

**Installation:**
```bash
cd /tmp
wget http://www.ivarch.com/programs/sources/pv-1.8.5.tar.gz
tar -xzf pv-1.8.5.tar.gz
cd pv-1.8.5
./configure --prefix=/.local
make && make install
```

**Usage:**
```bash
# Show progress while copying
pv largefile.iso > /destination/largefile.iso

# Show progress in pipe
cat largefile | pv | gzip > file.gz

# Monitor transfer rate
pv -pterb input.file > output.file
```

**Why useful:** See progress and speed of long-running operations.

---

### 32. **ncdu** (NCurses Disk Usage)
**Description:** Interactive disk usage analyzer.

**Installation:**
```bash
cd /tmp
wget https://dev.yorhel.nl/download/ncdu-2.3.tar.gz
tar -xzf ncdu-2.3.tar.gz
cd ncdu-2.3
./configure --prefix=/.local
make && make install
```

**Usage:**
```bash
# Analyze current directory
ncdu

# Analyze specific directory
ncdu /downloads

# Navigate with arrow keys, press 'd' to delete, 'q' to quit
```

**Why useful:** Find large files interactively, clean up disk space.

---

### 33. **aria2**
**Description:** Multi-protocol download utility (HTTP, FTP, BitTorrent).

**Installation:**
```bash
cd /tmp
wget https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-linux-gnu-64bit-build1.tar.bz2
tar -xjf aria2-1.37.0-linux-gnu-64bit-build1.tar.bz2
cp aria2-1.37.0-linux-gnu-64bit-build1/aria2c /.local/bin/
chmod +x /.local/bin/aria2c
```

**Usage:**
```bash
# Download file (16 connections)
aria2c -x 16 https://example.com/file.iso

# Download torrent
aria2c file.torrent

# Resume download
aria2c -c https://example.com/file.iso

# Limit download speed
aria2c --max-download-limit=1M https://example.com/file.iso
```

**Why useful:** Faster downloads than wget/curl, resume support, torrent support.

---

### 34. **croc**
**Description:** Secure file transfer between computers.

**Installation:**
```bash
cd /tmp
wget https://github.com/schollz/croc/releases/download/v9.6.16/croc_9.6.16_Linux-64bit.tar.gz
tar -xzf croc_9.6.16_Linux-64bit.tar.gz
cp croc /.local/bin/
chmod +x /.local/bin/croc
```

**Usage:**
```bash
# Send file
croc send myfile.txt
# Output: Code is: 1234-code-word

# Receive file (on another machine)
croc 1234-code-word

# Send with custom code
croc send --code my-secret-code myfile.txt
```

**Why useful:** Easy peer-to-peer file transfer without setting up servers.

---

### 35. **gping**
**Description:** Ping with a graph.

**Installation:**
```bash
cd /tmp
wget https://github.com/orf/gping/releases/download/gping-v1.16.0/gping-x86_64-unknown-linux-musl.tar.gz
tar -xzf gping-x86_64-unknown-linux-musl.tar.gz
cp gping /.local/bin/
chmod +x /.local/bin/gping
```

**Usage:**
```bash
# Ping with graph
gping google.com

# Ping multiple hosts
gping google.com cloudflare.com

# Show graph only
gping --simple-graphics google.com
```

**Why useful:** Visual ping, easier to see latency patterns.

---

### 36. **oha** (HTTP load testing)
**Description:** HTTP load generator (alternative to ab/wrk).

**Installation:**
```bash
cd /tmp
wget https://github.com/hatoo/oha/releases/download/v1.4.3/oha-linux-amd64
chmod +x oha-linux-amd64
mv oha-linux-amd64 /.local/bin/oha
```

**Usage:**
```bash
# 10,000 requests with 50 concurrent connections
oha -n 10000 -c 50 http://localhost:8080

# 30 second load test
oha -z 30s http://localhost:8080

# With custom headers
oha -H "Authorization: Bearer token" http://localhost:8080/api
```

**Why useful:** Test API performance, benchmark web servers.

---

### 37. **difftastic**
**Description:** Structural diff tool (understands syntax).

**Installation:**
```bash
cd /tmp
wget https://github.com/Wilfred/difftastic/releases/download/0.54.0/difft-x86_64-unknown-linux-gnu.tar.gz
tar -xzf difft-x86_64-unknown-linux-gnu.tar.gz
cp difft /.local/bin/
chmod +x /.local/bin/difft
```

**Usage:**
```bash
# Compare files
difft file1.py file2.py

# Use with git
GIT_EXTERNAL_DIFF=difft git diff

# Compare directories
difft dir1/ dir2/
```

**Why useful:** Better diffs for code, understands programming languages.

---

### 38. **jnv** (Interactive JSON filter)
**Description:** Interactive jq alternative.

**Installation:**
```bash
cd /tmp
wget https://github.com/ynqa/jnv/releases/download/v0.1.3/jnv-x86_64-unknown-linux-musl.tar.xz
tar -xJf jnv-x86_64-unknown-linux-musl.tar.xz
cp jnv /.local/bin/
chmod +x /.local/bin/jnv
```

**Usage:**
```bash
# Interactive JSON browsing
cat data.json | jnv

# Use arrow keys to navigate, press '/' to filter
```

**Why useful:** Easier than jq for exploring JSON data.

---

### 39. **viddy** (Modern watch)
**Description:** Modern alternative to watch command with history.

**Installation:**
```bash
cd /tmp
wget https://github.com/sachaos/viddy/releases/download/v0.4.0/viddy_0.4.0_Linux_x86_64.tar.gz
tar -xzf viddy_0.4.0_Linux_x86_64.tar.gz
cp viddy /.local/bin/
chmod +x /.local/bin/viddy
```

**Usage:**
```bash
# Watch command output
viddy df -h

# Update every 2 seconds
viddy -n 2 'ls -l /downloads'

# Use 's' to toggle suspend, 'q' to quit
```

**Why useful:** Better than watch, can pause and review history.

---

### 40. **zellij** (Terminal workspace)
**Description:** Modern terminal multiplexer (alternative to tmux).

**Installation:**
```bash
cd /tmp
wget https://github.com/zellij-org/zellij/releases/download/v0.39.2/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xzf zellij-x86_64-unknown-linux-musl.tar.gz
cp zellij /.local/bin/
chmod +x /.local/bin/zellij
```

**Usage:**
```bash
# Start zellij
zellij

# Create new session
zellij -s mysession

# List sessions
zellij list-sessions

# Attach to session
zellij attach mysession
```

**Why useful:** Easier than tmux, better UI, floating panes.

---

## Top 10 Most Useful for Seedbox

Based on typical seedbox workflows:

1. **aria2** - Fast downloads with resume, torrent support
2. **rclone** - Sync files to cloud storage
3. **ncdu** - Find and clean up large files
4. **pv** - Monitor progress of large file operations
5. **zstd** - Fast compression before transfer
6. **ffmpeg** - Convert/compress media files
7. **tmux/zellij** - Keep processes running after disconnect
8. **croc** - Easy file transfers between machines
9. **age** - Encrypt sensitive files
10. **fselect** - Find files with SQL queries

---

## Installation Tips

1. **Check if tool exists first:**
   ```bash
   command -v toolname >/dev/null 2>&1 && echo "Already installed"
   ```

2. **Always install to `/.local/bin/`:**
   ```bash
   cp binary /.local/bin/
   chmod +x /.local/bin/binary
   ```

3. **Update PATH if needed** (add to `/.bashrc`):
   ```bash
   export PATH="/.local/bin:${PATH}"
   ```

4. **Test after installation:**
   ```bash
   toolname --version
   ```

5. **Create wrapper scripts if needed:**
   ```bash
   cat > /.local/bin/mytool << 'EOF'
   #!/bin/bash
   exec /.local/share/mytool/bin/mytool "$@"
   EOF
   chmod +x /.local/bin/mytool
   ```

---

**Note:** Some tools require compilation or system libraries. Pre-compiled static binaries (musl-based) are recommended for the restricted seedbox environment.
