function drexec --description 'Execute a command as root in a compose service'
    docker exec --user root:root -it (dc ps -q $argv[1]) $argv[2]
end
