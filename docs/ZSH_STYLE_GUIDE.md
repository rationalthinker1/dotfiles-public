# ZSH Style & Standards Profile

**Version:** 1.0
**Last Updated:** 2026-01-01
**Maintainer:** Raza

---

## Table of Contents

1. [Quoting Standards](#quoting-standards)
2. [Function Syntax](#function-syntax)
3. [Variable Naming](#variable-naming)
4. [Command Existence Checks](#command-existence-checks)
5. [Conditional Tests](#conditional-tests)
6. [Parameter Expansion](#parameter-expansion)
7. [File Organization](#file-organization)
8. [ZSH Lifecycle](#zsh-lifecycle)
9. [Performance Guidelines](#performance-guidelines)
10. [Security Guidelines](#security-guidelines)

---

## 1. Quoting Standards

### Rule: Double Quotes by Default

**Always use double quotes for variable expansion unless single quotes are semantically required.**

✅ **Correct:**
```zsh
echo "Hello ${USER}"
path=("${HOME}/bin" "${path[@]}")
```

❌ **Incorrect:**
```zsh
echo Hello $USER          # Unquoted - word splitting risk
echo 'Hello ${USER}'      # Single quotes - no expansion
```

### When to Use Single Quotes

Use single quotes **only** when you explicitly want to suppress all expansion:

```zsh
# Literal string - no expansion wanted
alias grep='grep --color=auto'

# Heredoc markers
cat <<'EOF'
$HOME will not expand
EOF
```

### When to Leave Unquoted

**Never.** Always quote variables unless performing intentional word splitting:

```zsh
# Intentional word splitting (rare)
args="--flag1 --flag2"
command ${=args}  # ZSH split operator
```

---

## 2. Function Syntax

### Rule: Use `name() { }` Syntax

**Preferred syntax for all functions:**

```zsh
name() {
    local var="value"
    echo "Function body"
}
```

**Why this syntax?**
- POSIX-compatible (works in bash, sh, zsh)
- Clean, readable, widely recognized
- Avoids redundancy of `function name() {}`

✅ **Correct:**
```zsh
mkcd() {
    mkdir -p "${1}" && cd "${1}"
}
```

❌ **Incorrect:**
```zsh
# Redundant keyword
function mkcd() {
    mkdir -p "${1}" && cd "${1}"
}

# ZSH-only (not portable)
function mkcd {
    mkdir -p "${1}" && cd "${1}"
}
```

### Exception: Use `function name { }` for Local Scope

If you need ZSH-specific local variable scoping, use:

```zsh
function name {
    # Variables are automatically local in this syntax
    var="local value"
}
```

---

## 3. Variable Naming

### Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| **Exported environment variables** | `SCREAMING_SNAKE_CASE` | `EDITOR`, `HOST_OS`, `XDG_CONFIG_HOME` |
| **Local variables** | `lowercase_snake_case` | `local file_path`, `temp_dir` |
| **Readonly constants** | `SCREAMING_SNAKE_CASE` with `readonly` | `readonly MAX_RETRIES=3` |
| **Function names** | `lowercase_snake_case` | `install_package()`, `detect_os()` |

✅ **Correct:**
```zsh
export DOTFILES_ROOT="${HOME}/.dotfiles"
readonly VIM_MIN_VERSION="9"

install_package() {
    local package_name="${1}"
    local install_dir="${HOME}/.local"
}
```

❌ **Incorrect:**
```zsh
export dotfiles_root="${HOME}/.dotfiles"  # Should be UPPER
LOCAL_VAR="value"                          # Should be lower
INSTALL_PACKAGE() {                        # Should be lower
    PACKAGE_NAME="${1}"                    # Should be local lower
}
```

### Always Use `local` for Function Variables

```zsh
process_file() {
    local filename="${1}"      # Correct: scoped to function
    local temp="/tmp/temp"     # Correct: scoped to function

    filename="${1}"            # WRONG: pollutes global scope
}
```

---

## 4. Command Existence Checks

### Rule: Use `(( $+commands[foo] ))` for ZSH

**ZSH-native command existence check (fastest, no subprocess):**

✅ **Correct:**
```zsh
if (( $+commands[vim] )); then
    export EDITOR="vim"
fi
```

❌ **Incorrect:**
```zsh
# Forks subprocess - slower
if command -v vim &>/dev/null; then
    export EDITOR="vim"
fi

# Only checks hash table - unreliable
if which vim &>/dev/null; then
    export EDITOR="vim"
fi
```

### Exception: Portable Scripts

For scripts that must run in bash/sh, use `command -v`:

```bash
#!/usr/bin/env bash
# Cross-shell compatible
if command -v vim &>/dev/null; then
    export EDITOR="vim"
fi
```

---

## 5. Conditional Tests

### Rule: Always Use `[[ ]]` in ZSH

**ZSH-native conditional tests are faster and safer:**

✅ **Correct:**
```zsh
if [[ -f "${file}" ]]; then
    echo "File exists"
fi

if [[ "${var}" == "value" ]]; then
    echo "Match"
fi

# Pattern matching
if [[ "${filename}" == *.txt ]]; then
    echo "Text file"
fi
```

❌ **Incorrect:**
```zsh
# Old POSIX test - slower, no pattern matching
if [ -f "${file}" ]; then
    echo "File exists"
fi

# Single = is for assignment in some shells
if [ "${var}" = "value" ]; then
    echo "Match"
fi
```

### Comparison Operators

| Operator | Use Case |
|----------|----------|
| `==` | String equality |
| `!=` | String inequality |
| `=~` | Regex match |
| `-eq`, `-ne`, `-lt`, `-gt` | Numeric comparison |
| `-f`, `-d`, `-e`, `-x` | File tests |

---

## 6. Parameter Expansion

### Rule: Use ZSH Parameter Expansion Over External Commands

**Avoid forking `basename`, `dirname`, `cut`, `sed` when ZSH can do it:**

✅ **Correct:**
```zsh
filename="${path:t}"        # basename
dirname="${path:h}"         # dirname
extension="${file:e}"       # file extension
stem="${file:r}"            # remove extension

# String manipulation
upper="${var:u}"            # uppercase
lower="${var:l}"            # lowercase
```

❌ **Incorrect:**
```zsh
filename="$(basename "${path}")"     # Forks subprocess
dirname="$(dirname "${path}")"       # Forks subprocess
extension="${path##*.}"              # Less readable
```

### Common Parameter Expansion Patterns

```zsh
# Remove prefix/suffix
${var#pattern}      # Remove shortest match from start
${var##pattern}     # Remove longest match from start
${var%pattern}      # Remove shortest match from end
${var%%pattern}     # Remove longest match from end

# Replace
${var/pattern/replacement}    # Replace first match
${var//pattern/replacement}   # Replace all matches

# Default values
${var:-default}     # Use default if unset
${var:=default}     # Set and use default if unset
${var:?error}       # Error if unset
```

---

## 7. File Organization

### ZSH Configuration Directory Structure

```
~/.config/zsh/
├── .zshenv           # Environment variables (runs first, always)
├── .zprofile         # Login shell initialization
├── .zshrc            # Interactive shell configuration
├── .zlogin           # Post-interactive login setup
├── .zlogout          # Cleanup on shell exit
├── aliases.zsh       # All aliases and functions
├── local.zsh         # Machine-specific overrides (not in git)
├── .p10k.zsh         # Powerlevel10k theme config
├── cache/            # Cached completions, compiled files
└── references/       # Command reference files
```

### File Responsibilities

| File | Purpose | When It Runs |
|------|---------|--------------|
| `.zshenv` | Environment variables, PATH | **Every** shell invocation (interactive, non-interactive, scripts) |
| `.zprofile` | Login-only setup (GUI apps, launchctl) | Login shells only (SSH, terminal startup) |
| `.zshrc` | Interactive config (aliases, prompt, plugins) | Interactive shells only |
| `.zlogin` | Post-interactive login tasks | After `.zshrc` in login shells (rarely needed) |
| `.zlogout` | Cleanup, save state | When login shell exits |

---

## 8. ZSH Lifecycle

### Load Order (Login Shell)

```
1. /etc/zshenv     (system-wide - don't edit)
2. ~/.zshenv       ← Set environment variables here
3. /etc/zprofile   (system-wide - don't edit)
4. ~/.zprofile     ← Login-only initialization (macOS launchctl, browser)
5. /etc/zshrc      (system-wide - don't edit)
6. ~/.zshrc        ← Interactive config (aliases, prompt, plugins)
7. /etc/zlogin     (system-wide - don't edit)
8. ~/.zlogin       ← Post-interactive setup (rarely needed)

[shell session]

9. ~/.zlogout      ← Cleanup on exit
10. /etc/zlogout   (system-wide - don't edit)
```

### What Goes Where?

#### `.zshenv` - Environment Variables

```zsh
# Paths that ALL shells need (including scripts)
export XDG_CONFIG_HOME="${HOME}/.config"
export EDITOR="vim"
export PATH="${HOME}/.local/bin:${PATH}"

# OS detection (needed everywhere)
export HOST_OS="linux"
```

#### `.zprofile` - Login Initialization

```zsh
# macOS GUI app environment
if [[ "${OSTYPE}" == darwin* ]]; then
    launchctl setenv PATH "${PATH}"
fi

# Start SSH agent (once per login)
eval "$(ssh-agent -s)"
```

#### `.zshrc` - Interactive Configuration

```zsh
# Prompt, plugins, aliases, completions
source "${ZDOTDIR}/aliases.zsh"
zi light zsh-users/zsh-autosuggestions

# Interactive-only options
setopt AUTO_CD
setopt CORRECT
```

#### `.zlogout` - Cleanup

```zsh
# Clear sensitive variables
unset OPENAI_API_KEY

# Save session history
# (history is already auto-saved, but custom state can go here)
```

---

## 9. Performance Guidelines

### Lazy Load Expensive Operations

```zsh
# ❌ SLOW: Check every shell startup
if command -v nvm &>/dev/null; then
    export NVM_DIR="${HOME}/.nvm"
    source "${NVM_DIR}/nvm.sh"
fi

# ✅ FAST: Only load when needed
nvm() {
    unfunction nvm
    export NVM_DIR="${HOME}/.nvm"
    source "${NVM_DIR}/nvm.sh"
    nvm "$@"
}
```

### Compile ZSH Files

```zsh
# In .zshrc
if [[ "${ZDOTDIR}/.zshrc" -nt "${ZDOTDIR}/.zshrc.zwc" ]]; then
    zcompile "${ZDOTDIR}/.zshrc"
fi
```

### Use Async for Slow Operations

```zsh
# ❌ SLOW: Blocks shell startup
export WINDOWS_USER="$(wslvar USERPROFILE)"

# ✅ FAST: Run in background
{
    export WINDOWS_USER="$(wslvar USERPROFILE)"
} &!
```

### Cache Expensive Lookups

```zsh
# Cache command output
typeset -gA _my_cache
if [[ -z ${_my_cache[key]} ]]; then
    _my_cache[key]="$(expensive_command)"
fi
```

---

## 10. Security Guidelines

### Never Commit Secrets

❌ **NEVER:**
```zsh
# In version-controlled .zshrc
export OPENAI_API_KEY="sk-proj-..."
```

✅ **Use local.zsh (gitignored):**
```zsh
# In ~/.config/zsh/local.zsh (not in git)
export OPENAI_API_KEY="sk-proj-..."
```

✅ **Better: Use `pass` (password manager):**
```zsh
if (( $+commands[pass] )); then
    export OPENAI_API_KEY="$(pass show openai/api_key)"
fi
```

### Validate User Input

```zsh
# ❌ Dangerous: No validation
git_cli_prepend="$(cat .git_cli_prepend)"
eval "${git_cli_prepend} git push"

# ✅ Safe: Validate before use
if [[ -f ".git_cli_prepend" ]]; then
    local prepend="$(<.git_cli_prepend)"
    # Only allow safe characters
    if [[ "${prepend}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        "${prepend}" git push
    fi
fi
```

### Use `--` to Prevent Option Injection

```zsh
# ❌ Risky: Filename starting with - treated as option
rm "${file}"

# ✅ Safe: -- ends option parsing
rm -- "${file}"
```

---

## Appendix: Quick Reference

### Checklist for New Code

- [ ] Variables quoted with `"${var}"`
- [ ] Functions use `name() {` syntax
- [ ] Exports use `SCREAMING_SNAKE_CASE`
- [ ] Locals use `lowercase_snake_case`
- [ ] Command checks use `(( $+commands[foo] ))`
- [ ] Conditionals use `[[ ]]` not `[ ]`
- [ ] Parameter expansion instead of `basename`/`dirname`
- [ ] No secrets in version-controlled files
- [ ] Comments explain WHY, not WHAT

### Common Mistakes to Avoid

```zsh
# ❌ Unquoted variable
echo $HOME

# ❌ Old test syntax
if [ -f file ]; then

# ❌ Subprocess for basename
name=$(basename "$path")

# ❌ Global variable in function
myfunction() {
    result="value"  # Pollutes global scope
}

# ❌ Command existence check
if command -v foo &>/dev/null; then

# ❌ Single quotes when expansion needed
echo 'Hello $USER'
```

---

**End of Style Guide**
