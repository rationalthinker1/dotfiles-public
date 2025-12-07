#!/usr/bin/env zsh
# zmodload zsh/zprof # top of your .zshrc file - uncomment to profile startup time

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

# 📁 XDG base directories
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# 🧠 Shell and runtime config
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH="${ZDOTDIR}"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"

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

# 🧠 OpenAI API Key (don't commit this, bro)
export OPENAI_API_KEY="OPENAI_API_KEY_REMOVED"

# 📜 Make less not clear the terminal after exit
export LESS="-XRF"

# ☁️ AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/.aws/credentials"

# ==============================================================================
# Update PATH
# ==============================================================================

# Add only if directory exists & not already in $PATH
add_to_path_if_exists() {
  # Fast path: check directory existence first (fail fast for non-existent dirs)
  [[ -d "$1" ]] || return 1

  # Only check PATH if directory exists (avoid expensive string ops on failures)
  case ":${PATH}:" in
    *":$1:"*) return 0 ;;  # Already in PATH
    *) export PATH="$1:${PATH}" ;;  # Add to PATH
  esac
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
    # causing issues with vscode terminal, and everytime you open a new terminal, it would lauch dbus everytime
    #if [[ "$HOST_OS" == "wsl" && -n "$DISPLAY" && -z "$DBUS_SESSION_BUS_ADDRESS" && ! -f "/tmp/dbus-session-started"  ]]; then
    #   echo "Starting D-Bus session..."
    #   eval "$(dbus-launch --sh-syntax)"
    #   touch /tmp/dbus-session-started
    #fi
    export LIBGL_ALWAYS_INDIRECT=1
    export WSL_VERSION=$(wsl.exe -l -v | awk '/[*]/{print $NF}')
    export IP_ADDRESS=$(ip route list default | awk '{print $3}')
    export DISPLAY="${IP_ADDRESS}:0"
    export BROWSER="wslview"

    keep_current_path() {
        printf "\e]9;9;%s\e\\" "$(wslpath -w "${PWD}")"
    }
    precmd_functions+=(keep_current_path)

  if [ -n "$WT_SESSION" ]; then
    printf "\033]9;9;%s\033\\" "$(pwd)"
  fi
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

# ⚡ Powerlevel10k instant prompt (should be near top of .zshrc)
# Use source_if_exists for consistency:
source_if_exists "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

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
setopt SHARE_HISTORY              # Share history across multiple sessions
setopt LONG_LIST_JOBS             # Show PID in jobs list
setopt NOTIFY                     # Report background job status immediately
setopt NO_HUP                     # Don't kill background jobs on shell exit
setopt NO_CHECK_JOBS              # Don't warn about running jobs when exiting
setopt NUMERIC_GLOB_SORT          # Sort globs numerically (file1, file2, file10 instead of file1, file10, file2)

# 🧠 History behavior
setopt BANG_HIST                  # !foo expands to last "foo" command
setopt EXTENDED_HISTORY           # Save timestamp + duration in history
setopt INC_APPEND_HISTORY         # Append history instantly, not just on exit
setopt APPEND_HISTORY             # Don't overwrite, just append
setopt HIST_IGNORE_SPACE          # Don't save commands starting with space
setopt HIST_REDUCE_BLANKS         # Collapse multiple spaces
setopt HIST_EXPIRE_DUPS_FIRST     # Expire old dupes before new entries
setopt HIST_FIND_NO_DUPS          # Don’t show duplicate results when searching
setopt HIST_IGNORE_DUPS           # Don’t record if it’s the same as last
setopt HIST_IGNORE_ALL_DUPS       # Remove all previous dups when adding new one
setopt HIST_SAVE_NO_DUPS          # Never save duplicates to history file

#=======================================================================================
# Setting up home/end keys for keyboard
# https://unix.stackexchange.com/questions/20298/home-key-not-working-in-terminal
#=======================================================================================
# Vi mode
bindkey -v

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

# 🔁 Auto-source `.dirrc` when entering a directory
load-local-conf() {
  source_if_exists .dirrc
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

# ⚡ Powerlevel10k - fast, beautiful prompt
zi ice depth'1'
zi light romkatv/powerlevel10k

# ==============================================================================
# COMPLETION / INTERACTIVE ENHANCEMENTS
# ==============================================================================

# 🎨 syntax-highlighting - colorizes commands as you type
zi ice lucid depth'1'
zi light zdharma-continuum/fast-syntax-highlighting

# 💡 fzf - fuzzy finder core
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
zi ice depth'1' atclone'./install --bin' atpull'%atclone'
zi light junegunn/fzf
# Force correct fzf in PATH before anything else
add_to_path_if_exists "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins/junegunn---fzf/bin"

# 📂 fzf-tab - tab-completion UI using fzf
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
zi ice lucid wait'1' depth'1'
zi light Aloxaf/fzf-tab

# 🔍 fzf-tab-source - smarter matching in fzf-tab
zi ice lucid wait'1' depth'1' branch'main'
zi light Freed-Wu/fzf-tab-source

# 🔁 fzf-history-search - interactive Ctrl+R command history
zi ice lucid wait'1' depth'1'
zi light joshskidmore/zsh-fzf-history-search

# 🔄 zsh-autosuggestions - command suggestions while typing
zi ice lucid depth'1'
zi light zsh-users/zsh-autosuggestions

# 🔁 zsh-completions - extra completion scripts
zi ice depth'1'
zi light zsh-users/zsh-completions

# 🧠 atuin - shell history syncing, Ctrl+R replacement (optional)
zi ice lucid wait'2' depth'1' branch'main'
zi light atuinsh/atuin

# 🫵 you-should-use - reminds you of aliases you forgot you had
zi ice wait'!0' lucid depth'1'
zi light MichaelAquilina/zsh-you-should-use

# ⌨️ zsh-autopair - auto-closes quotes, brackets, etc.
zi ice lucid depth'1'
zi light hlissner/zsh-autopair

# 🧙‍♂️ jq-zsh-plugin - type command, hit Alt+J to interactively craft a jq query
zi ice wait'!0' lucid depth'1'
zi light reegnz/jq-zsh-plugin

# 🔥 fancy completions for modern tools (like GitHub CLI)
zi ice wait'!0' lucid depth'1' branch'main'
zi light z-shell/zsh-fancy-completions

# 💻 ssh alias manager
zi ice wait'!0' lucid depth'1' from'gh'
zi light sunlei/zsh-ssh

# ==============================================================================
# NAVIGATION & FILE MANAGEMENT TOOLS
# ==============================================================================

# 📁 enhancd - better `cd` command with history and fuzzy matching
export ENHANCD_DISABLE_DOT=1
export ENHANCD_FILTER="fzf"
export ENHANCD_COMMAND="ccd"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export ENHANCD_DIR_PATH_STYLE="full"
export ENHANCD_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/enhancd"
export ENHANCD_DIVE_MAX=10
zi ice lucid wait'2' depth'1' src'init.sh' branch'main'
zi light babarot/enhancd

# 📁 bd - go back to a parent dir by name (e.g. `bd src`)
zi ice wait'!0' as'program' pick'bd' mv'bd -> bd'
zi load vigneshwaranr/bd

# 📁 rename - CLI mass renamer
zi ice wait'!0' as'program' pick'rename' mv'rename -> rename'
zi load ap/rename

# 📊 eza - better ls alternative
zi ice lucid depth'1' from'gh-r' as'program' sbin'**/eza -> eza' atclone'cp -vf completions/eza.zsh _eza' bpick'eza_x86_64-unknown-linux-gnu.tar.gz'
zi light eza-community/eza

# 🌲 erdtree - directory tree with size info (like `ncdu` but pretty)
zi ice wait'!0' lucid depth'1' from'gh-r' as'command'
zi light solidiquis/erdtree

# ==============================================================================
# SEARCH / DEV TOOLS
# ==============================================================================

# 🔎 ripgrep (aka `rg`) - super fast grep
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/.ripgreprc"
zi ice from'gh-r' as'command' pick='*/rg'
zi load BurntSushi/ripgrep

# 🦇 bat - better `cat`, with syntax highlighting
export BAT_THEME="OneHalfDark"
zi ice from'gh-r' as'command' mv"bat* -> bat" pick"bat/bat"
zi load sharkdp/bat

# 🔍 fd - better `find`
zi ice from'gh-r' as'command' mv"fd* -> fd" pick"fd/fd"
zi load sharkdp/fd

# 🔬 xsv - analyze & manipulate CSVs from terminal
zi ice wait'!0' lucid depth'1' from'gh' as'command' atclone'"${CARGO_HOME}/bin/cargo" build --release' pick'target/release/xsv' atpull'%atclone'
zi light BurntSushi/xsv

# 📊 csvtool - pandas-powered CSV explorer in CLI
zi ice wait'!0' as'program' pick'csvtool/csvtool.py' \
  atclone'python3 -m venv venv && venv/bin/pip install pandas openpyxl' \
  atpull'%atclone' \
  cmd'./venv/bin/python csvtool "$@"'
zi load maroofi/csvtool

# 🧼 sd - simpler, modern `sed` replacement (e.g. `sd foo bar`)
zi ice wait'!0' from'gh-r' as'command' pick'gnu'
zi light chmln/sd

# 🧠 jq - CLI JSON processor
zi ice as'program' from'gh-r' bpick'*linux64' mv'jq* -> jq'
zi load jqlang/jq

# 💥 up - run `up` and it'll guess what command you wanted to run
zi ice wait'!0' lucid depth'1' from'gh-r' as'command'
zi light akavel/up

# 📷 imcat - display images in terminal (kitty/iterm support)
zi ice wait'!0' lucid depth'1' from'gh' as'command' make pick'imcat'
zi light stolk/imcat

# 📊 qsv - fast CSV command line toolkit written in Rust
zi ice wait'!0' lucid depth'1' as'program' pick'target/release/qsv' atclone'cargo build --release --locked --bin qsv --features "feature_capable,python,apply,foreach"' atpull'%atclone'
zi light dathere/qsv

# ==============================================================================
# GIT ENHANCEMENTS
# ==============================================================================

# 🧠 forgit - interactively view logs, diffs, branches, etc.
export forgit_log=gl
export FORGIT_DIFF_GIT_OPTS="-w --ignore-blank-lines"
zi ice lucid wait'1' depth'1' branch'main'
zi light wfxr/forgit

# 🌐 git-open - opens GitHub/GitLab/Bitbucket page for current repo
zi ice wait'!0' lucid depth'1'
zi light paulirish/git-open

# ==============================================================================
# NODE & LANGUAGE ENVIRONMENTS
# ==============================================================================

# 🌱 Fast Node Manager - automagic Node.js version switching
export ZSH_FNM_NODE_VERSION="22"
export ZSH_FNM_ENV_EXTRA_ARGS="--use-on-cd"
export ZSH_FNM_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fnm"
zi ice lucid wait'1' depth'1'
zi light dominik-schwabe/zsh-fnm

# ==============================================================================
# OMZ SNIPPETS (one-liners from Oh-My-Zsh)
# ==============================================================================

zi ice wait lucid blockf
zi snippet OMZP::sudo             # Hit ESC twice to sudo previous command
zi snippet OMZP::extract          # Adds `extract` to unzip anything
zi snippet OMZP::copyfile         # Copy file contents to clipboard
zi snippet OMZP::dirhistory       # Alt+arrows to jump dirs
zi snippet OMZP::docker-compose   # Completions for `docker-compose`

#=======================================================================================
# Autocompletion
#=======================================================================================

# 🔁 Initialize completion system with cache (safe for zshenv)
# if [[ -n "$ZSH_CACHE_DIR" ]]; then
#   mkdir -p "$ZSH_CACHE_DIR"
#   autoload -Uz compinit
#   compinit -i -d "$ZSH_CACHE_DIR/zcompdump-${HOST_OS:-default}"
# else
#   autoload -Uz compinit
#   compinit -i
# fi
# Trigger compinit safely (delayed)
# autoload -Uz compinit
# compinit -C
autoload -Uz colors && colors

#Calculator: zcalc
autoload -U zcalc

# 📦 Enable zmv for wildcard-based file renaming (e.g., zmv '*.txt' 'prefix_#1.txt')
autoload -Uz zmv

# ==============================================================================
# Custom Application Settings
# ==============================================================================

if [[ "$HOST_OS" == "wsl" ]] && command -v systemctl >/dev/null; then
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
if command -v kitty &> /dev/null; then
  export KITTY_CONFIG_DIRECTORY="${XDG_CONFIG_HOME}/kitty"
  kitty + complete setup zsh | source /dev/stdin
fi

# 🧬 direnv – per-project environment management
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# ☁️ doctl – DigitalOcean CLI completion
if command -v doctl &> /dev/null; then
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
