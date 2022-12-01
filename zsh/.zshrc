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

export HOST_OS="${HOST_OS}"
export LOCAL_CONFIG="${HOME}/.config"
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

# Basic auto/tab complete:
autoload -Uz compinit
compinit

#Calculator: zcalc
autoload -U zcalc

# reference: http://zsh.sourceforge.net/Doc/Release/Options.html
setopt CORRECT                    # Try to correct command line spelling
setopt AUTO_CD
setopt PUSHD_IGNORE_DUPS
unsetopt MENU_COMPLETE            # DO NOT AUTOSELECT THE FIRST COMPLETION ENTRY
unsetopt FLOWCONTROL
setopt AUTO_MENU                  # SHOW COMPLETION MENU ON SUCCESIVE TAB PRESs
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt EXTENDED_GLOB

setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE          # remove command lines from the history list when the first character on the line is a space
setopt SHARE_HISTORY              # import new commands from the history file also in other zsh-session
setopt HIST_EXPIRE_DUPS_FIRST     # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS           # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS       # If a new command line being added to the history list duplicates an older one, the older command is removed from the list
setopt EXTENDED_HISTORY           # save each command's beginning timestamp and the duration to the history file
setopt INC_APPEND_HISTORY         # Write to the history file immediately, not when the shell exits.

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


# #=======================================================================================
# # Sheldon
# #=======================================================================================
if [ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]; then
	source "/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,build,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
export RIPGREP_CONFIG_PATH="${LOCAL_CONFIG}/ripgrep/.ripgreprc"
export forgit_log=gl
export BAT_THEME='OneHalfDark'
export ENHANCD_DISABLE_DOT=1
eval "$(sheldon source)"


#=======================================================================================
# ZSH Settings
#=======================================================================================
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}  # 補完時の色
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:default' menu select=2  # 選択中の候補をハイライト
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'$DEFAULT
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'

#https://github.com/marlonrichert/zsh-autocomplete#with-fzf
zstyle ':autocomplete:*' fuzzy-search off
zstyle ':autocomplete:tab:*' completion cycle
zstyle ':autocomplete:list-choices:*' min-input 3



[[ -f "${HOME}/.local/share/broot/launcher/bash/1" ]] && source "${HOME}/.local/share/broot/launcher/bash/1"

[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh

if  [ -x "$(command -v kitty)" ]; then
	export KITTY_CONFIG_DIRECTORY="${HOME}/.config/kitty"
	kitty + complete setup zsh | source /dev/stdin
fi

if  [ -x "$(command -v direnv)" ]; then
	eval "$(direnv hook zsh)"
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
    # pip path if using --user
    export PATH=$PATH:$HOME/.local/bin
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
