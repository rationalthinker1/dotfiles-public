function dexbash --description 'bash in a container as the current user: dexbash <id>'
    if test (count $argv) -ne 1
        echo "Usage: dexbash CONTAINER_ID"
        return 1
    end
    docker exec -it --user (id -u):(id -g) "$argv[1]" /bin/bash
end
