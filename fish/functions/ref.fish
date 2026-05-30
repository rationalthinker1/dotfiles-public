function ref --description 'Quick reference cheat-sheet viewer'
    set -l references_dir "$ZDOTDIR/references"
    switch "$argv[1]"
        case --help -h
            printf '%s\n' \
                'Usage: ref <topic>           Print reference content to stdout' \
                '       ref -e <topic>        Open reference in $EDITOR' \
                '       ref -ls | --list      List all available reference topics' \
                '       ref --help | -h       Show this help message'
            return 0
        case -ls --list
            if test -d "$references_dir"
                set -l files
                for f in "$references_dir"/*.md
                    test -e "$f"; and set -a files "$f"
                end
                if test (count $files) -eq 0
                    echo "No reference topics found in $references_dir"
                    return 1
                end
                echo "Available reference topics:"
                for f in $files
                    echo "  - "(string replace -r '\.md$' '' (basename "$f"))
                end
            else
                echo "References directory not found: $references_dir"
                return 1
            end
            return 0
        case -e
            if test -z "$argv[2]"
                echo "Usage: ref -e <topic>"
                return 1
            end
            set -l file "$references_dir/$argv[2].md"
            if not test -f "$file"
                mkdir -p "$references_dir"
                touch "$file"
            end
            if set -q EDITOR
                $EDITOR "$file"
            else
                vim "$file"
            end
            return 0
        case ''
            ref --help
            return 0
        case '-*'
            echo "Unknown option: $argv[1]"
            echo "Run 'ref --help' for usage."
            return 1
        case '*'
            set -l file "$references_dir/$argv[1].md"
            if not test -f "$file"
                echo "No reference found for '$argv[1]'"
                ref -ls
                return 1
            end
            command cat "$file"
            return 0
    end
end
