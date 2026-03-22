# 🧠 awk Cheat Sheet

## 🔍 Basic Usage

```bash
awk '{print}' file                  # Print every line (like cat)
awk '{print $1}' file               # Print first field (space-delimited)
awk '{print $1, $3}' file           # Print fields 1 and 3
awk '{print $NF}' file              # Print last field
awk '{print NR, $0}' file           # Print line number + full line
echo "a b c" | awk '{print $2}'     # Read from stdin
```

## 📐 Built-in Variables

```bash
$0          # Entire current line
$1..$NF     # Fields 1 through last
NF          # Number of fields in current line
NR          # Current line number (across all files)
FNR         # Current line number (per file)
FS          # Input field separator (default: whitespace)
OFS         # Output field separator (default: space)
RS          # Input record separator (default: newline)
ORS         # Output record separator (default: newline)
FILENAME    # Current input filename
```

## 🔧 Setting Delimiters

```bash
awk -F: '{print $1}' /etc/passwd           # Use : as field separator
awk -F',' '{print $2}' file.csv            # Parse CSV
awk -F'\t' '{print $3}' file.tsv           # Tab-delimited
awk 'BEGIN{FS=":"; OFS="-"} {print $1,$3}' file  # Set FS and OFS in BEGIN
awk -F'[,;]' '{print $1}' file             # Multiple separators (regex)
```

## 🎯 Patterns and Conditions

```bash
awk '/pattern/' file                        # Print lines matching regex
awk '!/pattern/' file                       # Print lines NOT matching
awk '$3 > 100' file                         # Print if field 3 > 100
awk '$1 == "error"' file                    # Print if field 1 equals string
awk 'NR==5' file                            # Print only line 5
awk 'NR>=5 && NR<=10' file                  # Print lines 5–10
awk '/start/,/end/' file                    # Print between two patterns (range)
awk 'NR==1,NR==5' file                      # Print lines 1–5 (range by line number)
awk '$0 ~ /foo/ && $2 > 50' file            # Regex AND numeric condition
```

## 🏁 BEGIN and END Blocks

```bash
awk 'BEGIN{print "Header"} {print} END{print "Footer"}' file
awk 'BEGIN{count=0} /error/{count++} END{print count " errors"}' file
awk 'BEGIN{FS=","} {print $1}' file         # Set FS before processing
awk 'END{print NR " total lines"}' file     # Count lines
```

## ➕ Arithmetic

```bash
awk '{sum += $1} END{print sum}' file                      # Sum a column
awk '{sum += $1} END{print sum/NR}' file                   # Average a column
awk 'BEGIN{print 2^10}'                                    # Power: 1024
awk '{print $1 * $2}' file                                 # Multiply two fields
awk '$1 > max {max=$1} END{print max}' file                # Max value in column
awk '{if($1<min||NR==1) min=$1} END{print min}' file       # Min value
```

## 🔤 String Operations

```bash
awk '{print length($0)}' file               # Length of each line
awk '{print length($1)}' file               # Length of first field
awk '{print toupper($0)}' file              # Uppercase entire line
awk '{print tolower($1)}' file              # Lowercase first field
awk '{gsub(/foo/, "bar"); print}' file      # Replace all occurrences (global)
awk '{sub(/foo/, "bar"); print}' file       # Replace first occurrence only
awk '{gsub(/^ +| +$/, ""); print}' file     # Trim leading/trailing spaces
awk '{print substr($0, 5)}' file            # Substring from position 5
awk '{print substr($0, 5, 10)}' file        # Substring: pos 5, length 10
awk '{print index($0, "foo")}' file         # Position of "foo" in line (0 = not found)
awk '{split($0, arr, ",")}' file            # Split field into array on delimiter
```

## 📦 Arrays

```bash
# Count occurrences of field 1
awk '{count[$1]++} END{for(k in count) print k, count[k]}' file

# Sum field 2 grouped by field 1
awk '{sum[$1]+=$2} END{for(k in sum) print k, sum[k]}' file

# Check if key exists
awk '{if($1 in seen) print "dup:", $1; seen[$1]=1}' file

# Delete array element
awk '{arr[$1]=$2} END{delete arr["key"]; for(k in arr) print k, arr[k]}' file

# Multi-dimensional array
awk '{matrix[$1][$2]++} END{for(r in matrix) for(c in matrix[r]) print r,c,matrix[r][c]}' file
```

## 🔁 Control Flow

```bash
awk '{if($1>10) print "big"; else print "small"}' file
awk '{for(i=1;i<=NF;i++) print $i}' file    # Print each field on its own line
awk '{i=1; while(i<=NF){print $i; i++}}' file
awk 'NR%2==0' file                           # Print even-numbered lines
awk 'NR%2==1' file                           # Print odd-numbered lines
awk '{if($1=="skip") next; print}' file      # Skip matching lines (like continue)
awk '/start/{found=1} found{print} /end/{found=0}' file  # Stateful range
```

## 🖨️ Printf Formatting

```bash
awk '{printf "%s\n", $1}' file                      # Print string with newline
awk '{printf "%-20s %5d\n", $1, $2}' file           # Left-align str, right-align int
awk '{printf "%08.2f\n", $1}' file                  # Zero-padded float
awk '{printf "%d\t%s\n", NR, $0}' file              # Tab-separated line number + line
awk 'BEGIN{printf "%-10s %-10s\n", "Name", "Score"}' # Table header
```

## 🔗 Common Combos

```bash
# Sum second column of CSV
awk -F',' '{sum+=$2} END{print sum}' file.csv

# Print lines between two patterns (inclusive)
awk '/BEGIN/,/END/' file

# Remove duplicate lines (preserving order)
awk '!seen[$0]++' file

# Print unique values of field 1
awk '!seen[$1]++{print $1}' file

# Word count (like wc -w)
awk '{w+=NF} END{print w}' file

# Reverse fields on each line
awk '{for(i=NF;i>=1;i--) printf "%s%s",$i,(i>1?OFS:ORS)}' file

# Print lines longer than 80 chars
awk 'length($0)>80' file

# Replace delimiter: CSV → TSV
awk 'BEGIN{FS=","; OFS="\t"} {$1=$1; print}' file.csv

# Print filename and line count per file
awk 'FNR==1{if(NR>1) print lines, FILENAME; lines=0} {lines++} END{print lines, FILENAME}' file1 file2

# Nginx log: count requests per IP
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Sum column 3 only for lines where column 1 matches pattern
awk '/pattern/{sum+=$3} END{print sum}' file

# Print lines where field 2 is a duplicate
awk 'seen[$2]++' file
```

## 🆚 awk vs sed vs grep

```bash
# grep  — find lines matching a pattern (filter only)
# sed   — line-oriented substitutions and transforms
# awk   — field-aware processing, math, aggregation, formatted output
# Use awk when you need columns, counters, sums, or conditional logic
```

## ⚠️ Gotchas

```bash
# Field separator -F' ' is NOT the same as the default — default splits on any whitespace
# and trims leading whitespace; -F' ' treats each space as a separator
# Use $1=$1 to rebuild $0 with OFS applied (e.g., after changing OFS)
# awk arrays are associative — for(k in arr) order is undefined
# Integer comparison: $1 > 10 works; string comparison: $1 > "10" does lexicographic
# NR vs FNR: NR is global across files, FNR resets per file
# printf does not add a newline — use \n explicitly
# Regex in awk: /foo/ uses ERE by default (no need for grep -E)
```
