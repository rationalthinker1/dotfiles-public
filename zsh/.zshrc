#!/usr/bin/env zsh
# zmodload zsh/zprof # top of your .zshrc file - uncomment to profile startup time
# 🧭 Base paths (XDG-compliant)
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

# 📁 XDG base directories (XDG_CONFIG_HOME and ZDOTDIR already set in .zshenv)
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# 🧠 Shell and runtime config (ZDOTDIR and ZSH_CACHE_DIR already set in .zshenv)
export ZSH="${ZDOTDIR}"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"

# ==============================================================================
# ⚡ Powerlevel10k Instant Prompt (MUST BE NEAR TOP!)
# ==============================================================================
# Enable instant prompt to show prompt immediately while plugins load in background
# This MUST come before any code that produces console output or modifies the terminal
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
# Detect Host OS & Environment
# ==============================================================================

# 🧠 Detect operating system
case "$OSTYPE" in
  linux-gnu*)
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
      HOST_OS="wsl"
    else
      HOST_OS="linux"
    fi ;;
  darwin*)       HOST_OS="macos" ;;
  cygwin*|msys*) HOST_OS="windows" ;;
  *)             HOST_OS="unknown" ;;
esac

# 🖥️ Determine if running on desktop or headless server
if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
  HOST_LOCATION="desktop"
else
  HOST_LOCATION="server"
fi

# ==============================================================================
# Core Environment Variables
# ==============================================================================
# 💻 Host environment
export HOST_OS
export HOST_LOCATION

# 🧰 Tool-specific envs
export ADOTDIR="${ZDOTDIR}/antigen"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export VOLTA_HOME="${XDG_CONFIG_HOME}/volta"
export BUN_INSTALL="${XDG_CONFIG_HOME}/bun"
export PNPM_HOME="${XDG_CONFIG_HOME}/pnpm"

# 🖥️ Terminal & editor defaults
export TERM="xterm-256color"
export EDITOR="vim"

# 📜 Make less not clear the terminal after exit
export LESS="-XRF"

# ☁️ AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/.aws/credentials"

# ==============================================================================
# Update PATH
# ==============================================================================

# Make path array automatically unique (zsh magic!)
typeset -gU path PATH

# Add only if directory exists & not already in $PATH
add_to_path_if_exists() {
  # Fast path: check directory existence first (fail fast for non-existent dirs)
  [[ -d "$1" ]] || return 1

  # Prepend to path array - typeset -U automatically deduplicates!
  path=("$1" $path)
}

# Source file only if it exists and is readable
source_if_exists() {
  # Single file test for minimal overhead - -f checks both existence and regular file in one syscall
  [[ -f "$1" ]] && . "$1"
}

add_to_path_if_exists "${CARGO_HOME}/bin"
add_to_path_if_exists "${HOME}/.local/bin"
add_to_path_if_exists "/usr/local/go/bin"
add_to_path_if_exists "${HOME}/.yarn/bin"
add_to_path_if_exists "${HOME}/.config/yarn/global/node_modules/.bin"
add_to_path_if_exists "${BUN_INSTALL}/bin"
add_to_path_if_exists "${PNPM_HOME}/bin"

if [[ "${HOST_OS}" == "wsl" ]]; then
  add_to_path_if_exists "/mnt/c/Program Files/PowerShell/7"
  add_to_path_if_exists "/mnt/c/Windows"
  add_to_path_if_exists "/mnt/c/Windows/System32"
fi

# ==============================================================================
# Load Local Overrides
# ==============================================================================
source_if_exists "${ZDOTDIR}/local.zsh"
# NOTE: Commented out on this machine to improve startup time - uncomment if needed
# source_if_exists "${HOME}/local.zsh"
# source_if_exists "${ZDOTDIR}/.zprofile"
# source_if_exists "${HOME}/.zprofile"
# source_if_exists "${ZDOTDIR}/.bash_local"
# source_if_exists "${HOME}/.bash_local"

#=======================================================================================
# WSL-Specific Settings
#=======================================================================================
if [[ "${HOST_OS}" == "wsl" ]]; then
    export LIBGL_ALWAYS_INDIRECT=1
    export BROWSER="wslview"

    # Get IP address (FAST - no WSL boundary crossing)
    export IP_ADDRESS=${${(M)${(f)"$(ip route list default 2>/dev/null)"}:#*via*}[(w)3]}
    export DISPLAY="${IP_ADDRESS}:0"

    # Cache wslpath conversions in precmd (BIG performance gain)
    typeset -gA _wslpath_cache
    keep_current_path() {
        local cache_key=$PWD
        [[ -z ${_wslpath_cache[$cache_key]} ]] && _wslpath_cache[$cache_key]=$(wslpath -w "$PWD" 2>/dev/null)
        printf "\e]9;9;%s\e\\" "${_wslpath_cache[$cache_key]}"
    }
    precmd_functions+=(keep_current_path)

    [[ -n "$WT_SESSION" ]] && printf "\033]9;9;%s\033\\" "$PWD"

    # ASYNC: Cache Windows user profile path in background (SLOW - crosses WSL boundary)
    {
        export WINDOWS_USER_PROFILE=$(wslpath "$(wslvar USERPROFILE)" 2>/dev/null)
    } &!
fi

#=======================================================================================
# macOS-Specific Settings
#=======================================================================================
if [[ "${HOST_OS}" == "darwin" ]]; then
    launchctl setenv HOST_OS darwin
fi

#=======================================================================================
# Android Development Environment
#=======================================================================================
if [[ -d "${HOME}/android" ]]; then
    export JAVA_HOME="/usr/lib/jvm/jdk-17"
    export ANDROID_HOME="${HOME}/android"
    export ANDROID_SDK_ROOT="${ANDROID_HOME}"
    export WSLENV="${ANDROID_HOME}/p:${WSLENV}"
    add_to_path_if_exists "${ANDROID_HOME}/cmdline-tools/latest/bin"
    add_to_path_if_exists "${ANDROID_HOME}/platform-tools"
    add_to_path_if_exists "${ANDROID_HOME}/tools"
    add_to_path_if_exists "${ANDROID_HOME}/tools/bin"
fi

# ==============================================================================
# Shell Settings
# ==============================================================================

# 🔒 Fix Ctrl+Q messing with terminal (e.g. Vim visual block mode)
# See: https://stackoverflow.com/a/21806557
if [[ -t 0 ]]; then
  stty start undef
fi

# 🕓 History configuration
HISTSIZE=10000000
SAVEHIST=$HISTSIZE
HISTFILE="${ZDOTDIR}/.zsh_history"
WORDCHARS=''  # Fix weird behavior with word movement (https://github.com/ohmyzsh/ohmyzsh/issues/5108)

# 📖 Zsh options (behavior tweaks)
setopt CORRECT                    # Auto-correct misspelled commands
setopt AUTO_CD                    # Just type folder name to cd into it
setopt AUTO_LIST                  # Show completion options automatically
setopt AUTO_MENU                  # Show menu on multiple tab presses
setopt AUTO_PUSHD                 # Automatically push dirs onto directory stack
setopt PUSHD_IGNORE_DUPS          # Avoid duplicate directories in pushd stack
setopt PUSHD_MINUS                # Swap meaning of pushd +1 and -1
setopt PUSHD_SILENT               # Don't print directory stack after pushd/popd
setopt COMPLETE_IN_WORD           # Complete words in the middle
setopt ALWAYS_TO_END              # Cursor jumps to end after completion
setopt EXTENDED_GLOB              # Enhanced globbing (wildcards, etc.)
setopt GLOB_DOTS                  # Include hidden files in glob matches (no need for .*)
setopt INTERACTIVE_COMMENTS       # Allow comments in interactive shell
setopt MULTIOS                    # Allow tee-like behavior with pipes
setopt NO_BEEP                    # Silence the annoying bell
setopt NO_FLOW_CONTROL            # Disable Ctrl+S/Ctrl+Q flow control (frees up Ctrl+S for fwd search)
setopt PROMPT_SUBST               # Allow prompt string substitution
setopt LONG_LIST_JOBS             # Show PID in jobs list
setopt NOTIFY                     # Report background job status immediately
setopt NO_HUP                     # Don't kill background jobs on shell exit
setopt NO_CHECK_JOBS              # Don't warn about running jobs when exiting
setopt NUMERIC_GLOB_SORT          # Sort globs numerically (file1, file2, file10 instead of file1, file10, file2)

# 🧠 History behavior
setopt BANG_HIST                  # !foo expands to last "foo" command
setopt EXTENDED_HISTORY           # Save timestamp + duration in history
setopt SHARE_HISTORY              # Share history across sessions (implies INC_APPEND_HISTORY + INC_APPEND_HISTORY_TIME)
setopt HIST_IGNORE_SPACE          # Don't save commands starting with space
setopt HIST_REDUCE_BLANKS         # Collapse multiple spaces
setopt HIST_EXPIRE_DUPS_FIRST     # Expire old dupes before new entries
setopt HIST_FIND_NO_DUPS          # Don't show duplicate results when searching
setopt HIST_IGNORE_ALL_DUPS       # Remove all previous dups when adding new one (implies HIST_IGNORE_DUPS)
setopt HIST_SAVE_NO_DUPS          # Never save duplicates to history file
setopt HIST_VERIFY                # Verify history expansions before execution (prevents accidental !! or !foo)

#=======================================================================================
# Setting up home/end keys for keyboard
# https://unix.stackexchange.com/questions/20298/home-key-not-working-in-terminal
#=======================================================================================
# Vi mode
bindkey -v

# ==============================================================================
# Vi Mode Visual Indicators
# ==============================================================================

# Change cursor shape for different vi modes
function zle-keymap-select {
  case $KEYMAP in
    vicmd)      echo -ne '\e[1 q' ;;  # Block cursor (NORMAL mode)
    viins|main) echo -ne '\e[5 q' ;;  # Beam cursor (INSERT mode)
  esac
}

function zle-line-init {
  echo -ne '\e[5 q'  # Start with beam cursor (INSERT mode)
}

zle -N zle-keymap-select
zle -N zle-line-init

# Reset cursor on each new prompt
function reset_cursor {
  echo -ne '\e[5 q'
}
precmd_functions+=(reset_cursor)

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey '^w'	  backward-kill-word
bindkey '\e[1~'   beginning-of-line  # Linux console
bindkey '\e[H'    beginning-of-line  # xterm
bindkey '\eOH'    beginning-of-line  # gnome-terminal
bindkey '\e[2~'   overwrite-mode     # Linux console, xterm, gnome-terminal
bindkey '\e[3~'   delete-char        # Linux console, xterm, gnome-terminal
bindkey '\e[4~'   end-of-line        # Linux console
bindkey '\e[F'    end-of-line        # xterm
bindkey '\eOF'    end-of-line        # gnome-terminal

# ==============================================================================
# ZSH Settings
# ==============================================================================

# 📁 File & directory colors (for `ls`, `exa`, etc.)
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# 🔎 Completion engine behavior
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:match:*' original only
zstyle -e ':completion:*:approximate:*' max-errors \
  'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'

# 💬 Completion display formatting
zstyle ':completion:*:messages'     format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings'     format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options'      description 'yes'
zstyle ':completion:*:default'      list-prompt '%S%M matches%s'
zstyle ':completion:*'              format ' %F{yellow}-- %d --%f'
zstyle ':completion:*'              verbose yes

# 🔁 Completion behavior
zstyle ':completion:*:matches'      group 'yes'
zstyle ':completion:*'              group-name ''
zstyle ':completion:*'              use-cache true
zstyle ':completion:*'              rehash true
zstyle ':completion:*:functions'    ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*'              menu select interactive
zstyle ':completion:*'              matcher-list '' \
    'm:{[:lower:]}={[:upper:]}' \
    '+m:{[:upper:]}={[:lower:]}'

# 🚫 Sort git branches during `git checkout` completion
zstyle ':completion:*:git-checkout:*' sort false

# 🐳 Legacy Docker completions (OMZ plugin compat)
zstyle ':omz:plugins:docker' legacy-completion yes

# 🎨 FZF tab preview config
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group ',' '.'

# 🔒 Escape ? without quoting
set zle_bracketed_paste
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

# 🔁 Auto-source `.dirrc` when entering a directory (SAFE version)
load-local-conf() {
  local dirrc=.dirrc
  [[ -f $dirrc ]] || return 0

  # Only auto-load from trusted directories (HOME and its subdirectories)
  case $PWD in
    $HOME/*|$HOME)
      source "$dirrc"
      ;;
    *)
      # Warn about untrusted .dirrc files
      print -P "%F{yellow}⚠️  Found .dirrc in untrusted location: %F{cyan}$PWD%f"
      print -P "%F{yellow}Run 'source .dirrc' to load it manually%f"
      ;;
  esac
}
chpwd_functions+=(load-local-conf)

# ==============================================================================
# ZINIT (ZI) Plugin Manager Setup
# ==============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[[ ! -d $ZINIT_HOME ]] && mkdir -p "$(dirname $ZINIT_HOME)"
[[ ! -d $ZINIT_HOME/.git ]] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"
autoload -Uz _zinit; (( ${+_comps} )) && _comps[zinit]=_zinit

# ==============================================================================
# THEMING
# ==============================================================================

# ⚡ Powerlevel10k - Fast, customizable prompt with instant-prompt support
# Shows git status, command duration, exit codes, and more
# Configure: run `p10k configure` to customize appearance
# Disable configuration wizard on servers and non-interactive sessions
typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
zi ice depth'1'
zi light romkatv/powerlevel10k

# ==============================================================================
# COMPLETION / INTERACTIVE ENHANCEMENTS
# ==============================================================================

# 🎨 Fast Syntax Highlighting - Highlights commands as you type in real-time
# Valid commands = green, invalid = red, helps catch typos before execution
zi ice lucid depth'1'
zi light zdharma-continuum/fast-syntax-highlighting

# 💡 FZF - Fuzzy finder for files, commands, history
# Usage: Ctrl+T (files), Ctrl+R (history), Alt+C (directories)
# Integrates with many other plugins for fuzzy search everywhere
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
zi ice depth'1' atclone'./install --bin' atpull'%atclone'
zi light junegunn/fzf
# Force correct fzf in PATH before anything else
add_to_path_if_exists "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins/junegunn---fzf/bin"

# 📂 FZF-Tab - Replaces tab completion with FZF interface
# Usage: Press TAB for fuzzy-searchable completion menu with previews
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
zi ice lucid wait'1' depth'1'
zi light Aloxaf/fzf-tab

# 🔍 FZF-Tab-Source - Provides additional completion sources for fzf-tab
# Enhances fzf-tab with better context-aware completions
zi ice lucid wait'1' depth'1' branch'main'
zi light Freed-Wu/fzf-tab-source

# 🔁 FZF History Search - Enhanced Ctrl+R with fuzzy command history
# Usage: Ctrl+R to search shell history with fuzzy matching
zi ice lucid wait'1' depth'1'
zi light joshskidmore/zsh-fzf-history-search

# 🔄 ZSH Autosuggestions - Fish-like command suggestions from history
# Usage: Type command, press → (right arrow) to accept suggestion
# Shows grayed-out suggestion based on command history as you type
zi ice lucid depth'1'
zi light zsh-users/zsh-autosuggestions

# 🔁 ZSH Completions - Additional completion definitions for 1000+ commands
# Provides tab completions for commands not covered by default ZSH
zi ice depth'1'
zi light zsh-users/zsh-completions

# 🧠 Atuin - Magical shell history with sync, stats, and better search
# Usage: Ctrl+R for powerful history search, `atuin stats` for analytics
# Stores full context (directory, duration, exit code) and syncs across machines
zi ice lucid wait'2' depth'1' branch'main'
zi light atuinsh/atuin

# 🫵 You-Should-Use - Reminds you of existing aliases when you use full commands
# Usage: Automatic - alerts you "Found alias gst for git status" when you type long commands
# Helps you learn and use your aliases to save typing
zi ice wait'!0' lucid depth'1'
zi light MichaelAquilina/zsh-you-should-use

# ⌨️ ZSH Autopair - Auto-closes quotes, brackets, and parentheses
# Usage: Automatic - type '(' and it adds ')', type '"' and it adds closing '"'
zi ice lucid depth'1'
zi light hlissner/zsh-autopair

# 🧙‍♂️ JQ ZSH Plugin - Interactive jq query builder
# Usage: Type JSON command | (press Alt+J) - opens interactive jq builder
# Helps construct complex jq queries visually
zi ice wait'!0' lucid depth'1'
zi light reegnz/jq-zsh-plugin

# 🔥 Fancy Completions - Enhanced completions for modern CLI tools
# Provides smart completions for gh (GitHub CLI), docker, kubectl, etc.
zi ice wait'!0' lucid depth'1' branch'main'
zi light z-shell/zsh-fancy-completions

# 💻 SSH Alias Manager - Manages SSH connection aliases
# Usage: Creates convenient aliases for SSH hosts from ~/.ssh/config
zi ice wait'!0' lucid depth'1' from'gh'
zi light sunlei/zsh-ssh

# ==============================================================================
# NAVIGATION & FILE MANAGEMENT TOOLS
# ==============================================================================

# 📁 Enhancd - Enhanced cd with interactive directory history and fuzzy search
# Usage: `cd` - fuzzy search through visited directories
# Usage: `cd ..` multiple times - interactive selection of parent dirs
export ENHANCD_DISABLE_DOT=1
export ENHANCD_FILTER="fzf"
export ENHANCD_COMMAND="cd"
export ENHANCD_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/enhancd"
export ENHANCD_DIR="${ENHANCD_ROOT}"
export ENHANCD_DIR_PATH_STYLE="full"
export ENHANCD_HOME="${ENHANCD_ROOT}"
export ENHANCD_DIVE_MAX=10
zi ice lucid wait'2' depth'1' src'init.sh' branch'main'
zi light babarot/enhancd

# 📁 BD - Quickly go back to a parent directory by name
# Usage: `bd src` - jump back to /home/user/projects/src from deep subdirectory
# Example: In /home/user/projects/src/components/ui → `bd projects` → /home/user/projects
zi ice wait'!0' as'program' pick'bd' mv'bd -> bd'
zi load vigneshwaranr/bd

# 📁 Rename - Perl-based batch file renamer with regex support
# Usage: `rename 's/\.txt$/.md/' *.txt` - rename all .txt files to .md
zi ice wait'!0' as'program' pick'rename' mv'rename -> rename'
zi load ap/rename

# 📊 Eza - Modern ls replacement with colors, icons, and git integration
# Usage: Already aliased to `ls`, `l`, `la`, `ll`, `tree`
# Shows file permissions, size, git status, and uses colors automatically
zi ice lucid depth'1' from'gh-r' as'program' sbin'**/eza -> eza' atclone'cp -vf completions/eza.zsh _eza' bpick'eza_x86_64-unknown-linux-gnu.tar.gz'
zi light eza-community/eza

# 🌲 Erdtree - Modern file-tree visualization with disk usage
# Usage: `erdtree` or `et` - shows directory tree with file sizes
# Alternative to `tree` and `ncdu` with better visuals
zi ice wait'!0' lucid depth'1' from'gh-r' as'command'
zi light solidiquis/erdtree

# 🔖 ZSHmarks - Directory bookmarking system
# Usage: `bookmark <name>` - save current dir, `jump <name>` - jump to saved dir
# `showmarks` - list all bookmarks, `deletemark <name>` - remove bookmark
zi ice wait'!0' lucid depth'1'
zi light jocelynmallon/zshmarks

# ==============================================================================
# SEARCH / DEV TOOLS
# ==============================================================================

# 🔎 Ripgrep - Lightning-fast recursive grep with smart defaults
# Usage: `rg "pattern"` - searches files recursively, respects .gitignore
# Auto-pipes through less with `rg()` function in aliases.zsh
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/.ripgreprc"
zi ice from'gh-r' as'command' pick='*/rg'
zi load BurntSushi/ripgrep

# 🦇 Bat - Cat clone with syntax highlighting and git integration
# Usage: Already aliased to `cat` - shows line numbers and syntax colors
# Original cat available as `rcat`
export BAT_THEME="OneHalfDark"
zi ice from'gh-r' as'command' mv"bat* -> bat" pick"bat/bat"
zi load sharkdp/bat

# 🔍 FD - Simple, fast alternative to `find`
# Usage: `fd pattern` - finds files by name, faster than find
# `fd -e js` - find by extension, `fd -t d` - find directories only
zi ice from'gh-r' as'command' mv"fd* -> fd" pick"fd/fd"
zi load sharkdp/fd

# 🔬 XSV - Fast CSV command line toolkit
# Usage: `xsv stats data.csv` - show column statistics
# `xsv select column1,column2 data.csv` - select columns
zi ice wait'!0' lucid depth'1' from'gh' as'command' atclone'"${CARGO_HOME}/bin/cargo" build --release' pick'target/release/xsv' atpull'%atclone'
zi light BurntSushi/xsv

# 📊 CSVtool - Pandas-powered CSV manipulation tool
# Usage: `csvtool filter data.csv` - interactive CSV filtering
zi ice wait'!0' as'program' pick'csvtool/csvtool.py' \
  atclone'python3 -m venv venv && venv/bin/pip install pandas openpyxl' \
  atpull'%atclone' \
  cmd'./venv/bin/python csvtool "$@"'
zi load maroofi/csvtool

# 🧼 SD - Intuitive find & replace CLI (better than sed)
# Usage: `sd before after file.txt` - simpler syntax than sed
# `sd '\d+' '[$0]' file.txt` - regex with capture groups
zi ice wait'!0' from'gh-r' as'command' pick'gnu'
zi light chmln/sd

# 🧠 JQ - Command-line JSON processor
# Usage: `echo '{"key":"value"}' | jq .key` - extract JSON fields
# Works with jq-zsh-plugin for interactive query building (Alt+J)
zi ice as'program' from'gh-r' bpick'*linux64' mv'jq* -> jq'
zi load jqlang/jq

# 💥 UP - Interactive pipe builder for shell commands
# Usage: `up` - opens visual editor to build/test pipelines interactively
# Helps construct complex command pipelines with live preview
zi ice wait'!0' lucid depth'1' from'gh-r' as'command'
zi light akavel/up

# 📷 Imcat - Display images directly in terminal
# Usage: `imcat image.png` - renders image in terminal (kitty/iTerm2)
zi ice wait'!0' lucid depth'1' from'gh' as'command' make pick'imcat'
zi light stolk/imcat

# 📊 QSV - Ultra-fast CSV toolkit with Python integration
# Usage: `qsv stats data.csv` - advanced CSV statistics and operations
# More features than xsv: SQL queries, Python expressions, etc.
zi ice wait'!0' lucid depth'1' as'program' pick'target/release/qsv' atclone'cargo build --release --locked --bin qsv --features "feature_capable,python,apply,foreach"' atpull'%atclone'
zi light dathere/qsv

# ==============================================================================
# GIT ENHANCEMENTS
# ==============================================================================

# 🧠 Forgit - Interactive git operations with FZF
# Usage: `git log` aliased to `gl` - interactive commit browser
# `gd` - interactive diff, `ga` - interactive add, `glo` - interactive log
export forgit_log=gl
export FORGIT_DIFF_GIT_OPTS="-w --ignore-blank-lines"
zi ice lucid wait'1' depth'1' branch'main'
zi light wfxr/forgit

# 🌐 Git-Open - Open current repo in browser (GitHub/GitLab/Bitbucket)
# Usage: `git open` - opens repo URL in browser
# `git open --issue` - opens issues page
zi ice wait'!0' lucid depth'1'
zi light paulirish/git-open

# 🛠️ Git-Extras - Collection of 60+ git utilities
# Usage: `git summary` - repo summary, `git effort` - show file activity
# `git changelog` - generate changelog, `git ignore` - add to .gitignore
# Full list: https://github.com/tj/git-extras/blob/master/Commands.md
zi ice wait'!0' lucid depth'1' as'program' pick'$ZPFX/bin/git-*' make'PREFIX=$ZPFX' nocompile
zi light tj/git-extras

# ==============================================================================
# NODE & LANGUAGE ENVIRONMENTS
# ==============================================================================

# 🌱 ZSH-FNM - Fast Node Manager integration with auto-switching
# Usage: Automatic - switches Node version based on .nvmrc/.node-version
# `fnm list` - show installed versions, `fnm install 20` - install Node 20
# Faster than nvm, automatically switches on `cd` into projects
export ZSH_FNM_NODE_VERSION="22"
export ZSH_FNM_ENV_EXTRA_ARGS="--use-on-cd"
export ZSH_FNM_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
zi ice lucid wait'1' depth'1'
zi light dominik-schwabe/zsh-fnm

# 📦 Better NPM Completion - Enhanced tab completion for npm/yarn/pnpm
# Usage: `npm install <TAB>` - shows package suggestions from npm registry
# Works for npm, yarn, and pnpm commands
zi ice wait'!0' lucid depth'1' as'completion'
zi light lukechilds/zsh-better-npm-completion

# 🎨 Laravel Artisan Completion - Smart completions for Laravel Artisan
# Usage: `php artisan <TAB>` - shows available artisan commands
# Works with Docker alias `pa` as well
zi ice wait'!0' lucid depth'1'
zi light jessarcher/zsh-artisan

# # 🎼 Composer Completion - Tab completion for Composer commands
# # Usage: `composer <TAB>` - shows composer commands and package names
# zi ice wait'!0' lucid depth'1' as'completion'
# zi snippet https://github.com/composer/composer/blob/main/res/composer-completion.zsh

# ==============================================================================
# OMZ SNIPPETS (Useful one-liners from Oh-My-Zsh)
# ==============================================================================

zi ice wait'1' lucid blockf
zi snippet OMZP::sudo             # Usage: Press ESC twice to prefix previous command with sudo
zi snippet OMZP::extract          # Usage: `extract file.zip` - auto-detects and extracts any archive format
zi snippet OMZP::copyfile         # Usage: `copyfile file.txt` - copies file contents to clipboard
zi snippet OMZP::dirhistory       # Usage: Alt+Left/Right arrows to navigate directory history
zi snippet OMZP::docker-compose   # Provides tab completions for docker-compose commands

#=======================================================================================
# Autocompletion
#=======================================================================================

# 🔁 Completion system handled by ZINIT
autoload -Uz colors && colors

#Calculator: zcalc
autoload -U zcalc

# 📦 Enable zmv for wildcard-based file renaming (e.g., zmv '*.txt' 'prefix_#1.txt')
autoload -Uz zmv

# ==============================================================================
# Custom Application Settings
# ==============================================================================

if [[ "$HOST_OS" == "wsl" ]] && (( $+commands[systemctl] )); then
  if ! systemctl is-active --quiet docker 2>/dev/null; then
    if sudo -n systemctl start docker 2>/dev/null; then
      : # Docker started successfully
    fi
  fi
fi

# 🗂️ broot (directory visualizer)
# NOTE: Commented out - not installed on this machine
# source_if_exists "${XDG_CONFIG_HOME}/broot/launcher/bash/br"

# 🎨 Powerlevel10k theme config
source_if_exists "${ZDOTDIR}/.p10k.zsh"

# 🦀 Rust environment variables
# NOTE: Removed - already handled by add_to_path_if_exists "${CARGO_HOME}/bin" at line 113
# source_if_exists "${CARGO_HOME}/env"

# 🧠 FZF keybindings (Ctrl+T, Alt+C, Ctrl+R)
# NOTE: Lazy load to improve startup time
zi ice lucid wait'0' atload'source_if_exists "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins/junegunn---fzf/shell/key-bindings.zsh"'
zi snippet /dev/null

# ⚡️ Envman – environment loader
# NOTE: Commented out - envman not installed
# source_if_exists "${XDG_CONFIG_HOME}/envman/load.sh"

# 🐱 Kitty terminal config + completions
if (( $+commands[kitty] )); then
  export KITTY_CONFIG_DIRECTORY="${XDG_CONFIG_HOME}/kitty"

  # Cache kitty completion (regenerate only when kitty binary changes)
  local kitty_comp="${ZSH_CACHE_DIR}/kitty_completion.zsh"
  if [[ ! -f "$kitty_comp" ]] || [[ "${commands[kitty]}" -nt "$kitty_comp" ]]; then
    kitty + complete setup zsh >| "$kitty_comp"
  fi
  source "$kitty_comp"
fi

# 🧬 direnv – per-project environment management
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi

# ☁️ doctl – DigitalOcean CLI completion
if (( $+commands[doctl] )); then
  source <(doctl completion zsh)
  compdef _doctl doctl
fi

# VSCode Integration
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"


#[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# ==============================================================================
# WSL Windows Terminal sync (guarded)
# ==============================================================================
if [[ "${HOST_OS}" == 'wsl' ]]; then
    # Use full path to pwsh.exe instead of relying on PATH
    PWSH_EXE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"
    
    if [[ -x "$PWSH_EXE" ]]; then
        WINDOWS_USER=$("$PWSH_EXE" -NoProfile -Command '$env:UserName' | tr -d '\r')
        DOTFILES_DIR="$HOME/.dotfiles"
        TERMINAL_SETTINGS_DEST="/mnt/c/Users/$WINDOWS_USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
        TERMINAL_SETTINGS_SRC="$DOTFILES_DIR/windows-terminal/settings.json"

        if [[ -f "$TERMINAL_SETTINGS_DEST" && -f "$TERMINAL_SETTINGS_SRC" ]]; then
          if [[ "$TERMINAL_SETTINGS_SRC" -nt "$TERMINAL_SETTINGS_DEST" ]]; then
            cp "$TERMINAL_SETTINGS_DEST" "${TERMINAL_SETTINGS_DEST}.bak.$(date +%s)"
            cp "$TERMINAL_SETTINGS_SRC" "$TERMINAL_SETTINGS_DEST"
          fi
        fi
    fi
fi

#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
source_if_exists "${ZDOTDIR}/aliases.zsh"
# NOTE: Commented out - aliases.zsh not present in HOME
# source_if_exists "${HOME}/aliases.zsh"

# At the *end* of .zshrc
# Recompile if source is newer
if [[ -n "${(%):-%N}" && -r "${(%):-%N}" ]]; then
  if [[ "${(%):-%N}" -nt "${(%):-%N}.zwc" ]]; then
    echo "Recompiling ${(%):-%N}..."
    zcompile "${(%):-%N}"
  fi
fi
# If zsh is really slow, enable profiling via zprof, uncomment the line above and line 2
# zprof
