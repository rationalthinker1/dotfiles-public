🧠 Ripgrep (rg) Cheat Sheet

🔍 Basic Usage
rg "pattern"                # Search for pattern in current directory
rg "pattern" path/          # Search in specific path
rg -i "pattern"             # Case-insensitive search
rg -w "pattern"             # Match whole word
rg -F "pattern"             # Treat pattern as literal string

📁 File and Directory Control
rg --files                 # List all files ripgrep would search
rg --type js "pattern"     # Search only JavaScript files
rg --type-add "foo:*.foo"  # Add custom file type
rg --type foo "pattern"    # Use custom type
rg --hidden                # Include hidden files
rg --no-ignore             # Ignore .gitignore and .ignore

🧹 Output Control
rg -n "pattern"            # Show line numbers
rg -H "pattern"            # Show filename
rg -o "pattern"            # Show only matched text
rg -v "pattern"            # Invert match (exclude pattern)
rg -l "pattern"            # List matching files only
rg -c "pattern"            # Count matches per file
rg --color always          # Force color output

🧪 Regex and Context
rg "^start"                # Match lines starting with "start"
rg "end$"                  # Match lines ending with "end"
rg -C 3 "pattern"          # Show 3 lines of context around match
rg -B 2 "pattern"          # Show 2 lines before match
rg -A 2 "pattern"          # Show 2 lines after match

🧰 Advanced
rg --debug                 # Show debug info
rg --stats                 # Show search stats
rg --threads 4             # Limit number of threads
rg --max-filesize 1M       # Skip files larger than 1MB
rg --glob "*.js"           # Include only .js files
rg --glob "!*.test.js"     # Exclude test files

✅ Done. Happy grepping!
