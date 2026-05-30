function fdd --description 'fd: find directories (with default exclusions)'
    fd --hidden --ignore-case --follow --type d --exclude "$FD_EXCLUDE_PATTERN" $argv
end
