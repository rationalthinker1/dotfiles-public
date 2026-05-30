function drmf --description 'Stop and remove all docker containers (with confirmation)'
    read -P "Stop and remove ALL Docker containers? (y/n): " confirm
    if test "$confirm" != y
        echo "Cancelled"
        return 1
    end
    docker stop (docker ps -a -q); and docker rm (docker ps -a -q)
end
