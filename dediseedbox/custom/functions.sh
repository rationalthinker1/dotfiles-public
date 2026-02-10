#!/usr/bin/env bash
# ==============================================================================
# functions.sh - Portable Utility Functions for Restricted Seedbox
# ==============================================================================
# Bash functions using only standard GNU tools
# Loaded by .bashrc via oh-my-bash custom directory
# ==============================================================================

# ------------------------------------------------------------------------------
# Reload Bash Configuration
# ------------------------------------------------------------------------------
reload_bash() {
    source /.bashrc
    echo "Bash configuration reloaded"
}
alias rebash="reload_bash"

# ------------------------------------------------------------------------------
# Process Search
# ------------------------------------------------------------------------------
# Usage: psg <pattern>
psg() {
    [[ $# -eq 0 ]] && { echo "Usage: psg <pattern>"; return 1; }
    ps aux | grep -v grep | grep -i -e "$*"
}

# ------------------------------------------------------------------------------
# Archive Extraction (Enhanced)
# ------------------------------------------------------------------------------
# Usage: extract <file>
# Supports: tar.*, zip, 7z, rar, bz2, gz, xz, zst, lz4, and more
extract() {
    [[ $# -eq 0 ]] && { echo "Usage: extract <archive-file>"; return 1; }
    [[ ! -f "$1" ]] && { echo "Error: File '$1' not found"; return 1; }

    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz)   tar xzf "$1" ;;
        *.tar.xz|*.txz)   tar xJf "$1" ;;
        *.tar.zst)        tar --zstd -xf "$1" 2>/dev/null || { zstd -d "$1" | tar xf - ; } ;;
        *.tar.lz4)        lz4 -d "$1" | tar xf - ;;
        *.tar)            tar xf "$1" ;;
        *.bz2)            bunzip2 "$1" ;;
        *.rar)            unrar x "$1" 2>/dev/null || echo "Error: unrar not available" ;;
        *.gz)             gunzip "$1" ;;
        *.zip)            unzip "$1" ;;
        *.Z)              uncompress "$1" ;;
        *.7z)             7z x "$1" ;;
        *.xz)             unxz "$1" ;;
        *.zst)            unzstd "$1" 2>/dev/null || zstd -d "$1" ;;
        *.lz4)            unlz4 "$1" 2>/dev/null || lz4 -d "$1" ;;
        *)
            echo "Error: Cannot extract '$1' - unknown format"
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Password Generation
# ------------------------------------------------------------------------------
# Usage: genpass [length]
genpass() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-"${length}"
}

# ------------------------------------------------------------------------------
# Make Directory and CD
# ------------------------------------------------------------------------------
# Usage: mkcd <directory>
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# ------------------------------------------------------------------------------
# Backup/Restore File with .bak Extension
# ------------------------------------------------------------------------------
# Usage: bak <file>
bak() {
    [[ $# -eq 0 ]] && { echo "Usage: bak <file>"; return 1; }

    local file="$1"
    local backup="${file}.bak"

    if [[ -f "$file" && ! -f "$backup" ]]; then
        cp "$file" "$backup"
        echo "Created backup: $backup"
    elif [[ ! -f "$file" && -f "$backup" ]]; then
        mv "$backup" "$file"
        echo "Restored from backup: $file"
    elif [[ -f "$file" && -f "$backup" ]]; then
        local temp=$(mktemp)
        mv "$file" "$temp"
        mv "$backup" "$file"
        mv "$temp" "$backup"
        echo "Swapped: $file <-> $backup"
    else
        echo "Error: Neither $file nor $backup exists"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Directory Disk Usage
# ------------------------------------------------------------------------------
# Usage: dirsize [directory|directories]
# Shows size of directories, or all subdirectories if no args given
dirsize() {
    if [[ $# -lt 1 ]]; then
        du -sh * 2>/dev/null
    else
        du -sh "$@" 2>/dev/null
    fi
}

# Usage: fs [limit] - Show largest files in current directory
fs() {
    local limit="${1:-50}"
    find . -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n "$limit"
}

# Usage: ds [limit] - Show largest directories in current directory
ds() {
    local limit="${1:-50}"
    du -h --max-depth=1 2>/dev/null | sort -rh | head -n "$limit"
}

# ------------------------------------------------------------------------------
# Note Taking
# ------------------------------------------------------------------------------
# Usage: note [text] - Quick note to /notes/notes.txt
note() {
    local notes_dir="/notes"
    local notes_file="${notes_dir}/notes.txt"

    [[ ! -d "$notes_dir" ]] && mkdir -p "$notes_dir"

    if [[ $# -eq 0 ]]; then
        vim "$notes_file"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$notes_file"
        echo "Note saved to $notes_file"
    fi
}

# ------------------------------------------------------------------------------
# Find Files
# ------------------------------------------------------------------------------
# Usage: fdf <pattern> - Find files by name
fdf() {
    [[ $# -eq 0 ]] && { echo "Usage: fdf <pattern>"; return 1; }
    find . -type f -iname "*${1}*" 2>/dev/null
}

# Usage: fdd <pattern> - Find directories by name
fdd() {
    [[ $# -eq 0 ]] && { echo "Usage: fdd <pattern>"; return 1; }
    find . -type d -iname "*${1}*" 2>/dev/null
}

# ------------------------------------------------------------------------------
# Recursive Grep
# ------------------------------------------------------------------------------
# Usage: rgrep <pattern> [path]
# Unalias rgrep if it exists (conflicts with system rgrep alias)
unalias rgrep 2>/dev/null
rgrep() {
    [[ $# -eq 0 ]] && { echo "Usage: rgrep <pattern> [path]"; return 1; }
    local pattern="$1"
    local path="${2:-.}"
    grep -r -n --color=auto "$pattern" "$path" 2>/dev/null
}

# ------------------------------------------------------------------------------
# Find and Replace in Files
# ------------------------------------------------------------------------------
# Usage: replace-in-files <search> <replace> [file-pattern]
# Example: replace-in-files "oldName" "newName" "*.txt"
replace-in-files() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: replace-in-files <search> <replace> [file-pattern]"
        echo "Example: replace-in-files 'oldName' 'newName' '*.txt'"
        return 1
    fi

    local search="$1"
    local replace="$2"
    local pattern="${3:-*}"

    echo "🔍 Searching for: ${search}"
    echo "📝 Replacing with: ${replace}"
    echo "📁 In files matching: ${pattern}"
    echo ""

    # Use ripgrep if available, otherwise fall back to grep
    if command -v rg >/dev/null 2>&1; then
        # Show matches first
        rg "${search}" -l --glob "${pattern}"

        echo ""
        read -r -p "Proceed with replacement? (y/n) " confirm
        if [[ "${confirm}" == "y" ]]; then
            rg "${search}" -l --glob "${pattern}" | xargs sed -i "s/${search}/${replace}/g"
            echo "✓ Replacement complete"
        else
            echo "❌ Cancelled"
        fi
    else
        # Fallback to standard grep and find
        echo "Files containing '${search}':"
        find . -name "${pattern}" -type f -exec grep -l "${search}" {} \;

        echo ""
        read -r -p "Proceed with replacement? (y/n) " confirm
        if [[ "${confirm}" == "y" ]]; then
            find . -name "${pattern}" -type f -exec sed -i "s/${search}/${replace}/g" {} \;
            echo "✓ Replacement complete"
        else
            echo "❌ Cancelled"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Reference File Management
# ------------------------------------------------------------------------------
# Usage: ref [topic]
# Without args: Shows main reference file
# With args: Opens/creates topic-specific reference file
# Examples: ref git, ref docker, ref kubernetes
ref() {
    local ref_dir="/.dotfiles/dediseedbox/references"
    local main_ref="${ref_dir}/reference.txt"

    # Ensure references directory exists
    [[ ! -d "${ref_dir}" ]] && mkdir -p "${ref_dir}"

    if [[ $# -eq 0 ]]; then
        # Create main reference file if it doesn't exist
        if [[ ! -f "${main_ref}" ]]; then
            cat > "${main_ref}" <<'EOF'
# ==============================================================================
# Main Reference File
# ==============================================================================
# Quick command reminders and reference notes
# Use 'ref <topic>' to create topic-specific reference files
#
# Example topics:
# - ref git       : Git commands and workflows
# - ref docker    : Docker commands
# - ref bash      : Bash scripting tips
# - ref media     : Media management commands (Emby, torrenting)
# - ref network   : Network troubleshooting
#
# Existing reference files:
EOF
            # List existing reference files
            for file in "${ref_dir}"/*.txt; do
                [[ -f "$file" ]] && echo "# - $(basename "$file" .txt)" >> "${main_ref}"
            done
        fi
        cat "${main_ref}"
    else
        # Open/create topic-specific reference file
        local name="$1"
        local file="${ref_dir}/${name}.txt"

        if [[ ! -f "${file}" ]]; then
            cat > "${file}" <<EOF
# ==============================================================================
# ${name} Reference
# ==============================================================================
# Created: $(date '+%Y-%m-%d %H:%M:%S')
#
# Add your ${name} commands, tips, and notes here
#

EOF
        fi
        vim "${file}"
    fi
}

# ------------------------------------------------------------------------------
# Quick HTTP Server
# ------------------------------------------------------------------------------
# Usage: serve [port]
# Start a simple HTTP server in current directory (default port 8000)
serve() {
    local port="${1:-8000}"
    echo "🌐 Starting HTTP server on http://localhost:${port}"
    echo "Press Ctrl+C to stop"
    python3 -m http.server "${port}"
}

# ------------------------------------------------------------------------------
# Port Management
# ------------------------------------------------------------------------------
# List listening ports (lsof-based - more accurate)
alias lsp="sudo lsof -iTCP -sTCP:LISTEN -n -P"

# Kill process on port
# Usage: killport <port>
killport() {
    [[ $# -eq 0 ]] && { echo "Usage: killport <port>"; return 1; }

    if command -v lsof >/dev/null 2>&1; then
        local pid=$(lsof -ti tcp:"$1")
        if [[ -n "$pid" ]]; then
            kill -9 "$pid"
            echo "Killed process $pid on port $1"
        else
            echo "No process found on port $1"
        fi
    else
        echo "Error: lsof not available. Use 'ps aux' to find process and 'kill <pid>' manually."
        return 1
    fi
}

# ------------------------------------------------------------------------------
# FZF Functions (if fzf is installed)
# ------------------------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    # FZF + ripgrep: Interactive grep
    # Usage: frg [pattern]
    frg() {
        local pattern="${1:-}"
        if command -v rg >/dev/null 2>&1; then
            rg --color=always --line-number --no-heading --smart-case "${pattern}" |
                fzf --ansi \
                    --color "hl:-1:underline,hl+:-1:underline:reverse" \
                    --delimiter : \
                    --preview 'bat --color=always {1} --highlight-line {2}' \
                    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
        else
            grep -r -n --color=always "${pattern}" . |
                fzf --ansi \
                    --delimiter : \
                    --preview 'less +{2} {1}'
        fi
    }

    # FZF + find: Interactive file finder with preview
    # Usage: ff
    ff() {
        local file
        if command -v fd >/dev/null 2>&1 && command -v bat >/dev/null 2>&1; then
            file=$(fd --type f --hidden --follow --exclude .git |
                fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}')
        elif command -v fd >/dev/null 2>&1; then
            file=$(fd --type f --hidden --follow --exclude .git |
                fzf --preview 'cat {}')
        else
            file=$(find . -type f 2>/dev/null |
                fzf --preview 'cat {}')
        fi
        [[ -n "$file" ]] && echo "$file"
    }

    # FZF + git: Interactive git log browser
    # Usage: flog
    flog() {
        git log --oneline --color=always --decorate |
            fzf --ansi --no-sort --reverse --preview 'git show --color=always {1}'
    }
fi

# ------------------------------------------------------------------------------
# Zoxide Functions (if zoxide is installed)
# ------------------------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
    # Jump to directory and list contents
    # Usage: zl <pattern>
    zl() {
        local dir
        dir=$(zoxide query "$@")
        if [[ -n "$dir" ]]; then
            cd "$dir" || return 1
            if command -v eza >/dev/null 2>&1; then
                eza -la
            else
                ls -la
            fi
        fi
    }
fi

# ------------------------------------------------------------------------------
# Git Delta Functions (if delta is installed)
# ------------------------------------------------------------------------------
if command -v delta >/dev/null 2>&1; then
    # Show git diff with delta
    # Usage: gdd [file]
    gdd() {
        git diff "$@" | delta
    }

    # Show git diff --cached with delta
    # Usage: gddc [file]
    gddc() {
        git diff --cached "$@" | delta
    }
fi

# ------------------------------------------------------------------------------
# Tokei Functions (if tokei is installed)
# ------------------------------------------------------------------------------
if command -v tokei >/dev/null 2>&1; then
    # Code statistics for current directory
    # Usage: stats
    stats() {
        tokei --sort code
    }

    # Compare code stats between directories
    # Usage: cmpstats <dir1> <dir2>
    cmpstats() {
        [[ $# -lt 2 ]] && { echo "Usage: cmpstats <dir1> <dir2>"; return 1; }
        echo "=== $1 ==="
        tokei --sort code "$1"
        echo ""
        echo "=== $2 ==="
        tokei --sort code "$2"
    }
fi

# ------------------------------------------------------------------------------
# Yazi File Manager (if installed)
# ------------------------------------------------------------------------------
if command -v yazi >/dev/null 2>&1; then
    # Yazi wrapper that changes directory on exit
    # Usage: y [directory]
    y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        local cwd
        command yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# ------------------------------------------------------------------------------
# JQ/YQ Helper Functions (if installed)
# ------------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    # Pretty print JSON
    # Usage: json <file>
    json() {
        [[ $# -eq 0 ]] && { echo "Usage: json <file>"; return 1; }
        if command -v bat >/dev/null 2>&1; then
            jq '.' "$1" | bat --language json
        else
            jq '.' "$1"
        fi
    }
fi

if command -v yq >/dev/null 2>&1; then
    # Pretty print YAML
    # Usage: yaml <file>
    yaml() {
        [[ $# -eq 0 ]] && { echo "Usage: yaml <file>"; return 1; }
        if command -v bat >/dev/null 2>&1; then
            yq '.' "$1" | bat --language yaml
        else
            yq '.' "$1"
        fi
    }
fi

# ------------------------------------------------------------------------------
# Enhanced CD Function with FZF + Zoxide Integration
# ------------------------------------------------------------------------------
# Requirements: fzf (required), zoxide (optional), eza (optional), fd (optional)
#
# Usage:
#   cd           - Fuzzy select from zoxide history (or common directories if no zoxide)
#   cd ..        - Fuzzy select parent directories
#   cd .         - Fuzzy select subdirectories
#   cd -         - Fuzzy select recent directories
#   cd <path>    - Normal cd, or fuzzy match from zoxide if path doesn't exist
#
if command -v fzf >/dev/null 2>&1; then
    cd() {
        # Only override cd in interactive shells; use builtin for scripts
        [[ $- == *i* ]] || { builtin cd "$@"; return; }

        # Determine preview command (prefer eza, fallback to ls)
        local preview_cmd="ls -la"
        if command -v eza >/dev/null 2>&1; then
            preview_cmd="eza -la"
        fi

        if [[ $# -eq 0 ]]; then
            # No args: show zoxide directory history or fall back to common directories
            local dir
            if command -v zoxide >/dev/null 2>&1; then
                dir=$(zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="$preview_cmd {}")
            else
                # Fallback: find directories from common locations
                if command -v fd >/dev/null 2>&1; then
                    dir=$(fd --type d --max-depth 3 --hidden --exclude .git --exclude .cache --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="$preview_cmd {}")
                else
                    dir=$(find ~ -maxdepth 3 -type d \( -name .git -o -name .cache -o -name node_modules \) -prune -o -type d -print 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="$preview_cmd {}")
                fi
            fi
            [[ -n "$dir" ]] && builtin cd "$dir"

        elif [[ "$1" == ".." ]]; then
            # cd .. : use builtin cd (normal behavior - go up one directory)
            builtin cd "$@"

        elif [[ "$1" == "." ]]; then
            # cd . : use builtin cd (normal behavior - stay in current directory)
            builtin cd "$@"

        elif [[ "$1" == "-" ]]; then
            # cd - : show last 10 directories from zoxide or recent dirs from history
            local dir
            if command -v zoxide >/dev/null 2>&1; then
                dir=$(zoxide query -l | head -10 | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="$preview_cmd {}")
            else
                # Fallback: extract directories from shell history
                local -a recent_dirs=()
                while IFS= read -r line; do
                    # Extract directory paths from 'cd <path>' commands
                    if [[ "$line" =~ cd[[:space:]]+(.+) ]]; then
                        local path="${BASH_REMATCH[1]}"
                        # Expand ~ to HOME
                        path="${path/#\~/$HOME}"
                        # Remove quotes if present
                        path="${path//\"/}"
                        path="${path//\'/}"
                        # Add to array if it's a valid directory
                        [[ -d "$path" ]] && recent_dirs+=("$path")
                    fi
                done < <(history 20 | grep -o 'cd .*')

                if [[ ${#recent_dirs[@]} -gt 0 ]]; then
                    # Remove duplicates while preserving order
                    local -a unique_dirs=()
                    local -A seen=()
                    for d in "${recent_dirs[@]}"; do
                        [[ -z "${seen[$d]}" ]] && unique_dirs+=("$d") && seen[$d]=1
                    done
                    dir=$(printf '%s\n' "${unique_dirs[@]}" | fzf --height=40% --inline-info --reverse --preview="$preview_cmd {}")
                fi
            fi
            [[ -n "$dir" ]] && builtin cd "$dir"

        else
            # cd <path>: try normal cd, if fails try fuzzy match from zoxide
            if [[ -d "$1" ]]; then
                builtin cd "$@"
            else
                if command -v zoxide >/dev/null 2>&1; then
                    local matches
                    matches=$(zoxide query -l | grep -i "$1")
                    if [[ -n "$matches" ]]; then
                        local dir
                        dir=$(echo "$matches" | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="$preview_cmd {}")
                        [[ -n "$dir" ]] && builtin cd "$dir"
                    else
                        builtin cd "$@"
                    fi
                else
                    builtin cd "$@"
                fi
            fi
        fi
    }

    # ------------------------------------------------------------------------------
    # FZF Tab Completion for CD Command
    # ------------------------------------------------------------------------------
    # Trigger FZF when pressing Tab after 'cd' command
    # Shows all directories (folders and subfolders) with fuzzy search
    # ------------------------------------------------------------------------------
    _fzf_complete_cd() {
        local cur="${COMP_WORDS[COMP_CWORD]}"

        # Determine preview command (prefer eza, fallback to ls)
        local preview_cmd="ls -la"
        if command -v eza >/dev/null 2>&1; then
            preview_cmd="eza -la"
        fi

        # Build directory list using fd or find
        local dirs
        if command -v fd >/dev/null 2>&1; then
            # Use fd for faster directory search
            dirs=$(fd --type d --hidden --follow --exclude .git --exclude node_modules --exclude .cache . "${cur:-.}" 2>/dev/null)
        else
            # Fallback to find
            dirs=$(find "${cur:-.}" -type d \( -name .git -o -name node_modules -o -name .cache \) -prune -o -type d -print 2>/dev/null)
        fi

        # Show fzf for directory selection
        local selected
        selected=$(echo "$dirs" | fzf \
            --height=50% \
            --reverse \
            --inline-info \
            --preview="$preview_cmd {}" \
            --preview-window=right:50% \
            --bind='tab:down,btab:up' \
            --prompt="cd> " \
            --header="Select directory (Tab/Shift-Tab to navigate)" \
            --query="$cur" \
            --select-1 \
            --exit-0)

        if [[ -n "$selected" ]]; then
            # Replace current word with selected directory
            COMPREPLY=("$selected")
        else
            # If no selection, use default bash completion
            COMPREPLY=()
        fi
    }

    # Register the completion function for cd
    # Use -o nospace to prevent adding space after completion
    # Use -o dirnames as fallback when fzf is not triggered
    complete -o nospace -o dirnames -F _fzf_complete_cd cd
fi
