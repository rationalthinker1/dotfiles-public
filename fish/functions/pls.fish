function pls --description 'Repeat the last command with sudo'
    eval sudo $history[1]
end
