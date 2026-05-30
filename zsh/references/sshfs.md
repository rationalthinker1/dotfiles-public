# 🧠 sshfs Cheat Sheet

## 🔍 Basic Usage

```bash
sshfs user@host:/remote/path /local/mount       # Mount remote directory
sshfs user@host:/ /mnt/server                   # Mount remote root
sshfs user@host:~/ /mnt/home                    # Mount remote home directory
```

## ⚙️ Connection Options

```bash
sshfs -p 2222 user@host:/path /mount            # Non-default SSH port
sshfs -o IdentityFile=~/.ssh/id_ed25519 user@host:/path /mount  # Specific key file
sshfs -o StrictHostKeyChecking=no user@host:/path /mount         # Skip host key check
sshfs -o ProxyJump=bastion user@host:/path /mount                # Connect through jump host
sshfs -C user@host:/path /mount                 # Enable SSH compression
```

## 📊 Performance Options

```bash
sshfs -o cache=yes user@host:/path /mount                  # Enable caching (faster reads)
sshfs -o cache_timeout=600 user@host:/path /mount          # Cache TTL in seconds
sshfs -o ServerAliveInterval=15 user@host:/path /mount     # Send keepalive every 15s
sshfs -o ServerAliveCountMax=3 user@host:/path /mount      # Disconnect after 3 missed keepalives
sshfs -o Ciphers=aes128-ctr user@host:/path /mount         # Use faster cipher
sshfs -o big_writes user@host:/path /mount                 # Enable large write requests
```

## 🔒 Permissions and Access

```bash
sshfs -o allow_other user@host:/path /mount     # Allow other users to access mount
sshfs -o allow_root user@host:/path /mount      # Allow root to access mount
sshfs -o default_permissions user@host:/path /mount  # Enable local permission checking
sshfs -o uid=$(id -u) -o gid=$(id -g) user@host:/path /mount  # Force local UID/GID ownership
sshfs -o ro user@host:/path /mount              # Mount read-only
# Note: allow_other requires "user_allow_other" in /etc/fuse.conf
```

## 🔌 Unmounting

```bash
fusermount -u /local/mount                      # Unmount (Linux)
umount /local/mount                             # Unmount (macOS or Linux with root)
fusermount -uz /local/mount                     # Lazy unmount (force, even if busy)
```

## 🔁 Reconnection Options

```bash
sshfs -o reconnect user@host:/path /mount                  # Auto-reconnect on connection drop
sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 user@host:/path /mount  # Robust reconnection
sshfs -o follow_symlinks user@host:/path /mount            # Follow symlinks on remote
```

## 🧰 Recommended Mount Command

```bash
# Robust mount with sensible defaults:
sshfs user@host:/remote/path /local/mount \
  -o allow_other \
  -o reconnect \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=3 \
  -o cache=yes \
  -o cache_timeout=300

# Breakdown:
#   allow_other       Other users can access the mount
#   reconnect         Auto-reconnect on connection loss
#   ServerAlive*      Detect dead connections within 45s
#   cache=yes         Cache directory listings and attributes
#   cache_timeout     Cache valid for 5 minutes
```

## 📁 Mount via /etc/fstab (persistent)

```bash
# Add to /etc/fstab for auto-mount at boot:
# user@host:/remote/path /local/mount fuse.sshfs defaults,allow_other,reconnect,IdentityFile=/home/user/.ssh/id_ed25519 0 0

# Mount all fstab entries:
sudo mount -a
```

## 🔗 Common Combos

```bash
# Mount, work, unmount
mkdir -p /tmp/remote && sshfs user@host:/var/www /tmp/remote && ls /tmp/remote

# Quick edit remote files with local editor
sshfs user@host:/etc/nginx /tmp/nginx-conf && vim /tmp/nginx-conf/nginx.conf

# Check if mount is active
mount | grep sshfs

# List all FUSE mounts
mount -t fuse.sshfs

# Remount after disconnection
fusermount -u /mount 2>/dev/null; sshfs user@host:/path /mount -o reconnect

# Mount with verbose debugging
sshfs -o debug,sshfs_debug,loglevel=debug user@host:/path /mount
```

## 🆚 sshfs vs alternatives

```bash
# sshfs   — simple, works over SSH, no server setup needed
# NFS     — faster, but requires server-side config and open ports
# rsync   — one-time copy (not live mount), better for backups
# rclone mount — supports S3, GDrive, etc., not just SSH
```

## ⚠️ Gotchas

```bash
# allow_other requires: echo "user_allow_other" >> /etc/fuse.conf
# Create mount point before mounting: mkdir -p /local/mount
# Stale mounts after disconnect: fusermount -uz /mount to force cleanup
# sshfs is FUSE-based — file operations are slower than local or NFS
# Large file operations (git, builds) are slow — use rsync or scp instead
# macOS requires macFUSE: brew install macfuse && brew install sshfs
# WSL2: sshfs works but FUSE support may need kernel module enabled
```

