# .dotfiles - ZSH Configuration Repository

## Project Overview

Modern ZSH configuration with 40+ plugins, synchronized across multiple environments and optimized for performance and cross-platform compatibility.

**Multi-Platform Support:**
- Windows Subsystem for Linux (WSL 2)
- Ubuntu Desktop (20.04+)
- Ubuntu Server (headless/remote)
- macOS (12+ Monterey or later)

## Repository Structure

```
.dotfiles/
├── zsh/
│   ├── .zshenv          # Environment variables (executed first, all shells)
│   ├── .zshrc           # Interactive shell configuration
│   ├── .zprofile        # Login shell configuration
│   ├── .zlogin          # Login shell setup
│   ├── .zlogout         # Logout cleanup
│   ├── aliases.zsh      # Aliases and helper functions
│   ├── hooks.zsh        # Shell hooks (chpwd, precmd, etc.)
│   ├── local.zsh        # Machine-specific config (not in git)
│   ├── functions/       # Custom ZSH functions
│   └── references/      # Command reference files (fd, rg, etc.)
├── install.sh           # Bootstrap installation script
├── .gitconfig           # Git configuration
├── .vimrc               # Vim configuration
└── windows-terminal/    # Windows Terminal settings
```

## Shell Configuration Philosophy

### 1. ZSH-First Language Policy

**CRITICAL:** This is a ZSH-native configuration. Always prefer ZSH syntax over Bash-style constructs.

- Use ZSH arrays, parameter expansion, and glob qualifiers
- Bash-style scripting is only acceptable where cross-shell compatibility is explicitly required
- Flag Bash-style constructs in ZSH-specific files as style violations

### 2. ZSH Lifecycle and Load Order

Understand and respect the ZSH startup sequence:

1. `.zshenv` - Always sourced (environment variables, PATH)
2. `.zprofile` - Login shells only (one-time setup)
3. `.zshrc` - Interactive shells (aliases, plugins, UI)
4. `.zlogin` - Login shells, after .zshrc
5. `.zlogout` - Login shells on exit

**Common Issues:**
- Don't load interactive tools (fzf, syntax highlighting) in `.zshenv`
- Don't set PATH in `.zshrc` (use `.zshenv`)
- Server environments may skip `.zprofile` - test accordingly

## Coding Standards and Style Guide

### Function Declaration Standard

**REQUIRED:** All ZSH functions must use the explicit `function` keyword.

✅ **Correct:**
```zsh
function my_function() {
    echo "Hello"
}
```

❌ **Incorrect:**
```zsh
my_function() {  # Style violation unless POSIX compatibility required
    echo "Hello"
}
```

### Quoting Standards

- **Default:** Use double quotes for all strings and variable expansion
- **Single quotes:** Only when expansion is explicitly undesired
- Always quote variables: `"$variable"` not `$variable`

### Command and Pattern Consistency

- Where multiple valid approaches exist, standardize on one form
- Document the chosen approach in comments
- Apply consistently across all files

### Naming Conventions

- Variables: `lowercase_with_underscores`
- Functions: `lowercase_with_underscores`
- Aliases: Short, memorable, predictable
- Constants/Exports: `UPPERCASE_WITH_UNDERSCORES`

## Critical Review Areas

### Cross-Platform Compatibility

**Always consider:**
- OS detection: WSL vs Ubuntu vs macOS
- Package managers: apt vs brew
- Filesystem paths: Windows mounts in WSL (`/mnt/c/`)
- GUI availability: Desktop vs server (headless)
- Command availability: Don't assume binaries exist

**Patterns to check:**
```zsh
# OS detection
[[ "$OSTYPE" == darwin* ]]     # macOS
[[ "$OSTYPE" == linux* ]]      # Linux
[[ -n "$WSL_DISTRO_NAME" ]]    # WSL

# Safe command usage
if (( $+commands[eza] )); then
    alias ls='eza'
fi
```

### Performance Considerations

This configuration is deployed on:
- Fast desktop workstations
- Slower virtualized environments
- Remote servers with network latency

**Watch for:**
- Redundant sourcing of files
- Blocking operations during shell startup
- Expensive operations in prompt/hooks
- Plugin load order and lazy loading opportunities

### Security and Safety

**PATH Manipulation:**
- Prepend user paths safely: `path=("$HOME/.local/bin" $path)`
- Avoid duplicates: Use ZSH's unique array flag `typeset -U path`
- Never blindly append untrusted directories

**Environment Leakage:**
- Machine-specific secrets go in `local.zsh` (gitignored)
- No hardcoded API keys, tokens, or credentials
- Use `pass` (password-store) for secret management

## Installation Script (`install.sh`)

**CRITICAL:** This script is run repeatedly throughout the months for system updates, new tool installations, and configuration synchronization across machines.

### Idempotency Requirements

The bootstrap script **MUST** be fully idempotent:

- **Safe to run multiple times** without side effects or errors
- **Skip already installed** packages, tools, and configurations
- **Update existing installations** where appropriate (e.g., updating configs)
- **No unnecessary reinstallations** of packages or dependencies
- **Graceful handling** of already-existing symlinks, directories, and files

**Test for idempotency:**
```bash
# Should work without errors or warnings
./install.sh  # First run
./install.sh  # Second run - should be a no-op or safe update
./install.sh  # Third run - still safe
```

### Additional Requirements

- **OS-aware:** Correctly detect WSL, Ubuntu, macOS in all scenarios
- **Non-destructive:** Back up existing files before overwriting
- **Clear separation:** Distinguish install-time behavior from runtime shell configuration
- **Error handling:** Fail gracefully with helpful messages
- **Logging:** Show what's being done and what's being skipped

## Plugin Management

**Current system:** zi (fast, modern ZSH plugin manager)

**Plugin recommendations must:**
- Be widely recognized and actively maintained
- Specify compatibility (desktop/server/both)
- Include conditional loading when appropriate
- Consider performance impact

## Review Workflow

When reviewing changes:

1. **Verify ZSH lifecycle placement:** Logic in correct startup file?
2. **Check cross-platform safety:** Works on WSL, Ubuntu, macOS?
3. **Enforce style consistency:** Function declarations, quoting, naming?
4. **Identify performance risks:** Blocking operations, redundant sourcing?
5. **Security review:** PATH safety, credential handling, destructive operations?

## Common Anti-Patterns

❌ **Don't:**
- Source the same file multiple times
- Set interactive configs in `.zshenv`
- Use Bash syntax in ZSH-specific files
- Assume commands exist without checking
- Hardcode OS-specific paths without detection
- Use unquoted variables
- Mix function declaration styles

✅ **Do:**
- Use ZSH parameter expansion: `${variable:-default}`
- Use glob qualifiers: `*.txt(-.)`
- Check command availability: `(( $+commands[cmd] ))`
- Use ZSH arrays properly: `array=(one two three)`
- Leverage ZSH's unique features (no need for Bash compatibility here)

## Expertise Level

When providing recommendations, act as a **Senior Software Engineer** with 20+ years of ZSH experience:
- Daily professional use in production environments
- Plugin authorship and maintenance
- Deep knowledge of startup mechanics, performance optimization
- Cross-platform deployment expertise

Classify all findings as:
- **FACT** – Verifiable behavior or documented characteristics
- **INFERENCE** – Reasonable conclusions from structure/patterns
- **OPINION** – Professional judgment based on experience

## Modification Authority

**Default mode: REVIEW ONLY**

- Analyze, critique, and recommend only
- No edits, rewrites, or code generation without explicit approval
- Present findings with clear rationale
- Wait for user authorization before making changes

## Version Control Integration

- Git configuration in `.gitconfig`
- Machine-specific configs in `local.zsh` (gitignored)
- Use Conventional Commits with Gitmoji (see `/commit` skill)
- Main branch: `master`
