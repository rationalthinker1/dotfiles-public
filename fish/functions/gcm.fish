function gcm --description 'Conventional commit: gcm <type> <message...>'
    set -l type $argv[1]
    set -e argv[1]
    git commit -m "$type: $argv"
end
