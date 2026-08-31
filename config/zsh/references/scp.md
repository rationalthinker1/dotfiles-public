# 🧠 scp Cheat Sheet

## 🔍 Basic Usage

```bash
scp file.txt user@host:/path/                   # Upload file to remote
scp user@host:/path/file.txt .                  # Download file from remote
scp file.txt user@host:~/                       # Upload to remote home directory
scp user@host:~/file.txt /tmp/                  # Download to local /tmp
```

## 📁 Directories

```bash
scp -r dir/ user@host:/path/                    # Upload directory recursively
scp -r user@host:/path/dir/ .                   # Download directory recursively
```

## ⚙️ Connection Options

```bash
scp -P 2222 file.txt user@host:/path/           # Use non-default SSH port
scp -i ~/.ssh/id_ed25519 file.txt user@host:/path/  # Use specific identity/key file
scp -o StrictHostKeyChecking=no file.txt user@host:/path/  # Skip host key verification
scp -F ~/.ssh/config_custom file.txt myhost:/path/   # Use custom SSH config file
```

## 📊 Transfer Control

```bash
scp -C file.txt user@host:/path/                # Enable compression during transfer
scp -l 8000 file.txt user@host:/path/           # Limit bandwidth to 8000 Kbit/s (~ 1MB/s)
scp -q file.txt user@host:/path/                # Quiet mode (no progress bar)
scp -v file.txt user@host:/path/                # Verbose mode (debug SSH connection)
```

## 🔀 Remote to Remote

```bash
scp user1@host1:/path/file.txt user2@host2:/path/   # Copy between two remotes (via local)
scp -3 user1@host1:/path/file.txt user2@host2:/path/ # Copy between remotes through local machine
```

## 📦 Multiple Files

```bash
scp file1.txt file2.txt user@host:/path/        # Upload multiple files
scp user@host:"/path/{a.txt,b.txt}" .           # Download multiple files (brace expansion)
scp user@host:"/path/*.log" /tmp/               # Download with wildcard (quote to prevent local expansion)
```

## 🔒 Preserve Attributes

```bash
scp -p file.txt user@host:/path/                # Preserve modification times and modes
scp -rp dir/ user@host:/path/                   # Recursive + preserve attributes
```

## 🔗 Common Combos

```bash
# Upload with non-default port and specific key
scp -P 2222 -i ~/.ssh/deploy_key app.tar.gz user@host:/opt/

# Download entire directory with compression
scp -rC user@host:/var/log/app/ ./logs/

# Copy database dump to remote server
mariadb-dump -u root -p dbname | ssh user@host "cat > /tmp/dump.sql"   # Stream via ssh (better than scp for pipes)

# Sync multiple config files to server
scp nginx.conf php.ini my.cnf user@host:/etc/

# Quick backup from remote
scp -rC user@host:/var/www/html/ ./backup_$(date +%Y%m%d)/
```

## 🆚 scp vs rsync vs sftp

```bash
# scp   — simple, good for one-off copies. No delta/resume.
# rsync — delta transfer, resume, exclude patterns. Better for syncing.
# sftp  — interactive session, resume support, directory listings.
# For large/repeated transfers, prefer rsync over scp.
```

## ⚠️ Gotchas

```bash
# Port flag is uppercase -P (not lowercase -p which preserves attributes)
# Remote paths with spaces: scp user@host:"/path/my\ file.txt" .
# Wildcard patterns must be quoted to prevent LOCAL shell expansion
# scp does NOT support exclude patterns — use rsync for that
# scp copies through local machine by default for remote-to-remote — use -3 explicitly
# OpenSSH 9.0+ deprecated scp protocol in favor of sftp backend — behavior may differ
```

