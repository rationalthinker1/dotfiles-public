function kkk --description 'Fuzzy-pick a dir (zoxide) then a file to edit in vim'
    set -l dir
    if command -q zoxide
        set dir (zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
    else
        set dir (fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="eza -la {}")
    end
    if test -n "$dir"
        set -l file (cd "$dir"; and fzf --preview="bat --color=always {}")
        test -n "$file"; and vim "$dir/$file"
    end
end
