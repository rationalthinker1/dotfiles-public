function egrep --description 'colorised egrep when interactive'
    if status is-interactive
        command egrep --color=auto $argv
    else
        command egrep $argv
    end
end
