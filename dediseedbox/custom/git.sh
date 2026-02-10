#!/usr/bin/env bash
# ==============================================================================
# git.sh - Git Aliases and Functions for Restricted Seedbox
# ==============================================================================
# Complete Git workflow using standard git commands
# ==============================================================================

# ------------------------------------------------------------------------------
# Git Status & Info
# ------------------------------------------------------------------------------
alias gs="git status"
alias gss="git status -s"         # Short status
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"
alias gstd="git stash drop"

# ------------------------------------------------------------------------------
# Git Add & Commit
# ------------------------------------------------------------------------------
alias ga="git add"
alias gaa="git add --all"
alias gau="git add --update"      # Add modified/deleted, not untracked
alias gc="git commit"
alias gca="git commit --amend"
alias gcan="git commit --amend --no-edit"

# ------------------------------------------------------------------------------
# Git Diff
# ------------------------------------------------------------------------------
alias gd="git diff"
alias gdc="git diff --cached"     # Diff staged changes
alias gdw="git diff --word-diff"

# ------------------------------------------------------------------------------
# Git Checkout & Branch
# ------------------------------------------------------------------------------
alias gco="git checkout"
alias gcb="git checkout -b"       # Create and checkout new branch
alias gb="git branch"
alias gba="git branch -a"         # All branches (local + remote)
alias gbd="git branch -d"         # Delete branch
alias gbD="git branch -D"         # Force delete branch

# ------------------------------------------------------------------------------
# Git Pull & Push
# ------------------------------------------------------------------------------
alias gpf="git push --force-with-lease"  # Safer force push
alias gpr="git pull --rebase"

# Git pull with .git_cli_prepend support
function gp() {
    _validate_and_apply_git_prepend git pull
}

# Git push with auto-upstream and .git_cli_prepend support
function gpu() {
    local remote_branch=$(git config "branch.$(git symbolic-ref --short HEAD).merge" 2>/dev/null)
    if [[ -z $remote_branch ]]; then
        _validate_and_apply_git_prepend git push -u origin $(git symbolic-ref --short HEAD)
    else
        _validate_and_apply_git_prepend git push
    fi
}

# Git push force (with lease) with .git_cli_prepend support
function gpuf() {
    _validate_and_apply_git_prepend git push --force-with-lease
}

# Conventional commits helper
function gcm() {
    local type=$1
    shift
    git commit -m "${type}: $*"
}
# Usage: gcm feat add user authentication
# Types: feat, fix, docs, style, refactor, test, chore

# ------------------------------------------------------------------------------
# Git Fetch & Remote
# ------------------------------------------------------------------------------
alias gf="git fetch"
alias gfa="git fetch --all"
alias gr="git remote"
alias grv="git remote -v"

# ------------------------------------------------------------------------------
# Git Log
# ------------------------------------------------------------------------------
alias gl="git log"
alias glo="git log --oneline"
alias glg="git log --graph --oneline --decorate --all"
alias gll="git log --pretty=format:'%C(yellow)%h %C(cyan)%ad %C(green)%an %C(reset)%s' --date=short"

# ------------------------------------------------------------------------------
# Git Reset & Clean
# ------------------------------------------------------------------------------
alias grs="git reset"
alias grsh="git reset --hard"
alias gclean="git clean -fd"      # Remove untracked files/directories

# ------------------------------------------------------------------------------
# Git Grep
# ------------------------------------------------------------------------------
alias gg="git grep"

# ------------------------------------------------------------------------------
# Git Functions
# ------------------------------------------------------------------------------

# Go to git repository root
function groot() {
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" ]]; then
        cd "$root"
    else
        echo "Not in a git repository"
        return 1
    fi
}

# Git clone and cd into directory
function gcl() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gcl <repository-url> [directory]"
        return 1
    fi
    git clone "$@" && cd "$(basename "$1" .git)"
}

# Search git log for commits containing pattern
function git_search() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: git_search <pattern>"
        return 1
    fi
    git log --all --grep="$1" --oneline
}

# Git reset to specific commit or HEAD~N
function git_reset() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: git_reset <commit-or-HEAD~N>"
        echo "Example: git_reset HEAD~3"
        return 1
    fi
    git reset --hard "$1"
}

# Show files changed in last commit
alias gshow="git show --name-status"

# Undo last commit (keep changes)
alias gundo="git reset --soft HEAD~1"

# Show git branches sorted by last commit
alias gbr="git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'"
