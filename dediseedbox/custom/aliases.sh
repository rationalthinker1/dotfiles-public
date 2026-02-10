#!/usr/bin/env bash
# ==============================================================================
# aliases.sh - Functions and Aliases
# ==============================================================================
# Central repository for all custom aliases, functions, and command enhancements
# Ported from ZSH configuration
#
# SECTIONS:
# - Bash Configuration (reload, navigation)
# - Modern CLI Tools (bat, eza, ripgrep, fzf)
# - Git Workflow (smart commits, prepend support)
# - Docker Management (compose, exec, cleanup)
# - Development Tools (npm, yarn, laravel)
# - System Utilities (processes, networking, compression)
# ==============================================================================

# ==============================================================================
# Configuration Constants
# ==============================================================================
readonly DEFAULT_FS_LIMIT=50        # Default limit for fs() function
readonly DEFAULT_DS_LIMIT=50        # Default limit for ds() function
readonly DEFAULT_WCSV_LIMIT=10      # Default limit for wcsv() function

# ==============================================================================
# Bash Configuration
# ==============================================================================

# Reload Bash configuration
# Usage: reload_bash
# Reloads .bashrc without restarting the shell
function reload_bash() {
    source ~/.bashrc
}
alias rebash="reload_bash"

# Common directories
alias dot="cd ~/.dotfiles"
alias con="cd ~/.config"

# ==============================================================================
# Modern CLI Tools
# ==============================================================================

# 🦇 Bat: Better cat with syntax highlighting
# Override 'cat' to use 'bat' for prettier output
# Use 'rcat' or 'command cat' to access original cat command
if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
    alias rcat='command cat'
fi

# 📁 Eza: Modern ls replacement with colors and icons
# Override 'ls' and related commands to use 'eza'
# Use 'command ls' to access original ls command
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --color=auto'
    alias l='eza --color=auto --long --header --group --group-directories-first'
    alias ll='eza --color=auto --long --header --group --all --group-directories-first'
    alias lls='eza --color=auto --long --header --group --all --group-directories-first --sort size'
    alias lt='eza --color=auto --long --header --group --all --group-directories-first --reverse --sort oldest'
    alias llt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=2'
    alias lllt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=3'
    alias llllt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=4'
    alias l.='eza --color=auto --long --header --group --all --group-directories-first --list-dirs .*'
    alias ld='eza --color=auto --long --header --group --all --group-directories-first --only-dirs'
else
    alias ls='ls --color=auto'
    alias l='ls -lh --group-directories-first'
    alias ll='ls -lah --group-directories-first'
    alias lls='ls -laSh --group-directories-first'
    alias lt='ls -laht --group-directories-first'
    alias l.='ls -lah -d .*'
    alias ld='ls -lah --group-directories-first -d */'
fi

# Show history
alias h="history"

## get rid of command not found ##
alias cd..="builtin cd .."

## a quick way to get out of current directory ##
# Note: Using builtin cd to bypass the cd() function override
alias ..="builtin cd .."
alias ...="builtin cd ../../"
alias ....="builtin cd ../../../"
alias .....="builtin cd ../../../../"
alias .4="builtin cd ../../../../"
alias .5="builtin cd ../../../../.."
alias r="builtin cd /"

# Colorize the grep command output
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"

# Create parent dirs if they don't exist
alias mkdir="mkdir -pv"

# Repeat the previous command with sudo
alias pls="sudo !!"

# Preserve PATH when using sudo
function sudoi() {
    sudo env "PATH=${PATH}" "$@"
}

# ==============================================================================
# File Operations
# ==============================================================================

# Show processes by name
# Usage: psg <pattern>
function psg() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: psg <pattern>"
        return 1
    fi
    ps aux | grep -v grep | grep -i -e "$*"
}

# Prints out your public IP
alias myip="curl -s https://ipecho.net/plain && echo"

# Searches up history commands
alias hgrep="history | grep"

# Broot file manager
alias br="broot"

# Define fd exclusion patterns
FD_EXCLUDE_PATTERN="{.cargo,node_modules,.git,.cache,cache,vendor,tmp,.npm,*.bak,bundles,build}"

# Find files with fd (enhanced find for files)
# Usage: fdf <pattern>
function fdf() {
    if command -v fd >/dev/null 2>&1; then
        fd --hidden --ignore-case --follow --type f --exclude "${FD_EXCLUDE_PATTERN}" "$@"
    else
        find . -type f -iname "*${1}*" 2>/dev/null
    fi
}

# Find directories with fd (enhanced find for directories)
# Usage: fdd <pattern>
function fdd() {
    if command -v fd >/dev/null 2>&1; then
        fd --hidden --ignore-case --follow --type d --exclude "${FD_EXCLUDE_PATTERN}" "$@"
    else
        find . -type d -iname "*${1}*" 2>/dev/null
    fi
}

# 📄 Ripgrep: Enhanced grep with automatic paging
# Override 'rg' to automatically pipe output through less when in terminal
function rg() {
    if [[ -t 1 ]]; then
        command rg -p "$@" | less -RFX
    else
        command rg "$@"
    fi
}

# Swap file with its .bak version, or create .bak if doesn't exist
# Usage: bak <file>
function bak() {
    if [[ -z "$1" ]]; then
        echo "Error: No file or folder name provided."
        return 1
    fi

    if [[ ! -e "$1" && ! -e "$1.bak" ]]; then
        echo "Error: Neither ${1} nor ${1}.bak exists."
        return 1
    fi

    if [[ -e "$1" && -e "$1.bak" ]]; then
        mv "$1" "$1.tmp"
        mv "$1.bak" "$1"
        mv "$1.tmp" "$1.bak"
        echo "Swapped ${1} and ${1}.bak"
    elif [[ -e "$1" ]]; then
        mv "$1" "$1.bak"
        echo "Renamed ${1} to ${1}.bak"
    elif [[ -e "$1.bak" ]]; then
        mv "$1.bak" "$1"
        echo "Renamed ${1}.bak to ${1}"
    fi
}

# Get top biggest files in the filesystem
# Usage: fs [limit]
function fs() {
    local limit=${1:-$DEFAULT_FS_LIMIT}
    sudo du --count-links --all --human-readable --exclude /media 2>/dev/null | grep -v -e '^.*K[[:space:]]' | sort -r -n | head "-n${limit}"
}

# Get top biggest directories
# Usage: ds [limit]
function ds() {
    local limit=${1:-$DEFAULT_DS_LIMIT}
    sudo du --human-readable --max-depth=1 --exclude /media 2>/dev/null | sort -r -h | head "-n$((${limit} + 1))"
}

# Search current directory recursively with grep
# Usage: scd <pattern>
function scd() {
    grep -ir "$@" ./
}

# Download and preview first N lines of a file
# Usage: wcsv <url> [limit]
function wcsv() {
    local limit=${2:-$DEFAULT_WCSV_LIMIT}
    wget "$1" -qO - | head "-${limit}"
}

# https://github.com/vigneshwaranr/bd
# cd to parent directory matching substring
alias bd=". bd -si"

# Takes whatever you have cat previously and vims it
alias v!="fc -e \"sed -i -e \\\"s/cat /vim /\\\"\""

# Tail with follow
alias tf="tail -f"

# Installing, updating or removing applications (if not restricted)
if command -v apt-get >/dev/null 2>&1 && [[ -w /var/lib/apt ]]; then
    alias addrepo="sudo add-apt-repository -y"
    alias install="sudo apt-get install -y "
    alias remove="sudo apt-get remove"
    alias update="sudo apt-get update -y"
    alias upgrade="sudo apt-get update && sudo apt-get upgrade"
    alias dist-upgrade="sudo apt-get update && sudo apt-get dist-upgrade"

    # Install multiple apt packages
    function apt-install() {
        for application in "$@"; do
            sudo apt-get install -f -y "${application}"
        done
    }

    # Update apt package list
    function apt-update() {
        sudo apt-get -y update
    }

    # Add multiple apt repositories
    function add-repo() {
        for repository in "$@"; do
            sudo add-apt-repository -y "${repository}"
        done
    }

    # Simple install with PPA
    function simple-install() {
        repository=$1
        add-repo "${repository}"
        shift
        apt-update
        for application in "$@"; do
            apt-install "${application}"
        done
    }
fi

# Unzip file into directory named after the file
# Usage: unzipd <file.zip>
function unzipd() {
    filename="${1}"
    directory="${filename%.zip}"
    directory="${directory##*/}"
    unzip "${filename}" -d "${directory}"
}

# ==============================================================================
# NPM/Yarn/Node Enhanced Aliases
# ==============================================================================

if command -v npm >/dev/null 2>&1; then
    alias ni="npm install"
    alias nid="npm install --save-dev"
    alias nig="npm install -g"
    alias nrd="npm run dev"
    alias nrb="npm run build"
    alias nrs="npm run start"
    alias nrt="npm run test"
    alias nrl="npm run lint"
    alias nrf="npm run format"
    alias nci="npm ci"
    alias ncc="npm cache clean --force"
    alias nou="npm outdated"
    alias nup="npm update"
    alias pkg="vim package.json"
fi

if command -v yarn >/dev/null 2>&1; then
    # Add yarn package
    function ya() { yarn add "$@"; }
    # Add yarn dev dependency
    function yad() { yarn add -D "$@"; }

    alias yi="yarn install"
    alias yag="yarn global add"
    alias yrm="yarn remove"
    alias yup="yarn upgrade"
    alias yui="yarn upgrade-interactive"
    alias yout="yarn outdated"
    alias ycc="yarn cache clean"
    alias yd="yarn dev"
    alias yb="yarn build"
fi

# pnpm (if you use it)
if command -v pnpm >/dev/null 2>&1; then
    alias pi="pnpm install"
    alias pna="pnpm add"
    alias pnad="pnpm add -D"
    alias pr="pnpm remove"
fi

# ==============================================================================
# Git Aliases and Functions
# ==============================================================================

# Quick git checkout
function c() { git checkout "$@"; }

# Quick git branch
function b() { git branch "$@"; }

alias gcam="git commit -a --amend"
alias gc="git commit -am"
alias gs="git status"
alias gd="git diff --ignore-all-space --ignore-space-at-eol --ignore-space-change --ignore-blank-lines"

# Internal helper: validate and apply .git_cli_prepend safely
function _validate_and_apply_git_prepend() {
    local cmd=("$@")

    # SAFE prepend: validate and parse .git_cli_prepend (no eval!)
    if [[ -f ".git_cli_prepend" ]]; then
        local prepend=$(<.git_cli_prepend)
        # Strip whitespace
        prepend=${prepend## ##}
        prepend=${prepend%% ##}

        # Only allow safe alphanumeric commands (no shell metacharacters)
        if [[ $prepend =~ ^[a-zA-Z0-9_/-]+$ ]]; then
            cmd=($prepend "${cmd[@]}")
        else
            echo "⚠️  Unsafe .git_cli_prepend detected (ignored): $prepend" >&2
        fi
    fi

    "${cmd[@]}"
}

# Git pull with .git_cli_prepend support
function gp() {
    _validate_and_apply_git_prepend git pull
}

# Git push with auto-upstream and .git_cli_prepend support
function gpu() {
    local remote_branch=$(git config "branch.$(git symbolic-ref --short HEAD).merge" 2>/dev/null)

    # Check if remote branch is set
    if [[ -z $remote_branch ]]; then
        _validate_and_apply_git_prepend git push -u origin $(git symbolic-ref --short HEAD)
    else
        _validate_and_apply_git_prepend git push
    fi
}

# Git force push with .git_cli_prepend support
function gpuf() {
    _validate_and_apply_git_prepend git push --force
}

# Search git history for pattern across all commits
function git_search() {
    git rev-list --all | GIT_PAGER=cat xargs git grep "${@}"
}
alias gse="git_search"

# Reset git to a previous commit
function git_reset() {
    local COMMIT="HEAD"
    if [[ "$#" -eq 1 ]]; then
        COMMIT="HEAD~$1"
    fi
    git reset --hard "${COMMIT}"
}
alias gre="git_reset"

# Clone git repo and cd into it
function git-clone() {
    git clone "$@" && cd "$(basename "$1" .git)"
}

# Jump to git repository root
function groot() {
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" ]]; then
        cd "$root"
    else
        echo "Not in a git repository" >&2
        return 1
    fi
}
alias gr='groot'

# Enhanced Git shortcuts
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"
alias gsts="git stash show -p"

alias gco="git checkout"
alias gcob="git checkout -b"
alias gcom="git checkout master || git checkout main"

alias gf="git fetch"
alias gfa="git fetch --all"
alias gfp="git fetch --prune"

function grh() {
    local confirm
    read -p "Hard reset to HEAD? This discards local changes (y/n): " -r confirm
    if [[ "${confirm}" != "y" ]]; then
        echo "Cancelled"
        return 1
    fi
    git reset --hard
}
alias grsoft="git reset --soft"

alias glg="git log --graph --oneline --decorate"
alias glga="git log --graph --oneline --decorate --all"
alias glgp="git log -p"

alias gaa="git add --all"
alias gap="git add --patch"
alias gcan="git commit --amend --no-edit"
alias grs="git restore --staged"

# WIP (Work In Progress) helpers
alias gwip="git add -A && git commit -m 'WIP' --no-verify"
alias gunwip="git log -1 --pretty=%B | grep -q 'WIP' && git reset HEAD~1"

# Conventional commits helper
function gcm() {
    local type=$1
    shift
    git commit -m "${type}: $*"
}

# Composer shortcuts (if available)
if command -v composer >/dev/null 2>&1; then
    alias cu="composer update"
    alias ci="composer install"
    alias cda="composer dump-autoload -o"
fi

# ==============================================================================
# Power User Aliases and Functions
# ==============================================================================

# Create directory and cd into it
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Port listening checker
if command -v lsof >/dev/null 2>&1; then
    alias lsp="sudo lsof -iTCP -sTCP:LISTEN -n -P"
fi

# Kill process interactively with fzf
function killp() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: fzf not installed"
        return 1
    fi

    local pid
    local confirm
    pid=$(ps aux | fzf | awk '{print $2}')
    if [[ -n "$pid" ]]; then
        read -p "Kill PID ${pid} with SIGKILL? (y/n): " -r confirm
        [[ "${confirm}" == "y" ]] && kill -9 "$pid"
    fi
}

# Quick systemd service management
if command -v systemctl >/dev/null 2>&1; then
    alias sctl="sudo systemctl"
    alias sctle="sudo systemctl enable --now"
    alias sctld="sudo systemctl disable --now"
    alias sctls="systemctl status"
    alias sctlr="sudo systemctl restart"
fi

# Disk space analyzer
alias duh="du -h --max-depth=1 | sort -hr"

# Network shortcuts
alias ports="netstat -tulanp 2>/dev/null || ss -tulanp"
alias myip_public="curl -s https://api.ipify.org && echo"
alias myip_local="ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 || hostname -I | awk '{print \$1}'"

# Kill process by port number
function killport() {
    if [ $# -lt 1 ]; then
        echo "Usage: killport <port>"
        echo "Example: killport 3000"
        return 1
    fi

    local port="${1}"
    local pid=$(lsof -ti:"${port}" 2>/dev/null)

    if [[ -n "${pid}" ]]; then
        local confirm
        read -p "Kill PID ${pid} on port ${port} with SIGKILL? (y/n): " -r confirm
        if [[ "${confirm}" == "y" ]]; then
            echo "🔫 Killing process ${pid} on port ${port}..."
            kill -9 "${pid}"
            echo "✓ Process killed"
        else
            echo "❌ Cancelled"
        fi
    else
        echo "❌ No process found on port ${port}"
    fi
}

# Smart package manager runner - detects npm/yarn/pnpm
function run() {
    if [ $# -lt 1 ]; then
        echo "Usage: run <script>"
        echo "Example: run dev"
        return 1
    fi

    if [[ -f "yarn.lock" ]]; then
        echo "📦 Using Yarn"
        yarn "$@"
    elif [[ -f "pnpm-lock.yaml" ]]; then
        echo "📦 Using pnpm"
        pnpm "$@"
    elif [[ -f "package-lock.json" ]] || [[ -f "package.json" ]]; then
        echo "📦 Using npm"
        npm run "$@"
    else
        echo "❌ No package.json found"
        return 1
    fi
}

# Find and replace text in files with confirmation
function replace-in-files() {
    if [ $# -lt 2 ]; then
        echo "Usage: replace-in-files <search> <replace> [file-pattern]"
        echo "Example: replace-in-files 'oldName' 'newName' '*.js'"
        return 1
    fi

    local search="${1}"
    local replace="${2}"
    local pattern="${3:-*}"

    echo "🔍 Searching for: ${search}"
    echo "📝 Replacing with: ${replace}"
    echo "📁 In files matching: ${pattern}"
    echo ""

    # Use ripgrep if available, otherwise fall back to grep
    if command -v rg >/dev/null 2>&1; then
        rg "${search}" -l --glob "${pattern}"
        echo ""
        read -p "Proceed with replacement? (y/n) " confirm
        if [[ "${confirm}" == "y" ]]; then
            rg "${search}" -l --glob "${pattern}" | xargs sed -i "s/${search}/${replace}/g"
            echo "✓ Replacement complete"
        else
            echo "❌ Cancelled"
        fi
    else
        echo "Files containing '${search}':"
        find . -name "${pattern}" -type f -exec grep -l "${search}" {} \;
        echo ""
        read -p "Proceed with replacement? (y/n) " confirm
        if [[ "${confirm}" == "y" ]]; then
            find . -name "${pattern}" -type f -exec sed -i "s/${search}/${replace}/g" {} \;
            echo "✓ Replacement complete"
        else
            echo "❌ Cancelled"
        fi
    fi
}

# Quick directory size check
function dirsize() {
    if [ $# -lt 1 ]; then
        du -sh * 2>/dev/null
    else
        du -sh "$@" 2>/dev/null
    fi
}

# Extract any archive type
function extract() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: extract <file>"
        return 1
    fi

    if [[ -f "${1}" ]]; then
        case "${1}" in
            *.tar.bz2)   tar xjf "${1}"     ;;
            *.tar.gz)    tar xzf "${1}"     ;;
            *.tar.xz)    tar xJf "${1}"     ;;
            *.tar.zst)   tar --zstd -xf "${1}" 2>/dev/null || zstd -d "${1}" | tar xf - ;;
            *.tar.lz4)   lz4 -d "${1}" | tar xf - ;;
            *.bz2)       bunzip2 "${1}"     ;;
            *.rar)       unrar x "${1}"     ;;
            *.gz)        gunzip "${1}"      ;;
            *.tar)       tar xf "${1}"      ;;
            *.tbz2)      tar xjf "${1}"     ;;
            *.tgz)       tar xzf "${1}"     ;;
            *.zip)       unzip "${1}"       ;;
            *.Z)         uncompress "${1}"  ;;
            *.7z)        7z x "${1}"        ;;
            *.xz)        unxz "${1}"        ;;
            *.zst)       unzstd "${1}"      ;;
            *.lz4)       unlz4 "${1}"       ;;
            *)           echo "Cannot extract '${1}' - unknown format" ;;
        esac
    else
        echo "File '${1}' not found"
    fi
}

# Quick HTTP server in current directory
function serve() {
    local port="${1:-8000}"
    echo "🌐 Starting HTTP server on http://localhost:${port}"
    python3 -m http.server "${port}"
}

# Generate random password
function genpass() {
    local length="${1:-20}"
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-"${length}"
}

# Quick note taking
function note() {
    local notes_dir="${HOME}/notes"
    mkdir -p "${notes_dir}"

    if [ $# -eq 0 ]; then
        # Show recent notes
        echo "📝 Recent notes:"
        ls -lt "${notes_dir}" 2>/dev/null | head -10
    else
        # Create new note
        local note_file="${notes_dir}/$(date +%Y-%m-%d)-${1}.md"
        echo "# ${1}" > "${note_file}"
        echo "" >> "${note_file}"
        echo "Date: $(date)" >> "${note_file}"
        echo "" >> "${note_file}"
        vim "${note_file}"
    fi
}

# ==============================================================================
# Modern CLI Tool Aliases
# ==============================================================================

# Lazygit/Lazydocker TUIs
if command -v lazygit >/dev/null 2>&1; then
    function lg() { lazygit "$@"; }
fi

if command -v lazydocker >/dev/null 2>&1; then
    function lzd() { lazydocker "$@"; }
fi

# System monitoring
if command -v bottom >/dev/null 2>&1 || command -v btm >/dev/null 2>&1; then
    alias htop="btm"
    alias top="btm"
fi

# Disk usage
if command -v duf >/dev/null 2>&1; then
    alias df="duf"
fi

if command -v dust >/dev/null 2>&1; then
    alias ncdu="dust"
fi

# Process viewer
if command -v procs >/dev/null 2>&1; then
    function pps() { procs "$@"; }
fi

# DNS lookup
if command -v doggo >/dev/null 2>&1; then
    function dog() { doggo "$@"; }
fi

# Benchmarking
if command -v hyperfine >/dev/null 2>&1; then
    function bench() { hyperfine "$@"; }
fi

# Code statistics
if command -v tokei >/dev/null 2>&1; then
    function cloc() { tokei "$@"; }
    alias stats='tokei --sort code'
fi

# Delta - better git diff
if command -v delta >/dev/null 2>&1; then
    alias diff='delta'
    alias rdiff='/usr/bin/diff'
fi

# Yazi file manager wrapper
if command -v yazi >/dev/null 2>&1; then
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        local cwd
        command yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
    alias fm='yazi'
fi

# ==============================================================================
# FZF Enhancements
# ==============================================================================

if command -v fzf >/dev/null 2>&1; then
    # FZF file finder with preview
    if command -v bat >/dev/null 2>&1; then
        alias fzfp='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"'
    else
        alias fzfp='fzf --preview "cat {}"'
    fi

    # FZF directory finder with cd
    if command -v fd >/dev/null 2>&1; then
        alias fcd='cd $(fd --type d | fzf)'
    else
        alias fcd='cd $(find . -type d 2>/dev/null | fzf)'
    fi

    # FZF process killer
    alias fkill='ps aux | fzf --multi | awk "{print \$2}" | xargs kill -9'

    # FZF + Zoxide/Vim: Fuzzy find directory and edit file
    # Function name 'kkk' is intentionally short for quick access (triple k shortcut)
    function kkk() {
        local dir
        local file
        local preview_cmd="ls -la {}"

        # Use eza for preview if available
        if command -v eza >/dev/null 2>&1; then
            preview_cmd="eza -la {}"
        fi

        # Select directory using zoxide or fd/find
        if command -v zoxide >/dev/null 2>&1; then
            dir=$(zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="$preview_cmd")
        elif command -v fd >/dev/null 2>&1; then
            dir=$(fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="$preview_cmd")
        else
            dir=$(find . ~ -maxdepth 3 -type d ! -path '*/\.*' ! -path '*/node_modules/*' 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="$preview_cmd")
        fi

        # If directory selected, find file within it
        if [[ -n "$dir" ]]; then
            if command -v bat >/dev/null 2>&1; then
                file=$(cd "$dir" && fzf --preview="bat --color=always {}")
            else
                file=$(cd "$dir" && fzf --preview="cat {}")
            fi

            [[ -n "$file" ]] && vim "$dir/$file"
        fi
    }
fi

# ==============================================================================
# Zoxide Integration
# ==============================================================================

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd z)"
    alias cd='z'
    alias cdi='zi'
fi

# ==============================================================================
# Atuin Integration (shell history sync)
# ==============================================================================

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash)"
fi

# ==============================================================================
# Additional Utility Aliases
# ==============================================================================

# Current week number
alias week='date +%V'

# Current time
alias now='date +"%Y-%m-%d %H:%M:%S"'

# Clear screen
alias c='clear'

# Create directory alias (function in functions.sh)
alias md='mkcd'

# Vim shortcut
if command -v vim >/dev/null 2>&1; then
    alias v='vim'
fi

# Micro editor
if command -v micro >/dev/null 2>&1; then
    alias m='micro'
fi

# Print PATH, one entry per line
alias path='echo "$PATH" | tr ":" "\n"'
