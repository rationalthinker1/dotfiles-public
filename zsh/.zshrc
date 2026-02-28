#!/usr/bin/env zsh
# ==============================================================================
# .zshrc - Interactive Shell Configuration
# ==============================================================================
# This file runs for INTERACTIVE shells only (not scripts)
#
# LOAD ORDER:
#   1. .zshenv     (environment variables - already loaded)
#   2. .zprofile   (login shells only - already loaded if login shell)
#   3. .zshrc      ← YOU ARE HERE (interactive config)
#   4. .zlogin     (after .zshrc in login shells)
#
# USE THIS FILE FOR:
# - Aliases and functions
# - Shell options (setopt)
# - Key bindings
# - Prompt configuration
# - Plugin loading
# - Completions
#
# DO NOT PUT HERE:
# - Environment variables (→ .zshenv)
# - PATH modifications (→ .zshenv)
# ==============================================================================

# zmodload zsh/zprof # top of your .zshrc file - uncomment to profile startup time
# Environment variables and PATH are defined in .zshenv

# Note: .zshenv is always sourced first by ZSH (guaranteed by ZSH specification)
# If ZDOTDIR is not set, your shell environment is fundamentally misconfigured

# ==============================================================================
# ⚡ Powerlevel10k Instant Prompt (MUST BE NEAR TOP!)
# ==============================================================================
# Enable instant prompt to show prompt immediately while plugins load in background
# This MUST come before any code that produces console output or modifies the terminal
if [[ -r "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Add to PATH without checking directory existence (optimized for WSL startup speed)
# Non-existent dirs in PATH are harmless - shell handles them fine
function add_to_path_if_exists() {
    # Directory existence check removed for performance (was 20% of startup time in WSL)
    # [[ -d "${1}" ]] || return 1
    
    # Prepend to path array - typeset -U automatically deduplicates!
    path=("${1}" "${path[@]}")
}

# Source file only if it exists and is readable
function source_if_exists() {
    # Single file test for minimal overhead - -f checks both existence and regular file in one syscall
    [[ -f "${1}" ]] && source "${1}"
}

# ==============================================================================
# Load Local Overrides
# ==============================================================================
source_if_exists "${ZDOTDIR}/local.zsh"

# ==============================================================================
# Secret Management with pass
# ------------------------------------------------------------------------------
# pass is a GPG-encrypted password/secret manager. Quick reference:
#
#   Setup:
#     gpg --gen-key                        # generate a GPG key (one-time)
#     pass init "your@email.com"           # initialize the store
#
#   Store a secret:
#     pass insert api/openai               # opens $EDITOR, type value, save
#     echo "sk-xyz" | pass insert --echo api/openai  # pipe value directly
#
#   Retrieve:
#     pass api/openai                      # print to stdout
#     pass -c api/openai                   # copy to clipboard (clears after 45s)
#
#   List / remove:
#     pass ls                              # list all entries
#     pass rm api/openai                   # delete an entry
#
#   GPG agent caching (avoid re-prompting every shell):
#     mkdir -p "$GNUPGHOME" && chmod 700 "$GNUPGHOME"
#     echo "default-cache-ttl 86400" >> "$GNUPGHOME/gpg-agent.conf"
#     echo "max-cache-ttl 604800"    >> "$GNUPGHOME/gpg-agent.conf"
#     gpgconf --kill gpg-agent
# ==============================================================================
if (( $+commands[pass] )); then
    # Helper function to safely load secrets
    function load_secret() {
        local secret_path="${1}"
        local env_var="${2}"

        if pass show "${secret_path}" &>/dev/null; then
            export "$env_var"="$(pass show "${secret_path}")"
        fi
    }
    
    # Load API keys from pass (if configured)
    # Uncomment and configure after running: pass init <gpg-key-id>
    # load_secret "openai/api_key" "OPENAI_API_KEY"
    # load_secret "github/token" "GITHUB_TOKEN"
fi

#=======================================================================================
# macOS-Specific Settings
#=======================================================================================
# Note: launchctl configuration is in .zprofile (login-only)

#=======================================================================================
# Android Development Environment
#=======================================================================================
# Only load on desktop environments to avoid unnecessary JDK search on servers
if [[ "${HOST_LOCATION}" == "desktop" && -d "${HOME}/android" ]]; then
    # Dynamically find Java installation (prefer newer versions)
    for jdk_version in 21 17 11 8; do
        jdk_path="/usr/lib/jvm/jdk-${jdk_version}"
        if [[ -d "${jdk_path}" ]]; then
            export JAVA_HOME="${jdk_path}"
            break
        fi
    done
    
    # Fallback: use update-alternatives on Debian/Ubuntu
    if [[ -z "${JAVA_HOME}" ]] && (( $+commands[update-java-alternatives] )); then
        export JAVA_HOME="$(update-java-alternatives -l 2>/dev/null | awk 'NR==1 {print $3}')"
    fi
    
    # Only set Android paths if Java was found
    if [[ -n "${JAVA_HOME}" && -d "${JAVA_HOME}" ]]; then
        export ANDROID_HOME="${HOME}/android"
        export ANDROID_SDK_ROOT="${ANDROID_HOME}"
        # WSL-specific: Expose Android paths to Windows
        if [[ "${HOST_OS}" == "wsl" ]]; then
            export WSLENV="ANDROID_HOME/p:${WSLENV}"
        fi
        add_to_path_if_exists "${ANDROID_HOME}/cmdline-tools/latest/bin"
        add_to_path_if_exists "${ANDROID_HOME}/platform-tools"
        add_to_path_if_exists "${ANDROID_HOME}/tools"
        add_to_path_if_exists "${ANDROID_HOME}/tools/bin"
    else
        echo "WARNING: Android directory exists but no JDK found" >&2
    fi
fi

# ==============================================================================
# Shell Settings
# ==============================================================================

# 🔒 Fix Ctrl+Q messing with terminal (e.g. Vim visual block mode)
# See: https://stackoverflow.com/a/21806557
if [[ -t 0 ]]; then
    stty -ixon
fi

# 🕓 History configuration
HISTSIZE=10000000
SAVEHIST="${HISTSIZE}"
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

# ==============================================================================
# Vi Mode Visual Indicators
# ==============================================================================

# Change cursor shape for different vi modes
# Skip cursor changes in tmux (can cause glitches in some terminals)
if [[ -z "${TMUX}" ]]; then
    function zle-keymap-select() {
        case $KEYMAP in
            vicmd)      echo -ne '\e[1 q' ;;  # Block cursor (NORMAL mode)
            viins|main) echo -ne '\e[5 q' ;;  # Beam cursor (INSERT mode)
        esac
        zle reset-prompt
    }
    
    function zle-line-init() {
        echo -ne '\e[5 q'  # Start with beam cursor (INSERT mode)
        zle -K viins       # Start in insert mode
    }
    
    function zle-line-finish() {
        echo -ne '\e[1 q'  # Block cursor when command finishes
    }
    
    zle -N zle-keymap-select
    zle -N zle-line-init
    zle -N zle-line-finish
    
else
    # Simpler setup for tmux (no cursor shape changes)
    function zle-line-init() {
        zle -K viins       # Start in insert mode
    }
    
    zle -N zle-line-init
fi

# ==============================================================================
# Enhanced Keybindings (Vi mode with Emacs conveniences)
# ==============================================================================

# ⌨️ Ctrl-based navigation (works in both insert and normal mode)
bindkey '^a' beginning-of-line        # Ctrl+A: Go to beginning of line
bindkey '^e' end-of-line              # Ctrl+E: Go to end of line
bindkey '^u' backward-kill-line       # Ctrl+U: Delete to start of line
bindkey '^k' kill-line                # Ctrl+K: Delete to end of line
bindkey '^w' backward-kill-word       # Ctrl+W: Delete word backward
bindkey '^y' yank                     # Ctrl+Y: Paste (yank)
bindkey '^b' backward-char            # Ctrl+B: Move backward one char
bindkey '^f' forward-char             # Ctrl+F: Move forward one char
bindkey '^d' delete-char-or-list      # Ctrl+D: Delete char or show completions
bindkey '^h' backward-delete-char     # Ctrl+H: Backspace

# ⌨️ Word movement (Ctrl+Arrow keys and Alt+Arrow keys)
bindkey "^[[1;5C" forward-word        # Ctrl+Right: Forward word
bindkey "^[[1;5D" backward-word       # Ctrl+Left: Backward word
bindkey "^[[1;3C" forward-word        # Alt+Right: Forward word
bindkey "^[[1;3D" backward-word       # Alt+Left: Backward word

# ⌨️ Home/End keys (multiple terminal types)
bindkey '\e[1~'   beginning-of-line   # Linux console
bindkey '\e[H'    beginning-of-line   # xterm
bindkey '\eOH'    beginning-of-line   # gnome-terminal
bindkey '\e[4~'   end-of-line         # Linux console
bindkey '\e[F'    end-of-line         # xterm
bindkey '\eOF'    end-of-line         # gnome-terminal

# ⌨️ Other useful keys
bindkey '\e[2~'   overwrite-mode      # Insert
bindkey '\e[3~'   delete-char         # Delete
bindkey '\e[5~'   up-line-or-history  # Page Up
bindkey '\e[6~'   down-line-or-history # Page Down

# ==============================================================================
# Smart History Search (Up/Down arrows search by prefix)
# ==============================================================================
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search     # Up arrow
bindkey '^[[B' down-line-or-beginning-search   # Down arrow
bindkey '^P' up-line-or-beginning-search       # Ctrl+P (vi-style)
bindkey '^N' down-line-or-beginning-search     # Ctrl+N (vi-style)

# Vi mode: k/j also search by prefix
bindkey -M vicmd 'k' up-line-or-beginning-search
bindkey -M vicmd 'j' down-line-or-beginning-search

# ==============================================================================
# Edit Command Line in $EDITOR (Ctrl+X Ctrl+E or v in vi normal mode)
# ==============================================================================
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line      # Ctrl+X Ctrl+E: Open in $EDITOR
bindkey -M vicmd 'v' edit-command-line # v in normal mode: Open in $EDITOR

# ==============================================================================
# Vi Mode Enhancements
# ==============================================================================
#=======================================================================================
# Setting up home/end keys for keyboard
# https://unix.stackexchange.com/questions/20298/home-key-not-working-in-terminal
#=======================================================================================
# Vi mode
# bindkey -v  # DISABLED - Vim mode disabled

# Use emacs mode instead (default zsh mode)
bindkey -e

# Reduce ESC delay to 10ms for faster vi mode switching (default: 400ms)
# export KEYTIMEOUT=1  # Not needed in emacs mode

# Better undo/redo
bindkey -M vicmd 'u' undo
bindkey -M vicmd '^r' redo

# Increment/decrement numbers (like vim's Ctrl+A/X)
autoload -Uz incarg
zle -N incarg
bindkey -M vicmd '^a' incarg

# Text objects improvement (ci", ci', ci(, etc. work better)
autoload -Uz select-quoted select-bracketed surround
zle -N select-quoted
zle -N select-bracketed
zle -N delete-surround surround
zle -N add-surround surround
zle -N change-surround surround

# Bind text objects for vi mode
for m in visual viopp; do
    for c in {a,i}${(s..)^:-\'\"\`\|,./:;=+@}; do
        bindkey -M "${m}" "${c}" select-quoted
    done
    for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
        bindkey -M "${m}" "${c}" select-bracketed
    done
done

# Surround operations (like vim-surround)
bindkey -M vicmd 'cs' change-surround
bindkey -M vicmd 'ds' delete-surround
bindkey -M vicmd 'ys' add-surround
bindkey -M visual 'S' add-surround

# ==============================================================================
# Incremental Search Improvements
# ==============================================================================

# Ctrl+R: Reverse incremental search - DISABLED (overridden by atuin plugin at line 797)
# atuin provides superior history search with sync, stats, and SQLite backend
# bindkey '^r' history-incremental-search-backward
# bindkey -M vicmd '/' history-incremental-search-backward
# bindkey -M vicmd '?' history-incremental-search-forward

# ==============================================================================
# ZSH Settings
# ==============================================================================

# 📁 File & directory colors (for `ls`, `eza`, etc.)
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# 🔎 Completion engine behavior
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:match:*' original only
zstyle -e ':completion:*:approximate:*' max-errors \
'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'

# 💬 Completion display formatting
zstyle ':completion:*:messages'     format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings'     format '%F{red}⚠ No matches for: %F{yellow}%d%f'
zstyle ':completion:*:descriptions' format '%F{blue}completing %B%d%b%f'
zstyle ':completion:*:corrections'  format '%F{green}%d (errors: %e)%f'
zstyle ':completion:*:options'      description 'yes'
zstyle ':completion:*:default'      list-prompt '%S%M matches%s'
zstyle ':completion:*'              verbose yes

# 🔁 Completion behavior
zstyle ':completion:*:matches'      group 'yes'
zstyle ':completion:*'              group-name ''
zstyle ':completion:*'              use-cache true
zstyle ':completion:*'              cache-path "${ZSH_CACHE_DIR}/zcompcache"
zstyle ':completion:*'              rehash true
zstyle ':completion:*'              menu select interactive
zstyle ':completion:*'              matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*'              accept-exact '*(N)'        # Faster exact matches
zstyle ':completion:*'              squeeze-slashes true       # Cleanup paths (foo//bar -> foo/bar)
zstyle ':completion:*:*:*:*:processes' command "ps -u ${USER} -o pid,user,comm -w -w"  # Better process completion

# 🚫 Sort git branches during `git checkout` completion
zstyle ':completion:*:git-checkout:*' sort false

# 🐳 Legacy Docker completions (OMZ plugin compat)
zstyle ':omz:plugins:docker' legacy-completion yes

# 🎨 FZF tab preview config
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-preview 'ps aux | grep -v grep | grep -i $word'
zstyle ':fzf-tab:complete:kill:argument-rest' fzf-flags '--preview-window=down:3:wrap'
zstyle ':fzf-tab:complete:kill:*' fzf-preview '[[ $group == "[process ID]" ]] && ps aux | grep $word'
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff --color=always $word'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always $word'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview 'git show --color=always $word'
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

# 🔧 Kill command completions (process list)
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# 📂 CD improvements (parent directory completion, recent dirs)
zstyle ':completion:*:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order 'named-directories' 'path-directories' 'users' 'expand'

# 📋 Man page completions (section numbers)
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.*' insert-sections true

# 🔍 Ignore completion for commands we don't have
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*:*:*:users' ignored-patterns \
    adm amanda apache avahi beaglidx bin cacti canna clamav daemon \
    dbus distcache dovecot fax ftp games gdm gkrellmd gopher \
    hacluster haldaemon halt hsqldb ident junkbust ldap lp mail \
    mailman mailnull mldonkey mysql nagios named netdump news nfsnobody \
    nobody nscd ntp nut nx openvpn operator pcap postfix postgres privoxy \
    pulse pvm quagga radvd rpc rpcuser rpm shutdown squid sshd sync uucp \
    vcsa xfs '_*'

# 🎯 Hostname completion from known hosts
# Disabled: can cause hangs on servers with large known_hosts files
# zstyle ':completion:*:hosts' hosts \
#     ${${${${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//,/ }//\]:[0-9]*/ }

# 🔒 Enable bracketed paste mode for safer pasting
# This prevents pasted text from being executed immediately
# Note: Bracketed paste is enabled automatically in modern ZSH
if (( ${+options[bracketed_paste]} )); then
    setopt BRACKETED_PASTE
fi
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic
# NOTE: url-quote-magic disabled - causes severe per-character typing lag
# autoload -Uz url-quote-magic
# zle -N self-insert url-quote-magic


# ==============================================================================
# ZINIT (ZI) Plugin Manager Setup
# ==============================================================================

ZINIT_HOME="${XDG_DATA_HOME}/zinit/zinit.git"
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"
    autoload -Uz _zinit; (( ${+_comps} )) && _comps[zinit]=_zinit
fi

# Initialize ZSH completion system before any plugins that depend on it (e.g. fzf-tab)
autoload -Uz compinit; compinit

# ==============================================================================
# THEMING
# ==============================================================================

# ⚡ Powerlevel10k - Fast, customizable prompt with instant-prompt support
# Shows git status, command duration, exit codes, and more
# Configure: run `p10k configure` to customize appearance
# Disable configuration wizard on servers and non-interactive sessions
zi ice depth'1'
zi light romkatv/powerlevel10k

# ==============================================================================
# COMPLETION / INTERACTIVE ENHANCEMENTS
# ==============================================================================

# 🎨 Syntax Highlighting - DISABLED (re-enable after PATH optimization)
# The issue: syntax highlighting checks EVERY keystroke against 48 PATH entries
# Once typing is fast, you can re-enable with the lighter plugin
if [[ "${HOST_LOCATION}" == "desktop" && -z "${SSH_TTY:-}" ]]; then
    zi ice lucid wait'2' depth'1'  # Increased wait time
    zi light zsh-users/zsh-syntax-highlighting  # Lighter alternative
fi
# if [[ "${HOST_LOCATION}" == "desktop" && -z "${SSH_TTY:-}" ]]; then
#     zi ice lucid wait'1' depth'1'
#     zi light zdharma-continuum/fast-syntax-highlighting
# fi

# 💡 FZF - Fuzzy finder for files, commands, history
# Usage: Ctrl+T (files), Ctrl+R (history), Alt+C (directories)
# Integrates with many other plugins for fuzzy search everywhere
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
zi ice lucid wait'0' depth'1' atclone'./install --bin' atpull'%atclone' \
    atload'add_to_path_if_exists "${XDG_DATA_HOME}/zinit/plugins/junegunn---fzf/bin"'
zi light junegunn/fzf

# 🧠 FZF keybindings (Ctrl+T, Alt+C, Ctrl+R)
# NOTE: Lazy load to improve startup time
zi ice lucid wait'1' atload'source_if_exists "${XDG_DATA_HOME}/zinit/plugins/junegunn---fzf/shell/key-bindings.zsh"'
zi snippet /dev/null

# 📂 FZF-Tab - Replaces tab completion with FZF interface
# Usage: Press TAB for fuzzy-searchable completion menu with previews
zi ice lucid wait'1' depth'1'
zi light Aloxaf/fzf-tab

# 🔍 FZF-Tab-Source - Provides additional completion sources for fzf-tab
# Enhances fzf-tab with better context-aware completions
zi ice lucid wait'1' depth'1' branch'main'
zi light Freed-Wu/fzf-tab-source

# 🔄 ZSH Autosuggestions - Fish-like command suggestions from history
# Usage: Type command, press → (right arrow) to accept suggestion
# Shows grayed-out suggestion based on command history as you type
zi ice lucid depth'1'
zi light zsh-users/zsh-autosuggestions

# 🔁 ZSH Completions - Additional completion definitions for 1000+ commands
# Provides tab completions for commands not covered by default ZSH
zi ice depth'1'
zi light zsh-users/zsh-completions

# 🫵 You-Should-Use - Reminds you of existing aliases when you use full commands
# Usage: Automatic - alerts you "Found alias gst for git status" when you type long commands
# Helps you learn and use your aliases to save typing
zi ice wait'2' lucid depth'1'
zi light MichaelAquilina/zsh-you-should-use

# 🧙‍♂️ JQ ZSH Plugin - Interactive jq query builder
# Usage: Type JSON command | (press Alt+J) - opens interactive jq builder
# Helps construct complex jq queries visually
zi ice wait'2' lucid depth'1'
zi light reegnz/jq-zsh-plugin

# 🔥 Fancy Completions - Enhanced completions for modern CLI tools
# Provides smart completions for gh (GitHub CLI), docker, kubectl, etc.
zi ice lucid depth'1' branch'main'
zi light z-shell/zsh-fancy-completions

# ==============================================================================
# NAVIGATION & FILE MANAGEMENT TOOLS
# ==============================================================================

# 📁 Zoxide - Fast, smart directory jumper based on frequency
# Usage: `z <pattern>` - jump to most-frequent matching directory
_ZO_FZF_OPTS="--bind=ctrl-z:ignore --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview='eza -la {2..}'"
zi ice lucid wait'1' as"command" from"gh-r" \
    atclone"./zoxide init zsh --cmd z > init.zsh" \
    atpull"%atclone" src"init.zsh" nocompile'!'
zi load ajeetdsouza/zoxide

# 📁 BD - Quickly go back to a parent directory by name
# Usage: `bd src` - jump back to /home/user/projects/src from deep subdirectory
# Example: In /home/user/projects/src/components/ui → `bd projects` → /home/user/projects
zi ice wait'2' lucid as'program' pick'bd' mv'bd -> bd'
zi light vigneshwaranr/bd

# 📁 Rename - Perl-based batch file renamer with regex support
# Usage: `rename 's/\.txt$/.md/' *.txt` - rename all .txt files to .md
zi ice wait'2' lucid as'program' pick'rename' mv'rename -> rename'
zi light ap/rename

# 📊 Eza - Modern ls replacement with colors, icons, and git integration
# Usage: Already aliased to `ls`, `l`, `la`, `ll`, `tree`
# Shows file permissions, size, git status, and uses colors automatically
zi ice lucid from'gh-r' as'program' sbin'**/eza -> eza' \
    atclone'cp -vf completions/eza.zsh _eza' nocompile'!'
zi load eza-community/eza

# 🌲 Erdtree - Modern file-tree visualization with disk usage
# Usage: `erdtree` or `et` - shows directory tree with file sizes
# Alternative to `tree` and `ncdu` with better visuals
zi ice wait'2' lucid from'gh-r' as'command' nocompile'!'
zi load solidiquis/erdtree

zi ice wait'2' lucid from'gh-r' as'program' pick'*/dua' nocompile'!'
zi load Byron/dua-cli

# Note: zshmarks removed - use zoxide for directory jumping (z <pattern>)

# ==============================================================================
# SEARCH / DEV TOOLS
# ==============================================================================

# 🔎 Ripgrep - Lightning-fast recursive grep with smart defaults
# Usage: `rg "pattern"` - searches files recursively, respects .gitignore
# Auto-pipes through less with `rg()` function in aliases.zsh
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/.ripgreprc"
zi ice wait'2' lucid from'gh-r' as'command' pick='*/rg' nocompile'!'
zi load BurntSushi/ripgrep

# 🦇 Bat - Cat clone with syntax highlighting and git integration
# Usage: Already aliased to `cat` - shows line numbers and syntax colors
# Original cat available as `rcat`
export BAT_THEME="OneHalfDark"
zi ice wait'2' lucid from'gh-r' as'command' mv"bat* -> bat" pick"bat/bat" nocompile'!'
zi load sharkdp/bat

# 🔍 FD - Simple, fast alternative to `find`
# Usage: `fd pattern` - finds files by name, faster than find
# `fd -e js` - find by extension, `fd -t d` - find directories only
zi ice wait'2' lucid from'gh-r' as'command' mv"fd* -> fd" pick"fd/fd" nocompile'!'
zi load sharkdp/fd

# 🧼 SD - Intuitive find & replace CLI (better than sed)
# Usage: `sd before after file.txt` - simpler syntax than sed
# `sd '\d+' '[$0]' file.txt` - regex with capture groups
zi ice wait'2' lucid from'gh-r' as'command' nocompile'!'
zi load chmln/sd

# 🧠 JQ - Command-line JSON processor
# Usage: `echo '{"key":"value"}' | jq .key` - extract JSON fields
# Works with jq-zsh-plugin for interactive query building (Alt+J)
zi ice wait'2' lucid as'program' from'gh-r' mv'jq* -> jq' nocompile'!'
zi load jqlang/jq

# 💥 UP - Interactive pipe builder for shell commands
# Usage: `up` - opens visual editor to build/test pipelines interactively
# Helps construct complex command pipelines with live preview
zi ice wait'2' lucid from'gh-r' as'command' nocompile'!'
zi load akavel/up

# 📊 QSV - Ultra-fast CSV toolkit with Python integration
# Usage: `qsv stats data.csv` - advanced CSV statistics and operations
# More features than xsv: SQL queries, Python expressions, etc.
zi ice wait'2' lucid from'gh-r' as'program' pick'qsv' nocompile'!'
zi load dathere/qsv

zi ice wait'2' lucid from'gh-r' as'program' pick'*/yazi' nocompile'!'
zi load sxyazi/yazi

# ==============================================================================
# ADDITIONAL MODERN CLI TOOLS
# ==============================================================================

# 🔍 GitHub CLI - Essential for git-heavy workflow
zi ice wait'2' lucid from'gh-r' as'command' pick='*/bin/gh' nocompile'!'
zi load cli/cli

# 🧠 Atuin - Magical shell history with sync, stats, and better search
# Usage: Ctrl+R for powerful history search, `atuin stats` for analytics
# Stores full context (directory, duration, exit code) and syncs across machines
zi ice as"command" from"gh-r" bpick"atuin-x86_64-unknown-linux-gnu.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin init zsh > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" src"init.zsh"
zi light atuinsh/atuin

# 📊 Bottom - Modern system monitor
zi ice wait'2' lucid from'gh-r' as'command' pick='*/btm' nocompile='!'
zi load ClementTsang/bottom

# 🔥 Tokei - Fast code statistics
zi ice wait'2' lucid from'gh' as'program' pick'target/release/tokei' \
    atclone'cargo build --release --locked' atpull'%atclone'
zi light XAMPPRocky/tokei

# ⚡ Hyperfine - Command benchmarking
zi ice wait'2' lucid from'gh-r' as'command' pick='*/hyperfine' nocompile='!'
zi load sharkdp/hyperfine

# 🧼 Dust - Fast Rust-based alternative to du
zi ice wait'2' lucid from'gh-r' as'command' pick='*/dust' nocompile='!'
zi load bootandy/dust

# 🎨 Delta - Better git diffs with syntax highlighting
zi ice wait'0' lucid from'gh-r' as'command' pick='*/delta' nocompile='!'
zi load dandavison/delta

# 📁 Duf - Modern df alternative
zi ice wait'2' lucid from'gh-r' as'command' pick='*/duf' nocompile='!'
zi load muesli/duf

# 🐶 Doggo - Modern dig alternative with better output
zi ice wait'2' lucid from'gh-r' as'command' pick='doggo' nocompile='!'
zi load mr-karan/doggo

# 🦎 Lazygit - TUI for git
zi ice wait'2' lucid from'gh-r' as'command' pick='lazygit' nocompile='!'
zi load jesseduffield/lazygit

# 🐳 Lazydocker - TUI for docker
zi ice wait'2' lucid from'gh-r' as'command' pick='lazydocker' nocompile='!'
zi load jesseduffield/lazydocker

# 🔧 Procs - Modern ps alternative
zi ice wait'2' lucid from'gh-r' as'command' pick='procs' nocompile='!'
zi load dalance/procs

# ==============================================================================
# GIT ENHANCEMENTS
# ==============================================================================

# 🧠 Forgit - Interactive git operations with FZF
# Usage: `git log` aliased to `gl` - interactive commit browser
# `gd` - interactive diff, `ga` - interactive add, `glo` - interactive log
export forgit_log=gl
export FORGIT_DIFF_GIT_OPTS="-w --ignore-blank-lines"
zi ice lucid wait'0' depth'1' branch'main'
zi light wfxr/forgit

# 🌐 Git-Open - Open current repo in browser (GitHub/GitLab/Bitbucket)
# Usage: `git open` - opens repo URL in browser
# `git open --issue` - opens issues page
zi ice wait'2' lucid depth'1'
zi light paulirish/git-open

# 🛠️ Git-Extras - Collection of 60+ git utilities
# Usage: `git summary` - repo summary, `git effort` - show file activity
# `git changelog` - generate changelog, `git ignore` - add to .gitignore
# Full list: https://github.com/tj/git-extras/blob/master/Commands.md
zi ice wait'2' lucid depth'1' as'program' pick'$ZPFX/bin/git-*' make'PREFIX=$ZPFX' nocompile
zi light tj/git-extras

# ==============================================================================
# NODE & LANGUAGE ENVIRONMENTS
# ==============================================================================

# 🎨 Laravel Artisan Completion - Smart completions for Laravel Artisan
# Usage: `php artisan <TAB>` - shows available artisan commands
# Works with Docker alias `pa` as well
zi ice wait'2' lucid depth'1'
zi light jessarcher/zsh-artisan

# # 🎼 Composer Completion - Tab completion for Composer commands
# # Usage: `composer <TAB>` - shows composer commands and package names
# zi ice wait'2' lucid depth'1' as'completion'
# zi snippet https://github.com/composer/composer/blob/main/res/composer-completion.zsh

# ==============================================================================
# OMZ SNIPPETS (Useful one-liners from Oh-My-Zsh)
# ==============================================================================

zi ice wait'1' lucid blockf
zi snippet OMZP::sudo             # Usage: Press ESC twice to prefix previous command with sudo
zi snippet OMZP::copyfile         # Usage: `copyfile file.txt` - copies file contents to clipboard
zi snippet OMZP::dirhistory       # Usage: Alt+Left/Right arrows to navigate directory history

#=======================================================================================
# Autocompletion
#=======================================================================================

# 🔁 Completion system handled by ZINIT
autoload -Uz colors && colors

#Calculator: zcalc
autoload -Uz zcalc

# 📦 Enable zmv for wildcard-based file renaming (e.g., zmv '*.txt' 'prefix_#1.txt')
autoload -Uz zmv

# ==============================================================================
# Custom Application Settings
# ==============================================================================

# Auto-start Docker on WSL if not running (skip on SSH sessions)
if [[ "${HOST_OS}" == "wsl" && -z "${SSH_TTY:-}" ]] && (( $+commands[systemctl] )); then
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        # Start Docker without password prompt (requires sudoers NOPASSWD for systemctl)
        sudo -n systemctl start docker 2>/dev/null && echo "✓ Docker started" || true
    fi
fi

# 🗂️ broot (directory visualizer)
source_if_exists "${XDG_CONFIG_HOME}/broot/launcher/bash/br"

# 🎨 Powerlevel10k theme config
source_if_exists "${ZDOTDIR}/.p10k.zsh"

# 🦀 Rust environment variables
# NOTE: Removed - already handled by add_to_path_if_exists "${CARGO_HOME}/bin" at line 113
# source_if_exists "${CARGO_HOME}/env"

# ⚡️ Envman – environment loader
# NOTE: Commented out - envman not installed
# source_if_exists "${XDG_CONFIG_HOME}/envman/load.sh"

# 🧅 Bun – Fast JavaScript runtime and package manager
source_if_exists "${BUN_INSTALL}/_bun"

# 🐱 Kitty terminal config + completions
if (( $+commands[kitty] )); then
    export KITTY_CONFIG_DIRECTORY="${XDG_CONFIG_HOME}/kitty"
    
    # Cache kitty completion (regenerate only when kitty binary changes)
    typeset kitty_comp="${ZSH_CACHE_DIR}/kitty_completion.zsh"
    if [[ ! -f "${kitty_comp}" ]] || [[ "${commands[kitty]}" -nt "${kitty_comp}" ]]; then
        kitty + complete setup zsh >| "${kitty_comp}"
    fi
    source "${kitty_comp}"
fi

# 🧬 direnv – per-project environment management
# if (( $+commands[direnv] )); then
#  eval "$(direnv hook zsh)"
# fi

# Note: Most tool completions are now provided automatically via zinit or tool packages
# If you need manual completions for doctl, rustup, bat, fd, or rg, see git history

# VSCode Integration
[[ "${TERM_PROGRAM}" == "vscode" ]] && source "$(code --locate-shell-integration-path zsh)"

#[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# ==============================================================================
# mise - version manager for Node.js
# ==============================================================================
if (( $+commands[mise] )); then
    eval "$(mise activate zsh)"
fi

# ==============================================================================
# WSL Windows Terminal sync (manual function)
# ==============================================================================
if [[ "${HOST_OS}" == 'wsl' ]]; then
    function sync_wt_settings() {
        local PWSH_EXE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"

        if [[ -x "${PWSH_EXE}" ]]; then
            local WINDOWS_USER=$("${PWSH_EXE}" -NoProfile -Command '$env:UserName' | tr -d '\r')
            local DOTFILES_DIR="${HOME}/.dotfiles"
            local TERMINAL_SETTINGS_DEST="/mnt/c/Users/${WINDOWS_USER}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
            local TERMINAL_SETTINGS_SRC="${DOTFILES_DIR}/windows-terminal/settings.json"

            if [[ -f "${TERMINAL_SETTINGS_DEST}" && -f "${TERMINAL_SETTINGS_SRC}" ]]; then
                if [[ "${TERMINAL_SETTINGS_SRC}" -nt "${TERMINAL_SETTINGS_DEST}" ]]; then
                    cp "${TERMINAL_SETTINGS_DEST}" "${TERMINAL_SETTINGS_DEST}.bak.$(date +%s)"
                    cp "${TERMINAL_SETTINGS_SRC}" "${TERMINAL_SETTINGS_DEST}"
                    echo "✓ Synced Windows Terminal settings from dotfiles"
                else
                    cp "${TERMINAL_SETTINGS_DEST}" "${TERMINAL_SETTINGS_SRC}"
                    echo "✓ Synced dotfiles Windows Terminal settings from Windows"
                fi
            else
                echo "✗ Could not find settings files"
            fi
        else
            echo "✗ PowerShell not found at ${PWSH_EXE}"
        fi
    }
    
    alias update-wt-settings='sync_wt_settings'

    function sync_ssh_config() {
        local PWSH_EXE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"

        if [[ -x "${PWSH_EXE}" ]]; then
            local WINDOWS_USER=$("${PWSH_EXE}" -NoProfile -Command '$env:UserName' | tr -d '\r')
            local DOTFILES_DIR="${HOME}/.dotfiles"
            local SSH_CONFIG_DEST="/mnt/c/Users/${WINDOWS_USER}/.ssh/config"
            local SSH_CONFIG_SRC="${DOTFILES_DIR}/.ssh/config"

            if [[ -f "${SSH_CONFIG_DEST}" ]]; then
                # Create .ssh directory in dotfiles if it doesn't exist
                mkdir -p "${DOTFILES_DIR}/.ssh"

                if [[ -f "${SSH_CONFIG_SRC}" ]]; then
                    # Both files exist - compare timestamps
                    if [[ "${SSH_CONFIG_SRC}" -nt "${SSH_CONFIG_DEST}" ]]; then
                        cp "${SSH_CONFIG_DEST}" "${SSH_CONFIG_DEST}.bak.$(date +%s)"
                        cp "${SSH_CONFIG_SRC}" "${SSH_CONFIG_DEST}"
                        echo "✓ Synced SSH config from dotfiles to Windows"
                    else
                        cp "${SSH_CONFIG_SRC}" "${SSH_CONFIG_SRC}.bak.$(date +%s)"
                        cp "${SSH_CONFIG_DEST}" "${SSH_CONFIG_SRC}"
                        echo "✓ Synced SSH config from Windows to dotfiles"
                    fi
                else
                    # Only Windows file exists - copy to dotfiles
                    cp "${SSH_CONFIG_DEST}" "${SSH_CONFIG_SRC}"
                    echo "✓ Copied SSH config from Windows to dotfiles"
                fi
            else
                echo "✗ Could not find SSH config at ${SSH_CONFIG_DEST}"
            fi
        else
            echo "✗ PowerShell not found at ${PWSH_EXE}"
        fi
    }

    alias update-ssh-config='sync_ssh_config'

    function sync_wslconfig() {
        # Sync /etc/wsl.conf (per-distribution settings)
        local DOTFILES_DIR="${HOME}/.dotfiles"
        local WSLCONF_DEST="/etc/wsl.conf"
        local WSLCONF_SRC="${DOTFILES_DIR}/wsl.conf"

        if [[ -f "${WSLCONF_SRC}" ]]; then
            if [[ -f "${WSLCONF_DEST}" ]]; then
                # Both files exist - compare timestamps
                if [[ "${WSLCONF_SRC}" -nt "${WSLCONF_DEST}" ]]; then
                    sudo cp "${WSLCONF_DEST}" "${WSLCONF_DEST}.bak.$(date +%s)" 2>/dev/null || true
                    sudo cp "${WSLCONF_SRC}" "${WSLCONF_DEST}"
                    echo "✓ Synced wsl.conf from dotfiles to /etc/wsl.conf"
                    echo "  Run 'wsl --shutdown' from PowerShell to apply changes"
                else
                    cp "${WSLCONF_SRC}" "${WSLCONF_SRC}.bak.$(date +%s)"
                    sudo cp "${WSLCONF_DEST}" "${WSLCONF_SRC}"
                    sudo chown "$(id -u):$(id -g)" "${WSLCONF_SRC}"
                    echo "✓ Synced wsl.conf from /etc to dotfiles"
                fi
            else
                # No existing /etc/wsl.conf - copy from dotfiles
                sudo cp "${WSLCONF_SRC}" "${WSLCONF_DEST}"
                echo "✓ Installed wsl.conf to /etc/wsl.conf"
                echo "  Run 'wsl --shutdown' from PowerShell to apply changes"
            fi
        else
            echo "✗ wsl.conf not found in dotfiles at ${WSLCONF_SRC}"
        fi
    }

    alias update-wsl-settings='sync_wslconfig'

    function sync_wslconfig_global() {
        # Sync global .wslconfig (VM settings for all distros)
        local PWSH_EXE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"

        if [[ -x "${PWSH_EXE}" ]]; then
            local WINDOWS_USER=$("${PWSH_EXE}" -NoProfile -Command '$env:UserName' | tr -d '\r')
            local DOTFILES_DIR="${HOME}/.dotfiles"
            local WSLCONFIG_DEST="/mnt/c/Users/${WINDOWS_USER}/.wslconfig"
            local WSLCONFIG_SRC="${DOTFILES_DIR}/.wslconfig"

            if [[ -f "${WSLCONFIG_DEST}" ]]; then
                if [[ -f "${WSLCONFIG_SRC}" ]]; then
                    # Both files exist - compare timestamps
                    if [[ "${WSLCONFIG_SRC}" -nt "${WSLCONFIG_DEST}" ]]; then
                        cp "${WSLCONFIG_DEST}" "${WSLCONFIG_DEST}.bak.$(date +%s)"
                        cp "${WSLCONFIG_SRC}" "${WSLCONFIG_DEST}"
                        echo "✓ Synced .wslconfig from dotfiles to Windows"
                        echo "  Run 'wsl --shutdown' to apply changes"
                    else
                        cp "${WSLCONFIG_SRC}" "${WSLCONFIG_SRC}.bak.$(date +%s)"
                        cp "${WSLCONFIG_DEST}" "${WSLCONFIG_SRC}"
                        echo "✓ Synced .wslconfig from Windows to dotfiles"
                    fi
                else
                    # Only Windows file exists - copy to dotfiles
                    cp "${WSLCONFIG_DEST}" "${WSLCONFIG_SRC}"
                    echo "✓ Copied .wslconfig from Windows to dotfiles"
                fi
            else
                echo "✗ Could not find .wslconfig at ${WSLCONFIG_DEST}"
            fi
        else
            echo "✗ PowerShell not found at ${PWSH_EXE}"
        fi
    }

    alias update-wsl-global-settings='sync_wslconfig_global'

    function sync_all_wsl_settings() {
        # Force sync all WSL-related settings from dotfiles to system
        echo "=== Syncing WSL settings from dotfiles ==="

        local DOTFILES_DIR="${HOME}/.dotfiles"
        local PWSH_EXE="/mnt/c/Program Files/PowerShell/7/pwsh.exe"
        local updated=0

        # 1. Sync wsl.conf (per-distribution settings)
        local WSLCONF_DEST="/etc/wsl.conf"
        local WSLCONF_SRC="${DOTFILES_DIR}/wsl.conf"

        if [[ -f "${WSLCONF_SRC}" ]]; then
            if [[ -f "${WSLCONF_DEST}" ]]; then
                sudo cp "${WSLCONF_DEST}" "${WSLCONF_DEST}.bak.$(date +%s)"
            fi
            sudo cp "${WSLCONF_SRC}" "${WSLCONF_DEST}"
            echo "✓ wsl.conf → /etc/wsl.conf"
            ((updated++))
        else
            echo "✗ wsl.conf not found in dotfiles"
        fi

        # 2. Sync .wslconfig (global VM settings)
        if [[ -x "${PWSH_EXE}" ]]; then
            local WINDOWS_USER=$("${PWSH_EXE}" -NoProfile -Command '$env:UserName' | tr -d '\r')
            local WSLCONFIG_DEST="/mnt/c/Users/${WINDOWS_USER}/.wslconfig"
            local WSLCONFIG_SRC="${DOTFILES_DIR}/.wslconfig"

            if [[ -f "${WSLCONFIG_SRC}" ]]; then
                if [[ -f "${WSLCONFIG_DEST}" ]]; then
                    cp "${WSLCONFIG_DEST}" "${WSLCONFIG_DEST}.bak.$(date +%s)"
                fi
                cp "${WSLCONFIG_SRC}" "${WSLCONFIG_DEST}"
                echo "✓ .wslconfig → C:\Users\${WINDOWS_USER}\.wslconfig"
                ((updated++))
            else
                echo "✗ .wslconfig not found in dotfiles"
            fi
        else
            echo "✗ PowerShell not found, skipping .wslconfig"
        fi

        # 3. Sync Windows Terminal settings
        if [[ -x "${PWSH_EXE}" ]]; then
            local WINDOWS_USER=$("${PWSH_EXE}" -NoProfile -Command '$env:UserName' | tr -d '\r')
            local WT_DEST="/mnt/c/Users/${WINDOWS_USER}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
            local WT_SRC="${DOTFILES_DIR}/windows-terminal/settings.json"

            if [[ -f "${WT_SRC}" ]]; then
                if [[ -f "${WT_DEST}" ]]; then
                    cp "${WT_DEST}" "${WT_DEST}.bak.$(date +%s)"
                    cp "${WT_SRC}" "${WT_DEST}"
                    echo "✓ windows-terminal/settings.json → Windows Terminal"
                    ((updated++))
                else
                    echo "⚠ Windows Terminal settings.json not found at destination (install Windows Terminal first)"
                fi
            else
                echo "✗ windows-terminal/settings.json not found in dotfiles"
            fi
        fi

        echo ""
        echo "Synced ${updated} config(s). Run 'wsl --shutdown' from PowerShell to apply WSL changes."
    }

    alias update-all-wsl='sync_all_wsl_settings'
fi
#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
source_if_exists "${ZDOTDIR}/aliases.zsh"
source_if_exists "${ZDOTDIR}/hooks.zsh"

# Compile configuration files for faster loading
function compile_if_needed() {
    local source_file="${1}"
    [[ ! -f "${source_file}" ]] && return
    [[ "${source_file}" -nt "${source_file}.zwc" ]] && zcompile "${source_file}"
}

compile_if_needed "${ZDOTDIR}/.zshenv"
compile_if_needed "${ZDOTDIR}/.zshrc"
compile_if_needed "${ZDOTDIR}/aliases.zsh"
compile_if_needed "${ZDOTDIR}/hooks.zsh"
compile_if_needed "${ZDOTDIR}/.p10k.zsh"
compile_if_needed "${ZDOTDIR}/local.zsh"

# If zsh is really slow, enable profiling via zprof, uncomment the line above and line 2
# zprof
