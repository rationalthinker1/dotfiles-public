export ZSH="/home/$USER/.config/.oh-my-zsh"
export ZDOTDIR="$ZSH/dump"
source $ZSH/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle heroku
antigen bundle pip
antigen bundle lein
antigen bundle command-not-found
antigen bundle hlissner/zsh-autopair
antigen bundle zdharma/fast-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
#antigen bundle unixorn/autoupdate-antigen.zshplugin

# Load the theme.
antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
BULLETTRAIN_TIME_12HR=true
BULLETTRAIN_CONTEXT_DEFAULT_USER="$USER"
BULLETTRAIN_DIR_EXTENDED=0


# Tell antigen that you're done.
antigen apply


#=======================================================================================
# Basic Settings
#=======================================================================================
export HISTSIZE=2000            # bash history will save N commands
export HISTFILESIZE=${HISTSIZE} # bash will remember N commands
export HISTCONTROL=ignoreboth   # ingore duplicates and spaces
export HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'

# Default editor is set to vim
export VISUAL=vim

#=======================================================================================
# Aliases and functions
#=======================================================================================
if [ -f $HOME/.bash_aliases ]; then
    source $HOME/.bash_aliases
fi

#=======================================================================================
# Local Aliases and functions
#=======================================================================================
if [ -f $HOME/.bash_local ]; then
    source $HOME/.bash_local
fi

# added by Anaconda3 installer
export PATH="/opt/anaconda3/bin:$PATH"

[ -f ~/.config/fzf/.fzf.zsh ] && source ~/.config/fzf/.fzf.zsh

if [[ ! $TERM =~ screen ]]; then
    exec tmux -f ~/.config/tmux/tmux.conf
fi
