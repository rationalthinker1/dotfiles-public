function sudoi --description 'sudo preserving the current PATH'
    sudo env "PATH=$PATH" $argv
end
