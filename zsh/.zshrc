#zmodload zsh/zprof # top of your .zshrc file
# https://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
stty start undef

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


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
export TERM=xterm-256color

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
# History in cache directory:
HISTSIZE=20000             # bash history will save N commands
SAVEHIST="${HISTSIZE}"
HISTFILESIZE="${HISTSIZE}" # bash will remember N commands
HISTFILE="${ZDOTDIR}"/.zsh_history
HISTCONTROL=ignoreboth     # ingore duplicates and spaces
HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'
#https://github.com/ohmyzsh/ohmyzsh/issues/5108
WORDCHARS=''
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
# Styling
#=======================================================================================
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'$DEFAULT

zstyle ':completion:*:default' menu select=2  # 選択中の候補をハイライト
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}  # 補完時の色

zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'


#=======================================================================================
# Setting up home/end keys for keyboard
# https://unix.stackexchange.com/questions/20298/home-key-not-working-in-terminal
#=======================================================================================
# Vi mode
bindkey -v

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey '^w' backward-kill-word
bindkey '\e[1~'   beginning-of-line  # Linux console
bindkey '\e[H'    beginning-of-line  # xterm
bindkey '\eOH'    beginning-of-line  # gnome-terminal
bindkey '\e[2~'   overwrite-mode     # Linux console, xterm, gnome-terminal
bindkey '\e[3~'   delete-char        # Linux console, xterm, gnome-terminal
bindkey '\e[4~'   end-of-line        # Linux console
bindkey '\e[F'    end-of-line        # xterm
bindkey '\eOF'    end-of-line        # gnome-terminal


#=======================================================================================
# Zplug
#=======================================================================================
source "${ZPLUG_HOME}/init.zsh"
zplug "zplug/zplug", hook-build: "zplug --self-manage"

#zplug "junegunn/fzf-bin", as:command, from:gh-r, rename-to:fzf
zplug "akavel/up", as:command, from:gh-r, use:"*up"
zplug "stedolan/jq", as:command, from:gh-r
zplug "ogham/exa", from:gh-r, as:command, use:\*macos-x86\*, rename-to:exa
zplug "plugins/git",   from:oh-my-zsh
zplug "plugins/fzf",   from:oh-my-zsh
zplug "plugins/extract",   from:oh-my-zsh
zplug "sharkdp/bat", as:command, from:gh-r, rename-to:bat, hook-load:"export BAT_THEME='OneHalfDark'"
zplug "sharkdp/fd", as:command, from:gh-r, rename-to:fd
zplug "BurntSushi/ripgrep", as:command, rename-to:rg
zplug "zsh-users/zsh-history-substring-search"
zplug "plugins/command-not-found",   from:oh-my-zsh
zplug "zdharma/fast-syntax-highlighting", defer:2
zplug "zsh-users/zsh-autosuggestions", depth:1
zplug "zsh-users/zsh-completions", depth:1
zplug "zsh-users/zsh-history-substring-search", depth:1
zplug "b4b4r07/http_code", as:command, use:bin
zplug "b4b4r07/enhancd", use:init.sh, hook-load:"ENHANCD_DISABLE_DOT=1"
zplug "gko/ssh-connect", as:command, use:"ssh-connect.sh", rename-to:"ssh-connect", depth:1
zplug 'romkatv/powerlevel10k', as:theme, depth:1, use:powerlevel10k.zsh-theme
#zplug 'marlonrichert/zsh-autocomplete'
zplug "holman/boom", from:github, use:"completion/zsh", hook-build: "sudo gem install boom"

if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi
zplug load


#=======================================================================================
# Load plugins functions
#=======================================================================================
export FZF_DEFAULT_COMMAND="rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,oh-my-zsh,antigen,snap/*,*.lock}'"
export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"

export RIPGREP_CONFIG_PATH="${LOCAL_CONFIG}/ripgrep/.ripgreprc"

[[ -f "${ZDOTDIR}"/.p10k.zsh ]] && source "${ZDOTDIR}"/.p10k.zsh


#=======================================================================================
# Source aliases and functions
#=======================================================================================
# Load AFTER sourcing other files because some export path may not be defined
if [ -f "${LOCAL_CONFIG}"/zsh/aliases.zsh ]; then
	source "${LOCAL_CONFIG}"/zsh/aliases.zsh
fi

if  [ -x "$(command -v kitty)" ]; then
	export KITTY_CONFIG_DIRECTORY="${HOME}/.config/kitty"
	kitty + complete setup zsh | source /dev/stdin
fi
