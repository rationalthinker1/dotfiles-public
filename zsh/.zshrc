# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#=======================================================================================
# Loading up zprofiles
#=======================================================================================
export TERMINAL="gnome-terminal"
export LOCAL_CONFIG="${HOME}/.config"
export ZDOTDIR="${LOCAL_CONFIG}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}/oh-my-zsh"
export ENHANCD_DIR="${LOCAL_CONFIG}/enhancd"

export RIPGREP_CONFIG_PATH="${LOCAL_CONFIG}/ripgrep/.ripgreprc"
# Custom setting for commands
export ENHANCD_DISABLE_DOT=1
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen}'"
export FZF_CTRL_T_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen}'"

if [ -f "${LOCAL_CONFIG}"/zsh/.zprofile ]; then
    source "${LOCAL_CONFIG}"/zsh/.zprofile
fi

if [ -f "${HOME}"/.zprofile ]; then
    source "${HOME}"/.zprofile
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
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

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

# Vi mode
#set -o vi
bindkey -v
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line                   # Opens Vim to edit current command line

# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef


#=======================================================================================
# Antigen
#=======================================================================================
source "${ZDOTDIR}/antigen.zsh"
export TERM="xterm-256color"
# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Load the theme.
antigen theme romkatv/powerlevel10k
#antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
#antigen theme bhilburn/powerlevel9k powerlevel9k

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle fzf
antigen bundle jump
#antigen bundle agkozak/zsh-z
antigen bundle command-not-found
#antigen bundle autojump
antigen bundle zpm-zsh/ssh
antigen bundle g-plane/zsh-yarn-autocompletions
antigen bundle thetic/extract
antigen bundle voronkovich/apache2.plugin.zsh
antigen bundle command-not-found
antigen bundle hlissner/zsh-autopair
antigen bundle zdharma/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-history-substring-search
antigen bundle greymd/docker-zsh-completion
#antigen bundle softmoth/zsh-vim-mode
#antigen bundle rupa/z
#antigen bundle changyuheng/fz

# Tell antigen that you're done.
antigen apply


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
# Aliases and functions
#=======================================================================================
if [ -f "${LOCAL_CONFIG}"/zsh/aliases.zsh ]; then
    source "${LOCAL_CONFIG}"/zsh/aliases.zsh
fi

#=======================================================================================
# Local Aliases and functions
#=======================================================================================
if [ -f "${LOCAL_CONFIG}"/zsh/local.zsh ]; then
    source "${LOCAL_CONFIG}"/zsh/local.zsh
fi

if [ -f "${HOME}"/.bash_local ]; then
    source "${HOME}"/.bash_local
fi

# load node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Load fzf
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh
# load powerlevel10k settings
[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh

# Load tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
	exec tmux -f "${LOCAL_CONFIG}"/tmux/tmux.conf
fi

### Bashhub.com Installation
if [ -f ~/.bashhub/bashhub.zsh ]; then
    source ~/.bashhub/bashhub.zsh
fi

### Enhancd Installation
if [ -f "${LOCAL_CONFIG}/enhancd/init.sh" ]; then
    source "${LOCAL_CONFIG}"/enhancd/init.sh
fi

