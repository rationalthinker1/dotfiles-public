function fdf --description 'fd: find files (with default exclusions)'
    fd --hidden --ignore-case --follow --type f --exclude "$FD_EXCLUDE_PATTERN" $argv
end
