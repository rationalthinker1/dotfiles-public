function git-clone --description 'Clone a repo and cd into it'
    git clone $argv; and cd (string replace -r '\.git$' '' (basename "$argv[1]"))
end
