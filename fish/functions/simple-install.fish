function simple-install --description 'add-repo + update + install packages'
    set -l repository $argv[1]
    add-repo "$repository"
    set -e argv[1]
    apt-update
    for application in $argv
        apt-install "$application"
    end
end
