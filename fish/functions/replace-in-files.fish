function replace-in-files --description 'Find & replace across files with confirmation'
    if test (count $argv) -lt 2
        echo "Usage: replace-in-files <search> <replace> [file-pattern]"
        echo "Example: replace-in-files 'oldName' 'newName' '*.js'"
        return 1
    end
    set -l search $argv[1]
    set -l replace $argv[2]
    set -l pattern '*'
    test (count $argv) -ge 3; and set pattern $argv[3]
    echo "🔍 Searching for: $search"
    echo "📝 Replacing with: $replace"
    echo "📁 In files matching: $pattern"
    echo ""
    rg "$search" -l --glob "$pattern"
    echo ""
    read -P "Proceed with replacement? (y/n) " confirm
    if test "$confirm" = y
        if test "$HOST_OS" = darwin
            rg "$search" -l --glob "$pattern" | xargs sed -i '' "s/$search/$replace/g"
        else
            rg "$search" -l --glob "$pattern" | xargs sed -i "s/$search/$replace/g"
        end
        echo "✓ Replacement complete"
    else
        echo "❌ Cancelled"
    end
end
