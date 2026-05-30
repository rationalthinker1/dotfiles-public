function apt-install --description 'Install one or more apt packages'
    for application in $argv
        sudo apt-get install -f -y "$application"
    end
end
