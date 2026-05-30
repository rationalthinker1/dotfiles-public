function add-repo --description 'Add one or more apt repositories'
    for repository in $argv
        sudo add-apt-repository -y "$repository"
    end
end
