function rg --description 'ripgrep with paging when in a terminal'
    if isatty stdout
        command rg -p $argv | less -RFX
    else
        command rg $argv
    end
end
