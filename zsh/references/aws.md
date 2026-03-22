# 🧠 AWS CLI Cheat Sheet

## 🔄 S3 Sync

```bash
# Sync to DigitalOcean Spaces (dry run)
aws s3 sync .dotfiles \
  s3://hvac-portal/downloads \
  --endpoint=https://nyc3.digitaloceanspaces.com \
  --dryrun \
  --profile "do"

# Sync to AWS S3 (dry run)
aws s3 sync .dotfiles \
  s3://hvac-portal/downloads \
  --dryrun \
  --profile "aws"

# Sync to Glacier storage class (dry run)
aws s3 sync .dotfiles \
  s3://hvac-portal/downloads \
  --dryrun \
  --storage-class "GLACIER" \
  --profile "aws"

# Sync VM images to Glacier (dry run)
aws s3 sync /var/lib/libvirt/images \
  s3://raza-backup/winapps \
  --dryrun \
  --storage-class "GLACIER" \
  --profile "aws"

# Sync with delete (mirror local → remote, removes orphaned remote files)
aws s3 sync /var/www/html \
  s3://my-bucket/www \
  --delete \
  --profile "aws"

# Sync with exclusions
aws s3 sync ./project \
  s3://my-bucket/project \
  --exclude "*.log" \
  --exclude ".git/*" \
  --exclude "node_modules/*" \
  --profile "aws"

# Sync with ACL (make files public)
aws s3 sync ./dist \
  s3://my-bucket/static \
  --acl public-read \
  --profile "aws"

# Sync with reduced redundancy storage
aws s3 sync ./backups \
  s3://my-bucket/backups \
  --storage-class "REDUCED_REDUNDANCY" \
  --profile "aws"

# Sync only recently modified files (last 7 days via date filter)
aws s3 sync ./logs \
  s3://my-bucket/logs \
  --exclude "*" \
  --include "$(date +%Y-%m)*" \
  --profile "aws"
```

## 📋 S3 List and Inspect

```bash
aws s3 ls                                                     # List all buckets
aws s3 ls s3://my-bucket/                                     # List bucket contents
aws s3 ls s3://my-bucket/prefix/ --recursive                  # List recursively
aws s3 ls s3://my-bucket/ --recursive --human-readable --summarize  # With sizes + total

aws s3api get-bucket-location --bucket my-bucket              # Get bucket region
aws s3api get-bucket-acl --bucket my-bucket                   # Get bucket ACL
```

## 📤 S3 Copy and Move

```bash
# Copy single file
aws s3 cp file.txt s3://my-bucket/path/file.txt --profile "aws"

# Copy from remote to local
aws s3 cp s3://my-bucket/path/file.txt ./local.txt --profile "aws"

# Copy with metadata
aws s3 cp file.txt s3://my-bucket/ \
  --content-type "text/plain" \
  --cache-control "max-age=3600" \
  --profile "aws"

# Move (copy + delete source)
aws s3 mv s3://my-bucket/old.txt s3://my-bucket/new.txt --profile "aws"
```
