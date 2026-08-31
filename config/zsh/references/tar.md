# 🧠 tar Cheat Sheet

## 🔍 Basic Usage

```bash
tar -cf archive.tar dir/                        # Create archive from directory
tar -xf archive.tar                             # Extract archive
tar -tf archive.tar                             # List contents without extracting
tar -cf archive.tar file1 file2 dir/            # Archive multiple files and dirs
```

## 📦 Compression Formats

```bash
# Create compressed archives:
tar -czf archive.tar.gz dir/                    # gzip  (most common, fast)
tar -cjf archive.tar.bz2 dir/                   # bzip2 (better ratio, slower)
tar -cJf archive.tar.xz dir/                    # xz    (best ratio, slowest)
tar -c --zstd -f archive.tar.zst dir/           # zstd  (fast + good ratio, modern)

# Extract compressed archives (tar auto-detects format):
tar -xf archive.tar.gz                          # Extract gzip
tar -xf archive.tar.bz2                         # Extract bzip2
tar -xf archive.tar.xz                          # Extract xz
tar -xf archive.tar.zst                         # Extract zstd

# Explicit decompression flags (if auto-detect fails):
tar -xzf archive.tar.gz                         # Force gzip
tar -xjf archive.tar.bz2                        # Force bzip2
tar -xJf archive.tar.xz                         # Force xz
```

## 📁 Extract Options

```bash
tar -xf archive.tar -C /opt/                    # Extract to specific directory
tar -xf archive.tar file.txt                    # Extract single file from archive
tar -xf archive.tar "dir/subdir/"               # Extract specific directory
tar -xf archive.tar --strip-components=1        # Strip leading directory (useful for tarballs with wrapper dir)
tar -xf archive.tar --wildcards "*.conf"        # Extract files matching pattern
```

## 🧹 Flags Reference

```bash
# c = create        x = extract       t = list
# z = gzip          j = bzip2         J = xz
# f = filename      v = verbose       C = change directory
# r = append        u = update        --delete = remove from archive
tar -cvf archive.tar dir/                       # Verbose create (shows files added)
tar -xvf archive.tar                            # Verbose extract (shows files extracted)
tar -tvf archive.tar                            # Verbose list (sizes, dates, permissions)
```

## 🚫 Exclusions

```bash
tar -czf archive.tar.gz --exclude=".git" dir/              # Exclude directory
tar -czf archive.tar.gz --exclude="*.log" dir/             # Exclude by pattern
tar -czf archive.tar.gz --exclude-vcs dir/                 # Exclude .git, .svn, .hg, etc.
tar -czf archive.tar.gz --exclude-from=excludes.txt dir/   # Exclude patterns from file
tar -czf archive.tar.gz --exclude="node_modules" --exclude=".git" --exclude="*.log" dir/  # Multiple excludes
```

## 📊 Append and Update

```bash
tar -rf archive.tar newfile.txt                 # Append file to existing tar (uncompressed only)
tar -uf archive.tar dir/                        # Update: add newer files only (uncompressed only)
tar -f archive.tar --delete file.txt            # Remove file from tar (uncompressed only)
```

## 🔒 Preserve Permissions

```bash
tar -cpzf archive.tar.gz dir/                   # Preserve permissions on create
tar -xpf archive.tar                            # Preserve permissions on extract
tar --same-owner -xf archive.tar                # Preserve file ownership (requires root)
tar --numeric-owner -cf archive.tar dir/        # Store numeric UID/GID (portable across systems)
```

## 📏 Size and Splitting

```bash
tar -czf - dir/ | split -b 100M - archive.tar.gz.part_   # Split into 100MB chunks
cat archive.tar.gz.part_* | tar -xzf -                    # Rejoin and extract split archive
tar -czf - dir/ | wc -c                                   # Check compressed size without saving
```

## 🔗 Common Combos

```bash
# Backup with timestamp
tar -czf "backup_$(date +%Y%m%d_%H%M%S).tar.gz" dir/

# Archive and send to remote server
tar -czf - dir/ | ssh user@host "cat > /backups/dir.tar.gz"

# Download and extract in one step
curl -sL https://example.com/release.tar.gz | tar -xzf - -C /opt/

# Compare archive to filesystem (diff)
tar -df archive.tar                             # Show differences between archive and disk

# List only filenames (no metadata)
tar -tf archive.tar.gz | head -20

# Find large files in archive
tar -tvf archive.tar.gz | sort -k3 -rn | head -10

# Copy directory tree preserving everything (better than cp -a)
tar -cf - dir/ | tar -xf - -C /dest/

# Exclude common development junk
tar -czf project.tar.gz --exclude-vcs --exclude="node_modules" --exclude="dist" --exclude="*.log" project/
```

## ⚠️ Gotchas

```bash
# -f must be the LAST flag before filename: tar -czf archive.tar.gz (not tar -cfz)
# Append/update (-r/-u/--delete) only work on uncompressed .tar files
# GNU tar auto-detects compression on extract — BSD tar (macOS) may need explicit flags
# --strip-components=1 is critical for tarballs that wrap everything in a top-level dir
# tar preserves symlinks by default — use -h to dereference (follow) them instead
# Relative paths: tar stores paths as given — use -C to control the base directory
```

