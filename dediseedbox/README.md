# Bash Configuration for Restricted Seedbox Environment

This Bash configuration is designed for a jailed Docker seedbox with severe restrictions:
- **HOME="/"** (root of filesystem, not /home/user)
- No sudo/root access
- No package managers (apt, pip, npm)
- Only standard GNU tools available
- Uses **oh-my-bash** framework for modular configuration

## Quick Start

### Installation

From your seedbox (where HOME="/"):

```bash
# 1. Clone or copy this dotfiles repo to /.dotfiles
# 2. Run the installation script
cd /.dotfiles/dediseedbox
./install.sh

# 3. Activate the new configuration
source ~/.bashrc
```

The install script will:
- Check for oh-my-bash (already installed at `/.oh-my-bash`)
- Backup your existing `.bashrc`
- Copy configuration files to `/`
- Set up oh-my-bash custom directory
- Create `/.config` if needed

## Features

### Navigation
- Quick directory navigation: `..`, `...`, `....`, `.4`, `.5`
- Jump to root: `r` (since HOME="/")
- Quick access: `dot` (/.dotfiles), `con` (/.config)
- Fix typos: `cd..` works

### File Listings (using standard `ls`)
- `l` - Long listing with human-readable sizes
- `ll` - All files including hidden
- `lls` - Sort by size
- `lt` - Sort by time (newest first)
- `l.` - Hidden files only
- `ld` - Directories only

### Utility Functions
- `psg <pattern>` - Search running processes
- `extract <archive>` - Extract any archive (tar.*, zip, 7z, rar, xz, zst, lz4, etc.)
- `genpass [length]` - Generate secure password (default 32 chars)
- `mkcd <dir>` - Create directory and cd into it
- `bak <file>` - Create/restore/swap .bak backup
- `dirsize [dir]` - Show size of directories (all subdirs if no args)
- `fs [limit]` - Show largest files (default top 50)
- `ds [limit]` - Show largest directories (default top 50)
- `note [text]` - Quick note-taking to /notes/notes.txt
- `fdf <pattern>` - Find files by name
- `fdd <pattern>` - Find directories by name
- `rgrep <pattern> [path]` - Recursive grep
- `replace-in-files <search> <replace> [pattern]` - Find/replace in files with confirmation
- `ref [topic]` - Manage reference files (e.g., ref git, ref docker)
- `serve [port]` - Start HTTP server in current directory (default port 8000)

### Enhanced Functions (if modern tools installed)
**FZF Functions:**
- `frg [pattern]` - Interactive grep with preview
- `ff` - Interactive file finder with preview
- `flog` - Interactive git log browser
- `fcd` - FZF directory search with cd
- `fkill` - Interactive process killer

**Zoxide Functions:**
- `z <pattern>` - Smart cd (replaces cd command)
- `zi` - Interactive cd with fzf
- `zl <pattern>` - Jump and list directory contents

**Yazi Functions:**
- `y [dir]` - Launch yazi file manager and cd to last location on exit
- `fm` - Alias for yazi
- `br` - Broot file tree navigator (if installed)

**Git Functions:**
- `lg` - Launch lazygit TUI
- `gdd [file]` - Git diff with delta
- `gddc [file]` - Git diff --cached with delta

**Analysis Functions:**
- `stats` - Show code statistics (tokei)
- `json <file>` - Pretty print JSON with syntax highlighting
- `yaml <file>` - Pretty print YAML with syntax highlighting

### Enhanced Aliases (if modern tools installed)
The configuration automatically uses modern alternatives when available:
- `ls` → `eza` (with icons and colors)
- `cat` → `bat` (with syntax highlighting)
- `find` → `fd` (faster, respects .gitignore)
- `grep` → `rg` (ripgrep - much faster)
- `cd` → `z` (zoxide - learns your habits)
- `df` → `duf` (prettier disk usage)
- `du` → `dust` (better disk usage)
- `dig` → `doggo` (better DNS client)

**Fallbacks available:**
- `rcat` - Real cat (when bat is installed)
- `rdf` - Real df (when duf is installed)
- `rdu` - Real du (when dust is installed)
- `rgrep` - Real grep (when ripgrep is installed)

### Git Workflow (Complete Aliases)

**Status & Info:**
- `gs` - git status
- `gss` - git status -s (short)
- `gst` / `gstp` / `gstl` - git stash / pop / list

**Add & Commit:**
- `ga` / `gaa` / `gau` - git add / all / update
- `gc` / `gcm "msg"` - git commit / with message
- `gca` / `gcan` - git commit --amend / --no-edit

**Diff:**
- `gd` / `gdc` / `gdw` - git diff / cached / word-diff

**Branches:**
- `gb` / `gba` - git branch / all
- `gcb <name>` - create and checkout new branch
- `gbd` / `gbD` - delete branch / force delete

**Checkout:**
- `gco <branch>` - git checkout

**Push/Pull:**
- `gp` / `gpu` - git push / pull
- `gpf` - git push --force-with-lease (safer)
- `gpr` - git pull --rebase

**Log:**
- `gl` / `glo` - git log / oneline
- `glg` - git log --graph --all
- `gll` - pretty formatted log
- `gbr` - branches sorted by last commit

**Functions:**
- `groot` - go to git repository root
- `gcl <url>` - clone and cd into directory
- `git_search <pattern>` - search git log
- `gundo` - undo last commit (keep changes)

### Environment
- **XDG directories**: `/.config`, `/.local/share`, `/.cache`
- **Editor**: vim (set as EDITOR and VISUAL)
- **Colored output**: ls, grep, git with color support
- **History**: 10,000 lines with deduplication
- **oh-my-bash theme**: powerline-plain (ASCII-only, no Nerd Fonts needed)

## What's Available

✅ **Works in seedbox:**
- Bash 5.0.17 with full features
- Standard GNU tools (ls, grep, find, awk, sed, tr, cut, sort)
- Archive tools (tar, unzip, 7z, gzip, bzip2, xz)
- Network tools (curl, wget, git, rclone)
- Process tools (ps, top)
- Editors (vim, nano, vi)
- Languages (python3, perl)

❌ **Not available:**
- Modern CLI tools (eza, bat, fzf, fd, ripgrep, zoxide)
- Docker commands (no daemon access)
- systemd commands (no systemctl)
- Package managers (apt, pip, npm)
- Process tools (htop, lsof, netstat, ss)

## Customization

Create `/.bash_local` for machine-specific aliases/functions:

```bash
# Example /.bash_local
alias myserver="ssh user@server.com"
export CUSTOM_VAR="value"

# Custom function
function myfunction() {
    echo "Hello from custom function"
}
```

This file is automatically sourced if it exists.

## Troubleshooting

**Prompt not showing:**
```bash
source /.bashrc
```

**Functions not working:**
```bash
# Check if files are sourced
ls -la /.oh-my-bash/custom/
# Should show: aliases.sh, env.sh, functions.sh, git.sh
```

**Git aliases not working:**
```bash
# Verify git is available
git --version
# Check if git.sh is sourced
type gs
```

**oh-my-bash not loading:**
```bash
# Check if oh-my-bash exists
ls -la /.oh-my-bash/
# Reinstall if needed
cd /.dotfiles/dediseedbox && ./install.sh
```

## Optional: Installing Node.js

Node.js installation is included in the main `install.sh` script. During installation, you'll be prompted to install Node.js v22.11.0.

**Version checking:**
- If Node.js is already installed, the script checks the version
- Only upgrades if your current version is older than v22
- Safe to run multiple times (idempotent)

**After installation:**
```bash
# Activate the new configuration
source /.bashrc

# Verify installation
node --version
npm --version
```

This installs Node.js v22.11.0 (current stable) to `/.local/node/` and adds it to your PATH.

**Installing npm packages globally:**
```bash
# Global packages install to /.local/node/lib/node_modules/
npm install -g <package-name>
```

## Optional: Installing Portable CLI Tools

The installation script offers to install modern CLI tools to `/.local/bin/`. These tools enhance your command-line experience with faster, more user-friendly alternatives to standard Unix tools.

**During installation**, you'll be prompted to install:

### Essential Modern CLI Tools
- **fzf** - Fuzzy finder for files, commands, and history
- **ripgrep (rg)** - Blazing fast grep replacement (respects .gitignore)
- **fd** - Simple, fast alternative to `find`
- **bat** - Cat clone with syntax highlighting
- **eza** - Modern `ls` replacement with colors and icons
- **atuin** - Magical shell history sync and search

### Data Processing Tools
- **jq** - Command-line JSON processor
- **yq** - YAML processor
- **sd** - Intuitive find & replace (better than sed)

### Git Tools
- **delta** - Syntax-highlighting pager for git/diff
- **lazygit** - Terminal UI for git commands
- **git-open** - Open repo in browser

### File/Directory Tools
- **zoxide** - Smarter cd command (learns your habits)
- **yazi** - Blazing fast terminal file manager
- **duf** - Disk usage utility (better than df)
- **dust** - More intuitive du
- **dua** - Disk usage analyzer with TUI
- **erdtree** - Multi-threaded file-tree visualizer
- **ncdu** - Interactive disk usage analyzer (find large files)

### Editors & Text Tools
- **micro** - Modern, intuitive terminal text editor

### Network & Analysis Tools
- **doggo** - Modern DNS client (dig replacement)
- **tokei** - Count lines of code with statistics

### Additional Runtimes (Optional)
- **Go** - Go programming language compiler

**To install these tools:**
1. Run `./install.sh` and answer "y" when prompted
2. All tools install to `/.local/bin/` (no sudo required)
3. Tools are automatically added to PATH via `/.local/bin`

**To install individual tools later:**
See the [install.sh](install.sh) script for individual installation commands for each tool.

## Reload Configuration

After making changes:
```bash
rebash  # Short alias
# or
source /.bashrc  # Full command
```

## File Structure

```
/.dotfiles/dediseedbox/
├── .bashrc                # Main entry point
├── .bash_profile          # Login shell config
├── custom/                # oh-my-bash custom files
│   ├── aliases.sh         # Navigation, ls, grep aliases
│   ├── env.sh             # Environment variables
│   ├── functions.sh       # Utility functions
│   └── git.sh             # Git workflow
├── install.sh            # Installation script
├── README.md             # This file
└── references/           # Command references
    ├── curl.txt
    ├── find.txt
    └── wget.txt
```

## Tips

1. **Use tab completion** - oh-my-bash provides completion for git, ssh, and more
2. **Leverage git aliases** - Faster git workflow with short commands
3. **Use `extract` function** - No need to remember tar flags
4. **Quick notes with `note`** - Timestamped notes in /notes/notes.txt
5. **Find large files** - Use `fs` and `ds` to identify space hogs
6. **Process search** - `psg <pattern>` is faster than `ps aux | grep`

## Support

This configuration is specifically tailored for restricted seedbox environments. For issues or questions:
- Check the troubleshooting section above
- Review the dotfiles source code in `/.dotfiles/dediseedbox/`
- All functions and aliases use only standard tools

## License

Part of the dotfiles repository. See main dotfiles README for details.
