function genpass --description 'Generate a random password'
    set -l length $argv[1]
    test -z "$length"; and set length 20
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-"$length"
end
