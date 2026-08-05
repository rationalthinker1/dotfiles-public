#!/usr/bin/env zsh
# ==============================================================================
# aliases.zsh - Functions and Aliases
# ==============================================================================
# Central repository for all custom aliases, functions, and command enhancements
#
# Sourced by: .zshrc (line 923)
#
# SECTIONS:
# - ZSH Configuration (reload, navigation)
# - Modern CLI Tools (bat, eza, ripgrep, fzf)
# - Git Workflow (smart commits, prepend support)
# - Docker Management (compose, exec, cleanup)
# - Development Tools (npm, yarn, laravel)
# - System Utilities (processes, networking, compression)
# ==============================================================================

# ==============================================================================
# Configuration Constants
# ==============================================================================
# typeset -g (not readonly): this file is re-sourced by reload_zsh/vpr, and a
# second readonly assignment errors with "read-only variable".
typeset -g DEFAULT_FS_LIMIT=50        # Default limit for fs() function
typeset -g DEFAULT_DS_LIMIT=50        # Default limit for ds() function
typeset -g DEFAULT_WCSV_LIMIT=10      # Default limit for wcsv() function
typeset -g WSLPATH_CACHE_MAX_ENTRIES=100  # Max WSL path cache entries

# ==============================================================================
# ZSH Configuration
# ==============================================================================

# Reload ZSH configuration
# Usage: reload_zsh
# Reloads .zshrc without restarting the shell
function reload_zsh() {
    source "${ZDOTDIR}/.zshrc"
}
alias rebash="reload_zsh"

alias dirzshrc="grep -nT '^#|' \"${HOME}/.zshrc\""
alias zshrc="vim \"${HOME}/.zshrc\""
# vpr: Edit and reload .zshrc in one command
alias vpr="vim \"${ZDOTDIR}/.zshrc\" && reload_zsh"
# common directories
alias dot="cd ~/.dotfiles"
alias con="cd ~/.config"

# 🦇 Bat: Better cat with syntax highlighting
# Override 'cat' to use 'bat' for prettier output
# Use 'rcat' or 'command cat' to access original cat command
function cat() {
	# Only override cat in interactive shells; use builtin for scripts
	[[ -o interactive ]] || { command cat "$@"; return; }

	# Fall back to regular cat if bat is not installed
	(( $+commands[bat] )) || { command cat "$@"; return; }

	# Use regular cat if output is being piped (not a terminal)
	[[ -t 1 ]] || { command cat "$@"; return; }

	bat "$@"
}
alias rcat='command cat'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# 🔍 FZF + Zoxide: Enhanced cd with enhancd-style features
# cd (no args) - fuzzy select from zoxide history (if available) or recent dirs
# cd .. - fuzzy select parent directories
# cd . - fuzzy select subdirectories
# cd - - fuzzy select recent directories (last 10)
# cd <path> - normal cd or fuzzy match from history if not exists
function cd() {
	# Only override cd in interactive shells; use builtin for scripts
	[[ -o interactive ]] || { builtin cd "$@"; return; }

	if [[ $# -eq 0 ]]; then
		# No args: show zoxide directory history or fall back to common directories
		local dir
		if (( $+commands[zoxide] )); then
			# echo "🔍 Fuzzy selecting from zoxide directory history..."
			dir=$(zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
		else
			# Fallback: find directories from common locations
			# echo "🔍 Fuzzy selecting from common directories..."
			dir=$(fd --type d --max-depth 3 --hidden --exclude .git --exclude .cache --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="eza -la {}")
		fi
		[[ -n "$dir" ]] && builtin cd "$dir"
	elif [[ "$1" == ".." ]]; then
		# cd .. : show all parent directories
		local parents=()
		local current="$PWD"
		while [[ "$current" != "/" ]]; do
			current="${current:h}"
			parents+=("$current")
		done
		if [[ ${#parents[@]} -gt 0 ]]; then
			local dir
			dir=$(printf '%s\n' "${parents[@]}" | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
			[[ -n "$dir" ]] && builtin cd "$dir"
		fi
	elif [[ "$1" == "." ]]; then
		# cd . : show all subdirectories recursively
		local dir
		if (( $+commands[fd] )); then
			dir=$(fd --type d --hidden --exclude .git --exclude node_modules --exclude .cache | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
		else
			dir=$(find . -type d -name .git -prune -o -name node_modules -prune -o -type d -print 2>/dev/null | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
		fi
		[[ -n "$dir" ]] && builtin cd "$dir"
	elif [[ "$1" == "-" ]]; then
		# cd - : show last 10 directories from zoxide or recent dirs from history
		local dir
		if (( $+commands[zoxide] )); then
			dir=$(zoxide query -l | head -10 | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
		else
			# Fallback: extract directories from shell history using ZSH-native parameter expansion
			# Extract 'cd <path>' commands, remove 'cd ' prefix, expand ~, deduplicate
			local -a recent_dirs=(${${${(M)${(f)"$(fc -l -10)"}:#*cd *}##* cd }/#\~/${HOME}})
			if (( ${#recent_dirs[@]} > 0 )); then
				dir=$(printf '%s\n' "${recent_dirs[@]}" | sort -u | fzf --height=40% --inline-info --reverse --preview="eza -la {}")
			fi
		fi
		[[ -n "$dir" ]] && builtin cd "$dir"
	else
		# cd <path>: try normal cd, if fails try fuzzy match from zoxide
		if [[ -d "$1" ]]; then
			builtin cd "$@"
		else
			if (( $+commands[zoxide] )); then
				local matches
				matches=$(zoxide query -l | grep -i "$1")
				if [[ -n "$matches" ]]; then
					local dir
					dir=$(echo "$matches" | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
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

# 🧭 Yazi: Change directory based on project config
function y() {
	if ! (( $+commands[yazi] )); then
		echo "Error: requires 'yazi' to be installed." >&2
		return 1
	fi
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# 🔍 FZF + Vim: two-stage picker - choose a directory, then a file inside it, then edit.
# Stage 1 lists directories from zoxide's history (zoxide only indexes directories, not
# files, hence the two stages), previewed with eza; stage 2 lists that directory's files,
# previewed with bat. Falls back to fd for stage 1 when zoxide is missing.
# Function name 'kkk' is intentionally short for quick access (triple k shortcut)
function kkk() {
	local dir file lister

	if (( $+commands[zoxide] )); then
		dir=$(zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
	else
		# Fallback: find directories from common locations
		dir=$(fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="eza -la {}")
	fi
	[[ -n "${dir}" ]] || return 0

	# List the directory explicitly rather than `cd`-ing into it. A cd here would run
	# inside a command substitution and fire the chpwd hooks, whose stdout would be
	# captured into ${file} and corrupt the path handed to vim. Listing also yields
	# paths already prefixed with ${dir}, so no concatenation is needed.
	if (( $+commands[rg] )); then
		lister=(rg --files "${dir}")
	elif (( $+commands[fd] )); then
		lister=(fd --type f --hidden --exclude .git --exclude node_modules . "${dir}")
	else
		lister=(find "${dir}" -type f)
	fi

	file=$("${lister[@]}" 2>/dev/null | fzf --preview="bat --color=always {}")
	[[ -n "${file}" ]] && vim "${file}"
}

## 📁 Eza: Modern ls replacement with colors and icons
# Override 'ls' and related commands to use 'eza'
# Use '\ls' to access original ls command
## Colorize the ls output ##
function ls() {
	# Only override ls in interactive shells; use builtin for scripts
	[[ -o interactive ]] || { command ls --color=auto "$@"; return; }

	# Fall back to regular ls if eza is not installed
	(( $+commands[eza] )) || { command ls --color=auto "$@"; return; }

	eza --color=auto "$@"
}

## Use a long listing format ##
# List with human readable filesizes
alias l='eza --color=auto --long --header --group --group-directories-first'
# List all, with human readable filesizes
alias ll='eza --color=auto --long --header --group --all --group-directories-first'
# Same as above, but ordered by size
alias lls='eza --color=auto --long --header --group --all --group-directories-first --sort size'
# Same as above, but ordered by date
alias lt='eza --color=auto --long --header --group --all --group-directories-first --reverse --sort oldest'
# Show tree level 2
alias llt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=2'
# Show tree level 3
alias lllt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=3'
# Show tree level 4
alias llllt='eza --color=auto --long --header --group --all --group-directories-first --tree --level=4'
# Show hidden files ##
alias l.='eza --color=auto --long --header --group --all --group-directories-first --list-dirs .*'
# Show only directories
alias ld='eza --color=auto --long --header --group --all --group-directories-first --only-dirs'

## show history on h
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

## Colorize the grep command output for ease of use (good for log files)##
function grep() {
	# Only add color in interactive shells; use plain grep for scripts
	[[ -o interactive ]] || { command grep "$@"; return; }

	command grep --color=auto "$@"
}

# egrep/fgrep binaries are deprecated (GNU grep >= 3.8 warns on every use);
# delegate to `grep -E` / `grep -F` instead.
function egrep() {
	# Only add color in interactive shells; use plain grep for scripts
	[[ -o interactive ]] || { command grep -E "$@"; return; }

	command grep -E --color=auto "$@"
}

function fgrep() {
	# Only add color in interactive shells; use plain grep for scripts
	[[ -o interactive ]] || { command grep -F "$@"; return; }

	command grep -F --color=auto "$@"
}

# Create parent dirs if they don't exist
alias mkdir="mkdir -pv"

# Repeat the previous command with sudo.
# A function, not `alias pls="sudo !!"`: history expansion runs while the line is
# read, BEFORE alias expansion, so `!!` inside an alias body is never expanded.
# (OMZP::sudo's double-ESC covers the interactive case too.)
function pls() {
    local last="$(fc -ln -1)"
    print -ru2 -- "sudo ${last}"
    sudo "${(z)last[@]}"
}

# Preserve PATH when using sudo
function sudoi() {
    sudo env "PATH=${PATH}" "$@"
}

# sshfs with proper default settings
function sshfs() {
    command sshfs -o allow_other,uid="$(id -u)",gid="$(id -g)" "$@"
}

# Suspend / hibernate (pm-utils is long gone; systemd owns power management now)
alias suspend-now="systemctl suspend"
alias hibernate="systemctl hibernate"

# Show processes by name
# example: psg bash
function psg() {
	if [[ $# -eq 0 ]]; then
		echo "Usage: psg <pattern>"
		return 1
	fi
	ps aux | grep -v grep | grep -i -e "$*"
}

# Append -c to continue the download in case of problems
#alias wget='wget -c'

# Prints out your public IP (myip_public in Power User section is the same thing)
alias myip="curl -s https://api.ipify.org && echo"

# Searches up history commands
alias hgrep="history | grep"

alias br="broot"

# fd exclusion patterns used by fdf/fdd below (defined only here, not in .zshenv)
typeset -ga _fd_excludes=(
    .cargo
    node_modules
    .git
    .cache
    cache
    vendor
    tmp
    .npm
    "*.bak"
    bundles
    build
)
typeset -g FD_EXCLUDE_PATTERN="{${(j:,:)_fd_excludes}}"
unset _fd_excludes

# Find files with fd (enhanced find for files)
# Usage: fdf <pattern>
# Example: fdf "*.js"
function fdf() {
	fd --hidden --ignore-case --follow --type f --exclude "${FD_EXCLUDE_PATTERN}" "$@"
}
# Find directories with fd (enhanced find for directories)
# Usage: fdd <pattern>
# Example: fdd "node_modules"
function fdd() {
	fd --hidden --ignore-case --follow --type d --exclude "${FD_EXCLUDE_PATTERN}" "$@"
}

# 📄 Ripgrep: Enhanced grep with automatic paging
# Override 'rg' to automatically pipe output through less when in terminal
# Use 'command rg' to access original ripgrep without paging
function rg() {
	if [[ -t 1 ]]; then
		command rg -p "$@" | less -RFX
	else
		command rg "$@"
	fi
}

# Swap file with its .bak version, or create .bak if doesn't exist
# Usage: bak <file>
# Example: bak config.txt
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

# Copy file/folder with timestamp suffix
# Usage: bakt <file|folder>
# Example: bakt config.json -> config_20301512022026_backup.json
function bakt() {
    if [[ -z "$1" ]]; then
        echo "Error: No file or folder name provided."
        return 1
    fi

    if [[ ! -e "$1" ]]; then
        echo "Error: ${1} does not exist."
        return 1
    fi

    local timestamp=$(date +%S%M%H%d%m%Y)
    local target

    if [[ -d "$1" ]]; then
        # Directory - no extension to handle
        target="${1}_${timestamp}_backup"
    else
        # File - handle extension
        local basename="${1%.*}"
        local extension="${1##*.}"

        if [[ "$basename" == "$1" ]]; then
            # No extension
            target="${1}_${timestamp}_backup"
        else
            # Has extension
            target="${basename}_${timestamp}_backup.${extension}"
        fi
    fi

    cp -r "$1" "$target"
    echo "Copied ${1} to ${target}"
}


# look at the size of the sub-directories level 1
# Uncommented and created function below

# Get top biggest files in the filesystem
# Usage: fs [limit]
# Example: fs 20
function fs() {
	local limit=${1:-$DEFAULT_FS_LIMIT}
	sudo du --count-links --all --human-readable --exclude /media 2>/dev/null | grep -v -e '^.*K[[:space:]]' | sort -r -n | head "-n${limit}"
}

# Get top biggest directories
# Usage: ds [limit]
# Example: ds 20
function ds() {
	local limit=${1:-$DEFAULT_DS_LIMIT}
	sudo du --human-readable --max-depth=1 --exclude /media 2>/dev/null | sort -r -h | head "-n$((${limit} + 1))"
}

# Search current directory recursively with grep
# Usage: scd <pattern>
# Example: scd "TODO"
function scd() {
	grep -ir "$@" ./
}

# Download and preview first N lines of a file
# Usage: wcsv <url> [limit]
# Example: wcsv "https://example.com/data.csv" 20
function wcsv() {
	#wget http://riptide-reflection.s3.amazonaws.com/export_2_.csv -qO - | head -10
	local limit=${2:-$DEFAULT_WCSV_LIMIT}
	wget "$1" -qO - | head "-${limit}"
	#echo "wget $1 -qO - | head -${limit}"
}

# https://github.com/vigneshwaranr/bd
# cd to parent directory matching substring
alias bd=". bd -si"

# takes whatever you have cat previously and vims it
alias v!="fc -e \"sed -i -e \\\"s/cat /vim /\\\"\""

# example: tf laravel.log
alias tf="tail -f"

# Installing, updating or removing applications aliases and functions (Linux/WSL only)
if [[ "${HOST_OS}" == "linux" || "${HOST_OS}" == "wsl" ]]; then
	alias addrepo="sudo add-apt-repository -y"
	alias install="sudo apt-get install -y "
	alias remove="sudo apt-get remove"
	alias update="sudo apt-get update -y"
	alias upgrade="sudo apt-get update && sudo apt-get upgrade"
	alias dist-upgrade="sudo apt-get update && sudo apt-get dist-upgrade"

	# Install multiple apt packages
	# Usage: apt-install <package1> [package2...]
	# Example: apt-install vim git curl
	function apt-install() {
		for application in "$@"; do
			sudo apt-get install -f -y "${application}"
		done
	}

	# Update apt package list
	# Usage: apt-update
	function apt-update() {
		sudo apt-get -y update
	}

	# Add multiple apt repositories
	# Usage: add-repo <repo1> [repo2...]
	# Example: add-repo ppa:deadsnakes/ppa
	function add-repo() {
		for repository in "$@"; do
			sudo add-apt-repository -y "${repository}"
		done
	}

	# simple-install ppa:numix/ppa numix-gtk-theme numix-icon-theme-circle
	function simple-install() {
		repository=$1

		# Add the repository
		add-repo "${repository}"
		shift

		# Update list of available packages
		apt-update

		for application in "$@"; do
			# Install application
			apt-install "${application}"
		done
	}
fi

# Unzip file into directory named after the file
# Usage: unzipd <file.zip>
# Example: unzipd archive.zip
# Prefers ouch (works for any archive type, -d pins the exact output dir), falling
# back to plain unzip when it isn't on PATH yet (turbo load) or not installed.
function unzipd() {
	local filename="${1}"
	local directory="${filename%.zip}"
	directory="${directory##*/}"
	if (( $+commands[ouch] )); then
		ouch decompress "${filename}" --dir "${directory}"
	else
		unzip "${filename}" -d "${directory}"
	fi
}

# =======================================================================================
# Node/NPM/Yarn Enhanced Aliases
# =======================================================================================

# NPM shortcuts
alias ni="npm install"
alias nid="npm install --save-dev"
alias nig="npm install -g"
alias nrd="npm run dev"
alias nrb="npm run build"
alias nrs="npm run start"
alias nrt="npm run test"
alias nrl="npm run lint"
alias nrf="npm run format"
alias nci="npm ci"  # Clean install from package-lock.json
alias ncc="npm cache clean --force"
alias nou="npm outdated"
alias nup="npm update"

# Yarn shortcuts (enhanced from existing ya, yad)
# Add yarn package
# Usage: ya <package>
function ya() { yarn add "$@"; }
# Add yarn dev dependency
# Usage: yad <package>
function yad() { yarn add -D "$@"; }
alias yi="yarn install"
alias yag="yarn global add"
alias yrm="yarn remove"
alias yup="yarn upgrade"
alias yui="yarn upgrade-interactive"  # Interactive upgrade
alias yout="yarn outdated"
alias ycc="yarn cache clean"

# pnpm (if you use it)
alias pi="pnpm install"
alias pna="pnpm add"
alias pnad="pnpm add -D"
alias pr="pnpm remove"

# Quick package.json operations
alias pkg="vim package.json"
alias pkgj="cat package.json | jq"  # Pretty print with jq

# Git Aliases and functions
# Quick git checkout
# Usage: c <branch>
function c() { git checkout "$@"; }
# Quick git branch
# Usage: b [branch-name]
function b() { git branch "$@"; }
alias gcam="git commit -a --amend"
alias gc="git commit -am"
alias gs="git status"
# Removed: conflicted with forgit::diff
# alias gd="git diff --ignore-all-space --ignore-space-at-eol --ignore-space-change --ignore-blank-lines"

# Quick commit with Claude
function cc() {
    echo "📋 Files to be committed:"
    git status --short
    echo ""
    echo "📝 Last commit:"
    git log -1 --oneline --color=always
    echo ""
    git add -A && claude -p '/commit' && echo "" && echo "✅ New commit:" && git log -1 --color=always
}

# Internal helper: validate and apply .git_cli_prepend safely
# Usage: _validate_and_apply_git_prepend <git command args...>
function _validate_and_apply_git_prepend() {
	local -a cmd=("$@")

	# SAFE prepend: validate and parse .git_cli_prepend (no eval!)
	if [[ -f ".git_cli_prepend" ]]; then
		local prepend=$(<.git_cli_prepend)
		# Strip whitespace
		prepend=${prepend## ##}
		prepend=${prepend%% ##}

		# Only allow safe alphanumeric commands (no shell metacharacters)
		if [[ $prepend =~ ^[a-zA-Z0-9_/-]+$ ]]; then
			cmd=($prepend $cmd)
		else
			print -P "%F{red}⚠️  Unsafe .git_cli_prepend detected (ignored): $prepend%f" >&2
		fi
	fi

	"${cmd[@]}"
}

# Git pull with .git_cli_prepend support
# Usage: gp
function gp() {
	_validate_and_apply_git_prepend git pull
}

# Git push with auto-upstream and .git_cli_prepend support
# Usage: gpu
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
# Usage: gpuf
function gpuf() {
	_validate_and_apply_git_prepend git push --force
}

# Search git history for pattern across all commits
# Usage: git_search "pattern"
# Example: git_search "API_KEY"
function git_search() {
	git rev-list --all | GIT_PAGER=cat xargs git grep "${@}"
}
alias gse="git_search"

# Reset git to a previous commit
# Usage: git_reset [n]
# Example: git_reset 2  (resets to HEAD~2)
function git_reset() {
	local COMMIT="HEAD"
	if [[ "$#" -eq 1 ]]; then
		COMMIT="HEAD~$1"
	fi

	git reset --hard "${COMMIT}"
}
# Removed: conflicted with forgit::reset::head
# alias gre="git_reset"

# Clone git repo and cd into it
# Usage: git-clone <repo-url>
# Example: git-clone https://github.com/user/repo.git
function git-clone() {
	git clone "$@" && cd "${${1:t}%.git}"
}

# Jump to git repository root
# Usage: groot
# Example: cd deeply/nested/directory && groot → jumps to repo root
function groot() {
	local root=$(git rev-parse --show-toplevel 2>/dev/null)
	if [[ -n "$root" ]]; then
		builtin cd "$root"
	else
		echo "Not in a git repository" >&2
		return 1
	fi
}
alias gr='groot'  # Quick alias

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
	read -r "confirm?Hard reset to HEAD? This discards local changes (y/n): "
	if [[ "${confirm}" != "y" ]]; then
		echo "Cancelled"
		return 1
	fi
	git reset --hard
}
alias grsoft="git reset --soft"

alias glg="git log --graph --oneline --decorate"
alias glga="git log --graph --oneline --decorate --all"
alias glgp="git log -p"  # Show patches

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
# Usage: gcm feat add user authentication
# Types: feat, fix, docs, style, refactor, test, chore

# =======================================================================================
# Forgit - Interactive Git Tool Aliases
# =======================================================================================
# Check if forgit functions are available, otherwise use fallback aliases
if (( $+functions[forgit::log] )); then
    # Forgit is available - use interactive forgit commands
    alias gl='forgit::log'          # Interactive git log browser
    alias gd='forgit::diff'         # Interactive git diff viewer
    alias ga='forgit::add'          # Interactive git add
    alias gre='forgit::reset::head' # Interactive git reset HEAD
    alias gcf='forgit::checkout::file'   # Interactive checkout files
    alias gcb='forgit::checkout::branch' # Interactive checkout branch
    alias gss='forgit::stash::show' # Interactive stash viewer
    alias gcp='forgit::cherry::pick' # Interactive cherry-pick
    alias grb='forgit::rebase'      # Interactive rebase
    alias gfu='forgit::fixup'       # Interactive fixup
    alias gclean='forgit::clean'    # Interactive clean
else
    # Forgit not available - use standard git command fallbacks
    alias gl='git log --graph --oneline --decorate --all'
    alias gd='git diff'
    alias ga='git add'
    alias gre='git reset HEAD'
    alias gcf='git checkout'
    alias gcb='git checkout -b'
    alias gss='git stash show -p'
    alias gcp='git cherry-pick'
    alias grb='git rebase'
    alias gfu='git commit --fixup'
    alias gclean='git clean -id'
fi

# =======================================================================================
# Suffix Aliases
# =======================================================================================
alias -s git="git-clone"
alias -s txt="${EDITOR}"
alias -s cond="${EDITOR}"
alias -s log="${EDITOR}"
alias -s vim="${EDITOR}"
alias -s deb="sudo dpkg -i"
alias -s {c,py,cpp,r,rb,go,js,jsx,ts,java,sql,hs,md}="vim"
alias -s {xml,json,toml,yaml,yml,ini,conf}="vim"  # (log already mapped to ${EDITOR} above)
alias -s {gz,tgz,zip,lzh,bz2,tbz,Z,tar,arj,xz,7z}="extract"

# =======================================================================================
# Global Aliases
# =======================================================================================
alias -g C="| wc -l"
alias -g G="| grep"
alias -g F="| fzf"
alias -g H="| head"
alias -g J="| jq"
alias -g JL="| jless"   # browse JSON interactively (e.g. `xh :3000/api JL`)
alias -g JN="| jnv"     # build a jq filter interactively over the JSON
alias -g L="| less"
alias -g P="| ${PAGER}"
alias -g S="| sort -n"
alias -g T="| tail"
alias -g U="| uniq"
alias -g X="| xsel -b"
alias -g FF="-print0 | xargs -0 -I FILE"

# =======================================================================================
# Yarn Aliases and functions
# =======================================================================================
alias yd="yarn dev"
alias yb="yarn build"

# =======================================================================================
# Laravel Aliases and functions
# =======================================================================================
# Docker-based Laravel (existing aliases)
alias pa="dce php php -dxdebug.client_host=host.docker.internal artisan"
alias pam="dce php php -dxdebug.client_host=host.docker.internal artisan migrate"
alias par="dce php php -dxdebug.client_host=host.docker.internal artisan routes"
alias mysqlr="dce -it db mysql -u root -p123"

# Enhanced Artisan shortcuts (work with both Docker and native)
alias pamf="pa migrate:fresh"
alias pamfs="pa migrate:fresh --seed"
alias pams="pa migrate --seed"
alias pamr="pa migrate:rollback"
alias pamrs="pa migrate:reset"
alias paq="pa queue:work"
alias paqf="pa queue:failed"
alias paqr="pa queue:retry"
alias pat="pa tinker"
alias pau="pa up"
alias pad="pa down"
alias parl="pa route:list"
alias parc="pa route:cache"
alias pacc="pa config:cache"
alias pavc="pa view:cache"
alias pao="pa optimize"
alias paoc="pa optimize:clear"

# Testing
alias pat:u="pa test --filter"
alias pat:p="pa test --parallel"

# Native Laravel (non-Docker)
alias pam:r="php artisan migrate:refresh"
alias pam:roll="php artisan migrate:rollback"
alias pam:rs="php artisan migrate:refresh --seed"
alias pda="php artisan dumpautoload"

# Composer shortcuts
alias cu="composer update"
alias ci="composer install"
alias cda="dce php composer dump-autoload -o"
alias dcomp="dce php composer"
alias dcompi="dce php composer install"
alias dcompu="dce php composer update"
alias dcompd="dce php composer dump-autoload -o"

# Laravel logs
alias llog="tail -f storage/logs/laravel.log"
alias llogl="tail -100 storage/logs/laravel.log"
alias llogc="truncate -s 0 storage/logs/laravel.log"  # Clear log

# Laravel fresh install helper
function laravel-fresh() {
    echo "🔄 Dropping database..."
    pa migrate:fresh
    echo "🌱 Seeding database..."
    pa db:seed
    echo "🗑️  Clearing caches..."
    pa optimize:clear
    echo "✓ Laravel reset complete!"
}

# Quick Laravel setup
function laravel-setup() {
    composer install
    cp .env.example .env
    php artisan key:generate
    php artisan migrate
    php artisan db:seed
    echo "✓ Laravel project setup complete!"
}

# =======================================================================================
# Nginx Aliases and functions
# =======================================================================================
alias html="cd /var/www/html"

# common directories
alias ncon_enabled="cd /etc/nginx/sites-enabled/"
alias ncon_available="cd /etc/nginx/sites-available/"
alias ncon="ncon_enabled"  # Default to enabled
alias nerr="cd /var/log/nginx/"

# view logs
alias npe="tail -f /var/log/nginx/error*.log"
alias npa="tail -f /var/log/nginx/access*.log"

# reload nginx
alias nrel="sudo nginx -t && sudo nginx -s reload"

# =======================================================================================
# Node Aliases and functions
# =======================================================================================

# =======================================================================================
# Log Aliases and functions
# =======================================================================================
alias llog_prod="tail -f /var/www/html/ecoenergy/production/storage/logs/laravel.log"
alias nlog="tail -f /var/log/nginx/*.log"

# =======================================================================================
# Docker Aliases and functions
# =======================================================================================
# Runs docker compose command looking at other files
function dc() {
	export IP_ADDRESS=$(ip route list default | awk '{print $3}')
    IP_ADDRESS=$IP_ADDRESS docker compose "$@"
}

function dce() {
	dc exec --user "$(id -u):$(id -g)" "$@"
}

# Run docker compose in detached mode (looks for docker.sh first)
# Usage: dcu [args...]
function dcu() {
	if [[ -e "docker/docker.sh" ]]; then
		./docker/docker.sh "$@"
	elif [[ -e "docker.sh" ]]; then
		./docker.sh "$@"
	else
		dc up -d
	fi
}

# Get IP addresses of all docker compose containers
# Usage: dcip
function dcip() { docker inspect --format '{{$e := . }}{{with .NetworkSettings}} {{$e.Name}}
{{range $index, $net := .Networks}}{{$index}} IP:{{.IPAddress}}; Gateway:{{.Gateway}}
{{end}}{{end}}' $(dcp -q); }

# Follow docker compose logs
# Usage: dclo
function dclo() { dc logs -tf; }

# List docker compose processes
# Usage: dcp [args...]
function dcp() { dc ps "$@"; }

# Execute command in Docker Compose service
# Usage: dexec <service> <command>
# Example: dexec php bash
function dexec() { docker exec -it $(dc ps -q $1) $2; }

# Execute command as root in Docker Compose service
# Usage: drexec <service> <command>
# Example: drexec php apt-get update
function drexec() { docker exec --user root:root -it $(dc ps -q $1) $2; }

# Run bash shell in Docker Compose service
# Usage: dceb <service> [script]
# Example: dceb php /bin/bash
function dceb() {
	local script="/bin/bash"
	if [[ $# -lt 1 ]]; then
		echo "Usage: ${funcstack[1]} CONTAINER_ID"
		return 1
	fi
	if [[ -n "$2" ]]; then
		script="$2"
	fi

	dc exec --user "$(id -u):$(id -g)" "$1" "$script"
}

# Run bash shell as root in Docker Compose service
# Usage: dcebr <service> [script]
# Example: dcebr php /bin/bash
function dcebr() {
	local script="/bin/bash"
	if [[ $# -lt 1 ]]; then
		echo "Usage: ${funcstack[1]} CONTAINER_ID"
		return 1
	fi
	if [[ -n "$2" ]]; then
		script="$2"
	fi

	dc exec --user root:root "$1" "$script"
}

# Get latest container ID
alias dl="docker ps -l -q"

# Get container process
alias dps="docker ps"

# Get process included stop container
alias dpa="docker ps -a"

# Get images
alias di="docker images"

# Get container IP
alias dip="docker inspect --format '{{ .NetworkSettings.IPAddress }}'"

# Run deamonized container, e.g., $dkd base /bin/echo hello
alias dkd="docker run -d -P"

# Run interactive container, e.g., $dki base /bin/bash
alias dki="docker run -i -t -P"

# Stop all Docker containers
# Usage: dstop
function dstop() {
	local confirm
	read -r "confirm?Stop all Docker containers? (y/n): "
	if [[ "${confirm}" != "y" ]]; then
		echo "Cancelled"
		return 1
	fi
	docker stop $(docker ps -a -q)
}

# Stop and remove all Docker containers
# Usage: drmf
function drmf() {
	local confirm
	read -r "confirm?Stop and remove ALL Docker containers? (y/n): "
	if [[ "${confirm}" != "y" ]]; then
		echo "Cancelled"
		return 1
	fi
	docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q)
}

# Get IP addresses of all running containers
alias dpsi="docker ps -q | xargs docker inspect --format '{{ .Id }} - {{ .Name }} - {{ .NetworkSettings.IPAddress }}'"

# Remove all Docker containers
# Usage: drc
function drc() {
	local confirm
	read -r "confirm?Remove ALL Docker containers? (y/n): "
	if [[ "${confirm}" != "y" ]]; then
		echo "Cancelled"
		return 1
	fi
	docker rm $(docker ps -a -q)
}

# Remove all images
#dri() { docker rmi $(docker images -q); }

# Build Docker image with tag
# Usage: dbu <tag-name>
# Example: dbu myapp:latest
function dbu() { docker build -t=$1 .; }

# Run bash shell in Docker container as current user
# Usage: dexbash <container-id>
# Example: dexbash abc123
function dexbash() {
	if [[ $# -ne 1 ]]; then
		echo "Usage: ${funcstack[1]} CONTAINER_ID"
		return 1
	fi

	docker exec -it --user "$(id -u):$(id -g)" "$1" /bin/bash
}

# Build Docker image from directory with optional tags
# Usage: dbt <dirname> [tag1...]
# Example: dbt ./app myapp:v1.0
function dbt() {
	if [[ $# -lt 1 ]]; then
		echo "Usage ${funcstack[1]} DIRNAME [TAGNAME ...]"
		return 1
	fi

	local -a args=("$1")
	shift
	if [[ $# -ge 1 ]]; then
		args+=(-t "$@")
	fi

	docker build "${args[@]}"
}

# =======================================================================================
# WSL Aliases and functions
# =======================================================================================
if [[ $HOST_OS == "wsl" ]]; then
	# Open file in Windows Sublime Text from WSL
	# Usage: subl <file>
	function subl() {
		local SUBLIME_TEXT_LOCATION="/mnt/c/Program Files/Sublime Text/subl.exe"
		if [[ ! -f "$SUBLIME_TEXT_LOCATION" ]]; then
			SUBLIME_TEXT_LOCATION="/mnt/c/Program Files/Sublime Text 3/subl.exe"
		fi

		local FILE="$1"
		local FULL_PATH="$(readlink -f "${FILE}")"
		local WIN_PATH="$(wslpath -m "${FULL_PATH}")"
		"${SUBLIME_TEXT_LOCATION}" "${WIN_PATH}"
	}

	# Open file/directory in Windows VS Code from WSL
	# Usage: code [file or directory]
	function code() {
		local code_exe="${WINDOWS_USER_PROFILE:-/mnt/c/Users/${USER}}/AppData/Local/Programs/Microsoft VS Code/Code.exe"
		if [[ ! -x "${code_exe}" ]]; then
			echo "Error: VS Code not found at ${code_exe}" >&2
			return 1
		fi
		"${code_exe}" "$@"
	}
fi

# =======================================================================================
# Power User Aliases (Expert Level)
# =======================================================================================

# Create directory and cd into it
# Usage: mkcd <directory>
# Example: mkcd ~/projects/newproject
function mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Port listening checker
alias lsp="sudo lsof -iTCP -sTCP:LISTEN -n -P"

# Kill process interactively with fzf
# Usage: killp
function killp() {
  local pid
  local confirm
  pid=$(ps aux | fzf --header-lines=1 | awk '{print $2}')
  if [[ -n "$pid" ]]; then
    read -r "confirm?Kill PID ${pid} with SIGKILL? (y/n): "
    [[ "${confirm}" == "y" ]] && kill -9 "$pid"
  fi
}

# Quick systemd service management
alias sctl="sudo systemctl"
alias sctle="sudo systemctl enable --now"
alias sctld="sudo systemctl disable --now"
alias sctls="systemctl status"

# Disk space analyzer (human-readable)
alias duh="du -h --max-depth=1 | sort -hr"

# Network shortcuts
alias ports="netstat -tulanp"
alias myip_public="myip"

# macOS uses BSD grep, Linux uses GNU grep
if [[ "$HOST_OS" == "darwin" ]]; then
  alias myip_local="ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print \$2}'"
else
  alias myip_local="ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1"
fi

# =======================================================================================
# Development Workflow Functions
# =======================================================================================

# Kill process by port number
function killport() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: killport <port>"
    echo "Example: killport 3000"
    return 1
  fi

  local port="${1}"
  local pid=$(lsof -ti:"${port}")

  if [[ -n "${pid}" ]]; then
    local confirm
    read -r "confirm?Kill PID ${pid} on port ${port} with SIGKILL? (y/n): "
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

# Smart package manager runner - detects npm/yarn/pnpm/bun
function run() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: run <script>"
    echo "Example: run dev"
    return 1
  fi

  # bun is checked first: it writes bun.lockb (<1.2) or bun.lock (1.2+), but bun
  # projects frequently still carry a package-lock.json from before the switch, which
  # would otherwise fall through to npm below.
  if [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
    echo "📦 Using Bun"
    bun run "$@"
  elif [[ -f "yarn.lock" ]]; then
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

# Docker system cleanup - removes everything
function docker-clean() {
  local confirm
  read -r "confirm?Prune ALL Docker data (images, containers, volumes)? (y/n): "
  if [[ "${confirm}" != "y" ]]; then
    echo "Cancelled"
    return 1
  fi
  echo "🗑️  Cleaning Docker system..."
  docker system prune -af --volumes
  echo "✓ Docker cleanup complete"
}

# Find and replace text in files with confirmation
# Usage: replace-in-files <search> <replace> [file-pattern]
# Example: replace-in-files "oldName" "newName" "*.js"
function replace-in-files() {
  if [[ $# -lt 2 ]]; then
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

  # Show matches first
  rg "${search}" -l --glob "${pattern}"

  echo ""
  read "confirm?Proceed with replacement? (y/n) "
  if [[ "${confirm}" == "y" ]]; then
    if [[ "${HOST_OS}" == "darwin" ]]; then
      rg "${search}" -l --glob "${pattern}" | xargs sed -i '' "s/${search}/${replace}/g"
    else
      rg "${search}" -l --glob "${pattern}" | xargs sed -i "s/${search}/${replace}/g"
    fi
    echo "✓ Replacement complete"
  else
    echo "❌ Cancelled"
  fi
}

# Quick directory size check
function dirsize() {
  if [[ $# -lt 1 ]]; then
    du -sh *
  else
    du -sh "$@"
  fi
}

# Extract any archive type
# Prefers ouch (universal decompressor, installed via zinit) and falls back to the
# per-format toolbox below when it isn't on PATH yet (turbo load) or not installed.
# Note: ouch smart-unpacks — multi-entry archives land in a basename-derived
# subdirectory instead of littering the cwd (tarbomb protection); pass --dir . for
# the raw tar/unzip behavior.
function extract() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: extract <file>"
        return 1
    fi

    if (( $+commands[ouch] )) && [[ -f "${1}" ]]; then
        ouch decompress "${1}"
        return
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

  if [[ $# -eq 0 ]]; then
    # Show recent notes
    echo "📝 Recent notes:"
    ls -lt "${notes_dir}" | head -10
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

# =======================================================================================
# Modern CLI Tool Aliases
# =======================================================================================

# Full zinit reset: wipe every plugin/snippet/completion + polaris and reinstall from
# .zshrc. Preferred over a plain `zi update`, which snapshots a plugin's ices into
# <plugin>/._zinit/ at install time and replays *those* forever — editing an ice in
# .zshrc does nothing to an already-installed plugin, so an update will happily keep
# rebuilding a repo from source long after the config switched it to a prebuilt binary.
# Only deleting the plugin dir rewrites that metadata.
# Dry run by default; pass --go to execute. Args pass straight through.
alias zi-update="\"${ZDOTDIR}/functions/zinit-reset\""

# Update everything in one pass: system packages, shell plugins, then toolchains.
#
# The zinit step is deliberately a full wipe+reinstall (zi-update above) and there is no
# in-place fast path, because `zinit update` replays the ices each plugin saved into
# <plugin>/._zinit/ at install time rather than the ones .zshrc declares now. That
# divergence is silent and unbounded: it is what kept rebuilding qsv/yazi from source
# after they were switched to prebuilt binaries, what kept updating plugins long since
# deleted from the config, and what hangs tj/git-extras forever on an invisible
# `read -p` prompt. It also only bites once an update actually pulls new commits, so it
# passes for weeks and then fails. Re-downloading ~400MB is the cheaper failure.
#
# If you knowingly want the fast path on a machine you just reset, run
# `zinit update --parallel` directly — don't wire it back in here as a default.
function update-all() {
    local arg

    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)
                print -r -- "Usage: update-all"
                print -r -- "  Updates system packages, zinit plugins (full reinstall), and toolchains."
                return 0
                ;;
            (*)
                print -ru2 -- "update-all: unknown option '${arg}'"
                return 2
                ;;
        esac
    done

    # System packages first so any sudo prompt lands while you're still at the keyboard,
    # rather than ten minutes into what should be an unattended run.
    if [[ "${HOST_OS}" == "darwin" ]] && (( $+commands[brew] )); then
        print -r -- $'\n▸ homebrew'
        brew update && brew upgrade && brew cleanup
    elif (( $+commands[apt-get] && $+commands[sudo] )); then
        print -r -- $'\n▸ apt'
        sudo apt-get update && sudo apt-get upgrade -y
    fi

    print -r -- $'\n▸ zinit plugins'
    "${ZDOTDIR}/functions/zinit-reset" --go

    # mise owns node/python/rust/uv/yarn/vim here, so it covers most language runtimes;
    # rustup still updates the actual toolchains mise symlinks to.
    (( $+commands[mise] ))   && { print -r -- $'\n▸ mise';           mise upgrade }
    (( $+commands[rustup] )) && { print -r -- $'\n▸ rustup';         rustup update }
    (( $+commands[bun] ))    && { print -r -- $'\n▸ bun';            bun upgrade }
    (( $+commands[npm] ))    && { print -r -- $'\n▸ npm globals';    npm update -g }
    # `yarn global` is Yarn 1.x (classic) only — Berry (v2+) removed the command
    # entirely, so guard on the major version rather than just on yarn existing.
    if (( $+commands[yarn] )) && [[ "$(yarn --version 2>/dev/null)" == 1.* ]]; then
        print -r -- $'\n▸ yarn globals'
        yarn global upgrade
    fi
    (( $+commands[gh] ))     && { print -r -- $'\n▸ gh extensions';  gh extension upgrade --all }

    print -r -- $'\n✅ update-all complete'
}

# 🛠️ mise wrapper: inject the vim build env only when mise might compile vim.
# ASDF_VIM_CONFIG/LDFLAGS used to be computed in .zshenv, spawning python3 twice on
# EVERY zsh invocation (including scripts). Only `mise install/upgrade` needs them.
# `mise activate zsh` (run earlier in .zshrc) already defines a mise() function for
# shell integration, so we save a copy and chain to it instead of clobbering it.
if (( $+functions[mise] )) && ! (( $+functions[_mise_activate_orig] )); then
    functions -c mise _mise_activate_orig
fi
function mise() {
    case "${1:-}" in
        (install|i|upgrade|up)
            if (( $+commands[python3] && $+commands[python3-config] )); then
                local python_prefix
                python_prefix="$(python3 -c 'import sys; print(sys.prefix)' 2>/dev/null)"
                if [[ -n "${python_prefix}" ]]; then
                    export ASDF_VIM_CONFIG="--with-tlib=ncurses --with-compiledby=mise --enable-multibyte --enable-cscope --enable-terminal --enable-python3interp --with-python3-command=${commands[python3]} --enable-fail-if-missing --enable-gui=no --without-x"
                    # rpath embeds the Python lib path into the vim binary (no runtime LD_LIBRARY_PATH)
                    export LDFLAGS="-L${python_prefix}/lib -Wl,-rpath,${python_prefix}/lib ${LDFLAGS:-}"
                fi
            fi
            ;;
    esac

    if (( $+functions[_mise_activate_orig] )); then
        _mise_activate_orig "$@"
    else
        command mise "$@"
    fi
}

# ---------------------------------------------------------------------------------
# Modern tool wrappers, with availability checks and fallbacks.
#
# The check MUST happen at call time, not at source time. Every tool below is installed
# by zinit turbo (wait'2'), so none of them are on PATH yet when this file is sourced —
# a guard like `(( $+commands[btm] )) && alias top='btm'` evaluates false during .zshrc
# and the alias silently never gets defined. Functions defer the lookup until the
# command is actually run, by which point turbo has finished. This is the same reason
# cat() and ls() above test inside the function body rather than around it.
#
# Aliases that shadow a real system command (top, df, ncdu) fall back to that command,
# so a machine missing the modern tool degrades to standard behaviour instead of
# "command not found". Use `command <name>` to force the original either way.
# ---------------------------------------------------------------------------------

# System monitoring
# Guarded like cat()/ls(): pipelines and command substitutions (`top -bn1 | head`)
# must reach the real binary - btm is a TUI with incompatible output.
function top() {
	[[ -o interactive && -t 1 ]] || { command top "$@"; return }
	(( $+commands[btm] )) && { btm "$@"; return }
	command top "$@"
}

# Disk usage - scripts parse `df -h` output, so only substitute duf on a terminal
function df() {
	[[ -o interactive && -t 1 ]] || { command df "$@"; return }
	(( $+commands[duf] )) && { duf "$@"; return }
	command df "$@"
}

function ncdu() {
	(( $+commands[dust] )) && { dust "$@"; return }
	(( $+commands[ncdu] )) && { command ncdu "$@"; return }
	print -ru2 -- "ncdu: neither dust nor ncdu is installed"
	return 127
}

# Process viewer - procs, falling back to ps
function pps() {
	(( $+commands[procs] )) && { procs "$@"; return }
	command ps "$@"
}

# DNS lookup - doggo (mr-karan/doggo). The old `dog` binary came from ogham/dog, which
# is no longer declared in .zshrc, so a bare `command dog` here fails on a clean install.
function dog() {
	(( $+commands[doggo] )) && { doggo "$@"; return }
	(( $+commands[dig] ))   && { command dig "$@"; return }
	print -ru2 -- "dog: neither doggo nor dig is installed"
	return 127
}

# Benchmarking - no meaningful fallback, so fail loudly rather than silently
function bench() {
	(( $+commands[hyperfine] )) || { print -ru2 -- "bench: hyperfine is not installed"; return 127 }
	hyperfine "$@"
}

# Lazygit/Lazydocker TUIs - no fallback, but report the reason
function lg() {
	(( $+commands[lazygit] )) || { print -ru2 -- "lg: lazygit is not installed"; return 127 }
	lazygit "$@"
}

function lzd() {
	(( $+commands[lazydocker] )) || { print -ru2 -- "lzd: lazydocker is not installed"; return 127 }
	lazydocker "$@"
}

# Ping - gping graph TUI, falling back to system ping.
# The tty check is load-bearing: gping never exits and prints no parseable output,
# so `ping -c1 host | grep ...` or $(ping ...) must reach the real ping.
function ping() {
	[[ -o interactive && -t 1 ]] || { command ping "$@"; return }
	(( $+commands[gping] )) && { gping "$@"; return }
	command ping "$@"
}

# Hex viewer - hexyl, falling back to xxd.
# hexyl's output format is not xxd-compatible (and has no -r reverse mode), so
# anything piping or substituting xxd output gets the real binary.
function xxd() {
	[[ -o interactive && -t 1 ]] || { command xxd "$@"; return }
	(( $+commands[hexyl] )) && { hexyl "$@"; return }
	command xxd "$@"
}

# rga - ripgrep-all when installed, plain rg otherwise (same flags for simple searches)
function rga() {
	(( $+commands[rga] )) && { command rga "$@"; return }
	command rg "$@"
}

# HTTP client - xh (HTTPie syntax), falling back to curl
function http() {
	(( $+commands[xh] )) && { xh "$@"; return }
	command curl "$@"
}

# Same, but force HTTPS when the URL doesn't spell out a scheme
function https() {
	(( $+commands[xh] )) && { xh --https "$@"; return }
	command curl "$@"
}
