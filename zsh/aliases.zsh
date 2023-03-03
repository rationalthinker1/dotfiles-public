#!/usr/bin/env bash

## zshrc Related ##
alias dirzshrc="grep -nT '^#|' $HOME/.zshrc"
alias zshrc="vim $HOME/.zshrc"
alias rebash="source $HOME/.zshrc"

# common directories
alias dot="cd ~/.dotfiles"
alias con="cd ~/.config"

# if bat exists, use it instead of cat
if  [ -x "$(command -v bat)" ]; then
	alias cat="bat"
fi

## if exa exists, use it instead of ls
if  [ -x "$(command -v exa)" ]; then
	## Colorize the ls output ##
	alias ls='exa --color=auto'

	## Use a long listing format ##
	# List with human readable filesizes
	alias l="exa --color=auto --long --header --group --group-directories-first"
	# List all, with human readable filesizes
	alias ll="exa --color=auto --long --header --group --all --group-directories-first"
	# Same as above, but ordered by size
	alias lls="exa --color=auto --long --header --group --all --group-directories-first --sort size"
	# Same as above, but ordered by date
	alias llt="exa --color=auto --long --header --group --all --group-directories-first --reverse --sort oldest"
	# Show tree level 2
	alias lt="exa --color=auto --long --header --group --all --group-directories-first --tree --level=2"
	# Show tree level 3
	alias lt3="exa --color=auto --long --header --group --all --group-directories-first --tree --level=3"
	# Show tree level 4
	alias lt4="exa --color=auto --long --header --group --all --group-directories-first --tree --level=4"
	# Show hidden files ##
	alias l.="exa --color=auto --long --header --group --all --group-directories-first --list-dirs .*"
	# Show only directories
	alias ld="exa --color=auto --long --header --group --all --group-directories-first --only-dirs"
else
	## Colorize the ls output ##
	alias ls='ls --color=auto'

	## Use a long listing format ##
	alias l="ls --color=auto -lh --group-directories-first" # List all, with human readable filesizes
	alias ll="ls --color=auto -lah --group-directories-first" # List all, with human readable filesizes
	alias llt="ls --color=auto -lahFtr --group-directories-first" # Same as above, but ordered by date
	alias lls="ls --color=auto -lahFSr --group-directories-first" # Same as above, but ordered by size

	## Show hidden files ##
	alias l.='ls -d .* --color=auto'
fi

## show history on h
alias h="history"

## get rid of command not found ##
alias cd..='cd ..'

## a quick way to get out of current directory ##
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
alias r='cd /'

## Colorize the grep command output for ease of use (good for log files)##
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Create parent dirs if they don't exist
alias mkdir='mkdir -pv'

# Repeat the previous command with sudo
alias pls='sudo !!'

# Repeat the previous command with sudo
alias sudoi='sudo "PATH=$PATH"'

# Quickly edit this script and load it
alias vpr='vim $HOME/.zshrc && source $HOME/.zshrc'

# sshfs with proper default settings
alias sshfs='sshfs -o allow_other,uid=1000,gid=1000'

# Hiberate
alias hiberate='sudo pm-suspend'

# Show processes by name
# example: psg bash
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'

# Append -c to continue the download in case of problems
#alias wget='wget -c'

# Prints out your public IP
alias myip="curl http://ipecho.net/plain; echo"

# Searches up history commands
alias hgrep="history | grep"

alias br=broot

# use fdfind
alias fd=fdfind

FD_EXCLUDE_PATTERN="{"
FD_EXCLUDE_PATTERN+=.cargo,
FD_EXCLUDE_PATTERN+=node_modules,
FD_EXCLUDE_PATTERN+=.git,
FD_EXCLUDE_PATTERN+=.cache,
FD_EXCLUDE_PATTERN+=cache,
FD_EXCLUDE_PATTERN+=vendor,
FD_EXCLUDE_PATTERN+=tmp,
FD_EXCLUDE_PATTERN+=.npm,
FD_EXCLUDE_PATTERN+=*.bak,
FD_EXCLUDE_PATTERN+=bundles,
FD_EXCLUDE_PATTERN+=build,
FD_EXCLUDE_PATTERN+="}"

# search for files with fdf
function fdf() {
	echo fd --hidden --ignore-case --follow --type f --exclude "$FD_EXCLUDE_PATTERN" $@
	fd --hidden --ignore-case --follow --type f --exclude "$FD_EXCLUDE_PATTERN" $@
}
# search for directories with fdd
function fdd() {
	echo fd --hidden --ignore-case --follow --type d --exclude "$FD_EXCLUDE_PATTERN" $@
	fd --hidden --ignore-case --follow --type d --exclude "$FD_EXCLUDE_PATTERN" $@
}

# pages rg output automatically
function rg() {
    if [ -t 1 ]; then
        command rg -p "$@" | less -RFX
    else
        command rg "$@"
    fi
}

function bak() {
	if [[ "$#" -eq 0 ]]; then
		echo "used to back up file or folder"
		echo "usage: bak test"
		exit 0
	fi
	if [[ $1 == *".bak" ]]; then
		echo "renaming ${1%.bak}.bak to ${1%.bak}"
		mv "${1%.bak}.bak" "${1%.bak}"
	else
		echo "renaming ${1} to ${1}.bak"
		mv "${1}" "${1}.bak"
	fi
}

function ref() {
	if [[ "$#" -eq 0 ]]; then
		cat ~/.config/zsh/reference.zsh
	else
		name="${1}"
		folder="${LOCAL_CONFIG}/zsh/references"
		file="${folder}/${name}.zsh"
		if [[ ! -d $folder ]]; then
			mkdir -p $folder
		fi
		if [[ ! -f $file ]]; then
			touch $file
		fi
		vim $file
	fi
}

#alias ref="cat ~/.config/zsh/reference.zsh"

# look at the size of the sub-directories level 1
# Uncommented and created function below
#alias ds="du -chd 1 | sort -h"

# Ctrl+S doesn't cause terminal to freeze
# https://vim.fandom.com/wiki/Map_Ctrl-S_to_save_current_or_new_files
alias vim="stty stop '' -ixoff ; vim"

# get top biggest files
function fs() {
	LIMIT=${1:-50}
	sudo du --count-links --all --human-readable --exclude /media 2>/dev/null | grep -v -e '^.*K[[:space:]]' | sort -r -n | head "-n${LIMIT}"
}

# get top biggest directories
function ds() {
	LIMIT=${1:-51}
	sudo du --human-readable --max-depth=1 --exclude /media 2>/dev/null | sort -r -h | head "-n$((${LIMIT}+1))"
}
# So that vim shortcuts can work
#alias vim="stty stop '' -ixoff ; vim"

# Search current directory (SCD) in grep recursively
function scd() {
  grep -ir "$@" ./
}

# wgets portion of a line. Default is 10 lines
function wcsv() {
	#wget http://riptide-reflection.s3.amazonaws.com/export_2_.csv -qO - | head -10
	LIMIT=${2:-10}
	wget "$1" -qO - | head "-${LIMIT}"
	#echo "wget $1 -qO - | head -${LIMIT}"
}

# https://github.com/vigneshwaranr/bd
# cd to parent directory matching substring
alias bd=". bd -si"

# takes whatever you have cat previously and vims it
alias v!='fc -e "sed -i -e \"s/cat /vim /\""'

# Extract archives files
function extract() {
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2)   tar xvjf "$1"     ;;
            *.tar.xz)    tar xvJf "$1"     ;;
            *.tar.gz)    tar xvzf "$1"     ;;
            *.bz2)       bunzip2 "$1"      ;;
            *.rar)       unrar x "$1"      ;;
            *.gz)        gunzip "$1"       ;;
            *.tar)       tar xvf "$1"      ;;
            *.tbz2)      tar xvjf "$1"     ;;
            *.tgz)       tar xvzf "$1"     ;;
            *.zip)       unzip "$1"        ;;
            *.Z)         uncompress "$1"   ;;
            *.7z)        7z x "$1"         ;;
            *)           echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file!"
    fi
}

#=======================================================================================
# Installing, updating or removing applications aliases and functions
#=======================================================================================
alias addrepo='sudo add-apt-repository -y'
alias install='sudo apt-get install -y '
alias remove='sudo apt-get remove'
alias update='sudo apt-get update -y'
alias upgrade='sudo apt-get update && sudo apt-get upgrade'

function apt-install() {
	for application in "$@"
	do
		sudo apt-get install -f -y "${application}"
    done
}

function apt-update() {
	sudo apt-get -y update
}

function add-repo() {
	for repository in "$@"
	do
		sudo add-apt-repository -y "${repository}"
    done
}

# simple-install ppa:numix/ppa numix-gtk-theme numix-icon-theme-circle
function simple-install() {
	repository=$1

	# Add the repository
	add-repo "${repository}"
	shift

	# Update list of available packages
	apt-update

	for application in "$@"
	do
		# Install application
		apt-install "${application}"
	done
}

function unzipd() {
	filename="${1}"
	directory="${filename%.zip}"
	directory="${directory##*/}"
	unzip "${filename}" -d "${directory}"
}

function install-font-subdirectories() {
	directory="${1}"
	for subdirectory in $(find $directory -maxdepth 1 -mindepth 1 -type d); do
		install-font-folder "${directory}/${subdirectory}"
	done
}

function install-font-folder() {
	directory="${1}"
	last_folder=$(basename $directory)
	sudo mkdir -p /usr/share/fonts/{true,open}type/"${last_folder}"
	find "${directory}" -type f -name "*.otf" | xargs -I{} sudo cp {} /usr/share/fonts/opentype/"${last_folder}"
	find "${directory}" -type f -name "*.ttf" | xargs -I{} sudo cp {} /usr/share/fonts/truetype/"${last_folder}"
	fc-cache -f -v | grep "${last_folder}"
}

function install-font-zip() {
	filename="${1}"
	directory="${filename%.zip}"
	directory="${directory##*/}"
	unzipd "${filename}"
	install-font-folder "${directory}"
	rm -rf "./${directory}"
}

#=======================================================================================
# Yarn Aliases
#=======================================================================================
alias ya="yarn add $@"
alias yad="yarn add -D $@"

#=======================================================================================
# Git Aliases and functions
#=======================================================================================
function c { git checkout "$@"; }
function b { git branch "$@"; }
alias gcam="git commit -a --amend"
alias gc="git commit -am"
alias gs="git status"
alias gd="git diff --ignore-all-space --ignore-space-at-eol --ignore-space-change --ignore-blank-lines"
#alias dc="git diff --cached"
#alias dv="git diff | vim -"
#alias gl="git log"
alias gp="git pull"
#alias gpu="git push"
alias gpu='[[ -z $(git config "branch.$(git symbolic-ref --short HEAD).merge") ]] && git push -u origin $(git symbolic-ref --short HEAD) || git push'
alias gpuf="git push --force"

git_search() {
	git rev-list --all | GIT_PAGER=cat xargs git grep '"${@}"'
}
alias gse=git_search

git_reset() {
    COMMIT="HEAD"
    if [[ "$#" -eq 1 ]];
    then
        COMMIT="HEAD~$1"
    fi
    git reset --hard "${COMMIT}"
}
alias gre=git_reset

git-clone() {
	git clone "$@" && cd "$(basename "$1" .git)"
}

#=======================================================================================
# Suffix Aliases
#=======================================================================================
alias -s git='git-clone'
alias -s txt=$EDITOR
alias -s cond=$EDITOR
alias -s log=$EDITOR
alias -s vim=$=$EDITOR
alias -s deb="sudo dpkg -i"
alias -s {c,py,cpp,r,rb,go,js,jsx,ts,java,sql,hs,md}='vim'
alias -s {xml,json,toml,yaml,yml,ini,conf,log}='vim'
alias -s {gz,tgz,zip,lzh,bz2,tbz,Z,tar,arj,xz,7z}='extract'


#=======================================================================================
# Global Aliases
#=======================================================================================
alias -g A='| a'
alias -g B='| bcat'
alias -g C='| wc -l'
alias -g D='| dump'
alias -g G='| grep'
alias -g F='| fzf'
alias -g H='| head'
alias -g J='| jq'
alias -g L='| less'
alias -g P='| $PAGER'
alias -g S='| sort -n'
alias -g T='| tail'
alias -g U='| uniq'
alias -g X='| xsel -b'


#=======================================================================================
# Vagrant Aliases and functions
#=======================================================================================
alias vst='vagrant status'
alias vup='vagrant up'
alias vdo='vagrant halt'
alias vssh='vagrant ssh'
alias vkill='vagrant destroy'

#=======================================================================================
# Laravel Aliases and functions
#=======================================================================================
alias pa="docker-compose -f "./docker-compose.yml" --project-directory ./ exec -e XDEBUG_SESSION=PHPSTORM php php -dxdebug.remote_host=172.17.0.1 artisan"
alias pam="docker-compose -f "./docker-compose.yml" --project-directory ./ exec -e XDEBUG_SESSION=PHPSTORM php php -dxdebug.remote_host=172.17.0.1 artisan migrate"
alias par="docker-compose -f "./docker-compose.yml" --project-directory ./ exec -e XDEBUG_SESSION=PHPSTORM php php -dxdebug.remote_host=172.17.0.1 artisan routes"
alias mysqlr="docker-compose exec -it db mysql -u root -p123"

alias pam:r="php artisan migrate:refresh"
alias pam:roll="php artisan migrate:rollback"
alias pam:rs="php artisan migrate:refresh --seed"
alias pda="php artisan dumpautoload"
alias cu="composer update"
alias ci="composer install"
alias cda="docker-compose -f "./docker-compose.yml" --project-directory ./ exec php composer dump-autoload -o"
alias pacc="php artisan clear-compiled"

#=======================================================================================
# Nginx Aliases and functions
#=======================================================================================
# common directories
alias ncon="cd /etc/nginx/sites-enabled/"
alias nerr="cd /var/log/nginx/"

# view logs
alias npe='tail -f /var/log/nginx/*error.log'
alias npa='tail -f /var/log/nginx/*access.log'

# reload nginx
alias nrel='sudo nginx -s reload'
#=======================================================================================
# Apache Aliases and functions
#=======================================================================================
# common directories
alias acon="cd /etc/apache2/sites-available/"
alias aerr="cd /var/log/apache2/"
alias html='cd /var/www/html'

# view logs
alias ape='tail -f /var/log/apache2/*error.log'
alias apa='tail -f /var/log/apache2/*access.log'

# reload apache
alias aprel='sudo service apache2 reload'

# view active virtual hosts
alias aplist='sudo apache2ctl -S'
#=======================================================================================
# Node Aliases and functions
#=======================================================================================
#alias npm='sudo npm'
alias ncon="cd /etc/nginx/sites-available/"
alias nerr="cd /var/log/nginx/"

#=======================================================================================
# Lampp Aliases and functions
#=======================================================================================
alias lst='sudo /opt/lampp/lampp start'
alias lsp='sudo /opt/lampp/lampp stop'
alias alog='sudo tail -f /opt/lampp/logs/*'

#=======================================================================================
# Docker Aliases and functions
#=======================================================================================
# Runs docker-compose command looking at other files
dc() {
  if [ -e "docker-compose.yml" ]; then
    docker-compose "$@"
  elif [ -e "./docker/docker-compose.yml" ]; then
    docker-compose -f "./docker/docker-compose.yml" --project-directory ./ "$@"
  fi
}

# Runs the docker-compose detached
dcu() {
  if [[ -a "docker/docker.sh" ]]; then
    ./docker/docker.sh "$@"
  elif [ -e "docker.sh" ]; then
    ./docker.sh "$@"
  else
    dc up -d
  fi
}

# Get the ip addresses of the dockers
dcip() { docker inspect --format '{{$e := . }}{{with .NetworkSettings}} {{$e.Name}}
{{range $index, $net := .Networks}}{{$index}} IP:{{.IPAddress}}; Gateway:{{.Gateway}}
{{end}}{{end}}' $(dcp -q); }

# Get the log of the docker compose
dclo() { dc logs -tf; }

# Get process included stop container
dcp() { dc ps "$@"; }

# Execute command in Docker Compose service
dexec() { docker exec -it $(dc ps -q $1) $2; }
drexec() { docker exec -u root:root -it $(dc ps -q $1) $2; }

# Run a bash shell in the specified container (with docker-compose).
dceb() {
  SCRIPT="/bin/bash"
  if [ $# -lt 1 ]; then
    echo "Usage: ${FUNCNAME[0]} CONTAINER_ID"
    return 1
  fi
  if [ -n "$2" ]; then
    SCRIPT="$2"
  fi

  dc exec --user "$(id -u):$(id -g)" "$1" "$SCRIPT"
}

#alias dce="docker-compose -f "./docker/docker-compose.yml" --project-directory ./ exec --user \"$(id -u):$(id -g)\""
alias dce="docker-compose -f "./docker/docker-compose.yml" --project-directory ./ exec"

# Get latest container ID
alias dl="docker ps -l -q"

# Get container process
alias dps="docker ps"

# Get process included stop container
alias dpa="docker ps -a"

# Get images
alias di="docker images"

# Get container IP
alias dip="docker inspect --format '{{ .NetworkSettings.IPAddress }}'"

# Run deamonized container, e.g., $dkd base /bin/echo hello
alias dkd="docker run -d -P"

# Run interactive container, e.g., $dki base /bin/bash
alias dki="docker run -i -t -P"

# Stop all containers
alias dstop='docker stop $(docker ps -a -q)'

# Stop and Remove all containers
alias drmf='docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q)'

# Get IP addresses of containers
alias dps="docker ps -q | xargs docker inspect --format '{{ .Id }} - {{ .Name }} - {{ .NetworkSettings.IPAddress }}'"

# Remove all containers
drc() { docker rm $(docker ps -a -q); }

# Remove all images
#dri() { docker rmi $(docker images -q); }

# Dockerfile build, e.g., $dbu tcnksm/test
dbu() { docker build -t=$1 .; }

# Run a bash shell in the specified container.
dexbash() {
  if [ $# -ne 1 ]; then
    echo "Usage: ${FUNCNAME[0]} CONTAINER_ID"
    return 1
  fi

  docker exec -it --user "$(id -u):$(id -g)" "$1" /bin/bash
}

# Runs Docker build and tag it with the given name.
dbt() {
  if [ $# -lt 1 ]; then
    echo "Usage ${FUNCNAME[0]} DIRNAME [TAGNAME ...]"
    return 1
  fi

  ARGS="$1"
  shift
  if [ $# -ge 2 ]; then
    ARGS="$ARGS -t $@"
  fi

  docker build $ARGS
}
