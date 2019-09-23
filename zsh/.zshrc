#export TERM="xterm-256color"
export LOCAL_CONFIG="/home/${USER}/.config"
export ZDOTDIR="${LOCAL_CONFIG}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}/oh-my-zsh"

#=======================================================================================
# Basic Settings
#=======================================================================================
export HISTSIZE=2000              # bash history will save N commands
export HISTFILESIZE="${HISTSIZE}" # bash will remember N commands
export HISTCONTROL=ignoreboth     # ingore duplicates and spaces
export HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'
setopt HIST_IGNORE_SPACE
setopt AUTO_CD
setopt PUSHD_IGNORE_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
unsetopt MENU_COMPLETE            # DO NOT AUTOSELECT THE FIRST COMPLETION ENTRY
unsetopt FLOWCONTROL
setopt AUTO_MENU                  # SHOW COMPLETION MENU ON SUCCESIVE TAB PRESs
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt HIST_REDUCE_BLANKS
export VISUAL=vim

#=======================================================================================
# Antigen
#=======================================================================================
source "${ZDOTDIR}/antigen.zsh"
export TERM="xterm-256color"
# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle docker
antigen bundle docker-compose
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

# Load the theme.
antigen theme romkatv/powerlevel10k
#antigen theme https://github.com/caiogondim/bullet-train-oh-my-zsh-theme bullet-train
#antigen theme bhilburn/powerlevel9k powerlevel9k

# Tell antigen that you're done.
antigen apply

autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
bashcompinit -i

# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef
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

# Load fzf
[ -f "${LOCAL_CONFIG}"/fzf/.fzf.zsh ] && source "${LOCAL_CONFIG}"/fzf/.fzf.zsh
# load powerlevel10k settings
[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh

# Load tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
	exec tmux -f "${LOCAL_CONFIG}"/tmux/tmux.conf
fi

