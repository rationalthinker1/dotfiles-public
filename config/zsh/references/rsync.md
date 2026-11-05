# 🧠 rsync Cheat Sheet

## 🔍 Basic Usage

```bash
rsync -av src/ dest/                            # Archive mode, verbose (the default workhorse)
rsync -avh --progress src/ dest/                # Human-readable sizes + per-file progress
rsync -avz src/ user@host:/dest/                # Push to remote, compressed in transit
rsync -avz user@host:/src/ dest/                # Pull from remote
rsync -avn src/ dest/                           # Dry run (-n): show what WOULD change
rsync -av --info=progress2 src/ dest/           # Single overall progress line
```

## ⚠️ Trailing Slash

```bash
rsync -av src/ dest/                            # Copies CONTENTS of src into dest
rsync -av src  dest/                            # Copies the src DIRECTORY itself → dest/src/
# Slash on the destination makes no difference; slash on the source does
```

## 📦 What -a Means

```bash
# -a = -rlptgoD
#   -r recursive    -l copy symlinks as symlinks    -p permissions
#   -t mtimes       -g group    -o owner (root only)    -D devices/specials
rsync -aAX src/ dest/                           # Add ACLs (-A) and xattrs (-X)
rsync -avH src/ dest/                           # Preserve hard links (-H)
rsync -avL src/ dest/                           # Follow symlinks, copy the targets (--copy-links)
rsync -rt src/ dest/                            # Recursive + mtimes only (FAT/exFAT/NTFS targets)
```

## 🌐 Remote and SSH

```bash
rsync -av -e "ssh -p 2222" src/ user@host:/dest/        # Custom SSH port
rsync -av -e "ssh -i ~/.ssh/key" src/ user@host:/dest/  # Specific key
rsync -av --rsync-path="sudo rsync" src/ user@host:/dest/  # Run remote side as root
# Remote-to-remote is NOT supported (rsync user@host1:/src/ user@host2:/dest/ errors out)
# Instead, run it from host1 and push to host2:
ssh -A user@host1 'rsync -av /src/ user@host2:/dest/'   # -A forwards your SSH agent to host1
rsync -av -e "ssh -J jump@bastion" src/ user@host:/dest/   # Via jump host
rsync -avz --compress-level=3 src/ user@host:/dest/     # Tune compression (skip for already-compressed data)
```

## 🔄 Sync and Delete

```bash
rsync -av --delete src/ dest/                   # Make dest match src (DELETES extras in dest)
rsync -av --delete-after src/ dest/             # Delete only after transfer succeeds
rsync -av --delete-excluded src/ dest/          # Also delete excluded files from dest
rsync -av --ignore-existing src/ dest/          # Skip files that already exist in dest
rsync -av --update src/ dest/                   # Skip files newer in dest
rsync -av --existing src/ dest/                 # Update only files that already exist in dest
rsync -av --remove-source-files src/ dest/      # Move: delete source files after transfer (dirs stay)
```

## 🔍 Filtering

```bash
rsync -av --exclude='*.log' src/ dest/          # Exclude pattern
rsync -av --exclude={'node_modules','.git'} src/ dest/   # Multiple excludes (bash/zsh brace expansion)
rsync -av --include='*.jpg' --exclude='*' src/ dest/     # Only jpgs (include BEFORE exclude)
rsync -av --include='*/' --include='*.jpg' --exclude='*' src/ dest/  # Only jpgs, keep dir tree
rsync -av --exclude-from=ignore.txt src/ dest/  # Patterns from file
rsync -av --filter=':- .gitignore' src/ dest/   # Honor .gitignore files
rsync -av --max-size=100M src/ dest/            # Skip files larger than 100M
rsync -av --min-size=1K src/ dest/              # Skip files smaller than 1K
rsync -av --files-from=list.txt src/ dest/      # Transfer only paths listed in file (relative to src)
```

## ⚙️ Transfer Options

```bash
rsync -avP src/ dest/                           # -P = --partial --progress (resume interrupted)
rsync -av --partial-dir=.rsync-partial src/ dest/   # Keep partials in a hidden dir
rsync -av --bwlimit=5m src/ dest/               # Limit bandwidth (KiB/s default; 5m = 5 MiB/s)
rsync -av --checksum src/ dest/                 # Compare by checksum, not size+mtime (slow)
rsync -av --size-only src/ dest/                # Compare by size only
rsync -av --inplace src/ dest/                  # Write into existing file (saves space, not atomic)
rsync -av --whole-file src/ dest/               # Skip delta algorithm (faster on LAN/local)
rsync -av --timeout=60 src/ dest/               # I/O timeout in seconds
rsync -av --chown=www-data:www-data src/ user@host:/dest/  # Set ownership on dest
rsync -av --chmod=D755,F644 src/ dest/          # Normalize dir/file permissions
```

## 🛟 Backups and Safety

```bash
rsync -av --backup --suffix=.bak src/ dest/     # Keep replaced files as *.bak
rsync -av --backup --backup-dir=../old-$(date +%F) --delete src/ dest/  # Keep deleted/replaced files in a dated dir
rsync -av --link-dest=../prev src/ dest/new/    # Incremental snapshot: hardlink unchanged files to prev
rsync -av --max-delete=50 --delete src/ dest/   # Abort if more than 50 deletions
rsync -av --itemize-changes src/ dest/          # -i: show WHY each file is transferred
```

## 📊 Output and Logging

```bash
rsync -avi src/ dest/                           # Per-file change codes (>f+++++++++ = new file)
rsync -av --stats src/ dest/                    # Summary: files, bytes, speedup
rsync -av --log-file=rsync.log src/ dest/       # Write log to file
rsync -av --out-format='%n %l' src/ dest/       # Custom per-file output (name, length)
rsync -ain --delete src/ dest/ | grep '^\*deleting'   # Preview only the deletions
```

## 🔗 Common Combos

```bash
# Safe preview, then real run (zsh only: read -q is a zsh builtin)
rsync -avhn --delete src/ user@host:/dest/ && read -q '?Proceed? ' && rsync -avh --delete src/ user@host:/dest/

# Resumable large transfer over flaky link
rsync -avzP --timeout=30 -e "ssh -p 2222" big.iso user@host:/data/

# Deploy a site, skip VCS and env files
rsync -avz --delete --exclude={'.git','.env','node_modules'} ./ user@host:/var/www/site/

# Full system-ish backup preserving everything
sudo rsync -aAXHv --numeric-ids --delete --exclude={'/dev/*','/proc/*','/sys/*','/tmp/*','/run/*','/mnt/*','/media/*','/lost+found'} / /mnt/backup/

# Rotating snapshots with hardlinks
rsync -a --delete --link-dest=/backup/latest src/ /backup/$(date +%F)/ && ln -sfn /backup/$(date +%F) /backup/latest

# Copy only files modified in the last day
find src -type f -mtime -1 -printf '%P\n' | rsync -av --files-from=- src/ dest/

# Mirror a directory over a custom port with a bandwidth cap
rsync -avz --bwlimit=2m -e "ssh -p 222" src/ user@host:/dest/
```

## ⚠️ Gotchas

```bash
# Trailing slash on SOURCE changes behavior: src/ = contents, src = the directory itself
# --delete removes files in dest not in src — run with -n first
# --delete with a wrong/empty src or typo'd dest can wipe the destination — use --max-delete
# -a does not include -H (hard links), -A (ACLs) or -X (xattrs) — add them explicitly
# -z wastes CPU on already-compressed data (jpg, mp4, zip, 7z) — omit it there
# --inplace and --partial can leave a corrupt file if interrupted mid-write
# Remote-to-remote is unsupported — run from one end, or use rclone
# Quote globs and spaces in remote paths; the remote shell expands them (use -s / --protect-args)
# macOS ships rsync 2.6.9 — missing many flags; brew install rsync for 3.x
# Use --exclude patterns relative to the transfer root, not absolute paths
# Prefer rclone for cloud storage (S3, Drive, B2); rsync needs SSH or an rsync daemon
```
