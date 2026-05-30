function gpu --description 'git push with auto-upstream (.git_cli_prepend aware)'
    set -l branch (git symbolic-ref --short HEAD)
    set -l remote_branch (git config "branch.$branch.merge" 2>/dev/null)
    if test -z "$remote_branch"
        _validate_and_apply_git_prepend git push -u origin $branch
    else
        _validate_and_apply_git_prepend git push
    end
end
