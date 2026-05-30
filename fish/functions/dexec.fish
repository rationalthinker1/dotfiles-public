function dexec --description 'Execute a command in a compose service: dexec <service> <cmd>'
    docker exec -it (dc ps -q $argv[1]) $argv[2]
end
