function grh --description 'git reset --hard HEAD (with confirmation)'
    read -P "Hard reset to HEAD? This discards local changes (y/n): " confirm
    if test "$confirm" != y
        echo "Cancelled"
        return 1
    end
    git reset --hard
end
