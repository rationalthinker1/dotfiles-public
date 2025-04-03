#!/usr/bin/env zsh
# zmodload zsh/zprof # top of your .zshrc file

#=======================================================================================
# Detect Host OS
#=======================================================================================
case "$OSTYPE" in
  linux-gnu*)
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
      HOST_OS="wsl"
    else
      HOST_OS="linux"
    fi
    ;;
  darwin*)  HOST_OS="macos" ;;
  cygwin* | msys*) HOST_OS="windows" ;;
  *)        HOST_OS="unknown" ;;
esac

# Determine if running on Desktop or Server
if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
  HOST_LOCATION="desktop"
else
  HOST_LOCATION="server"
fi

# Export Key Environment Variables
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:=${HOME}/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:=${HOME}/.local/share}"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH="${ZDOTDIR}"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"
export HOST_OS="${HOST_OS}"
export HOST_LOCATION="${HOST_LOCATION}"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"
export ADOTDIR="${ZDOTDIR}/antigen"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export NVM_DIR="${XDG_CONFIG_HOME}/.nvm"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export VOLTA_HOME="${XDG_CONFIG_HOME}/volta"
export TERM="xterm-256color"
export EDITOR="vim"
export CODENAME=$(lsb_release -cs 2>/dev/null)
export OPENAI_API_KEY="OPENAI_API_KEY_REMOVED"
# allows commands like cat to stay in teminal after using it
export LESS="-XRF"

# Update PATH
[[ -d "${CARGO_HOME}/bin" ]] && [[ ":$PATH:" != *":${CARGO_HOME}/bin:"* ]] && export PATH="${CARGO_HOME}/bin:$PATH"
[[ -d "${HOME}/.local/bin" ]] && [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:$PATH"
[[ -d "/usr/local/go/bin" ]] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]] && export PATH="/usr/local/go/bin:$PATH"
[[ -d "${HOME}/.yarn/bin" ]] && [[ ":$PATH:" != *":${HOME}/.yarn/bin:"* ]] && export PATH="${HOME}/.yarn/bin:$PATH"
[[ -d "${HOME}/.config/yarn/global/node_modules/.bin" ]] && [[ ":$PATH:" != *":${HOME}/.config/yarn/global/node_modules/.bin:"* ]] && export PATH="${HOME}/.config/yarn/global/node_modules/.bin:$PATH"

[[ -f "${ZDOTDIR}/local.zsh" ]] && source "${ZDOTDIR}/local.zsh"
[[ -f "${HOME}/local.zsh" ]] && source "${HOME}/local.zsh"
[[ -f "${ZDOTDIR}/.zprofile" ]] && source "${ZDOTDIR}/.zprofile"
[[ -f "${HOME}/.zprofile" ]] && source "${HOME}/.zprofile"
[[ -f "${ZDOTDIR}/.bash_local" ]] && source "${ZDOTDIR}/.bash_local"
[[ -f "${HOME}/.bash_local" ]] && source "${HOME}/.bash_local"
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
    export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${PATH}"
fi

#=======================================================================================
# Shell Settings
#=======================================================================================
# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
if [[ -t 0 ]]; then
  # Fix for Vim Ctrl+Q issue
  stty start undef
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# History in cache directory
HISTSIZE=10000000				# bash history will save N commands
SAVEHIST="${HISTSIZE}"
HISTFILESIZE="${HISTSIZE}"		# bash will remember N commands
HISTFILE="${ZDOTDIR}"/.zsh_history
HISTCONTROL=ignoreboth     # ingore duplicates and spaces
HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'
#https://github.com/ohmyzsh/ohmyzsh/issues/5108
WORDCHARS=''

# reference: http://zsh.sourceforge.net/Doc/Release/Options.html
setopt CORRECT                    # try to correct command line spelling
setopt AUTO_CD                    # use cd by typing directory name if it's not a command
setopt PUSHD_IGNORE_DUPS
# unsetopt MENU_COMPLETE            # do not autoselect the first completion entry
# unsetopt FLOWCONTROL
setopt AUTO_MENU                  # show completion menu on succesive tab press
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt EXTENDED_GLOB
setopt AUTO_LIST                  # automatically list choices on ambiguous completion
setopt AUTO_PUSHD                 # make cd push the old directory onto the directory stack
setopt INTERACTIVE_COMMENTS       # comments even in interactive shells
setopt MULTIOS                    # implicit tees or cats when multiple redirections are attempted
setopt NO_BEEP                    # don't beep on error
setopt PROMPT_SUBST               # substitution of parameters inside the prompt each time the prompt is drawn
setopt PUSHD_IGNORE_DUPS          # don't push multiple copies directory onto the directory stack
setopt PUSHD_MINUS                # swap the meaning of cd +1 and cd -1 to the opposite

setopt BANG_HIST                  # treat the '!' character, especially during expansion
setopt HIST_REDUCE_BLANKS         # remove superfluous blanks from history items
setopt HIST_IGNORE_SPACE          # remove command lines from the history list when the first character on the line is a space
setopt SHARE_HISTORY              # import new commands from the history file also in other zsh-session
setopt HIST_EXPIRE_DUPS_FIRST     # expire duplicate entries first when trimming history
setopt HIST_FIND_NO_DUPS          # remove older duplicate entries from history
setopt HIST_IGNORE_DUPS           # don't record an entry that was just recorded again
setopt HIST_IGNORE_ALL_DUPS       # if a new command line being added to the history list duplicates an older one, the older command is removed from the list
setopt HIST_SAVE_NO_DUPS          # do not write a duplicate event to the history file
setopt APPEND_HISTORY             # allow multiple sessions to append to one zsh command history
setopt EXTENDED_HISTORY           # save each command's beginning timestamp and the duration to the history file
setopt INC_APPEND_HISTORY         # write to the history file immediately, not when the shell exits


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


#=======================================================================================
# Autocompletion
#=======================================================================================
# Basic auto/tab complete:
# enable completion
# autoload -Uz compinit
# if [[ -n $ZSH_CACHE_DIR ]]; then
#   compinit -d "$ZSH_CACHE_DIR/zcompdump-${HOST_OS}-${HOST_LOCATION}"
# else
#   compinit
# fi
autoload -Uz colors && colors

#Calculator: zcalc
autoload -U zcalc

#=======================================================================================
# ZSH Settings
#=======================================================================================
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:match:*' original only
zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*' use-cache true
zstyle ':completion:*' rehash true
zstyle ':completion:*' menu select interactive


# https://ali.anari.io/posts/zinit/
zstyle ':completion:*:git-checkout:*' sort false
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

# https://github.com/ohmyzsh/ohmyzsh/issues/11817
zstyle ':omz:plugins:docker' legacy-completion yes

# Escape ? so you don't have to put \? or in quotes everytime
set zle_bracketed_paste
autoload -Uz bracketed-paste-magic url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
zle -N self-insert url-quote-magic

# Source a file in zsh when entering a directory
# https://stackoverflow.com/questions/17051123/source-a-file-in-zsh-when-entering-a-directory
load-local-conf() {
	# check file exists, is regular file and is readable:
	if [[ -f .dirrc && -r .dirrc ]]; then
		source .dirrc
	fi
}
chpwd_functions+=( load-local-conf )

# If you duplicate a tab in WSL, it will open a new tab with the same directory
if [[ "${HOST_OS}" == "wsl" ]]; then
	keep_current_path() {
	printf "\e]9;9;%s\e\\" "$(wslpath -w "$PWD")"
	}
	precmd_functions+=(keep_current_path)
fi

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

# 💡 fzf - fuzzy finder core
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
zi ice depth'1'
zi light junegunn/fzf
# Force correct fzf in PATH before anything else
export PATH="$HOME/.local/share/zinit/plugins/junegunn---fzf/bin:$PATH"

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
zi ice depth'1'
zi light zsh-users/zsh-autosuggestions

# 🔁 zsh-completions - extra completion scripts
zi ice depth'1'
zi light zsh-users/zsh-completions

# 🎨 syntax-highlighting - colorizes commands as you type
zi ice depth'1'
zi light zdharma-continuum/fast-syntax-highlighting

# 🧠 atuin - shell history syncing, Ctrl+R replacement (optional)
zi ice lucid wait'2' depth'1' branch'main'
zi light atuinsh/atuin

# 🫵 you-should-use - reminds you of aliases you forgot you had
zi ice lucid wait'2' depth'1'
zi light MichaelAquilina/zsh-you-should-use

# ⌨️ zsh-autopair - auto-closes quotes, brackets, etc.
zi ice lucid wait'2' depth'1'
zi light hlissner/zsh-autopair

# 🧙‍♂️ jq-zsh-plugin - type command, hit Alt+J to interactively craft a jq query
zi ice lucid wait'2' depth'1'
zi light reegnz/jq-zsh-plugin

# 🔥 fancy completions for modern tools (like GitHub CLI)
zi ice lucid wait'3' depth'1' branch'main'
zi light z-shell/zsh-fancy-completions

# 💻 ssh alias manager
zi ice lucid wait'2' depth'1' from'gh'
zi light sunlei/zsh-ssh

# ==============================================================================
# NAVIGATION & FILE MANAGEMENT TOOLS
# ==============================================================================

# 📁 enhancd - better `cd` command with history and fuzzy matching
export ENHANCD_DISABLE_DOT=1
export ENHANCD_FILTER="fzf"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export ENHANCD_DIR_PATH_STYLE="full"
export ENHANCD_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/enhancd"
export ENHANCD_DIVE_MAX=10
zi ice lucid wait'2' depth'1' src'init.sh' branch'main'
zi light babarot/enhancd

# 📁 bd - go back to a parent dir by name (e.g. `bd src`)
zi ice as'program' pick'bd' mv'bd -> bd'
zi load vigneshwaranr/bd

# 📁 rename - CLI mass renamer
zi ice as'program' pick'rename' mv'rename -> rename'
zi load ap/rename

# 📊 eza - better ls alternative
zi ice lucid wait'0' depth'1' from'gh-r' as'program' sbin'**/eza -> eza' atclone'cp -vf completions/eza.zsh _eza' bpick'eza_x86_64-unknown-linux-gnu.tar.gz'
zi light eza-community/eza

# 🌲 erdtree - directory tree with size info (like `ncdu` but pretty)
zi ice lucid wait'3' depth'1' from'gh-r' as'command'
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
zi ice lucid wait'3' depth'1' from'gh' as'command' atclone'"${CARGO_HOME}/bin/cargo" build --release' pick'target/release/xsv'
zi light BurntSushi/xsv

# 📊 csvtool - pandas-powered CSV explorer in CLI
zi ice as'program' pick'csvtool/csvtool.py' \
  atclone'python3 -m venv venv && venv/bin/pip install pandas openpyxl' \
  atpull'%atclone' \
  cmd'./venv/bin/python csvtool "$@"'
zi load maroofi/csvtool

# 🧼 sd - simpler, modern `sed` replacement (e.g. `sd foo bar`)
zi ice from'gh-r' as'command' pick'gnu'
zi light chmln/sd

# 🧠 jq - CLI JSON processor
zi ice as'program' from'gh-r' bpick'*linux64' mv'jq* -> jq'
zi load jqlang/jq

# 💥 up - run `up` and it'll guess what command you wanted to run
zi ice lucid wait'3' depth'1' from'gh-r' as'command'
zi light akavel/up

# 📷 imcat - display images in terminal (kitty/iterm support)
zi ice lucid wait'2' depth'1' from'gh' as'command' make pick"imcat"
zi light stolk/imcat

# ==============================================================================
# GIT ENHANCEMENTS
# ==============================================================================

# 🧠 forgit - interactively view logs, diffs, branches, etc.
export forgit_log=gl
export FORGIT_DIFF_GIT_OPTS="-w --ignore-blank-lines"
zi ice lucid wait'1' depth'1' branch'main'
zi light wfxr/forgit

# 🌐 git-open - opens GitHub/GitLab/Bitbucket page for current repo
zi ice lucid wait'2' depth'1'
zi light paulirish/git-open

# ==============================================================================
# NODE & LANGUAGE ENVIRONMENTS
# ==============================================================================

# 🌱 Fast Node Manager - automagic Node.js version switching
zi ice lucid wait'1' depth'1' atinit'ZSH_FNM_NODE_VERSION="20"'
zi light dominik-schwabe/zsh-fnm

# ==============================================================================
# OMZ SNIPPETS (one-liners from Oh-My-Zsh)
# ==============================================================================

zi snippet OMZP::sudo             # Hit ESC twice to sudo previous command
zi snippet OMZP::extract          # Adds `extract` to unzip anything
zi snippet OMZP::copyfile         # Copy file contents to clipboard
zi snippet OMZP::dirhistory       # Alt+arrows to jump dirs
zi snippet OMZP::docker-compose   # Completions for `docker-compose`

#=======================================================================================
# Custom Application Settings
#=======================================================================================
[[ -f "${XDG_CONFIG_HOME}/broot/launcher/bash/br" ]] && source "${XDG_CONFIG_HOME}/broot/launcher/bash/br"

[[ -f "${ZDOTDIR}/.p10k.zsh" ]] && source "${ZDOTDIR}/.p10k.zsh"

[[ -f "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"

[[ -f "${XDG_CONFIG_HOME}/fzf/fzf.zsh" ]] && source "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
# Load fzf keybindings (Ctrl+T, Alt+C, Ctrl+R)
if [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins/junegunn---fzf/shell/key-bindings.zsh" ]]; then
  source "${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins/junegunn---fzf/shell/key-bindings.zsh"
fi

[[ -f "${XDG_CONFIG_HOME}/envman/load.sh" ]] && source "${XDG_CONFIG_HOME}/envman/load.sh"

if  [ -x "$(command -v kitty)" ]; then
	export KITTY_CONFIG_DIRECTORY="${XDG_CONFIG_HOME}/kitty"
	kitty + complete setup zsh | source /dev/stdin
fi

if  [ -x "$(command -v direnv)" ]; then
	eval "$(direnv hook zsh)"
fi

if  [ -x "$(command -v doctl)" ]; then
	source <(doctl completion zsh)
	compdef _doctl doctl
fi

#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
[[ -f "${ZDOTDIR}/aliases.zsh" ]] && source "${ZDOTDIR}/aliases.zsh"
[[ -f "${HOME}/aliases.zsh" ]] && source "${HOME}/aliases.zsh"


#[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# At the *end* of .zshrc
# Recompile if source is newer
if [[ -n "${(%):-%N}" && -r "${(%):-%N}" ]]; then
  if [[ "${(%):-%N}" -nt "${(%):-%N}.zwc" ]]; then
    echo "Recompiling ${(%):-%N}..."
    zcompile "${(%):-%N}"
  fi
fi

# If zsh is really show, enable profiling via zprof, uncomment the line below and the first line
# zprof
