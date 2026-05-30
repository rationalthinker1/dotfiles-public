function fgrep --description 'colorised fgrep when interactive'
    if status is-interactive
        command fgrep --color=auto $argv
    else
        command fgrep $argv
    end
end
