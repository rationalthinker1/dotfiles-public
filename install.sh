#!/usr/bin/env bash

# Strict error handling for production-grade install script
set -euo pipefail  # Exit on error, undefined vars, pipe failures

#=======================================================================================
# Logging System
#=======================================================================================
# Set DEBUG from environment or default to empty
: "${DEBUG:=}"

#=======================================================================================
# Configuration Constants
#=======================================================================================
readonly DOWNLOAD_RETRIES=3
readonly DOWNLOAD_RETRY_DELAY=5
readonly CURL_TIMEOUT=10
readonly SPINNER_SLEEP=0.1
readonly SPINNER_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
readonly VIM_MIN_VERSION="9"
readonly WINDOWS_TERMINAL_PKG="Microsoft.WindowsTerminal_8wekyb3d8bbwe"

# Path constants
readonly DOTFILES_ROOT="${HOME}/.dotfiles"
readonly BACKUP_DIR="${DOTFILES_ROOT}/backup"
readonly FONTS_DIR="${DOTFILES_ROOT}/fonts"

#=======================================================================================
# Declarative Package Definitions
#=======================================================================================
readonly -a DARWIN_PACKAGES=(
	git grep wget curl zsh powerline-go fontconfig python3
	csvkit xclip htop p7zip rename unzip xsel
	glances ctags up broot pcre2-utils rsync go
	# GNU tools (macOS has BSD versions)
	coreutils gnu-sed
	# Build dependencies
	autoconf automake libtool pkg-config
	# Libraries
	openssl@3
)

readonly -a LINUX_PACKAGES=(
	build-essential git tmux htop curl zsh powerline fonts-powerline
	python3-venv python3-dev python3-pip xclip p7zip-full zip unzip
	unrar wipe cmake net-tools xsel exuberant-ctags golang-go rsync
	libncurses5-dev libncursesw5-dev util-linux-extra pcre2-utils jq
	# Tier 1: Critical build tools (NOT in build-essential)
	autoconf automake libtool pkg-config
	# Tier 1: Development libraries (Python/Node/Rust dependencies)
	libssl-dev libcurl4-openssl-dev zlib1g-dev libffi-dev libreadline-dev
	# Tier 1: Essential utilities
	man-db less openssh-client software-properties-common
	# Tier 2: Debugging & development helpers
	strace gdb lsb-release shellcheck tree
)

readonly -a CARGO_PACKAGES=(
	"broot --locked --features clipboard"
)

# Symlink mappings: [source_relative_path]=destination
declare -A DOTFILE_LINKS=(
	[zsh/.zshrc]="${HOME}/.zshrc"
	[zsh/.zshenv]="${HOME}/.zshenv"
	[.vimrc]="${HOME}/.vimrc"
	[.vim]="${HOME}/.vim"
	[.gitconfig]="${HOME}/.gitconfig"
	[zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zsh"
	[ranger]="${XDG_CONFIG_HOME:-${HOME}/.config}/ranger"
	[sheldon]="${XDG_CONFIG_HOME:-${HOME}/.config}/sheldon"
	[ripgrep]="${XDG_CONFIG_HOME:-${HOME}/.config}/ripgrep"
	[kitty]="${XDG_CONFIG_HOME:-${HOME}/.config}/kitty"
	[broot]="${XDG_CONFIG_HOME:-${HOME}/.config}/broot"
	[alacritty]="${XDG_CONFIG_HOME:-${HOME}/.config}/alacritty"
	[tmux]="${XDG_CONFIG_HOME:-${HOME}/.config}/tmux"
	[fzf/fzf.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/fzf/fzf.zsh"
	[.Xresources]="${HOME}/.Xresources"
	[rc.sh]="${HOME}/.ssh/rc"
	[zi/init.zsh]="${XDG_CONFIG_HOME:-${HOME}/.config}/zi/init.zsh"
)
readonly DOTFILE_LINKS

# Logging functions with timestamps
LOG_FILE="${HOME}/.dotfiles/install.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
	local level="$1"
	shift
	local msg="$*"
	# Use bash built-in printf for timestamp (no subprocess spawn)
	local timestamp
	printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
	echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@" >&2; }

# Log with decorative header (replaces hardcoded echo decorations)
log_section() {
	local msg="$1"
	log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	log_info "  $msg"
	log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Unified debug logging (replaces decho)
log_debug() {
	[[ -n "${DEBUG:-}" ]] && log "DEBUG" "$@"
	return 0
}

# Fault-tolerant download helper with retry logic (user priority: reliability over speed)
download_with_retry() {
	local url="$1"
	local output="${2:--}"  # Default to stdout if not specified
	local attempt=1

	while [[ $attempt -le $DOWNLOAD_RETRIES ]]; do
		log_info "Downloading $url (attempt $attempt/$DOWNLOAD_RETRIES)"

		if [[ "$output" == "-" ]]; then
			# Output to stdout
			if curl -fsSL --connect-timeout "$CURL_TIMEOUT" --retry 2 "$url"; then
				return 0
			fi
		else
			# Output to file
			if curl -fsSL --connect-timeout "$CURL_TIMEOUT" --retry 2 -o "$output" "$url"; then
				return 0
			fi
		fi

		if [[ $attempt -lt $DOWNLOAD_RETRIES ]]; then
			log_warn "Download failed, retrying in ${DOWNLOAD_RETRY_DELAY}s..."
			sleep "$DOWNLOAD_RETRY_DELAY"
		fi
		((attempt++))
	done

	log_error "Failed to download $url after $DOWNLOAD_RETRIES attempts"
	return 1
}

# Trap errors AFTER log functions are defined
trap 'log_error "Script failed at line $LINENO. Command: $BASH_COMMAND"; exit 1' ERR

#=======================================================================================
# Expert-Level Helper Functions (Reusable Abstractions)
#=======================================================================================

# Validate command exists, optionally install package
# Usage: validate_command <cmd> [package_name] [installer_func]
validate_command() {
	local cmd="$1"
	local pkg="${2:-$1}"
	local installer="${3:-}"

	if command -v "$cmd" &>/dev/null; then
		return 0
	fi

	if [[ -n "$installer" ]]; then
		log_warn "$cmd not found, attempting to install..."
		"$installer" || { log_error "Failed to install $pkg"; return 1; }
	else
		log_error "$cmd not found and no installer provided"
		return 1
	fi
}

# Safe source with existence check
# Usage: safe_source <file> [required]
safe_source() {
	local file="$1"
	local required="${2:-false}"

	if [[ -f "$file" ]]; then
		# shellcheck disable=SC1090
		source "$file"
		return 0
	elif [[ "$required" == "true" ]]; then
		log_error "Required file not found: $file"
		return 1
	fi
	return 0
}

# Ensure directory exists with proper permissions
# Usage: ensure_dir <path> [mode]
ensure_dir() {
	local dir="$1"
	local mode="${2:-0755}"

	if [[ ! -d "$dir" ]]; then
		mkdir -p "$dir" || { log_error "Failed to create directory: $dir"; return 1; }
		chmod "$mode" "$dir"
		log_info "Created directory: $dir"
	fi
	return 0
}

# Extract version number from command output
# Usage: extract_version <command> <awk_field>
extract_version() {
	local cmd="$1"
	local field="${2:-5}"
	local version

	version=$("$cmd" --version 2>/dev/null | awk -v f="$field" 'NR==1 {print $f}')
	echo "${version%%.*}"  # Return major version
}

# Compare version numbers (supports major.minor.patch)
# Usage: version_ge <version1> <version2>
version_ge() {
	local ver1="$1"
	local ver2="$2"

	# Convert to comparable format
	local IFS=.
	local i ver1_arr=($ver1) ver2_arr=($ver2)

	# Fill empty positions with zeros
	for ((i=${#ver1_arr[@]}; i<${#ver2_arr[@]}; i++)); do
		ver1_arr[i]=0
	done

	for ((i=0; i<${#ver1_arr[@]}; i++)); do
		# Use default value expansion to avoid unbound variable error
		local v2="${ver2_arr[i]:-0}"
		if ((10#${ver1_arr[i]} > 10#${v2})); then
			return 0
		fi
		if ((10#${ver1_arr[i]} < 10#${v2})); then
			return 1
		fi
	done
	return 0
}

# Execute function with spinner (visual feedback for long operations)
# Usage: with_spinner "message" function_name [args...]
# Design: Runs command in background, displays animated spinner while waiting
with_spinner() {
	local msg="$1"
	shift

	# Check if stdout is a terminal (not redirected to file/pipe)
	if [[ -t 1 ]]; then
		local i=0

		# Run command in background, suppress all output
		# "$@" expands to all remaining arguments (the actual command to run)
		"$@" &>/dev/null &
		local pid=$!

		# Animation loop: while background process is still running
		while kill -0 "$pid" 2>/dev/null; do
			# Cycle through spinner frames using modulo arithmetic
			# ${#SPINNER_FRAMES} = length of spinner string
			i=$(((i + 1) % ${#SPINNER_FRAMES}))

			# \r returns cursor to line start (overwrites previous frame)
			# ${SPINNER_FRAMES:$i:1} extracts single character at position i
			printf "\r%s %s" "${SPINNER_FRAMES:$i:1}" "$msg"

			# Small sleep to control animation speed (prevents CPU spin)
			sleep "$SPINNER_SLEEP"
		done

		# Wait for background process to finish and capture exit code
		wait "$pid"
		local ret=$?

		# Replace spinner with checkmark and newline (final state)
		printf "\r✓ %s\n" "$msg"
		return $ret
	else
		# Non-interactive mode: run command directly without spinner
		# (e.g., when output is redirected or running in CI/CD)
		"$@"
	fi
}

# Declarative package installer (supports apt, brew, cargo, pip)
# Usage: install_packages <manager> package1 package2 ...
install_packages() {
	local manager="$1"
	shift
	local -a packages=("$@")

	case "$manager" in
		apt)
			sudo apt-get install -y "${packages[@]}"
			;;
		brew)
			brew install "${packages[@]}"
			;;
		cargo)
			for pkg in "${packages[@]}"; do
				cargo install "$pkg" || log_warn "Failed to install cargo package: $pkg"
			done
			;;
		pip3)
			# Ubuntu 24.04+ has PEP 668 externally-managed environment protection
			# Use --break-system-packages flag to bypass it
			pip3 install --user --break-system-packages "${packages[@]}"
			;;
		*)
			log_error "Unknown package manager: $manager"
			return 1
			;;
	esac
}

# Fetch GitHub release asset URL (expert pattern for API interactions)
# Usage: github_release_url <repo> <asset_pattern> [exclude_pattern]
github_release_url() {
	local repo="$1"
	local asset_pattern="$2"
	local exclude_pattern="${3:-}"
	local release_json url

	# Fetch with retry
	release_json=$(download_with_retry "https://api.github.com/repos/$repo/releases/latest") || return 1

	# Build jq filter dynamically
	local jq_filter='.assets[] | select(.name | contains("'"$asset_pattern"'")'
	[[ -n "$exclude_pattern" ]] && jq_filter+=' and (contains("'"$exclude_pattern"'") | not)'
	jq_filter+=') | .browser_download_url'

	url=$(echo "$release_json" | jq -r "$jq_filter" | head -n 1)

	if [[ -z "$url" ]]; then
		log_error "No matching asset found for: $asset_pattern"
		return 1
	fi

	echo "$url"
}

# Install .deb package from URL with cleanup (reusable pattern)
# Usage: install_deb_from_url <url> <package_name>
install_deb_from_url() {
	local url="$1"
	local pkg_name="$2"
	local filename="${url##*/}"
	local temp_deb="/tmp/$filename"

	# Trap-based cleanup (expert pattern)
	local cleanup_done=0
	_cleanup_deb() {
		[[ $cleanup_done -eq 0 && -f "$temp_deb" ]] && rm -f "$temp_deb" && cleanup_done=1
	}
	trap _cleanup_deb RETURN

	download_with_retry "$url" "$temp_deb" || return 1
	sudo dpkg -i --force-overwrite "$temp_deb" || { log_error "Failed to install $pkg_name"; return 1; }
	log_info "$pkg_name installed successfully"
}

# Install package from GitHub releases (expert abstraction pattern)
# Usage: install_github_release <repo> <asset_pattern> [exclude_pattern] <pkg_name>
install_github_release() {
	local repo="$1"
	local asset_pattern="$2"
	local exclude_pattern="${3:-}"
	local pkg_name="${4:-${repo##*/}}"

	# Guard clause: check if already installed
	command -v "$pkg_name" &>/dev/null && {
		log_info "$pkg_name already installed"
		return 0
	}

	log_info "Installing $pkg_name from GitHub..."

	local url
	url=$(github_release_url "$repo" "$asset_pattern" "$exclude_pattern") || return 1
	install_deb_from_url "$url" "$pkg_name"
}

#=======================================================================================
# Environment Detection Functions
#=======================================================================================

# Detect operating system (expert abstraction)
detect_os() {
	if [[ -f "/proc/sys/kernel/osrelease" ]] && [[ "$(</proc/sys/kernel/osrelease)" == *microsoft* ]]; then
		echo "wsl"
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		echo "darwin"
	else
		echo "linux"
	fi
}

# Detect environment type
detect_location() {
	local os="$1"
	if dpkg -l ubuntu-desktop &>/dev/null 2>&1 || [[ "$os" == "darwin" ]]; then
		echo "desktop"
	else
		echo "server"
	fi
}

# Get distribution codename (portable)
get_codename() {
	if [[ -f /etc/os-release ]]; then
		grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || echo "unknown"
	elif command -v lsb_release &>/dev/null; then
		lsb_release -cs 2>/dev/null || echo "unknown"
	else
		echo "unknown"
	fi
}

#=======================================================================================
# Environment Initialization
#=======================================================================================

# Initialize environment detection
HOST_OS=$(detect_os)
HOST_LOCATION=$(detect_location "$HOST_OS")
CODENAME=$(get_codename)

log_debug "HOST_OS: $HOST_OS"
log_debug "HOST_LOCATION: $HOST_LOCATION"
log_debug "CODENAME: $CODENAME"

# Export environment variables
export HOST_OS HOST_LOCATION CODENAME
export LOCAL_CONFIG="${HOME}/.config"
export XDG_CONFIG_HOME="${HOME}/.config"
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ADOTDIR="${ZDOTDIR}/antigen"
export ZSH="${ZDOTDIR}"
export ZSH_CACHE_DIR="${ZSH}/cache"
export ENHANCD_DIR="${XDG_CONFIG_HOME}/enhancd"
export NVM_DIR="${XDG_CONFIG_HOME}/.nvm"
export RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup"
export CARGO_HOME="${XDG_CONFIG_HOME}/.cargo"
export TERM=xterm-256color
export EDITOR=vim
export LESS="-XRF"  # Allows commands like cat to stay in terminal after using it

# Script location variables
ABSOLUTE_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
BASE_DIR=$(dirname "${ABSOLUTE_PATH}")

# Use expert helper for safe sourcing
safe_source "${XDG_CONFIG_HOME}/zsh/.zprofile"
safe_source "${HOME}/.zprofile"

function updateFiles() {
	local dotfiles_file="${1}"
	local current_file="${2}"
	local link_target

	log_debug "FUNCTION updateFiles"
	log_debug "current_file: ${current_file}"
	log_debug "dotfiles_file: ${dotfiles_file}"

	# if the link is not symbolic link or if the file is a symbolic link and the target does not contain string "dotfiles"
	if [[ ! -L "${current_file}" ]]; then
		echo "file ${dotfiles_file} is being setup"
		backupFile "${current_file}"
		createSymlink "${dotfiles_file}" "${current_file}"
		return 0
	elif [[ -L "${current_file}" ]]; then
		link_target=$(readlink -f "${current_file}")
		if [[ ! "${link_target}" =~ dotfiles ]]; then
			echo "file ${dotfiles_file} is being setup"
			backupFile "${current_file}"
			createSymlink "${dotfiles_file}" "${current_file}"
			return 0
		fi
	fi

	log_debug "file ${current_file} does not need to be updated"
	return 0
}

function createSymlink() {
	local source="${1}"
	local target="${2}"

	if [[ ! -L "${source}" ]]; then
		log_debug "FUNCTION createSymlink"
		log_debug "source: ${source}"
		log_debug "target: ${target}"
		log_debug ""
		# In DEBUG mode, skip file operations (dry-run mode)
		if [[ ! "${DEBUG}" ]]; then
			ln -nfs "${source}" "${target}"
		else
			log "DEBUG" "Would create symlink: ${source} -> ${target}"
		fi
		echo ""
		echo "<======================================== link created: ${target} ========================================>"
	fi
}

function backupFile() {
	local file_path="${1}"
	local filename
	filename=$(basename "${file_path}")

	log_debug "FUNCTION backupFile"
	log_debug "file_path: ${file_path}"
	log_debug "filename: ${filename}"
	log_debug ""

	if [[ ! -f "${file_path}" && ! -d "${file_path}" ]]; then
		log_debug "${file_path} does not exist" && return 0
	fi

	# In DEBUG mode, skip file operations (dry-run mode)
	if [[ ! "${DEBUG}" ]]; then
		if rsync -avzhL --quiet "${file_path}" "${BACKUP_DIR}/"; then
			rm -rf "${file_path}"
		else
			log_error "backupFile: Failed to backup ${file_path}, not removing original"
			return 1
		fi
	else
		log "DEBUG" "Would backup: ${file_path} -> ${BACKUP_DIR}/"
	fi
	echo ""
	echo "<======================================== backed up ${filename} to ${BACKUP_DIR} ========================================>"
}

#=======================================================================================
# Installation Functions (Modular Design)
#=======================================================================================

# Install Homebrew on macOS (idempotent)
install_homebrew() {
	command -v brew &>/dev/null && { log_info "Homebrew already installed"; return 0; }

	log_section "Installing Homebrew"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Add to shell profile
	{
		echo
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
	} >>"/Users/${USER}/.zprofile"

	eval "$(/opt/homebrew/bin/brew shellenv)"
	log_info "Homebrew installed successfully"
}

# Configure zsh as default shell (idempotent)
configure_default_shell() {
	local zsh_path
	zsh_path=$(command -v zsh)

	# Add to /etc/shells if not present
	if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
		echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
		log_info "Added $zsh_path to /etc/shells"
	else
		log_info "$zsh_path already in /etc/shells"
	fi

	# Change shell for root and user
	sudo chsh -s "$zsh_path" 2>/dev/null || true
	chsh -s "$zsh_path" 2>/dev/null || true
	log_info "Default shell configured to zsh"
}

# Install essential packages based on platform
install_essential_packages() {
	if [[ "${HOST_OS}" == "darwin" ]]; then
		install_homebrew
		with_spinner "Installing Darwin packages" install_packages brew "${DARWIN_PACKAGES[@]}"
	else
		sudo apt-get -y update
		sudo apt-get -y upgrade
		with_spinner "Installing Linux packages" install_packages apt "${LINUX_PACKAGES[@]}"
	fi

	# Python packages
	install_packages pip3 pynvim

	# Configure zsh as default shell
	configure_default_shell

	# Install zplug
	if [[ ! -d "${HOME}/.zplug" ]]; then
		log_info "Installing zplug..."
		curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
	fi

	# Set clock correctly (Linux only)
	if [[ "${HOST_OS}" != "darwin" ]]; then
		sudo hwclock --hctosys 2>/dev/null || log_warn "Failed to sync hardware clock"
	fi

	log_info "Essential packages installed"
}

# Installing zsh and basic packages
if [[ ! $(command -v zsh) ]]; then
	log_debug "zsh does not exist"
	install_essential_packages
fi

# Install Vim dependencies (modular approach)
install_vim_dependencies() {
	local -r DEPS=(
		build-essential libncurses5-dev libncursesw5-dev
		python3-dev ruby-dev lua5.3 liblua5.3-dev libperl-dev
		git libx11-dev libxt-dev libxpm-dev libgtk-3-dev
	)

	sudo apt-get install -y "${DEPS[@]}"
}

# Configure Vim build (expert abstraction)
configure_vim_build() {
	local py3_config="$1"
	local -r FEATURES=(
		"--with-features=huge"
		"--enable-multibyte"
		"--enable-rubyinterp=yes"
		"--enable-python3interp=yes"
		"--enable-perlinterp=yes"
		"--enable-luainterp=yes"
		"--enable-cscope"
		"--enable-fail-if-missing"
		"--disable-gui"
		"--without-x"
		"--prefix=/usr/local"
		"--with-tlib=ncurses"
	)

	./configure "${FEATURES[@]}" --with-python3-config-dir="$py3_config"
}

# Build and install Vim from source
install_vim_from_source() {
	log_section "Building Vim ${VIM_MIN_VERSION}+ from source"

	# Validate dependencies with expert helper
	validate_command python3-config python3-dev || return 1

	local py3_config
	py3_config=$(python3-config --configdir 2>&1)
	[[ -d "$py3_config" ]] || { log_error "Invalid python3-config: $py3_config"; return 1; }

	install_vim_dependencies

	# Clone and build in isolated scope (prevents directory pollution)
	{
		git clone --depth=1 https://github.com/vim/vim.git || return 1
		cd vim/src || return 1

		configure_vim_build "$py3_config"
		with_spinner "Compiling Vim" make -j"$(nproc)"
		sudo make install

		cd ../..
		rm -rf vim
	}

	log_info "Vim ${VIM_MIN_VERSION}+ installed successfully"
}

# Ensure Vim version meets requirements (intelligent version management)
ensure_vim_version() {
	if ! command -v vim &>/dev/null; then
		install_vim_from_source
		return $?
	fi

	local current_version
	current_version=$(vim --version 2>/dev/null | awk 'NR==1 {print $5}')

	# Validate version format
	if [[ ! "$current_version" =~ ^[0-9]+\. ]]; then
		log_warn "Cannot parse vim version '$current_version', rebuilding"
		install_vim_from_source
		return $?
	fi

	# Use expert version comparison helper
	if version_ge "$current_version" "$VIM_MIN_VERSION"; then
		log_info "Vim $current_version meets requirements (>= $VIM_MIN_VERSION)"
		return 0
	fi

	log_info "Vim $current_version outdated, upgrading to ${VIM_MIN_VERSION}+"
	install_vim_from_source
}

#=======================================================================================
# Tool Installation (Declarative Pattern)
#=======================================================================================

# Ensure command exists, install if missing (expert abstraction)
ensure_tool() {
	local cmd="$1"
	local installer="$2"

	command -v "$cmd" &>/dev/null && return 0

	log_info "$cmd not found, installing..."
	eval "$installer"
}

# Install Rust toolchain (idempotent)
install_rust() {
	curl https://sh.rustup.rs -sSf | \
		RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup" \
		CARGO_HOME="${XDG_CONFIG_HOME}/.cargo" \
		sh -s -- -y

	safe_source "${XDG_CONFIG_HOME}/.cargo/env"
	rustup install stable
	rustup default stable

	# Install Wayland dependencies (Linux only)
	[[ "${HOST_OS}" == "linux" ]] && sudo apt install -y libwayland-dev pkg-config 2>/dev/null || true

	log_info "Rust toolchain installed"
}

# Install cargo package (abstraction for cargo install)
install_cargo_package() {
	local pkg="$1"
	cargo install $pkg  # Note: $pkg may contain flags
}

# Install WSL utilities
install_wslu() {
	log_info "Installing latest wslu from PPA..."

	# Add PPA for latest version (PPA has 4.1.3 vs Ubuntu's 3.2.3)
	# Note: software-properties-common (provides add-apt-repository) is in LINUX_PACKAGES
	sudo add-apt-repository ppa:wslutilities/wslu -y
	sudo apt-get update -y
	sudo apt-get install -y wslu

	log_info "wslu installed successfully"
}

# Expert-level blackhosts installer (demonstrates elegant abstraction)
install_blackhosts() {
	# Guard clauses (fail fast pattern)
	command -v blackhosts &>/dev/null && { log_info "blackhosts already installed"; return 0; }

	log_info "Installing blackhosts..."

	# Use reusable GitHub helper
	local url
	url=$(github_release_url "Lateralus138/blackhosts" "blackhosts.deb" "musl") || return 1

	# Use reusable .deb installer
	install_deb_from_url "$url" "blackhosts"
}

# Install all development tools (orchestration function)
install_development_tools() {
	log_section "Installing development tools"

	# Core tools
	ensure_tool zsh install_essential_packages
	ensure_vim_version

	# Rust and cargo tools
	ensure_tool cargo install_rust
	for pkg in "${CARGO_PACKAGES[@]}"; do
		local cmd="${pkg%% *}"  # Extract command name
		ensure_tool "$cmd" "install_cargo_package '$pkg'"
	done

	# Platform-specific tools
	[[ $HOST_LOCATION == 'desktop' && $HOST_OS == 'linux' ]] && install_blackhosts
	[[ $HOST_OS == 'wsl' ]] && ensure_tool wslvar install_wslu

	log_info "Development tools installed"
}

#=======================================================================================
# Font Installation
#=======================================================================================

# Install fonts (desktop Linux only, idempotent)
install_fonts() {
	[[ $HOST_LOCATION != 'desktop' || $HOST_OS != 'linux' ]] && return 0
	[[ -f "${FONTS_DIR}/.installed" ]] && { log_info "Fonts already installed"; return 0; }

	log_section "Installing fonts"

	local install_dir="${FONTS_DIR}/installations"
	mkdir -p "$install_dir"

	# Extract all font archives
	for zipfile in "${FONTS_DIR}"/*.zip; do
		[[ -f "$zipfile" ]] && unzip -q "$zipfile" -d "$install_dir"
	done

	# Install fonts (requires aliases.zsh function)
	safe_source "${DOTFILES_ROOT}/zsh/aliases.zsh" true
	if command -v install-font-subdirectories &>/dev/null; then
		install-font-subdirectories "$install_dir"
	else
		log_warn "install-font-subdirectories not found, skipping font installation"
	fi

	# Cleanup and mark as installed
	rm -rf "$install_dir"
	touch "${FONTS_DIR}/.installed"

	log_info "Fonts installed successfully"
}

#=======================================================================================
# Dotfile Symlink Management (Data-Driven)
#=======================================================================================

# Ensure directory exists (helper)
ensure_dir() {
	[[ -d "$1" ]] || mkdir -p "$1"
}

# Update dotfile symlink (improved from updateFiles)
update_dotfile_link() {
	local source="$1"
	local target="$2"

	# If target doesn't exist or isn't a symlink, set it up
	if [[ ! -L "$target" ]]; then
		log_debug "Setting up: $target -> $source"
		backupFile "$target"
		createSymlink "$source" "$target"
		return 0
	fi

	# If symlink exists but doesn't point to dotfiles, update it
	local link_target
	link_target=$(readlink -f "$target" 2>/dev/null || echo "")
	if [[ ! "$link_target" =~ dotfiles ]]; then
		log_debug "Updating non-dotfiles symlink: $target"
		backupFile "$target"
		createSymlink "$source" "$target"
		return 0
	fi

	log_debug "Symlink already correct: $target"
}

# Install all dotfile symlinks (data-driven approach)
install_dotfile_links() {
	log_section "Installing dotfile symlinks"

	ensure_dir "$BACKUP_DIR"
	ensure_dir "${XDG_CONFIG_HOME}/zi"

	for source_path in "${!DOTFILE_LINKS[@]}"; do
		local source="${DOTFILES_ROOT}/${source_path}"
		local target="${DOTFILE_LINKS[$source_path]}"

		# Ensure parent directory exists
		ensure_dir "$(dirname "$target")"

		update_dotfile_link "$source" "$target"
	done

	log_info "Dotfile symlinks installed successfully"
}

#=======================================================================================
# WSL Configuration (Unified)
#=======================================================================================

# Setup WSL Windows home directory with validation
setup_wsl_windows_home() {
	# Try to get Windows profile - this will fail in Docker/non-WSL environments
	local windows_profile
	windows_profile=$(wslvar USERPROFILE 2>&1) || {
		log_warn "Failed to get USERPROFILE (not in real WSL environment), skipping Windows home setup"
		return 0
	}

	[[ -z "$windows_profile" ]] && {
		log_warn "Empty USERPROFILE, skipping Windows home setup"
		return 0
	}

	local windows_home
	windows_home=$(wslpath "$windows_profile" 2>&1) || {
		log_warn "Failed to convert path (not in real WSL environment), skipping Windows home setup"
		return 0
	}

	log_info "Windows home: $windows_home"

	# Copy WSL config if it exists
	[[ -f "${DOTFILES_ROOT}/.wslconfig" ]] && {
		cp "${DOTFILES_ROOT}/.wslconfig" "${windows_home}/.wslconfig"
		log_info "✓ Copied .wslconfig"
	}
}

# Setup Windows Terminal configuration
setup_windows_terminal() {
	if ! command -v powershell.exe &>/dev/null; then
		log_warn "powershell.exe not found, skipping Windows Terminal setup"
		return 0
	fi

	local windows_user
	windows_user=$(powershell.exe '$env:UserName' 2>&1 | tr -d '\r\n')

	[[ -z "$windows_user" || "$windows_user" =~ ^[Ee]rror ]] && {
		log_error "Failed to get Windows username: $windows_user"
		return 1
	}

	log_info "Windows user: $windows_user"

	# Construct paths using constant
	local settings_src="${DOTFILES_ROOT}/windows-terminal/settings.json"
	local settings_dest="/mnt/c/Users/$windows_user/AppData/Local/Packages/${WINDOWS_TERMINAL_PKG}/LocalState/settings.json"

	[[ ! -f "$settings_src" ]] && { log_warn "Source not found: $settings_src"; return 0; }

	# Backup existing settings
	if [[ -f "$settings_dest" ]]; then
		cp "$settings_dest" "${settings_dest}.bak.$(date +%s)"
		log_info "✓ Backed up existing settings.json"
	fi

	cp "$settings_src" "$settings_dest"
	log_info "✓ Windows Terminal configured"
}

# Setup WSL environment (orchestration function)
setup_wsl_environment() {
	[[ $HOST_OS != 'wsl' ]] && return 0

	log_section "Configuring WSL environment"

	setup_wsl_windows_home
	setup_windows_terminal
}

#=======================================================================================
# Main Installation Flow (Expert Orchestration)
#=======================================================================================

main() {
	log_section "Starting dotfiles installation"
	log_info "OS: $HOST_OS | Location: $HOST_LOCATION | Codename: $CODENAME"

	# Phase 1: Install development tools
	install_development_tools

	# Phase 2: Install fonts
	install_fonts

	# Phase 3: Install dotfile symlinks
	install_dotfile_links

	# Phase 4: Install Vim plugins
	log_section "Installing Vim plugins"
	vim -E -c PlugInstall -c qall! 2>/dev/null || log_warn "Vim plugin installation failed"

	# Phase 5: Setup WSL environment
	setup_wsl_environment

	log_section "Installation complete!"
	log_info "Log file: $LOG_FILE"
}

# Run main function
main "$@"