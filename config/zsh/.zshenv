#!/usr/bin/env zsh
# ==============================================================================
# .zshenv - Environment Variables (Runs for ALL shells)
# ==============================================================================
# This file runs for EVERY zsh invocation (interactive, non-interactive, scripts)
#
# LOAD ORDER:
#   1. .zshenv     ← YOU ARE HERE (environment variables)
#   2. .zprofile   (login shells only)
#   3. .zshrc      (interactive shells only)
#   4. .zlogin     (after .zshrc in login shells)
#
# USE THIS FILE FOR:
# - Environment variables (PATH, EDITOR, XDG_* paths)
# - Variables needed by scripts and non-interactive shells
# - OS detection that all contexts need
#
# DO NOT PUT HERE:
# - Aliases (→ .zshrc or aliases.zsh)
# - Functions (→ .zshrc or aliases.zsh)
# - Interactive-only config (prompt, plugins → .zshrc)
# ==============================================================================

# Guard for .zshrc fallback sourcing
export ZSHENV_LOADED=1

# Ubuntu's /etc/zsh/zshrc runs a bare `compinit` (no -d) before our .zshrc gets a say,
# which both dumps a ~50KB .zcompdump into ZDOTDIR — i.e. into this repo — and pays for
# a second full compaudit fpath scan on every start. .zshrc already runs compinit
# properly, cached under XDG_CACHE_HOME. This is the opt-out /etc/zsh/zshrc itself
# documents, and it must be set here: ZDOTDIR/.zshenv is read before /etc/zsh/zshrc.
# Not exported — it is only ever read by that one file, in this same shell.
skip_global_compinit=1

# 🧭 Base paths (XDG-compliant)
export DOTFILES_ROOT="${HOME}/.dotfiles"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
# STATE is the fourth XDG root and was the only one never exported — it was referenced with
# an inline `${XDG_STATE_HOME:-…}` default in a handful of places instead. That works until
# something outside this file wants it, which is exactly what the history-file relocations
# below need. Declared here so there is one definition rather than N copies of the fallback.
export XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH_CACHE_DIR="${ZDOTDIR}/cache"

# 🧠 Shell and runtime config
export ZSH="${ZDOTDIR}"
export LOCAL_CONFIG="${XDG_CONFIG_HOME}"

# 🧰 Tool-specific envs
export ADOTDIR="${ZDOTDIR}/antigen"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export VOLTA_HOME="${XDG_CONFIG_HOME}/volta"
export BUN_INSTALL="${XDG_CONFIG_HOME}/bun"
export PNPM_HOME="${XDG_CONFIG_HOME}/pnpm"
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"
export CODEX_HOME="${XDG_CONFIG_HOME}/codex"
export GNUPGHOME="${XDG_CONFIG_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_CONFIG_HOME}/password-store"
export FNM_PATH="${XDG_CONFIG_HOME}/.fnm"

# Relocations found by `xdg-audit`. Each of these tools reads an env var but defaults to a
# dotfile in $HOME, so without these four lines they scatter state across the home directory
# for no reason other than that nobody set the variable.
#
# Setting a variable does NOT move existing data — install.sh's migrate_to_xdg block does
# that, and these paths must stay in step with it.
#
# The two history files are STATE, not config: they are written by the program, never edited
# by hand, and losing one costs nothing. That is the distinction XDG_STATE_HOME exists for.
export NODE_REPL_HISTORY="${XDG_STATE_HOME}/node_repl_history"
# Python 3.13+ only. Older interpreters ignore it and keep using ~/.python_history, which is
# harmless — the variable simply has no effect until the interpreter is new enough.
export PYTHON_HISTORY="${XDG_STATE_HOME}/python_history"
# DOTNET_CLI_HOME is a HOME substitute, not a target directory: the CLI creates its own
# `.dotnet` folder inside whatever this points at. So this yields …/share/dotnet/.dotnet,
# and the migration moves ~/.dotnet to exactly that path rather than to the parent.
export DOTNET_CLI_HOME="${XDG_DATA_HOME}/dotnet"
# Covers the model blobs only — the part actually worth relocating, since models run to
# gigabytes. ~/.ollama/config.json and ~/.ollama/history have no override and stay put;
# xdg-audit reports that as partial coverage rather than pretending the directory is gone.
export OLLAMA_MODELS="${XDG_DATA_HOME}/ollama/models"

# 🖥️ Terminal & editor defaults
#
# Which editor is the daily driver. Both stay installed and configured — vim
# from .vim/, neovim from config/nvim/ — so this only decides what `vim`,
# `$EDITOR` and the suffix aliases resolve to. Toggle with `usenvim` / `usevim`
# (see aliases.zsh); revert costs one command and no config changes.
#
# The switch is a MARKER FILE, not a variable in local.zsh, because local.zsh is
# sourced from .zshrc — interactive shells only, and far too late to set $EDITOR
# for `git commit` or `crontab -e`. .zshenv runs for every shell, which is the
# whole point.
#
# It lives under XDG_STATE_HOME rather than XDG_CONFIG_HOME because
# ~/.config/zsh is a SYMLINK INTO THIS REPO — a marker there shows up as an
# untracked file in `git status` on every switch.
#
# DOTFILES_VIM in the environment overrides the marker, for one-off use:
#   DOTFILES_VIM=nvim git commit
if [[ -z "${DOTFILES_VIM}" ]]; then
    if [[ -f "${XDG_STATE_HOME:-${HOME}/.local/state}/dotfiles/use-nvim" ]]; then
        export DOTFILES_VIM="nvim"
    else
        export DOTFILES_VIM="vim"
    fi
fi
export EDITOR="${DOTFILES_VIM}"
export VISUAL="${DOTFILES_VIM}"
export LESS="-XRF"

# 🛠️ Vim build configuration for mise (ASDF_VIM_CONFIG) lives in the [env] block of
# mise/config.toml. It was here once, computing the flags with two python3 spawns on
# EVERY zsh invocation (including scripts); then in a mise() wrapper in aliases.zsh,
# which interactive-only shells could bypass. mise's own config applies it to every
# invocation at zero shell-startup cost.

# ☁️ AWS
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/.aws/credentials"

# ==============================================================================
# XDG-compliant home migrations
# ==============================================================================
# Node.js / npm
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME}/npm"
export NPM_CONFIG_PREFIX="${XDG_DATA_HOME}/npm"

# Yarn (yarn 1 is already XDG-native on Linux: global folder lives in
# ${XDG_DATA_HOME}/yarn; only the cache location is worth pinning)
export YARN_CACHE_FOLDER="${XDG_CACHE_HOME}/yarn"

# Python / IPython
export PYTHONSTARTUP="${XDG_CONFIG_HOME}/python/startup.py"
export IPYTHONDIR="${XDG_CONFIG_HOME}/ipython"

# Keras
export KERAS_HOME="${XDG_CONFIG_HOME}/keras"

# Docker
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

# GNU Parallel
export PARALLEL_HOME="${XDG_CONFIG_HOME}/parallel"

# Wget
export WGETRC="${XDG_CONFIG_HOME}/wget/wgetrc"

# Mise
export MISE_CONFIG_FILE="${XDG_CONFIG_HOME}/mise/config.toml"
# Git
export GIT_CONFIG_GLOBAL="${XDG_CONFIG_HOME}/git/config"
# Go workspace
export GOPATH="${XDG_DATA_HOME}/go"
export GOBIN="${GOPATH}/bin"

# Atuin
export ATUIN_CONFIG_DIR="${XDG_CONFIG_HOME}/atuin"

# gf patterns
export GF_PATH="${XDG_CONFIG_HOME}/gf"

# Modern CLI tools (zinit-managed). Config dirs are pinned to XDG; macOS would
# otherwise use ~/Library. Cache dirs are left to each tool's own default:
# tealdeer deprecated TEALDEER_CACHE_DIR in 1.8 (it warns on every invocation),
# and on Linux its default already honours XDG_CACHE_HOME, so the pin bought
# nothing. Its replacement — `cache_dir` in config.toml — expands neither ~ nor
# $HOME, so it cannot be tracked portably across /home and /Users.
# The rest of the set (jless, ouch, gping, hexyl, grex, pastel, jnv, rga) either
# has no config file or no env override to pin.
export TEALDEER_CONFIG_DIR="${XDG_CONFIG_HOME}/tealdeer"
export XH_CONFIG_DIR="${XDG_CONFIG_HOME}/xh"

# ==============================================================================
# Detect Host OS & Environment
# ==============================================================================
if [[ -f "${ZDOTDIR}/functions/detect_os.sh" ]]; then
  source "${ZDOTDIR}/functions/detect_os.sh"
fi

# ==============================================================================
# Update PATH
# ==============================================================================
typeset -gU path PATH
path=(
  "${CARGO_HOME}/bin"
  "${HOME}/.local/bin"
  "/usr/local/go/bin"
  "${NPM_CONFIG_PREFIX}/bin"
  "${XDG_DATA_HOME}/yarn/global/node_modules/.bin"
  "${BUN_INSTALL}/bin"
  "${PNPM_HOME}/bin"
  "${FNM_PATH}"
  $path
  # mise SHIMS, deliberately LAST.
  #
  # `mise activate` runs in .zshrc, so it only ever reaches interactive shells.
  # Everything else — `git commit` spawning $EDITOR, cron, a script, an IDE
  # shelling out — sees none of it: in a clean shell `vim` resolved to Ubuntu's
  # /bin/vim (9.1) rather than the pinned mise 9.2, and `nvim` was not found at
  # all, which would have made EDITOR=nvim simply fail.
  #
  # Shims fix that for non-interactive use. They go at the END so that in an
  # interactive shell `mise activate`'s real install paths still win: shims are
  # a fallback, not the primary mechanism, and never shadow the faster path.
  "${XDG_DATA_HOME}/mise/shims"
)

# Drop entries whose directory does not exist.
#
# `typeset -U path` above dedupes but keeps dead entries, and every one of them costs a
# failed stat() on EVERY command lookup for the life of the shell. Worse, a dead entry hides
# a broken assumption: FNM_PATH pointed at ~/.config/.fnm long after fnm stopped being
# installed, and /usr/local/go/bin survived a go uninstall — both looked correct in this
# file while doing nothing. Three of the entries above were dead on the machine this was
# written on.
#
# (N-/) is the whole fix: N so an absent path expands to nothing instead of erroring, - to
# follow symlinks before testing, / to keep only directories. ${^path} distributes the
# qualifier across the array rather than applying it once to the joined string.
#
# Deliberately AFTER the array is built, not a guard on each line: entries are added
# unconditionally so the list stays readable, and the filter runs once over the result.
path=( ${^path}(N-/) )

if [[ "${HOST_OS:-}" == "wsl" ]]; then
  # Filter Windows PATH to only essential directories (performance optimization)
  # WSL automatically appends Windows PATH, but it includes 20+ slow NTFS-mounted dirs
  # This causes severe slowdown in fast-syntax-highlighting and other command lookups

  # Build filtered Windows PATH with only essential tools
  typeset -a windows_paths=(
    "/mnt/c/Program Files/PowerShell/7"
    "/mnt/c/Windows/System32"
    "/mnt/c/Windows"
  )

  # Deduplicate and filter PATH: keep Linux paths, add only essential Windows paths
  # This reduces PATH from 30+ entries to ~15, dramatically improving performance
  typeset -U path  # Remove duplicates
  path=(
    ${windows_paths[@]}
    ${path:#/mnt/c/*}  # Remove ALL Windows paths first
  )
fi

# ==============================================================================
# WSL-Specific Settings
# ==============================================================================
if [[ "${HOST_OS:-}" == "wsl" ]]; then
  export LIBGL_ALWAYS_INDIRECT=1
  export BROWSER="wslview"
fi
