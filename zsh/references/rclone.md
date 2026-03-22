# 🧠 rclone Cheat Sheet

## 🔍 Basic Usage

```bash
rclone ls remote:                               # List all files on remote (recursive)
rclone lsd remote:                              # List directories only (top-level)
rclone lsl remote:path/                         # List files with size and timestamp
rclone tree remote:                             # Tree view of remote
rclone size remote:path/                        # Total size and file count
```

## 📋 Setup and Configuration

```bash
rclone config                                   # Interactive config wizard (add/edit/delete remotes)
rclone config show                              # Show all configured remotes
rclone listremotes                              # List remote names only
rclone config file                              # Show config file path
rclone about remote:                            # Show quota/space usage on remote
```

## 📤 Copy and Sync

```bash
rclone copy src/ remote:dest/                   # Copy files (source → remote, no deletes)
rclone copy remote:src/ local_dir/              # Copy files (remote → local)
rclone sync src/ remote:dest/                   # Sync: make dest match source (DELETES extras in dest)
rclone sync remote:src/ local_dir/              # Sync remote to local
rclone bisync local/ remote:path/               # Bidirectional sync (experimental)
rclone move src/ remote:dest/                   # Move files (deletes from source after transfer)
rclone moveto local.txt remote:file.txt         # Move/rename single file
```

## 📁 File Operations

```bash
rclone mkdir remote:newdir/                     # Create directory on remote
rclone rmdir remote:emptydir/                   # Remove empty directory
rclone purge remote:dir/                        # Remove directory and ALL contents (dangerous)
rclone delete remote:path/                      # Delete files (keep directory structure)
rclone deletefile remote:file.txt               # Delete single file
rclone cat remote:file.txt                      # Print file contents to stdout
rclone copyto remote:file.txt local.txt         # Copy single file
```

## ⚙️ Transfer Options

```bash
rclone copy src/ remote:dest/ -P                # Show real-time progress
rclone copy src/ remote:dest/ --dry-run         # Preview what would happen (no changes)
rclone copy src/ remote:dest/ -v                # Verbose output
rclone copy src/ remote:dest/ --transfers 8     # Parallel file transfers (default 4)
rclone copy src/ remote:dest/ --checkers 16     # Parallel hash checkers (default 8)
rclone copy src/ remote:dest/ --bwlimit 10M     # Limit bandwidth to 10 MB/s
rclone copy src/ remote:dest/ --max-size 100M   # Skip files larger than 100 MB
rclone copy src/ remote:dest/ --min-size 1k     # Skip files smaller than 1 KB
rclone copy src/ remote:dest/ --max-age 7d      # Only files modified in last 7 days
rclone copy src/ remote:dest/ --min-age 30d     # Only files older than 30 days
```

## 🔍 Filtering

```bash
rclone copy src/ remote:dest/ --include "*.jpg"              # Include only JPG files
rclone copy src/ remote:dest/ --exclude "*.log"              # Exclude log files
rclone copy src/ remote:dest/ --exclude-from excludes.txt    # Exclude patterns from file
rclone copy src/ remote:dest/ --include "*.{jpg,png,gif}"    # Include multiple extensions
rclone copy src/ remote:dest/ --filter-from filters.txt      # Complex filter rules from file
rclone copy src/ remote:dest/ --exclude ".git/**"            # Exclude .git recursively
rclone copy src/ remote:dest/ --exclude "node_modules/**"    # Exclude node_modules
```

## 🔒 Encryption (crypt remote)

```bash
# Set up encrypted remote via: rclone config → New remote → Type: crypt
rclone copy secret/ crypt_remote:                # Upload and encrypt
rclone copy crypt_remote: decrypted/             # Download and decrypt
rclone ls crypt_remote:                          # List decrypted filenames
```

## 🌐 Mount (FUSE)

```bash
rclone mount remote:path/ /mnt/remote/ &         # Mount remote as local filesystem
rclone mount remote: /mnt/remote/ --daemon        # Mount as background daemon
fusermount -u /mnt/remote/                        # Unmount (Linux)
umount /mnt/remote/                               # Unmount (macOS)
rclone mount remote: /mnt/r/ --vfs-cache-mode full  # Full caching (best for read/write)
rclone mount remote: /mnt/r/ --read-only          # Read-only mount
```

## 🔄 Check and Compare

```bash
rclone check src/ remote:dest/                   # Compare source and dest (report differences)
rclone check src/ remote:dest/ --one-way         # Check source files exist on dest
rclone hashsum MD5 remote:path/                  # Show MD5 hashes of files
rclone md5sum remote:path/                       # Same as hashsum MD5
rclone dedupe remote:path/                       # Find and handle duplicate files
```

## 🔗 Common Combos

```bash
# Backup with progress and bandwidth limit
rclone sync ~/Documents/ remote:backup/docs/ -P --bwlimit 5M

# Mirror a website backup excluding logs
rclone sync /var/www/ remote:www-backup/ --exclude "*.log" --exclude ".git/**"

# Copy only recent photos
rclone copy ~/Photos/ remote:photos/ --include "*.{jpg,png,heic}" --max-age 30d -P

# Dry run before destructive sync
rclone sync local/ remote:dest/ --dry-run -v

# Serve remote as HTTP (quick file sharing)
rclone serve http remote:path/ --addr :8080

# Serve remote as WebDAV
rclone serve webdav remote:path/ --addr :8080

# Copy between two remotes (cloud-to-cloud)
rclone copy gdrive:src/ s3:bucket/dest/ -P

# Check config is working
rclone lsd remote: --max-depth 1
```

## ⚠️ Gotchas

```bash
# sync DELETES files in dest that don't exist in source — use copy if unsure
# Always --dry-run before sync to preview deletions
# purge is recursive delete with no confirmation — be very careful
# mount requires FUSE: sudo apt install fuse3 (Linux) or macFUSE (macOS)
# --transfers and --checkers multiply bandwidth usage — tune for your connection
# bisync is experimental — test with --dry-run first
# Config file may contain credentials — protect it: chmod 600 ~/.config/rclone/rclone.conf
```

