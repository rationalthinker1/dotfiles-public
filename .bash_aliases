#!/bin/bash

## Bashrc Related ##
alias dirbashrc="grep -nT '^#|' $HOME/.bashrc"
alias bashrc="vim $HOME/.bashrc"
alias rebash="source $HOME/.bashrc"

## Colorize the ls output ##
alias ls='ls --color=auto'

## Use a long listing format ##
alias l="ls --color=auto -lh --group-directories-first" # List all, with human readable filesizes
alias ll="ls --color=auto -lah --group-directories-first" # List all, with human readable filesizes
alias llt="ls --color=auto -lahFtr --group-directories-first" # Same as above, but ordered by date
alias lls="ls --color=auto -lahFSr --group-directories-first" # Same as above, but ordered by size

## Show hidden files ##
alias l.='ls -d .* --color=auto'

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
alias c="clear" # Typing the whole word is annoying
alias h="cd $HOME/" # Go home

## Colorize the grep command output for ease of use (good for log files)##
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Create parent dirs if they don't exist
alias mkdir='mkdir -pv'

# Repeat the previous command with sudo
alias pls='sudo !!'

# Quickly edit this script and load it
alias vpr='vim $HOME/.bashrc && source $HOME/.bashrc'

# sshfs with proper default settings
alias sshfs='sshfs -o allow_other,uid=1000,gid=1000'

# Hiberate
alias hiberate='sudo pm-suspend'

# Show processes by name
# example: psg bash
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'

# Append -c to continue the download in case of problems
alias wget='wget -c'

# Prints out your public IP
alias myip="curl http://ipecho.net/plain; echo"

# Searches up history commands
alias hgrep="history | grep"

# Search current directory (SCD) in grep recursively
function scd() {
  grep -r "$@" ./
}

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

#=======================================================================================
# Git Aliases and functions
#=======================================================================================
function c { git checkout "$@"; }
function b { git branch "$@"; }
alias gcam="git commit -a --amend"
alias gc="git commit -am"
alias gs="git status"
alias gd="git diff --ignore-all-space --ignore-space-at-eol --ignore-space-change --ignore-blank-lines -- . ':(exclude)*package-lock.json' -- . ':(exclude)*yarn.lock'"
#alias dc="git diff --cached"
#alias dv="git diff | vim -"
alias gl="git log"
alias gp="git pull"
alias gpu="git push"
alias gpuf="git push --force"

git_reset() {
    COMMIT="HEAD"
    if [[ "$#" -eq 1 ]];
    then
        COMMIT="HEAD~$1"
    fi
    git reset --hard "${COMMIT}"
}
alias gre=git_reset

#=======================================================================================
# Vagrant Aliases and functions
#=======================================================================================
alias v='vagrant version && vagrant global-status'
alias vst='vagrant status'
alias vup='vagrant up'
alias vdo='vagrant halt'
alias vssh='vagrant ssh'
alias vkill='vagrant destroy'

#=======================================================================================
# Laravel Aliases and functions
#=======================================================================================
alias pa="php artisan"
alias par="php artisan routes"
alias pam="php artisan migrate"
alias pam:r="php artisan migrate:refresh"
alias pam:roll="php artisan migrate:rollback"
alias pam:rs="php artisan migrate:refresh --seed"
alias pda="php artisan dumpautoload"
alias cu="composer update"
alias ci="composer install"
alias cda="composer dump-autoload -o"
alias pacc="php artisan clear-compiled"

#=======================================================================================
# Nginx Aliases and functions
#=======================================================================================
alias ncon="cd /etc/nginx/sites-available/"
alias nerr="cd /var/log/nginx/"

# Reload Nginx Configuration
alias nreload="sudo nginx -s reload"

#=======================================================================================
# Apache Aliases and functions
#=======================================================================================
# Easy access to Apache logs
alias acon="cd /etc/apache2/sites-available/"
alias aerr="cd /var/log/apache2/"

# Restart Apache
alias aprel='sudo service apache2 reload'
alias ape='tail -f /var/log/apache2/*error.log'
alias apa='tail -f /var/log/apache2/*access.log'
alias html='cd /var/www/html'
alias aplist='sudo apache2ctl -S'
#=======================================================================================
# Node Aliases and functions
#=======================================================================================
#alias npm='sudo npm'

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
    docker-compose -f "./docker/docker-compose.yml" --project-directory ../ "$@"
  fi
}

# Runs the docker-compose detached
dcu() {
  if [ -e "docker.sh" ]; then
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

  dc exec "$1" "$SCRIPT"
}

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

  docker exec -it "$1" /bin/bash
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
