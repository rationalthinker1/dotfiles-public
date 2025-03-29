#!/usr/bin/env bash
# zmodload zsh/zprof # top of your .zshrc file

#=======================================================================================
# Detect Host OS
#=======================================================================================
if [[ -f "/proc/sys/kernel/osrelease" ]] && grep -qi microsoft /proc/sys/kernel/osrelease; then
    HOST_OS="wsl"
elif [[ "${OSTYPE}" == "darwin"* ]]; then
    HOST_OS="darwin"
else
    HOST_OS="linux"
fi

# Determine if running on Desktop or Server
dpkg -l ubuntu-desktop > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
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
export ZSH_CACHE_DIR="${ZSH}/cache"
export HOST_OS="${HOST_OS}"
export HOST_LOCATION="${HOST_LOCATION}"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"
export ADOTDIR="${ZDOTDIR}/antigen"
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
[[ -d "${CARGO_HOME}/bin" ]] && export PATH="${CARGO_HOME}/bin:${PATH}"
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"
[[ -d "/usr/local/go/bin" ]] && export PATH="/usr/local/go/bin:${PATH}"
[[ -d "${HOME}/.yarn" ]] && export PATH="${HOME}/.yarn/bin:${HOME}/.config/yarn/global/node_modules/.bin:${PATH}"

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
    export $(dbus-launch)
    export LIBGL_ALWAYS_INDIRECT=1
    export WSL_VERSION=$(wsl.exe -l -v | awk '/[*]/{print $NF}')
    export IP_ADDRESS=$(ip route list default | awk '{print $3}')
    export DISPLAY="${IP_ADDRESS}:0"
    export PATH="${PATH}:${HOME}/.local/bin"
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
stty start undef # Fix for Vim Ctrl+Q issue

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
autoload -Uz compinit && compinit
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

#=======================================================================================
# ZINIT
#=======================================================================================
# https://wiki.zshell.dev/docs/getting_started/installation

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zi ice depth'1'; zi light romkatv/powerlevel10k
zi ice lucid wait'1' depth'1'; zi light Aloxaf/fzf-tab

export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export FZF_ALT_C_COMMAND="fd --type d"
# FZF options for sexy dropdowns
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"

# Preview file contents on Ctrl-T
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"

# Change directories with preview using exa
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# zi ice depth'1'; zi pack"default+keys" for fzf

zinit ice lucid wait'1' depth'1'; zinit light joshskidmore/zsh-fzf-history-search

zi ice lucid wait'4' depth'1'; zi light Freed-Wu/fzf-tab-source

zinit ice depth'1'; zinit light zsh-users/zsh-autosuggestions
zinit ice depth'1'; zinit light zsh-users/zsh-completions

export forgit_log=gl
export FORGIT_DIFF_GIT_OPTS="-w --ignore-blank-lines"
zinit ice lucid wait'1' depth'1'; zi light wfxr/forgit

zinit ice depth'1'; zi light zdharma-continuum/fast-syntax-highlighting

zi ice  lucid wait'3' depth'1' from'gh-r' as'command'; zi light akavel/up

zi ice from'gh-r' as'program' sbin'**/eza -> eza' atclone'cp -vf completions/eza.zsh _eza'
zinit ice depth'1'; zi light eza-community/eza
zinit ice depth'1'; zi light z-shell/zsh-eza

export ENHANCD_DISABLE_DOT=1
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
zinit ice lucid wait'2' depth'1'; zi light babarot/enhancd

export BAT_THEME="OneHalfDark"
zi ice from'gh-r' as'command' mv"bat* -> bat" pick"bat/bat"; zi load sharkdp/bat

zi ice from'gh-r' as'command' mv"fd* -> fd" pick"fd/fd"; zi load sharkdp/fd

zi ice lucid lucid wait'2' depth'1' from'gh' as'command'; zi light sunlei/zsh-ssh

export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/.ripgreprc"
zi ice from'gh-r' as'command' pick='*/rg'; zi load BurntSushi/ripgrep

# xsv is a command line program for indexing, slicing, analyzing, splitting and joining CSV files
zi ice lucid wait'3' depth'1' from'gh' as'command' atclone'"${CARGO_HOME}/bin/cargo" build --release' pick'target/release/xsv'; zi light BurntSushi/xsv

zi ice lucid wait'3' depth'1' from'gh-r' as'command'; zi light solidiquis/erdtree
zinit ice lucid wait'3' depth'1'; zi light z-shell/zsh-fancy-completions
#zi ice atinit'export ZSH_THEME="bubblified"'; zi light hohmannr/bubblified
zi ice lucid wait'2' depth'1' from'gh' as'command' make pick"imcat"; zi light stolk/imcat

# type out a command that you expect to produce json on it's standard output
# press alt + j and interactively write a jq expression
# press enter, and the jq expression is appended to your initial command!
zinit ice lucid wait'2' depth'1'; zi light reegnz/jq-zsh-plugin

# A simple plugin that auto-closes, deletes and skips over matching delimiters
zinit ice lucid wait'2' depth'1'; zi light hlissner/zsh-autopair
# zi snippet OMZP::gitfast
# zi snippet OMZP::docker
zi snippet OMZP::docker-compose

# press ESC twice to sudo previous command
zi snippet OMZP::sudo

# adds a 'extract' function to unzip zip/rar/7z/tar.gz etc...
zi snippet OMZP::extract

#copies the contents of a file in your system clipboard by using command 'copyfile <filename>'
zi snippet OMZP::copyfile

# alt+left -> Go to previous directory
# alt+right -> Go to next directory
# alt+up -> Go to parent directory
# alt+down -> Go to first child directory by alphabetical order
zi snippet OMZP::dirhistory

# sed s/before/after/g -> sd before after;  sd before after file.txt -> sed -i -e 's/before/after/g' file.txt
zi ice from'gh-r' as'command' pick'gnu'; zi light chmln/sd

zi ice as'program' from'gh-r' bpick'*linux64' mv'jq* -> jq'; zi load jqlang/jq

zi ice as'program' pick'csvtool/csvtool.py' \
  atclone'python3 -m venv venv && venv/bin/pip install pandas openpyxl' \
  atpull'%atclone' \
  cmd'./venv/bin/python csvtool "$@"'; zi load maroofi/csvtool

zi ice as'program' pick'bd' mv'bd -> bd'; zi load vigneshwaranr/bd

zi ice as'program' pick'rename' mv'rename -> rename'; zi load ap/rename

# Ctrl+R to search through your history
zinit ice lucid wait'2' depth'1'; zi light atuinsh/atuin

# reminder to use the alias
zinit ice lucid wait'2' depth'1'; zi light MichaelAquilina/zsh-you-should-use

# Type git open and it opens the GitHub/GitLab/etc. page for the current repo/branch in your browser.
zinit ice lucid wait'2' depth'1'; zi light paulirish/git-open

# export NVM_COMPLETION=true
# export NVM_SYMLINK_CURRENT="true"
# zinit wait depth'1' lucid light-mode for lukechilds/zsh-nvm

#=======================================================================================
# Custom Application Settings
#=======================================================================================
[[ -f "{XDG_CONFIG_HOME}/broot/launcher/bash/br" ]] && source "{XDG_CONFIG_HOME}/broot/launcher/bash/br"

[[ -f "${ZDOTDIR}/.p10k.zsh" ]] && source "${ZDOTDIR}/.p10k.zsh"

[[ -f "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"

[[ -f "${XDG_CONFIG_HOME}/fzf/fzf.zsh" ]] && source "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
[[ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]] && source "/usr/share/doc/fzf/examples/key-bindings.zsh"
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


nvm() {
  unset -f nvm
  export NVM_COMPLETION=true
  export NVM_SYMLINK_CURRENT=true
  source "$NVM_DIR/nvm.sh"
  [ -f "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
  nvm "$@"
}

# [ -f "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh" # This loads nvm
# [ -f "${NVM_DIR}/bash_completion" ] && source "${NVM_DIR}/bash_completion" # This loads nvm bash_completion

#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
[[ -f "${ZDOTDIR}/aliases.zsh" ]] && source "${ZDOTDIR}/aliases.zsh"
[[ -f "${HOME}/aliases.zsh" ]] && source "${HOME}/aliases.zsh"


#[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# If zsh is really show, enable profiling via zprof, uncomment the line below and the first line
# zprof