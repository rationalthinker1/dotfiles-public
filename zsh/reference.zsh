# Shred a file securely
shred -zvu -n5 "${file}"

# Shred a directory securely
wipe -rfi "${folder}"/*

# Creates a 7z securely with password and maximum compression (-mx[1..9])
7z a -t7z -mhe -mx9 -p "${file}".7z "${folder}"

# Searches for text found in apt sources files
grep -R --include="*.list" "${name}" /etc/apt
