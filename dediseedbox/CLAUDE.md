# Bash Configuration for Restricted Docker Seedbox Environment

## Overview

This directory contains a **Bash shell configuration** designed for a **highly restricted Docker-based seedbox environment** with severe limitations. This is NOT a normal Linux environment - it has unique constraints that require special handling.

**Purpose:** Provide a functional, feature-rich shell environment using **only standard GNU tools** and **portable pre-compiled binaries**, without requiring sudo, package managers, or compilation.

**Framework:** Uses [oh-my-bash](https://github.com/ohmybash/oh-my-bash) for modular configuration (similar to oh-my-zsh but for Bash).

---

## ⚠️ IMPORTANT: What NOT to Port from Main Dotfiles

When porting aliases and functions from the main ZSH dotfiles (`~/.dotfiles/zsh/`), **DO NOT** include the following:

### ❌ Excluded Functionality

**Docker/Container Management:**
- ❌ NO Docker functions (`dc`, `dce`, `dcu`, `dceb`, `dcebr`, `dstop`, `drmf`, etc.)
- ❌ NO Docker Compose aliases or functions
- ❌ NO Docker cleanup utilities
- **Reason:** This is a Docker-based seedbox - no Docker daemon access available

**Web Server Management:**
- ❌ NO Nginx functions (`ncon`, `nrel`, `npe`, `npa`, etc.)
- ❌ NO Apache functions
- **Reason:** Seedbox doesn't have web server management

**Laravel/PHP Development:**
- ❌ NO Laravel Artisan Docker functions (`pa`, `pam`, `dce php`, etc.)
- ❌ NO Laravel-specific helpers (`laravel-fresh`, `laravel-setup`)
- ❌ NO Docker-based Composer shortcuts (`dcomp`, `dcompi`)
- **Reason:** Not a PHP development environment

**What IS allowed:**
- ✅ Basic Composer shortcuts (if PHP available): `cu`, `ci`, `cda`
- ✅ Git workflow functions (all of them)
- ✅ NPM/Yarn/Node development tools
- ✅ File management utilities
- ✅ System utilities that work without sudo

---

## Critical Environment Constraints

### ⚠️ Unique Characteristics

```bash
HOME="/"              # HOME is root of filesystem, NOT /home/user
SHELL="/bin/sh"       # Default shell is sh, not bash
OS="Ubuntu 20.04.1"   # Inside Docker overlay filesystem
USER="rationalthinker1"  # Non-root user with limited permissions
```

### ✅ What IS Available

**Shell:**
- `/bin/bash` (5.0.17) - full Bash features work (`[[ ]]`, arrays, etc.)
- `/bin/sh` - POSIX shell (default login shell)

**Standard GNU Tools:**
- `ls`, `grep`, `find`, `awk`, `sed`, `tr`, `cut`, `sort`, `uniq`
- `ps`, `top` (no htop)
- `tar`, `unzip`, `7z`, `gzip`, `bzip2`, `xz`

**Network Tools:**
- `curl`, `wget`, `git` (2.25.1), `rclone`

**Editors:**
- `vim`, `nano`, `vi`

**Languages:**
- `python3` (NO pip, NO distutils)
- `perl`
- `openssl`

**Write Access:**
- `/` (HOME directory)
- `/.config`, `/.local`, `/.cache`
- `/tmp`

### ❌ What IS NOT Available

**No Privilege:**
- ❌ NO sudo / root access
- ❌ NO ability to change login shell (`chsh` fails)

**No Package Managers:**
- ❌ NO apt/apt-get (exists but doesn't work without sudo)
- ❌ NO pip (Python package installer)
- ❌ NO npm (exists but doesn't work properly)
- ❌ NO compilers (gcc, make, cmake, autoconf)

**No Modern Tools:**
- ❌ NO zsh or oh-my-zsh
- ❌ NO modern CLI tools (eza, bat, fzf, fd, ripgrep, etc.) - **must install manually**
- ❌ NO htop, lsof, netstat, ss

**No Container Control:**
- ❌ NO Docker daemon access (commands fail)
- ❌ NO systemd (systemctl, journalctl fail)
- ❌ NO SSH key management (host handles SSH)

---

## Architecture

### File Structure

```
dediseedbox/
├── install.sh              # Main installation script
├── install_node.sh         # Standalone Node.js installer
├── .bashrc                 # Main Bash configuration (loads oh-my-bash)
├── .bash_profile           # Login shell configuration
├── custom/                 # oh-my-bash custom directory
│   ├── env.sh              # Environment variables (XDG, PATH)
│   ├── aliases.sh          # Aliases (navigation, ls, modern tools)
│   ├── functions.sh        # Utility functions (extract, psg, etc.)
│   └── git.sh              # Git aliases and functions
├── README.md               # User-facing documentation
├── CLAUDE.md               # This file (AI assistant guide)
└── references/             # Command reference files
    ├── curl.txt
    ├── find.txt
    └── wget.txt
```

### Configuration Loading Order

```
1. /.bash_profile           # Login shell (sources .bashrc)
2. /.bashrc                 # Main config
   ├── Load oh-my-bash      # Framework initialization
   ├── Source env.sh        # Environment variables
   ├── Source aliases.sh    # Aliases (conditional based on installed tools)
   ├── Source functions.sh  # Utility functions
   └── Source git.sh        # Git workflow
```

### oh-my-bash Integration

**Why oh-my-bash?**
- Modular plugin system (familiar structure like oh-my-zsh)
- Works in restricted environments (no sudo needed)
- Pure Bash implementation (no external dependencies)
- Lightweight themes that work without Nerd Fonts

**Configuration:**
```bash
OSH="/.oh-my-bash"                    # Installation directory
OSH_THEME="powerline-plain"           # ASCII-only theme
plugins=(git)                         # Git completions only
aliases=(general)                     # Basic aliases
```

**Plugins AVOID (require external tools):**
- `aws`, `docker`, `docker-compose` - Not available
- `nvm`, `npm`, `yarn` - Not available
- `fzf` - Must install manually first
- `battery`, `golang`, `latex` - Not applicable

---

## Key Features

### 1. Conditional Tool Support

**Philosophy:** Configuration works with **standard tools by default**, but automatically enables **modern alternatives** if installed.

```bash
# In aliases.sh
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --color=auto --icons=auto'  # Modern
else
    alias ls='ls --color=auto'                # Fallback
fi
```

**Result:**
- Fresh install: Uses standard `ls`, `cat`, `grep`, `find`
- After installing tools: Automatically uses `eza`, `bat`, `rg`, `fd`

### 2. Portable Tool Installation

**Location:** All tools install to `/.local/bin/` (no sudo required)

**Categories:**
- **Essential CLI Tools:** fzf, ripgrep, fd, bat, eza
- **Data Processing:** jq, yq, sd
- **Git Tools:** delta, lazygit, git-open
- **File/Directory:** zoxide, yazi, duf, dust, dua, erdtree
- **Editors:** micro
- **Network & Analysis:** doggo, tokei
- **Runtimes:** Node.js, Go

**Installation:**
```bash
./install.sh    # Prompts for each category
```

### 3. Smart Aliases & Functions

**Enhanced Aliases (if tools installed):**
```bash
ls → eza       # Modern ls with icons
cat → bat      # Syntax highlighting
grep → rg      # Faster grep
cd → z         # Smart cd (zoxide)
df → duf       # Pretty disk usage
```

**Fallback Aliases:**
```bash
rcat    # Real cat (when bat installed)
rgrep   # Real grep (when ripgrep installed)
```

**Utility Functions:**
```bash
psg <pattern>         # Process search
extract <archive>     # Extract any archive
genpass [length]      # Generate password
mkcd <dir>            # Make dir and cd
bak <file>            # Backup/restore file
fs [limit]            # Largest files
ds [limit]            # Largest directories
note [text]           # Quick notes
fdf <pattern>         # Find files
```

**FZF Functions (if fzf installed):**
```bash
frg [pattern]         # Interactive grep
ff                    # Interactive file finder
flog                  # Interactive git log
fkill                 # Interactive process killer
```

### 4. Complete Git Workflow

**Status & Info:**
```bash
gs      # git status
gss     # git status -s
gst     # git stash
gstp    # git stash pop
```

**Add & Commit:**
```bash
ga      # git add
gaa     # git add --all
gc      # git commit
gcm     # git commit -m
gca     # git commit --amend
```

**Branches & Checkout:**
```bash
gb      # git branch
gco     # git checkout
gcb     # git checkout -b
gba     # git branch -a
```

**Diff & Log:**
```bash
gd      # git diff
gdc     # git diff --cached
gl      # git log
glo     # git log --oneline
glg     # git log --graph
```

**Functions:**
```bash
groot               # Go to repo root
gcl <url>           # Clone and cd
git_search <query>  # Search commits
gundo               # Undo last commit
```

---

## Installation Guide

### Prerequisites

**Verify you're in the correct environment:**
```bash
echo $HOME          # Should be "/"
bash --version      # Should be 5.0.17+
git --version       # Should be available
```

### Step 1: Clone Dotfiles

```bash
# If .dotfiles doesn't exist
git clone <repo-url> /.dotfiles

# Navigate to seedbox config
cd /.dotfiles/dediseedbox
```

### Step 2: Run Installation

```bash
./install.sh
```

**What it does:**
1. Checks for oh-my-bash (installs if missing)
2. Backs up existing `/.bashrc` to `/.bashrc.backup`
3. Copies configuration files to `/`
4. Creates `/.config` directory if needed
5. Sets up oh-my-bash custom directory
6. **Prompts for Node.js installation** (optional)
7. **Prompts for portable tools installation** (optional)

### Step 3: Activate Configuration

```bash
source ~/.bashrc
# or
exec bash
```

### Step 4: Verify Installation

```bash
# Check oh-my-bash loaded
echo $OSH              # Should be /.oh-my-bash

# Check custom functions work
psg bash               # Should show bash processes
genpass 16             # Should generate password

# Check git aliases work
gs                     # Should run git status
glo                    # Should show git log
```

---

## Portable Tools Installation

### Node.js (v22.11.0)

**Installation:**
```bash
# Option 1: During main install (prompted)
./install.sh

# Option 2: Standalone script
./install_node.sh
```

**Installs to:** `/.local/node/`
**PATH:** Automatically added via `env.sh`
**npm packages:** Install to `/.local/node/lib/node_modules/`

**Verify:**
```bash
node --version     # v22.11.0
npm --version      # 10.9.0
```

### Modern CLI Tools (40+ tools)

**During installation**, you'll be prompted to install categories:

**Essential (recommended):**
- fzf (fuzzy finder)
- ripgrep (fast grep)
- fd (fast find)
- bat (cat with syntax highlighting)
- eza (modern ls)

**All categories:**
```bash
./install.sh
# Answer "y" when prompted for tools installation
# All tools install to /.local/bin/
```

**Installation size:**
- Essential tools: ~100MB
- All tools: ~250MB
- With runtimes (Node + Go): ~600MB

**Verify:**
```bash
# Check tools available
command -v fzf rg fd bat eza

# Check PATH
echo $PATH | tr ':' '\n' | grep local
```

---

## PATH Management

### PATH Order (from env.sh)

```bash
/.local/bin              # Portable tools (highest priority)
/.local/node/bin         # Node.js + npm packages
/.local/go/bin           # Go (if installed)
/usr/local/bin           # System local binaries
/usr/bin                 # Standard system binaries
/bin                     # Essential binaries
```

### Adding Tools to PATH

**For single binaries:**
```bash
# Download binary
wget <url> -O /.local/bin/tool
chmod +x /.local/bin/tool

# Already in PATH (via env.sh)
```

**For runtime directories:**
```bash
# Add to /.oh-my-bash/custom/env.sh
echo '[[ -d "/.local/tool/bin" ]] && export PATH="/.local/tool/bin:${PATH}"' >> /.oh-my-bash/custom/env.sh

# Reload
source /.bashrc
```

---

## Environment Variables

### XDG Base Directory Specification

```bash
XDG_CONFIG_HOME="/.config"        # Configuration files
XDG_DATA_HOME="/.local/share"     # User data files
XDG_CACHE_HOME="/.cache"          # Cache files
```

**Why XDG?**
- Standard locations for config/data
- Prevents clutter in HOME (which is `/`)
- Many tools respect XDG variables

### Important Variables (from env.sh)

```bash
# Editor
EDITOR="vim"
VISUAL="vim"

# Pager
PAGER="less"
LESS="-XRF"    # No init/deinit, ANSI colors, quit if one screen

# Colors
GREP_COLOR='1;32'                                    # Green grep matches
LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:...'       # Directory colors

# Git
GIT_PAGER="less -XRF"

# Python
PYTHONDONTWRITEBYTECODE=1    # No __pycache__
PYTHONUNBUFFERED=1           # Unbuffered output

# Locale (with fallback)
LANG=en_US.UTF-8 (or C.UTF-8 if not available)
LC_ALL=en_US.UTF-8
```

---

## Best Practices for AI Assistants

### ✅ DO

**Use conditional checks:**
```bash
# Good
if command -v eza >/dev/null 2>&1; then
    eza -la
else
    ls -la
fi
```

**Use standard tools by default:**
```bash
# Good - works everywhere
grep -r "pattern" .

# Risky - requires ripgrep
rg "pattern"
```

**Use absolute paths for HOME:**
```bash
# Good
/.config
/.local/bin
/.dotfiles

# Bad (doesn't work when HOME="/")
~/config
$HOME/.local/bin
```

**Check before installation:**
```bash
# Good
if ! command -v tool >/dev/null 2>&1; then
    echo "Installing tool..."
    wget <url>
fi
```

### ❌ DON'T

**Don't assume standard HOME:**
```bash
# Wrong - HOME is "/" not "/home/user"
~/.bashrc           # This is /.bashrc
$HOME/downloads     # This is /downloads

# Correct
/.bashrc
/downloads
```

**Don't use sudo or package managers:**
```bash
# Wrong - will fail
sudo apt install tool
pip install package
npm install -g package

# Correct
wget <binary-url> -O /.local/bin/tool
chmod +x /.local/bin/tool
```

**Don't assume tools are installed:**
```bash
# Wrong - might not exist
bat README.md
rg "pattern"
fd "*.sh"

# Correct - check first
if command -v bat >/dev/null 2>&1; then
    bat README.md
else
    cat README.md
fi
```

**Don't create files outside writable areas:**
```bash
# Wrong - no permissions
/etc/config.conf
/usr/local/bin/script.sh

# Correct
/.config/tool/config.conf
/.local/bin/script.sh
```

**Don't use interactive installation scripts:**
```bash
# Wrong - can't interact
curl -fsSL <url> | sh    # Might prompt for input

# Correct - use direct downloads
wget <direct-binary-url>
```

---

## Troubleshooting

### Common Issues

**1. "Command not found" for new tools**

```bash
# Check PATH
echo $PATH | tr ':' '\n'

# Reload configuration
source /.bashrc

# Verify tool exists
ls -la /.local/bin/tool
```

**2. npm fails with "node: not found"**

```bash
# npm shebang requires node in PATH
# Solution: Install Node.js via install_node.sh
./install_node.sh

# Then reload
source /.bashrc
```

**3. oh-my-bash not loading**

```bash
# Check installation
ls -la /.oh-my-bash/

# Reinstall
cd /.dotfiles/dediseedbox
./install.sh
```

**4. Aliases not working**

```bash
# Check if alias file sourced
grep aliases /.bashrc

# Check if custom files exist
ls -la /.oh-my-bash/custom/

# Reload configuration
source /.bashrc
```

**5. "Permission denied" errors**

```bash
# Check file permissions
ls -la /.local/bin/tool

# Fix permissions
chmod +x /.local/bin/tool
```

### Debug Commands

```bash
# Check environment
echo "HOME: $HOME"
echo "SHELL: $SHELL"
echo "OSH: $OSH"

# Check writable directories
ls -ld / /.config /.local /.cache /tmp

# Check oh-my-bash
ls -la /.oh-my-bash/
ls -la /.oh-my-bash/custom/

# Check installed tools
ls -la /.local/bin/
ls -la /.local/node/

# Test functions
type psg
type extract
type groot

# Test aliases
alias | grep ls
alias | grep cat
```

---

## Security Considerations

### Safe Practices

**✅ Safe to install:**
- Official pre-compiled binaries from GitHub releases
- Tools that don't require compilation
- Standalone executables

**⚠️ Use caution:**
- Random shell scripts from the internet
- Tools that download and execute code
- Anything requiring sudo (won't work anyway)

### Verification

```bash
# Verify checksums (if available)
wget <url>
wget <url>.sha256
sha256sum -c <file>.sha256

# Check binary type
file /.local/bin/tool

# Expected: ELF 64-bit LSB executable
```

---

## Performance Considerations

### Startup Time

**oh-my-bash** is relatively lightweight:
- **No plugins:** ~50ms
- **With git plugin:** ~100ms
- **All custom files:** ~150ms

**Tips for faster startup:**
- Disable unused completions
- Use `wait` for non-essential oh-my-bash features
- Keep PATH short

### Tool Performance

**Modern tools are MUCH faster:**
- `rg` (ripgrep) is 10-100x faster than `grep`
- `fd` is 5-10x faster than `find`
- `bat` has instant syntax highlighting
- `eza` is faster than `ls --color`

**Recommendation:** Install modern tools for better experience

---

## Version History

**v1.0.0** (2025-02-04)
- Initial release
- oh-my-bash integration
- Portable tool installation support (40+ tools)
- Node.js v22.11.0 support
- Conditional aliases based on installed tools
- Complete Git workflow
- FZF integration functions

---

## Related Documentation

- [README.md](README.md) - User-facing installation guide
- [install.sh](install.sh) - Main installation script
- [install_node.sh](install_node.sh) - Node.js installation script
- [oh-my-bash documentation](https://github.com/ohmybash/oh-my-bash)

---

## Contributing

When modifying this configuration:

1. **Test in actual seedbox environment** (not regular Linux)
2. **Use only standard GNU tools** for core functionality
3. **Make modern tools optional** with conditional checks
4. **Avoid HOME variable** - use absolute paths (`/.config` not `~/.config`)
5. **Test without modern tools installed** - should still work
6. **Update this CLAUDE.md** with any significant changes
7. **Update README.md** for user-facing changes

---

## Quick Reference

**Configuration files:**
```
/.bashrc                    # Main config
/.bash_profile              # Login shell
/.oh-my-bash/custom/*.sh    # Custom configuration
```

**Tool locations:**
```
/.local/bin/                # Portable binaries
/.local/node/               # Node.js installation
/.local/go/                 # Go installation (if installed)
```

**Reload configuration:**
```bash
source /.bashrc
# or
rebash
```

**Check what's installed:**
```bash
ls /.local/bin/
command -v fzf rg fd bat eza
node --version
```

---

This configuration provides a **fully functional, modern shell environment** in one of the most **restricted Linux environments possible** - without sudo, without package managers, and without compilation. It's a testament to what can be achieved with portable binaries and smart shell configuration.
