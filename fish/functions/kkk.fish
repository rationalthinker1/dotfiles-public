# Two-stage picker: choose a directory (zoxide history), then a file inside it, then
# edit it in vim. zoxide only indexes directories, not files, hence the two stages.
function kkk --description 'Fuzzy-pick a dir (zoxide) then a file to edit in vim'
    set -l dir
    if command -q zoxide
        set dir (zoxide query -l | fzf --exit-0 --height=40% --inline-info --no-sort --reverse --select-1 --preview="eza -la {}")
    else
        set dir (fd --type d --max-depth 3 --hidden --exclude .git --exclude node_modules . ~ 2>/dev/null | fzf --height=40% --inline-info --reverse --preview="eza -la {}")
    end
    test -n "$dir"; or return 0

    # List the directory explicitly rather than `cd`-ing into it. A cd here would run
    # inside a command substitution and fire the PWD hooks, whose stdout would be
    # captured into $file and corrupt the path handed to vim. Listing also yields paths
    # already prefixed with $dir, so no concatenation is needed.
    set -l lister
    if command -q rg
        set lister rg --files "$dir"
    else if command -q fd
        set lister fd --type f --hidden --exclude .git --exclude node_modules . "$dir"
    else
        set lister find "$dir" -type f
    end

    set -l file ($lister 2>/dev/null | fzf --preview="bat --color=always {}")
    test -n "$file"; and vim "$file"
end
