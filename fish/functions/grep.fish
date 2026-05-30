function grep --description 'colorised grep when interactive'
    if status is-interactive
        command grep --color=auto $argv
    else
        command grep $argv
    end
end
