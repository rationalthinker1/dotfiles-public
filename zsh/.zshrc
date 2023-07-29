#!/usr/bin/env bash
#zmodload zsh/zprof # top of your .zshrc file

#=======================================================================================
# Loading up variables
#=======================================================================================
if [[ -f "/proc/sys/kernel/osrelease" ]] && [[ "$(< /proc/sys/kernel/osrelease)" == *microsoft* ]]; then
	HOST_OS="wsl"
elif [[ "$OSTYPE" == "darwin"* ]]; then
	HOST_OS="darwin"
else
	HOST_OS="linux"
fi

dpkg -l ubuntu-desktop > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
	LOCATION="desktop"
else
	LOCATION="server"
fi

export HOST_OS="${HOST_OS}"
export LOCAL_CONFIG="${HOME}/.config"
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${LOCAL_CONFIG}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}/oh-my-zsh"
export ENHANCD_DIR="${LOCAL_CONFIG}/enhancd"
export NVM_DIR="${LOCAL_CONFIG}/.nvm"
export TERM=xterm-256color
export EDITOR=vim
# allows commands like cat to stay in teminal after using it
export LESS="-XRF"

if [ -f "${LOCAL_CONFIG}"/zsh/local.zsh ]; then
	source "${LOCAL_CONFIG}"/zsh/local.zsh
fi

if [ -f "${LOCAL_CONFIG}"/zsh/.zprofile ]; then
	source "${LOCAL_CONFIG}"/zsh/.zprofile
fi

if [ -f "${HOME}"/.zprofile ]; then
	source "${HOME}"/.zprofile
fi

if [ -f "${HOME}"/.bash_local ]; then
	source "${HOME}"/.bash_local
fi

if [ -d "${HOME}/.local/bin" ] ; then
	export PATH="${HOME}/.local/bin:$PATH"
fi

if [ -d "/usr/local/go/bin" ] ; then
	export PATH="/usr/local/go/bin:$PATH"
fi

#=======================================================================================
# Basic Settings
#=======================================================================================
# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef

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
# ZINIT
#=======================================================================================
# https://wiki.zshell.dev/docs/getting_started/installation
if [ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]; then
	source "/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export RIPGREP_CONFIG_PATH="${LOCAL_CONFIG}/ripgrep/.ripgreprc"

typeset -Ag ZI
typeset -gx ZI[HOME_DIR]="${LOCAL_CONFIG}/zi" ZI[BIN_DIR]="${ZI[HOME_DIR]}/bin"
command mkdir -p "$ZI[BIN_DIR]"
source <(curl -sLk init.zshell.dev); zzinit

zi pack for fzf
zi ice depth=1;  zi light romkatv/powerlevel10k
zi ice wait'!0'; zi light zsh-users/zsh-autosuggestions
zi ice wait'!0'; zi light zsh-users/zsh-completions
zi ice wait'!0' atinit'export forgit_log=gl'; zi light wfxr/forgit
zi ice wait'!0'; zi light zdharma-continuum/fast-syntax-highlighting
zi ice wait'!0' from'gh-r' as'command'; zi light akavel/up
zi ice wait'!0' from'gh-r' as'command'; zi light ogham/exa
zi ice wait'!0' atinit'export ENHANCD_DISABLE_DOT=1'; zi light b4b4r07/enhancd
zi ice wait'!0' from'gh-r' as'command' mv"bat* -> bat" pick"bat/bat" atinit'export BAT_THEME="OneHalfDark"'; zi light sharkdp/bat
zi ice wait'!0' from'gh-r' as'command' mv"fd* -> fd" pick"fd/fd"; zi light sharkdp/fd
zi ice wait'!0' from'gh' as'command'; zi light stedolan/jq
zi ice wait'!0' from'gh' as'command'; zi light sunlei/zsh-ssh
zi ice wait'!0' from'gh-r' as'command' pick='*/rg'; zi light BurntSushi/ripgrep
zi ice wait'!0' from'gh-r' as'command'; zi light solidiquis/erdtree
zi ice wait'!0'; zi light z-shell/zsh-fancy-completions
#zi ice wait'!0' atinit'export ZSH_THEME="bubblified"'; zi light hohmannr/bubblified
zi ice wait'!0' from'gh' as'command' make pick"imcat"; zi light stolk/imcat

# type out a command that you expect to produce json on it's standard output
# press alt + j and interactively write a jq expression
# press enter, and the jq expression is appended to your initial command!
zi ice wait'!0'; zi light reegnz/jq-zsh-plugin

# A simple plugin that auto-closes, deletes and skips over matching delimiters
zi ice wait'!0'; zi light hlissner/zsh-autopair
zi ice wait'!0'; zi snippet OMZP::gitfast
zi ice wait'!0'; zi snippet OMZP::docker
zi ice wait'!0'; zi snippet OMZP::docker-compose

# press ESC twice to sudo previous command
zi ice wait'!0'; zi snippet OMZP::sudo

# adds a 'extract' function to unzip zip/rar/7z/tar.gz etc...
zi ice wait'!0'; zi snippet OMZP::extract

#copies the contents of a file in your system clipboard by using command 'copyfile <filename>'
zi ice wait'!0'; zi snippet OMZP::copyfile

# alt+left -> Go to previous directory
# alt+right -> Go to next directory
# alt+up -> Go to parent directory
# alt+down -> Go to first child directory by alphabetical order
zi ice wait'!0'; zi snippet OMZP::dirhistory

zi ice wait'!0'; zi light zsh-users/zsh-completions

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
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}  # 補完時の色
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:default' menu select=2  # 選択中の候補をハイライト
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'$DEFAULT
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*' use-cache true
zstyle ':completion:*' rehash true
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

[[ -f "${HOME}/.local/share/broot/launcher/bash/1" ]] && source "${HOME}/.local/share/broot/launcher/bash/1"

[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh

[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh

if  [ -x "$(command -v kitty)" ]; then
	export KITTY_CONFIG_DIRECTORY="${HOME}/.config/kitty"
	kitty + complete setup zsh | source /dev/stdin
fi

if  [ -x "$(command -v direnv)" ]; then
	eval "$(direnv hook zsh)"
fi

if  [ -x "$(command -v doctl)" ]; then
	source <(doctl completion zsh)
	compdef _doctl doctl
fi

# Source a file in zsh when entering a directory
# https://stackoverflow.com/questions/17051123/source-a-file-in-zsh-when-entering-a-directory
load-local-conf() {
     # check file exists, is regular file and is readable:
     if [[ -f .dirrc && -r .dirrc ]]; then
       source .dirrc
     fi
}
chpwd_functions+=( load-local-conf )

# WSL?
if [[ "${HOST_OS}" == *wsl* ]]; then
    export $(dbus-launch)
    export LIBGL_ALWAYS_INDIRECT=1
    export WSL_VERSION=$(wsl.exe -l -v | grep -a '[*]' | sed 's/[^0-9]*//g')
    export IP_ADDRESS=$(tail -1 /etc/resolv.conf | cut -d' ' -f2)
    export DISPLAY=$IP_ADDRESS:0
    export PATH=$PATH:$HOME/.local/bin
	export BROWSER="/mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe"
fi

if [[ "${HOST_OS}" == *darwin* ]]; then
	# sets environment variables on MacOS
	launchctl setenv HOST_OS darwin
fi

#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
if [ -f "${LOCAL_CONFIG}"/zsh/aliases.zsh ]; then
	source "${LOCAL_CONFIG}"/zsh/aliases.zsh
fi
