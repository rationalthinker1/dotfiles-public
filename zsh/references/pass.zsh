🧠 pass (password-store) Cheat Sheet

🔍 Basic Usage
pass                                    # List all entries in the store
pass show Email/personal                # Show password for an entry
pass show -c Email/personal             # Copy password to clipboard (clears after 45s)
pass show -c2 Email/personal            # Copy 2nd line (e.g. username) to clipboard
pass find "pattern"                     # Search entry names matching pattern
pass grep "pattern"                     # Search entry contents matching pattern

🔑 Managing Passwords
pass insert Email/work                  # Add new password (prompted interactively)
pass insert -m Email/work               # Add multiline entry (end with Ctrl+D)
pass insert -f Email/work               # Overwrite existing entry without confirmation
pass generate Social/twitter 20         # Generate 20-char random password
pass generate -c Social/twitter 20      # Generate and copy to clipboard
pass generate -n Social/twitter 20      # Generate without symbols (alphanumeric only)
pass edit Email/personal                # Edit entry in $EDITOR
pass mv Email/old Email/new             # Rename or move an entry
pass cp Email/personal Email/backup     # Copy an entry
pass rm Email/old                       # Delete an entry (prompts for confirmation)
pass rm -f Email/old                    # Delete without confirmation
pass rm -r Email/                       # Recursively delete a directory

📁 Store Organization
pass init "GPG-KEY-ID"                  # Initialize or re-encrypt the store
pass init -p work/ "WORK-GPG-KEY-ID"   # Use different GPG key for a subfolder
pass ls                                 # List all entries (same as bare pass)
pass ls Email/                          # List entries in a subfolder

🔄 Git Integration
pass git init                           # Initialize git repo in the password store
pass git push                           # Push changes to remote
pass git pull                           # Pull changes from remote
pass git log                            # View password store commit history
pass git remote add origin <url>        # Add remote for syncing across machines

📋 Multiline Entry Format
# Convention: first line is the password, additional lines are metadata
# Example entry for "Email/work":
#   s3cur3P@ssw0rd
#   username: john@example.com
#   url: https://mail.example.com
#   notes: MFA enabled, recovery codes in safe

🔐 GPG Key Management
pass init "NEW-GPG-KEY-ID"              # Re-encrypt entire store with new key
pass init "KEY1" "KEY2"                 # Encrypt for multiple recipients
gpg --list-keys                         # List available GPG keys
gpg --list-secret-keys                  # List your private keys

🧩 Extensions
pass otp insert Email/work              # Add TOTP secret (pass-otp extension)
pass otp Email/work                     # Generate current TOTP code
pass otp -c Email/work                  # Generate and copy TOTP code

⚙️  Environment Variables
PASSWORD_STORE_DIR="${HOME}/.password-store"     # Custom store location
PASSWORD_STORE_CLIP_TIME=45                      # Clipboard clear timeout (seconds)
PASSWORD_STORE_GENERATED_LENGTH=25               # Default generated password length
PASSWORD_STORE_GPG_OPTS="--armor"                # Extra GPG options
PASSWORD_STORE_ENABLE_EXTENSIONS=true            # Enable extensions

🔗 Common Combos
# Copy username (2nd line) to clipboard
pass show -c2 Email/work

# Generate password, copy to clipboard, no symbols
pass generate -cn Banking/checking 30

# Pipe password to another command
pass show Server/db | head -1 | pbcopy

# Export all entry names
pass ls | grep -v "^\(├\|│\|└\| \)" > entries.txt

# Backup the store
tar -czf pass-backup.tar.gz "${PASSWORD_STORE_DIR:-${HOME}/.password-store}"

# Restore on a new machine
gpg --import private-key.asc
git clone <remote-url> "${HOME}/.password-store"

# Search and copy in one step (with fzf)
pass show -c "$(pass ls | fzf)"

⚠️  Gotchas
# pass uses GPG — ensure your key is unlocked (gpg-agent caches passphrase)
# Clipboard auto-clears after $PASSWORD_STORE_CLIP_TIME seconds (default: 45)
# pass git auto-commits on insert/generate/edit/rm — no manual commit needed
# -c copies first line only — use -c2, -c3 for other lines
# Re-encrypting (pass init) touches every file — large stores take time
# On WSL, clipboard integration needs xclip or wl-copy installed
# pass show without -c prints to stdout — be mindful of shoulder surfing

✅ Done. Happy securing!
