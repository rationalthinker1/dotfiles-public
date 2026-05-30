function dirsize --description 'Quick directory size'
    if test (count $argv) -lt 1
        du -sh *
    else
        du -sh $argv
    end
end
