# 🧠 jq Cheat Sheet

## 🔍 Basic Usage

```bash
jq "." file.json                                # Pretty-print JSON
jq "." <<< '{"a":1}'                            # Parse from string
curl -s https://api.example.com | jq "."        # Pretty-print API response
echo '{"a":1}' | jq "."                         # Pipe JSON to jq
```

## 🔑 Access Fields

```bash
jq ".name" file.json                            # Get top-level field
jq ".user.name" file.json                       # Get nested field
jq ".users[0]" file.json                        # First element of array
jq ".users[-1]" file.json                       # Last element of array
jq ".users[2:5]" file.json                      # Array slice (index 2 to 4)
jq ".users | length" file.json                  # Array length
jq "keys" file.json                             # Get all keys of object
jq "values" file.json                           # Get all values of object
jq "has(\"name\")" file.json                    # Check if key exists (true/false)
```

## 📊 Arrays

```bash
jq ".[]" file.json                              # Iterate array (one item per line)
jq ".[].name" file.json                         # Get field from each array element
jq "[.[] | .name]" file.json                    # Collect field values into array
jq "map(.name)" file.json                       # Same as above (shorthand)
jq "[.[] | select(.age > 30)]" file.json        # Filter array elements
jq "map(select(.active))" file.json             # Filter where field is truthy
jq "first" file.json                            # First element
jq "last" file.json                             # Last element
jq "sort_by(.name)" file.json                   # Sort array of objects by field
jq "reverse" file.json                          # Reverse array
jq "unique" file.json                           # Remove duplicates
jq "unique_by(.name)" file.json                 # Unique by field
jq "group_by(.type)" file.json                  # Group by field value
jq "flatten" file.json                          # Flatten nested arrays
jq "min_by(.price)" file.json                   # Object with minimum value
jq "max_by(.price)" file.json                   # Object with maximum value
```

## 🔧 Transform and Construct

```bash
jq "{name: .user.name, age: .user.age}" file.json  # Build new object
jq "[.[] | {name, email}]" file.json               # Select fields from array
jq ".users | map({name, active})" file.json         # Project specific fields
jq ".a + .b" <<< '{"a":1,"b":2}'                    # Arithmetic (returns 3)
jq ".name | length" file.json                        # String length
jq ".name | ascii_downcase" file.json                # Lowercase string
jq ".name | ascii_upcase" file.json                  # Uppercase string
jq ".name | split(\" \")" file.json                  # Split string into array
jq "[.[] | .price] | add" file.json                  # Sum array of numbers
jq "to_entries" file.json                            # Object → [{key, value}, ...]
jq "from_entries" file.json                          # [{key, value}, ...] → object
jq "with_entries(.value |= . + 1)" file.json        # Transform all values
```

## 🔍 Filtering and Conditionals

```bash
jq "select(.age > 30)" file.json                    # Keep if condition is true
jq "if .status == \"active\" then .name else empty end" file.json  # If/then/else
jq ".[] | select(.name | test(\"^A\"))" file.json   # Regex match (starts with A)
jq ".[] | select(.name | contains(\"john\"))" file.json  # Substring match
jq ".[] | select(.tags | index(\"python\"))" file.json   # Array contains value
jq "map(select(.price > 10 and .stock > 0))" file.json   # Multiple conditions
jq ".[] | select(.name != null)" file.json               # Filter out nulls
jq "del(.password)" file.json                        # Delete a field
jq "del(.[] | select(.active == false))" file.json   # Delete matching elements
```

## ⚙️ Output Options

```bash
jq -r ".name" file.json                         # Raw output (no quotes around strings)
jq -c "." file.json                             # Compact output (one line)
jq -S "." file.json                             # Sort keys alphabetically
jq -e ".name" file.json                         # Exit code 1 if result is null/false
jq -n "{name: \"test\"}"                        # Create JSON from scratch (no input)
jq --arg name "John" '.user = $name' file.json  # Pass string variable
jq --argjson age 30 '.age = $age' file.json     # Pass number/bool/null variable
jq -s "." file1.json file2.json                 # Slurp: read multiple files into array
jq -R "." file.txt                              # Read raw text lines as JSON strings
jq --indent 4 "." file.json                     # Custom indent width
```

## 🧰 Advanced Patterns

```bash
# Update nested field
jq '.user.name = "New Name"' file.json

# Add field to all objects in array
jq '[.[] | . + {processed: true}]' file.json

# Merge two objects
jq -s '.[0] * .[1]' file1.json file2.json

# Convert CSV-like to JSON
echo "name,age" | jq -R 'split(",") | {name: .[0], age: .[1]}'

# Path query (find where a value lives)
jq 'path(.. | select(. == "target_value"))' file.json

# Walk and transform recursively
jq 'walk(if type == "string" then ascii_downcase else . end)' file.json

# Reduce (fold)
jq '[.[] | .price] | reduce .[] as $x (0; . + $x)' file.json

# String interpolation
jq -r '.[] | "\(.name) is \(.age) years old"' file.json

# Convert to CSV
jq -r '.[] | [.name, .email, .age] | @csv' file.json

# Convert to TSV
jq -r '.[] | [.name, .email] | @tsv' file.json

# URL encode
jq -r '@uri' <<< '"hello world"'

# Base64 encode/decode
jq -r '@base64' <<< '"hello"'
jq -r '@base64d' <<< '"aGVsbG8="'
```

## 🔗 Common Combos

```bash
# Pretty-print and colorize API response
curl -s https://api.example.com/data | jq -C "." | less -R

# Extract IDs from paginated API
curl -s "https://api.example.com/items?page=1" | jq -r ".[].id"

# Count items by type
jq 'group_by(.type) | map({type: .[0].type, count: length})' file.json

# Find duplicates by field
jq 'group_by(.email) | map(select(length > 1)) | flatten | .[].email' file.json

# Diff two JSON files (keys only)
diff <(jq -S 'keys' a.json) <(jq -S 'keys' b.json)

# Modify JSON in place
jq '.version = "2.0"' package.json > tmp.json && mv tmp.json package.json

# Validate JSON (exit code 0 = valid)
jq empty file.json && echo "Valid" || echo "Invalid"

# Chain with other tools
cat data.json | jq -r '.[].url' | xargs -P 4 -I {} curl -sO {}
```

## ⚠️ Gotchas

```bash
# Strings in jq filters need escaped quotes: jq '.status == "active"'
# Use -r for raw strings — without it, output includes surrounding quotes
# null propagates: .missing.field returns null, not an error
# .foo? suppresses errors for missing keys (optional access)
# jq processes line-by-line — use -s (slurp) to read entire file as one array
# Shell variable in jq: use --arg, not direct interpolation (avoids injection)
# Empty result from select() produces no output (not null) — may look like it hangs
```

