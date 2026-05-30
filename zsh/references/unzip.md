# 🧠 unzip Cheat Sheet

## 🔍 Basic Usage

```bash
unzip archive.zip                    # Extract to current directory
unzip archive.zip -d /opt            # Extract to specific directory
unzip archive.zip file.txt           # Extract only file.txt from archive
unzip archive.zip "*.csv"            # Extract only CSV files
unzip archive.zip -x "*.log"         # Extract everything except .log files
```

## 📋 Inspection (Non-Destructive)

```bash
unzip -l archive.zip                 # List contents (filenames, sizes, dates)
unzip -v archive.zip                 # Verbose list (compression ratio, method, CRC)
unzip -t archive.zip                 # Test integrity without extracting
unzip -Z archive.zip                 # zipinfo-style detailed listing
```

## ⚙️ Extract Options

```bash
unzip -o archive.zip                 # Overwrite existing files without prompting
unzip -n archive.zip                 # Never overwrite (skip existing files)
unzip -j archive.zip                 # Junk paths (extract flat, ignore directory structure)
unzip -q archive.zip                 # Quiet mode (suppress output)
unzip -qq archive.zip                # Extra quiet (suppress all but errors)
unzip -P password archive.zip        # Extract with password
```

## 📁 Selective Extraction

```bash
unzip archive.zip "src/*"            # Extract only files under src/
unzip archive.zip "*.json" -d conf/  # Extract JSON files to conf/
unzip archive.zip -x "*.test.*"      # Exclude test files from extraction
unzip -j archive.zip "*/config.yml"  # Extract config.yml flat (ignoring subdirs)
```

## 🔗 Common Combos

```bash
unzip -l archive.zip | grep ".sql"                    # Find SQL files in archive
unzip -p archive.zip config.json | jq "."             # Pipe file contents to jq (no extract)
unzip -o archive.zip -d /opt && ls /opt               # Extract and verify
fd -e zip | xargs -I {} unzip -t {}                   # Test all zip files in tree
curl -sL url/package.zip -o /tmp/p.zip && unzip /tmp/p.zip -d ./  # Download and extract
```

## 🆚 unzip vs 7z for ZIP Files

```bash
# unzip — simple, fast, available everywhere
# 7z x  — handles more formats, better Unicode, but heavier
unzip archive.zip -d out/            # Classic approach
7z x archive.zip -oout/              # Alternative with 7z
```

## ⚠️ Gotchas

```bash
# unzip does NOT handle .tar.gz, .7z, .rar — use tar, 7z, or unrar instead
# -P passes password on command line (visible in process list) — prefer interactive prompt
# Wildcard patterns must be quoted to prevent shell expansion: "*.csv" not *.csv
# -j (junk paths) can cause filename collisions if archive has same-named files in different dirs
```

