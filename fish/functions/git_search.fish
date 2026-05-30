function git_search --description 'Search all git history for a pattern'
    git rev-list --all | GIT_PAGER=cat xargs git grep $argv
end
