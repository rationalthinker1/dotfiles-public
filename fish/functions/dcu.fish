function dcu --description 'docker compose up (prefers docker/docker.sh)'
    if test -e docker/docker.sh
        ./docker/docker.sh $argv
    else if test -e docker.sh
        ./docker.sh $argv
    else
        dc up -d
    end
end
