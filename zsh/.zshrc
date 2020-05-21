#zmodload zsh/zprof # top of your .zshrc file

#=======================================================================================
# Loading up variables
#=======================================================================================
export LOCAL_CONFIG="${HOME}/.config"
export ZDOTDIR="${LOCAL_CONFIG}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}/oh-my-zsh"
export ENHANCD_DIR="${LOCAL_CONFIG}/enhancd"
export NVM_DIR="${LOCAL_CONFIG}/.nvm"
export ZPLUG_HOME="${ZDOTDIR}"/.zplug

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

#=======================================================================================
# Basic Settings
#=======================================================================================
# History in cache directory:
HISTSIZE=20000             # bash history will save N commands
HISTFILE="${ZDOTDIR}"/.zsh_history
HISTFILESIZE="${HISTSIZE}" # bash will remember N commands
HISTCONTROL=ignoreboth     # ingore duplicates and spaces
HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'

# Basic auto/tab complete:
autoload -Uz compinit
compinit
# reference: http://zsh.sourceforge.net/Doc/Release/Options.html
setopt CORRECT                    # Try to correct command line spelling
setopt AUTO_CD
setopt PUSHD_IGNORE_DUPS
unsetopt MENU_COMPLETE            # DO NOT AUTOSELECT THE FIRST COMPLETION ENTRY
unsetopt FLOWCONTROL
setopt AUTO_MENU                  # SHOW COMPLETION MENU ON SUCCESIVE TAB PRESs
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY         # append history list to the history file (important for multiple parallel zsh sessions!)
setopt SHARE_HISTORY              # import new commands from the history file also in other zsh-session
setopt EXTENDED_HISTORY           # save each command's beginning timestamp and the duration to the history file
setopt HIST_IGNORE_ALL_DUPS       # If a new command line being added to the history list duplicates an older one, the older command is removed from the list
setopt HIST_IGNORE_SPACE          # remove command lines from the history list when the first character on the line is a space
setopt EXTENDED_GLOB

#=======================================================================================
# Antigen
#=======================================================================================
source "${ZPLUG_HOME}/init.zsh"

zplug "zsh-users/zsh-history-substring-search"
zplug "plugins/git",   from:oh-my-zsh
zplug "plugins/fzf",   from:oh-my-zsh
zplug "plugins/extract",   from:oh-my-zsh
zplug "plugins/command-not-found",   from:oh-my-zsh
zplug "zdharma/fast-syntax-highlighting", defer:2
zplug "zsh-users/zsh-autosuggestions"
zplug "zsh-users/zsh-completions"
zplug "zsh-users/zsh-history-substring-search"
zplug "hlissner/zsh-autopair"
zplug "b4b4r07/enhancd", at:v1

zplug "romkatv/powerlevel10k", as:theme, depth:1

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi
zplug load

[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#=======================================================================================
# Setting up home/end keys for keyboard
# https://unix.stackexchange.com/questions/20298/home-key-not-working-in-terminal
#=======================================================================================
bindkey '\e[1~'   beginning-of-line  # Linux console
bindkey '\e[H'    beginning-of-line  # xterm
bindkey '\eOH'    beginning-of-line  # gnome-terminal
bindkey '\e[2~'   overwrite-mode     # Linux console, xterm, gnome-terminal
bindkey '\e[3~'   delete-char        # Linux console, xterm, gnome-terminal
bindkey '\e[4~'   end-of-line        # Linux console
bindkey '\e[F'    end-of-line        # xterm
bindkey '\eOF'    end-of-line        # gnome-terminal


#=======================================================================================
# Basic Settings
#=======================================================================================
# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef


#=======================================================================================
# Load plugins functions
#=======================================================================================
# Load fzf
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh

export ENHANCD_DISABLE_DOT=1
# Enhancd Installation
if [ -f "${LOCAL_CONFIG}/enhancd/init.sh" ]; then
	source "${LOCAL_CONFIG}"/enhancd/init.sh
fi

export RIPGREP_CONFIG_PATH="${LOCAL_CONFIG}/ripgrep/.ripgreprc"


#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
if [ -f "${LOCAL_CONFIG}"/zsh/aliases.zsh ]; then
	source "${LOCAL_CONFIG}"/zsh/aliases.zsh
fi

# Load tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
	exec tmux -f "${LOCAL_CONFIG}"/tmux/tmux.conf
fi

