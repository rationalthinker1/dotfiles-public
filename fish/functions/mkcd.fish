function mkcd --description 'mkdir -p then cd into it'
    mkdir -p $argv[1]; and cd $argv[1]
end
