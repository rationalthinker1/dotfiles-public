function dc --description 'docker compose with host IP exported as IP_ADDRESS'
    set -gx IP_ADDRESS (ip route list default | awk '{print $3}')
    docker compose $argv
end
