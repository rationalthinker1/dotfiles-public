#!/bin/bash

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi


#=======================================================================================
# Basic Settings
#=======================================================================================
export HISTSIZE=10000           # bash history will save N commands
export HISTFILESIZE=${HISTSIZE} # bash will remember N commands
export HISTCONTROL=ignoreboth   # ignore duplicates and spaces
export HISTIGNORE='&:ls:ll:la:cd:exit:clear:history:ls:[bf]g:[cb]d:b:exit:[ ]*:..'

# Default editor is set to vim
export VISUAL=vim

#=======================================================================================
# Aliases and functions
#=======================================================================================
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

#=======================================================================================
# Local Aliases and functions
#=======================================================================================
if [ -f ~/.bash_local ]; then
    source ~/.bash_local
fi
