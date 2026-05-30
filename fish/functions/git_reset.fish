function git_reset --description 'Hard reset to HEAD~n'
    set -l commit HEAD
    if test (count $argv) -eq 1
        set commit "HEAD~$argv[1]"
    end
    git reset --hard "$commit"
end
