function sshfs --description 'sshfs with sane default options'
    command sshfs -o allow_other,uid=(id -u),gid=(id -g) $argv
end
