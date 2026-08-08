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
# Kept for the man() fallback below: when batman (bat-extras) isn't installed,
# plain man still renders through bat via this pager.
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# 📖 Man pages via batman (bat-extras) - proper bat rendering without the col hack.
# Guarded like cat(): piped calls (`man ls | grep`) reach the real man.
function man() {
	[[ -o interactive && -t 1 ]] || { command man "$@"; return }
	(( $+commands[batman] )) && { batman "$@"; return }
	command man "$@"
}

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

# 📄 Ripgrep: batgrep (bat-extras) on a terminal for syntax-highlighted context
# blocks, falling back to paged rg. Piped/captured calls always reach plain rg so
# scripts and things like kkk()'s `rg --files` capture keep parseable output.
#
# batgrep only understands a small subset of rg's flags (-i/-s/-S, -A/-B/-C, -F,
# -U, -P), so it is used ONLY when every given flag is in that subset. Anything
# else (-t, -w, -v, -g, --files, -l, --json, ...) gets the classic paged rg -
# same behavior as before batgrep existed.
# Use 'command rg' for the raw tool; rgp always gives the classic paged view.
function rg() {
	[[ -t 1 ]] || { command rg "$@"; return }

	if (( $+commands[batgrep] )); then
		local arg batgrep_ok=1
		for arg in "$@"; do
			[[ "${arg}" == -* ]] || continue
			case "${arg}" in
				(-i|--ignore-case|-s|--case-sensitive|-S|--smart-case) ;;
				(-[ABC]|-[ABC][0-9]*|--after-context*|--before-context*|--context*) ;;
				(-F|--fixed-strings|-U|--multiline|-P|--pcre2) ;;
				(*) batgrep_ok=0; break ;;
			esac
		done
		(( batgrep_ok )) && { batgrep "$@"; return }
	fi

	command rg -p "$@" | less -RFX
}

# Classic paged ripgrep view (pre-batgrep behavior)
function rgp() {
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
# On a terminal this uses batgrep (bat-extras: ripgrep hits with syntax-highlighted
# context); piped/scripted calls keep the original parseable grep -ir output.
function scd() {
	if [[ -o interactive && -t 1 ]] && (( $+commands[batgrep] )); then
		batgrep -i "$@"
	else
		grep -ir "$@" ./
	fi
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

# Full-spectrum system maintenance in one pass: update system packages, shell plugins,
# and language toolchains, then prune caches, clean up, and health-check.
# Supersedes the old `update-all` (kept as an alias below).
#
# Each step is independent and self-guarded: a missing tool is skipped, and a step that
# fails is recorded rather than aborting the run. A summary at the end lists reclaimed
# disk and any steps that failed (and the function returns non-zero if any did).
#
# Platform awareness (HOST_OS / HOST_LOCATION / IS_DEVCONTAINER from detect_os.sh):
#   - Runs on WSL, Ubuntu desktop, Ubuntu server, and macOS; brew steps cover Linuxbrew.
#   - Root shells work without sudo (sudo_cmd shim expands to nothing when EUID==0).
#   - Devcontainers skip OS-level steps (apt/snap/flatpak/fstrim/journal/trash/…).
#   - Servers get a read-only status report: reboot-required, failed systemd units,
#     services needing restart, journal error count. It never changes state.
#
# Destructive steps are conservative: trash/thumbnails only drop items older than 30
# days, and docker prune keeps volumes and anything younger than 7 days.
#
# Every run is tee'd to ${XDG_STATE_HOME}/logs/maintain/maintain-<timestamp>.log
# (10 newest kept) by the wrapper below.
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

function maintain::usage() {
    print -r -- "Usage: maintain [-h|--help]"
    print -r -- ""
    print -r -- "Full-spectrum system maintenance, run in six phases:"
    print -r -- "  1. System & OS package managers (brew/apt, flatpak, snap, firmware/macOS updates)"
    print -r -- "  2. Runtimes & version managers (gh, zinit reset, mise, rustup, …)"
    print -r -- "  3. Global packages & language build caches (npm, bun, uv, pipx, composer, go, cargo)"
    print -r -- "  4. Container hygiene (docker/podman prune, safe mode)"
    print -r -- "  5. System cleanup & docs (tldr, TRIM, journal, nix gc, trash/thumbnails >30d)"
    print -r -- "  6. Health checks & audits (brew/mise doctor, PATH shadow scan, server report)"
    print -r -- ""
    print -r -- "Before the phases begin, asks whether to run the dotfiles install.sh"
    print -r -- "bootstrap first (default N — a bare Enter skips it). The prompt is"
    print -r -- "suppressed entirely when stdin is not a terminal, so scripted and cron"
    print -r -- "runs always skip it."
    print -r -- ""
    print -r -- "Primes sudo up front and keeps it alive so the run is unattended"
    print -r -- "(root shells run sudo-free). Devcontainers skip OS-level steps."
    print -r -- "Skips any tool that isn't installed; records (never aborts on) failures"
    print -r -- "and prints a summary of reclaimed disk plus any steps that failed."
    print -r -- "Every run is logged to \${XDG_STATE_HOME:-~/.local/state}/logs/maintain/ (10 kept)."
    print -r -- "The run itself executes in a subshell (it is piped to tee), so finish with"
    print -r -- "'exec zsh' to pick up updated command paths."
}

# Report commands that exist in more than one install location. This catches the failure
# mode where a tool installed two ways leaves the OLDER copy winning on PATH forever, in
# silence: a stale ~/.local/bin/gh 2.92.0 shadowed the zinit-managed 2.97.0 while maintain
# dutifully updated the copy that never ran. Nothing else in the run would surface that.
#
# Strictly read-only — it prints, and never reorders PATH or deletes anything.
#
# The allowlist is what makes this worth having, not a nicety. Without it the check reports
# 13 deliberate shadows on a perfectly healthy machine, and a report you learn to skip past
# is worse than no report because it still looks like coverage. Keep the list short and keep
# each reason attached: if one of those decisions changes — say mise stops owning vim, see
# mise/config.toml — the matching entries MUST come out, or they will mask real duplicates.
function maintain::path_dupes() {
    emulate -L zsh
    setopt local_options null_glob

    local -a expected=(
        vim view rvim rview ex vimdiff vimtutor xxd  # mise owns vim; plugins need 9.2
        python3 pydoc3 python3-config                # mise python shadows python3-minimal
        sg                                           # apt `login` beats ast-grep's stray sg
        install                                      # coreutils; a plugin dir leaks one
    )

    local d f c
    local -aU cands
    for d in ~/.local/share/mise/installs/*/*/bin(/N) ~/.local/share/zinit/plugins/*(/N) \
             ~/.local/share/zinit/polaris/bin(/N) ~/.cargo/bin(/N) \
             ~/.local/share/npm/bin(/N) ~/.config/bun/bin(/N) ~/.local/bin(/N); do
        for f in "${d}"/*(-*N); do cands+=( "${f:t}" ); done
    done

    local -a hits
    for c in ${(o)cands}; do
        (( ${expected[(Ie)${c}]} )) && continue
        local -aU locs reals
        locs=( ${(f)"$(whence -a -p -- ${c} 2>/dev/null)"} )
        (( ${#locs} > 1 )) || continue
        # Compare RESOLVED targets: /bin is a symlink to /usr/bin on Ubuntu, so the very
        # same file would otherwise be reported as a duplicate of itself on every box.
        reals=( ${locs[@]:A} )
        (( ${#reals} > 1 )) && hits+=( "      ${c}: ${(j: :)locs}" )
    done

    if (( ${#hits} )); then
        print -r -- "    ⚠️ Shadowed commands (first path wins; a newer copy may be masked):"
        print -rl -- "${hits[@]}"
    else
        print -r -- "    ✓ No unexpected duplicate executables on PATH"
    fi
}

# Wrapper: tee the whole run to a timestamped log (keeping the 10 newest), preserving
# the inner function's exit status through the pipe. `log_file` is a local here, and
# zsh's dynamic scoping lets maintain::run reference it in the summary block.
#
# Argument parsing lives HERE, ahead of the logging setup, so `maintain --help` doesn't
# mkdir a log dir, write a log containing nothing but the usage text, and rotate.
#
# Note the pipe: zsh runs only the LAST element of a pipeline in the current shell, so
# maintain::run executes in a subshell. Nothing it does to shell state — command hash,
# variables, cwd — survives back here. That is fine for every step (each one only shells
# out) but it is why the summary insists on `exec zsh` rather than merely suggesting it.
function maintain() {
    setopt local_options

    local arg
    for arg in "$@"; do
        case "${arg}" in
            (-h|--help)
                maintain::usage
                return 0
                ;;
            (*)
                print -ru2 -- "maintain: unknown option '${arg}'"
                return 2
                ;;
        esac
    done

    # Optional bootstrap re-run, asked HERE rather than inside maintain::run: that
    # function's stdout is the tee pipe, and a prompt written into a pipe is exactly the
    # trap that made the apt/debconf dialog unsteerable. Up here stdout is still the
    # terminal, and asking before the long unattended phases start mirrors why sudo is
    # primed up front — every question lands now, not ten minutes in.
    #
    # ZDOTDIR is ~/.config/zsh, a symlink into the repo, so :A resolves it before :h
    # takes the parent — a bare ${ZDOTDIR:h} would look in ~/.config and miss.
    #
    # Default is N: a bare Enter, EOF, or a non-tty stdin (cron, CI, `maintain < /dev/null`)
    # all mean skip. run_install/install_script are locals here; zsh's dynamic scoping
    # lets maintain::run see them through the pipeline subshell, same as log_file.
    local install_script="${ZDOTDIR:A:h}/install.sh"
    local run_install=0
    if [[ -t 0 && -r "${install_script}" ]]; then
        local reply=""
        read -r "reply?▸ Run dotfiles install.sh as part of this run? [y/N] "
        [[ "${reply}" == [yY]* ]] && run_install=1
    fi

    local log_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/logs/maintain"
    mkdir -p "${log_dir}"
    local log_file="${log_dir}/maintain-$(date +%Y%m%d-%H%M%S).log"

    maintain::run 2>&1 | tee "${log_file}"
    local ret=${pipestatus[1]}

    # Retention: filenames sort chronologically; On = newest first; [11,-1] = older ones.
    local -a old_logs=( "${log_dir}"/maintain-*.log(On[11,-1]) )
    (( ${#old_logs} )) && rm -f "${old_logs[@]}"

    return ${ret}
}

function maintain::run() {
    # Keep option/trap changes local so we never leak state into the caller's shell.
    setopt local_options local_traps

    local start=${SECONDS}
    local -a failures
    local initial_df="$(command df -h / | awk 'NR==2 {print $4}')"

    print -r -- "=================================================="
    print -r -- "          🚀 Starting System Maintenance          "
    print -r -- "=================================================="

    # sudo shim: an EMPTY array when already root (servers/containers), so
    # "${sudo_cmd[@]}" <cmd> works everywhere without sprinkling EUID checks through the
    # phases — zsh expands a quoted empty array to zero words, not to an empty argument.
    local -a sudo_cmd
    (( EUID == 0 )) && sudo_cmd=() || sudo_cmd=(sudo)
    local can_sudo=$(( $+commands[sudo] || EUID == 0 ))
    local in_container="${IS_DEVCONTAINER:-false}"

    # Prime sudo up front so any password prompt lands now — not ten minutes into what
    # should be an unattended run — and refresh the timestamp in a background loop so no
    # single step stalls waiting for re-auth. macOS is primed too (softwareupdate needs
    # it). The loop self-exits if the parent shell dies; the trap tears it down on
    # normal return or Ctrl-C.
    local sudo_keepalive_pid=""
    if (( $+commands[sudo] && EUID != 0 )); then
        print -r -- $'\n▸ Priming sudo (keep-alive for unattended run)'
        if sudo -v 2>/dev/null; then
            while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 60; done &!
            sudo_keepalive_pid=${!}
            trap '[[ -n "${sudo_keepalive_pid}" ]] && kill "${sudo_keepalive_pid}" 2>/dev/null' EXIT INT TERM
        fi
    fi

    # Dotfiles bootstrap, opt-in via the wrapper's prompt (default N). Unnumbered, like
    # the sudo prime above, because it is not one of the six phases.
    #
    # Runs BEFORE the package phases on purpose: install.sh is idempotent and may install
    # new tools, and anything it adds then gets updated by phases 1-3 in the same pass.
    # It also inherits the sudo credential primed just above, so its privileged steps do
    # not re-prompt. Failure is recorded, never fatal — same contract as every other step.
    if (( run_install )); then
        print -r -- $'\n▸ Running dotfiles bootstrap (install.sh)'
        print -r -- "  • ${install_script}"
        "${install_script}" || failures+=("install.sh")
    fi

    # ----------------------------------------------------
    # 1. OS & SYSTEM PACKAGE MANAGERS
    # ----------------------------------------------------
    print -r -- $'\n▸ [1/6] System & OS Package Managers'

    if [[ "${in_container}" == "true" ]]; then
        # Homebrew is user-scoped and works fine in a container, so it still runs below;
        # what gets skipped is anything that touches the host OS (apt/flatpak/snap/fwupd).
        print -r -- "  (devcontainer detected — skipping host OS package steps)"
    fi

    # Homebrew covers macOS AND Linuxbrew (Linux/WSL) alike.
    if (( $+commands[brew] )); then
        print -r -- "  • Homebrew (update, upgrade, cleanup, autoremove)"
        { brew update && brew upgrade && brew cleanup -s && brew autoremove } || failures+=("Homebrew")
    fi

    if [[ "${HOST_OS}" == "darwin" ]]; then
        (( $+commands[mas] )) && { print -r -- "  • Mac App Store (mas)"; mas upgrade || failures+=("mas") }
        # macOS system updates (uses the sudo primed above). Deliberately -ir, not -ia:
        # -a installs EVERY available update including major OS upgrades, which can run
        # for half an hour and leave the machine demanding a reboot — not something an
        # unattended cache-pruning pass should decide on your behalf. -r restricts it to
        # Apple's recommended (security/point-release) set.
        (( can_sudo )) && { print -r -- "  • macOS system updates (softwareupdate, recommended only)"; "${sudo_cmd[@]}" softwareupdate -ir || failures+=("softwareupdate") }
    elif [[ "${in_container}" != "true" ]] && (( $+commands[apt-get] && can_sudo )); then
        print -r -- "  • Apt (update, upgrade, autoremove, clean)"
        # A debconf dialog here is unrecoverable, not merely awkward: maintain::run's
        # stdout is a PIPE (the tee wrapper), so whiptail's cursor-positioning escapes
        # interleave with the log stream and paint an unusable screen, while stdin is
        # still the tty — the run then blocks forever on a dialog you cannot steer.
        # `-y` only answers apt's OWN prompts; it does nothing for maintainer scripts.
        # needrestart's "Pending kernel upgrade" notice is the usual culprit.
        #
        # `env` (rather than exporting) because sudo's env_reset drops DEBIAN_FRONTEND;
        # it also works unchanged when sudo_cmd is empty on root shells.
        local -a apt_env=( env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a )
        # confold/confdef: never silently clobber a conffile you have edited. The cost is
        # reconciling the occasional .dpkg-dist by hand — preferable to an unattended
        # sweep rewriting configs. `dpkg --audit` and `phase 6`'s needrestart -r l report
        # still surface anything that needs a human.
        # Quoting is load-bearing: unquoted, zsh's EQUALS expansion fires on the `=--force-…`
        # tail and dies with "--force-confold not found".
        local -a apt_opts=( -o 'Dpkg::Options::=--force-confold' -o 'Dpkg::Options::=--force-confdef' )
        # `clean`, not `autoclean`: autoclean only drops .debs that can no longer be
        # downloaded from any configured repo, so on a machine whose repos are all current
        # it deletes nothing — /var/cache/apt/archives had grown to 1020M across 632 files
        # (a 134M chrome, two docker-ce builds) while autoclean reported 0 removals every
        # run. Every cached .deb is re-downloadable on demand, so the only cost is
        # re-fetching a package you happen to reinstall soon after.
        { "${sudo_cmd[@]}" "${apt_env[@]}" apt-get update \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get "${apt_opts[@]}" upgrade -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get autoremove -y \
            && "${sudo_cmd[@]}" "${apt_env[@]}" apt-get clean } || failures+=("apt")
    fi

    # Universal Linux distribution packages
    [[ "${in_container}" != "true" ]] && (( $+commands[flatpak] )) && { print -r -- "  • Flatpak packages"; { flatpak update -y && flatpak uninstall --unused -y } || failures+=("flatpak") }

    # Snap: snapd never runs under WSL (the command exists but every call fails) and it
    # requires systemd — check the socket is actually active before trying.
    if [[ "${in_container}" != "true" && "${HOST_OS}" != "wsl" ]] && (( $+commands[snap] && can_sudo )); then
        if (( $+commands[systemctl] )) && systemctl is-active -q snapd.socket 2>/dev/null; then
            print -r -- "  • Snap packages"
            "${sudo_cmd[@]}" snap refresh || failures+=("snap")
        fi
    fi

    # Firmware updates: real Linux desktops only (fwupd talks to UEFI — pointless on
    # WSL; servers are handled conservatively; containers excluded above).
    # Run it under the sudo primed above: unprivileged fwupdmgr goes through polkit,
    # which would pop an interactive auth prompt in the middle of an unattended run.
    if [[ "${in_container}" != "true" && "${HOST_OS}" == "linux" && "${HOST_LOCATION:-}" == "desktop" ]] \
       && (( $+commands[fwupdmgr] && can_sudo )); then
        print -r -- "  • Firmware updates (fwupd)"
        # fwupdmgr reserves exit code 2 for "nothing to do" — both `refresh` (metadata
        # still fresh) and `update` (no devices need updating) return it on a perfectly
        # healthy machine. Treating that as failure would book a phantom fwupd entry in
        # the summary on every run, so only >2 counts as a real error.
        local fwupd_rc=0
        "${sudo_cmd[@]}" fwupdmgr refresh --force; (( $? > 2 )) && fwupd_rc=1
        "${sudo_cmd[@]}" fwupdmgr update -y;       (( $? > 2 )) && fwupd_rc=1
        (( fwupd_rc )) && failures+=("fwupd")
    fi


    # ----------------------------------------------------
    # 2. RUNTIMES & TOOLCHAIN MANAGERS
    # ----------------------------------------------------
    print -r -- $'\n▸ [2/6] Runtimes & Version Managers'

    # gh runs BEFORE the zinit wipe: gh is zinit-managed at a VERSIONED path
    # (cli---cli/gh_<ver>_linux_amd64/bin/gh). The wipe+reinstall happens in a child
    # shell, so this shell's PATH entry and command hash still point at the old
    # version's directory — which no longer exists once the reinstall pulls a newer
    # gh. The $+commands guard then passes on the stale hash and execution dies with
    # "command not found". Every other tool below lives at a stable path.
    (( $+commands[gh] )) && { print -r -- "  • GitHub CLI extensions"; gh extension upgrade --all || failures+=("gh extensions") }

    print -r -- "  • Resetting Zinit Plugins"
    "${ZDOTDIR}/functions/zinit-reset" --go || failures+=("zinit reset")
    # Drop stale command-hash entries pointing into the pre-wipe plugin dirs, so the
    # steps below this line resolve correctly. This only repairs THIS process — we run in
    # a subshell (see the pipe in maintain()), so the calling shell keeps its stale hash
    # regardless; that is what the closing `exec zsh` in the summary is for.
    rehash

    # Self-update only when mise is a standalone install (under $HOME). Package-manager
    # installs (brew/apt) can't self-update and would record a spurious failure.
    if (( $+commands[mise] )); then
        print -r -- "  • Mise runtimes"
        mise upgrade || failures+=("mise")
        [[ "${commands[mise]}" == "${HOME}"/* ]] && { mise self-update --yes || failures+=("mise self-update") }
    fi
    (( $+commands[asdf] ))   && { print -r -- "  • Asdf plugins";      asdf plugin update --all || failures+=("asdf") }
    (( $+commands[rustup] )) && { print -r -- "  • Rustup toolchains"; rustup update || failures+=("rustup") }
    # `yes |` pre-answers sdkman's interactive "Do you want to install?" prompt.
    (( $+commands[sdk] ))    && { print -r -- "  • SDKMAN!";           { sdk update && yes | sdk upgrade } || failures+=("sdkman") }


    # ----------------------------------------------------
    # 3. GLOBAL PACKAGES & LANGUAGE CACHES
    # ----------------------------------------------------
    print -r -- $'\n▸ [3/6] Global Packages & Build Caches'

    # Node / JS ecosystem
    # The cache is cleared by path, not via `bun pm cache rm`: every `bun pm` subcommand
    # resolves a project root first and hard-fails ("No package.json was found", rc=1)
    # when run outside one — which is always, since `maintain` runs from wherever you
    # happen to be. The location is deterministic from BUN_INSTALL (set in .zshenv), and
    # BUN_INSTALL_CACHE_DIR overrides it when set, matching bun's own resolution order.
    if (( $+commands[bun] )); then
        print -r -- "  • Bun (upgrade & cache clear)"
        bun upgrade || failures+=("bun")
        rm -rf "${BUN_INSTALL_CACHE_DIR:-${BUN_INSTALL:-${HOME}/.bun}/install/cache}"
    fi
    (( $+commands[npm] )) && { print -r -- "  • NPM globals & cache"; { npm update -g && npm cache clean --force } || failures+=("npm") }

    if (( $+commands[yarn] )) && [[ "$(yarn --version 2>/dev/null)" == 1.* ]]; then
        print -r -- "  • Yarn v1 globals & cache"
        { yarn global upgrade && yarn cache clean } || failures+=("yarn")
    fi

    # Python ecosystem. `uv self update` refuses (exit 2) on anything not installed by
    # the standalone script, and "lives under $HOME" is NOT sufficient to prove that: a
    # mise-managed uv sits at ~/.local/share/mise/installs/uv/…, passes the $HOME test,
    # and then fails on every single run. Exclude version-manager install trees, and let
    # the owning manager (mise upgrade, above) do the updating there.
    if (( $+commands[uv] )); then
        print -r -- "  • UV (self-update & cache prune)"
        if [[ "${commands[uv]}" == "${HOME}"/* && "${commands[uv]}" != *"/mise/installs/"* \
           && "${commands[uv]}" != *"/asdf/installs/"* ]]; then
            uv self update || failures+=("uv self-update")
        fi
        uv cache prune || failures+=("uv cache")
    fi
    (( $+commands[pipx] )) && { print -r -- "  • Pipx packages"; pipx upgrade-all || failures+=("pipx") }
    (( $+commands[pip] ))  && { print -r -- "  • Pruning Pip cache"; pip cache purge 2>/dev/null || true }

    # PHP ecosystem
    (( $+commands[composer] )) && { print -r -- "  • Composer globals"; composer global update || failures+=("composer") }

    # Compiled Languages (Go / Rust)
    (( $+commands[go] ))    && { print -r -- "  • Cleaning Go build cache"; go clean -cache -testcache || failures+=("go cache") }
    (( $+commands[cargo] )) && (( $+commands[cargo-cache] )) && { print -r -- "  • Cargo cache prune"; cargo cache --remove-dir git-db,registry-sources || failures+=("cargo cache") }
    # cargo-update refreshes cargo-installed binaries (dua-cli, qsv, yazi, …)
    (( $+commands[cargo-install-update] )) && { print -r -- "  • Cargo-installed binaries"; cargo install-update -a || failures+=("cargo install-update") }


    # ----------------------------------------------------
    # 4. DEVOPS & CONTAINER HYGIENE (SAFE MODES)
    # ----------------------------------------------------
    print -r -- $'\n▸ [4/6] Containers & Cloud Tools'

    # Safe Docker prune: keeps volumes intact, only removes items older than 7 days
    # (168h). If the user isn't in the docker group (common on servers), fall back to
    # sudo — the step used to be skipped silently in that case.
    local -a docker_cmd
    if (( $+commands[docker] )); then
        if docker info >/dev/null 2>&1; then
            docker_cmd=(docker)
        elif (( can_sudo )) && "${sudo_cmd[@]}" docker info >/dev/null 2>&1; then
            docker_cmd=("${sudo_cmd[@]}" docker)
        fi
    fi

    if (( ${#docker_cmd} )); then
        print -r -- "  • Docker prune (safe mode: keeping volumes, items <7 days old)"
        { "${docker_cmd[@]}" system prune -f --filter "until=168h" && "${docker_cmd[@]}" builder prune -f --filter "until=168h" } || failures+=("docker prune")
    elif (( $+commands[podman] )); then
        print -r -- "  • Podman system prune (safe mode)"
        podman system prune -f --filter "until=168h" || failures+=("podman prune")
    fi


    # ----------------------------------------------------
    # 5. SYSTEM CLEANUP & DOCUMENTATION REFRESH
    # ----------------------------------------------------
    print -r -- $'\n▸ [5/6] System Cleanup & Docs'

    (( $+commands[tldr] )) && { print -r -- "  • Updating tldr pages"; tldr --update || failures+=("tldr") }

    # mise never garbage-collects on its own: every `mise up` leaves the previous version
    # installed forever, so ~/.local/share/mise grows without bound (node/python runtimes
    # are 200-450MB each). prune keeps whatever is current per tracked config and drops the
    # superseded versions. It only removes versions no config still references, so it is
    # safe to run unattended — but note it will also drop tools you installed ad-hoc and
    # never pinned in mise/config.toml.
    (( $+commands[mise] )) && { print -r -- "  • mise (prune superseded tool versions)"; mise prune -y || failures+=("mise prune") }

    # Nix store garbage collection (only when nix is installed)
    (( $+commands[nix-collect-garbage] )) && { print -r -- "  • Nix store garbage collection"; nix-collect-garbage -d || failures+=("nix gc") }

    # Safely remove broken symlinks in local user bin directory
    if [[ -d "${HOME}/.local/bin" ]]; then
        print -r -- "  • Cleaning broken symlinks in ~/.local/bin"
        find -L "${HOME}/.local/bin" -maxdepth 1 -type l -exec rm -f {} + 2>/dev/null
    fi

    # Linux desktop only — HOST_OS 'linux' already excludes 'wsl' and 'darwin'. WSL has no
    # real disk to TRIM and no desktop trash to empty; macOS handles all of this itself.
    # Devcontainers skip all of it (ephemeral filesystem).
    if [[ "${HOST_OS}" == "linux" && "${in_container}" != "true" ]]; then
        if (( $+commands[fstrim] && can_sudo )); then
            print -r -- "  • SSD TRIM (fstrim -av)"
            "${sudo_cmd[@]}" fstrim -av || failures+=("fstrim")
        fi

        if (( $+commands[journalctl] && can_sudo )); then
            print -r -- "  • Vacuuming systemd journal (keep <2 weeks)"
            "${sudo_cmd[@]}" journalctl --vacuum-time=2weeks || failures+=("journal vacuum")
        fi

        # Age-based (30d) instead of wipe-all: recently trashed files survive a cleanup.
        print -r -- "  • Emptying user trash (deleted more than 30 days ago)"
        if (( $+commands[trash-empty] )); then
            trash-empty -f 30 2>/dev/null
        else
            # freedesktop.org trash spec. The age key is DeletionDate= inside each
            # info/<name>.trashinfo — NOT the mtime of the entry in files/. Trashing is a
            # rename(), which preserves the file's own mtime, so `find files/ -mtime +30`
            # would mean "last edited over 30 days ago": a document you wrote last year
            # and binned ten seconds ago would be destroyed on the very next run, while a
            # file edited yesterday but binned six months ago would live forever. The two
            # directories also have to be reaped in lockstep, or you strand .trashinfo
            # records whose payload is gone (and vice versa).
            #
            # DeletionDate is ISO-8601 with fixed-width fields, so a plain string
            # comparison against the cutoff orders it correctly.
            local trash_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/Trash"
            local cutoff="$(date -d '30 days ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null)"
            if [[ -n "${cutoff}" && -d "${trash_dir}/info" ]]; then
                local info_file deleted_at trashed_name
                for info_file in "${trash_dir}/info/"*.trashinfo(N); do
                    deleted_at="$(grep -m1 '^DeletionDate=' "${info_file}" 2>/dev/null)"
                    deleted_at="${deleted_at#DeletionDate=}"
                    # No parseable date → leave it alone rather than guess.
                    [[ -n "${deleted_at}" && "${deleted_at}" < "${cutoff}" ]] || continue
                    trashed_name="${${info_file:t}%.trashinfo}"
                    rm -rf "${trash_dir}/files/${trashed_name}" "${info_file}"
                done
            fi
        fi

        local thumb_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails"
        if [[ -d "${thumb_dir}" ]]; then
            print -r -- "  • Clearing old thumbnails (>30 days)"
            find "${thumb_dir}" -type f -mtime +30 -delete 2>/dev/null
        fi
    fi


    # ----------------------------------------------------
    # 6. DIAGNOSTICS & HEALTH CHECKS
    # ----------------------------------------------------
    print -r -- $'\n▸ [6/6] Health Checks & Audits'

    if [[ "${HOST_OS}" == "darwin" ]] && (( $+commands[brew] )); then
        brew doctor || print -r -- "  ⚠️ Homebrew doctor reported warnings."
    fi

    (( $+commands[mise] )) && { mise doctor || print -r -- "  ⚠️ Mise doctor reported issues." }

    # Informational only: never recorded as a failure, since a shadowed command is a thing
    # for a human to judge (some shadows are deliberate) rather than a broken step.
    print -r -- "  • Duplicate executables on PATH"
    maintain::path_dupes

    # Read-only server status report — highlights action items, never changes state.
    if [[ "${HOST_LOCATION:-}" == "server" && "${HOST_OS}" == "linux" ]]; then
        print -r -- "  • Server status report (read-only)"

        if [[ -f /var/run/reboot-required ]]; then
            print -r -- "    ⚠️ REBOOT REQUIRED"
            if [[ -f /var/run/reboot-required.pkgs ]]; then
                local pkgs="$(head -10 /var/run/reboot-required.pkgs | tr '\n' ' ')"
                print -r -- "      Packages: ${pkgs}"
            fi
        fi

        if [[ -d /run/systemd/system ]] && (( $+commands[systemctl] )); then
            local failed_units="$(systemctl list-units --failed --no-legend --plain 2>/dev/null)"
            if [[ -n "${failed_units}" ]]; then
                local unit_line
                print -r -- "    ⚠️ Failed systemd units:"
                print -r -- "${failed_units}" | while IFS= read -r unit_line; do print -r -- "        ${unit_line}"; done
            fi
        fi

        (( $+commands[needrestart] && can_sudo )) && "${sudo_cmd[@]}" needrestart -r l 2>/dev/null

        if (( $+commands[journalctl] && can_sudo )); then
            local err_count="$("${sudo_cmd[@]}" journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)"
            err_count="${err_count// /}"
            (( err_count > 0 )) && print -r -- "    ⚠️ ${err_count} journal error(s) since boot — inspect: journalctl -b -p err"
        fi
    fi

    # Stop the sudo keep-alive before handing the terminal back (trap covers Ctrl-C).
    if [[ -n "${sudo_keepalive_pid}" ]]; then
        kill "${sudo_keepalive_pid}" 2>/dev/null
        sudo_keepalive_pid=""
    fi

    local final_df="$(command df -h / | awk 'NR==2 {print $4}')"
    local elapsed=$(( SECONDS - start ))

    print -r -- $'\n=================================================='
    print -r -- "✅ Maintenance Complete!"
    printf '   Elapsed:           %dm %02ds\n' $(( elapsed / 60 )) $(( elapsed % 60 ))
    print -r -- "   Storage Available: ${initial_df} ➔ ${final_df}"
    if (( ${#failures} )); then
        print -r -- "   ⚠️ ${#failures} step(s) failed:"
        local f
        for f in "${failures[@]}"; do print -r -- "        • ${f}"; done
    else
        print -r -- "   All steps completed successfully."
    fi
    print -r -- "   Log saved to:      ${log_file}"
    print -r -- "   Run 'exec zsh' to apply updated command paths."
    print -r -- "=================================================="

    return $(( ${#failures} > 0 ))
}

# Familiar name kept working; `maintain` is now the canonical entry point.
alias update-all="maintain"

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

# batgrep directly (bat-extras) - ripgrep results with highlighted context,
# falling back to paged rg with context lines
function bgrep() {
	(( $+commands[batgrep] )) && { batgrep "$@"; return }
	command rg -p -C 2 "$@" | less -RFX
}

# batdiff (bat-extras) - working-tree git diff via bat; delta still owns the
# configured git pager, this is just a quick standalone view
function bdiff() {
	(( $+commands[batdiff] )) && { batdiff "$@"; return }
	git diff "$@"
}

# batwatch (bat-extras) - re-render a file with highlighting whenever it changes
function bwatch() {
	(( $+commands[batwatch] )) || { print -ru2 -- "bwatch: batwatch (bat-extras) is not installed"; return 127 }
	batwatch "$@"
}
