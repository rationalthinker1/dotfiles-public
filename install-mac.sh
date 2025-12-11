#!/usr/bin/env bash

#=======================================================================================
# Loading up variables
#=======================================================================================
function decho() {
	if [[ "${DEBUG}" ]]; then
		echo "${1}"
	fi
}

if [[ -f "/proc/sys/kernel/osrelease" ]] && [[ "$(< /proc/sys/kernel/osrelease)" == *microsoft* ]]; then
	HOST_OS="wsl"
elif [[ "$OSTYPE" == "darwin"* ]]; then
	HOST_OS="darwin"
else
	HOST_OS="linux"
fi
decho "HOST_OS $HOST_OS"

dpkg -l ubuntu-desktop > /dev/null 2>&1
if [[ $? -eq 0 || $HOST_OS == "darwin" ]]; then
	HOST_LOCATION="desktop"
else
	HOST_LOCATION="server"
fi
decho "HOST_LOCATION $HOST_LOCATION"

export HOST_OS="${HOST_OS}"
export HOST_LOCATION="${HOST_LOCATION}"
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
# allows commands like cat to stay in teminal after using it
export LESS="-XRF"

ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${HOME}/.dotfiles/backup"

if [ -f "${XDG_CONFIG_HOME}"/zsh/.zprofile ]; then
	source "${XDG_CONFIG_HOME}"/zsh/.zprofile
fi

if [ -f "${HOME}"/.zprofile ]; then
	source "${HOME}"/.zprofile
fi

function updateFiles() {
	dotfiles_file="${1}"
	current_file="${2}"

	decho "FUNCTION updateFiles"
	decho "current_file: ${current_file}"
	decho "dotfiles_file: ${dotfiles_file}"

	# if the link is not symbolic link or if the file is a symbolic link and the target does not contain string "dotfiles"
	if [[ ( ! -L "${current_file}" ) || ( -L "${current_file}" && (! $(readlink -f "${current_file}") =~ "dotfiles" ) ) ]]; then
		echo "file ${dotfiles_file} is being setup"
		backupFile "${current_file}"
		createSymlink "${dotfiles_file}" "${current_file}"
		return 0
	fi

	decho "file ${current_file} does not need to be updated"
	return 0
}

function createSymlink() {
	if [[ ! -L "${1}" ]]; then
		decho "FUNCTION createSymlink"
		decho "argument 1: ${1}"
		decho "argument 2: ${2}"
		decho ""
		if [[ ! "${DEBUG}" ]]; then
			ln -nfs "${1}" "${2}"
		fi
		echo ""
		echo "<======================================== link created: ${2} ========================================>"
	fi
}

function backupFile() {
	filename=$(basename "${1}")
	decho "FUNCTION backupFile"
	decho "argument 1: ${1}"
	decho "filename: ${filename}"
	decho ""
	if [[ ! -f "${1}" && ! -d "${1}" ]]; then
		decho "${1} does not exist" && return 0
	fi

	if [[ ! "${DEBUG}" ]]; then
		rsync -avzhL --quiet "${1}" "${BACKUP_DIR}/"
		rm -rf "${1}"
	fi
	echo ""
	echo "<======================================== backed up ${filename} to ${BACKUP_DIR} ========================================>"
}

# Installing zsh and basic packages
if [[ ! $(zsh --version 2>/dev/null) ]]; then
	decho "zsh does not exist"
	echo "upgrading all packages"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> "/Users/${USER}/.zprofile"
	eval "$(/opt/homebrew/bin/brew shellenv)"

	brew install \
			git \
			grep \
			wget \
			curl \
			zsh \
			powerline-go \
			fontconfig \
			python3 \
			csvkit \
			xclip \
			htop \
			p7zip \
			rename \
			unzip \
			xsel \
			xclip \
			glances \
			ctags \
			broot \
			go
fi

# Installing vim
if  [[ ! -x "$(command -v vim)" ]]; then
	git clone https://github.com/vim/vim.git
	cd vim/src
	./configure --with-features=huge --enable-python3interp --enable-fail-if-missing --with-python3-command=/usr/bin/python3 --with-python3-config-dir=/usr/lib/python3.10/config-3.10-x86_64-linux-gnu
	make
	sudo make install
	cd ..
	cd ..
	rm -rf vim
fi

# Installing rust
if  [[ ! -x "$(command -v cargo)" ]]; then
	curl https://sh.rustup.rs -sSf | RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup" CARGO_HOME="${XDG_CONFIG_HOME}/.cargo" sh -s -- -y
	source "${XDG_CONFIG_HOME}/.cargo/env"
	rustup default stable
fi

# Installing sd
# sed s/before/after/g -> sd before after;  sd before after file.txt -> sed -i -e 's/before/after/g' file.txt
if  [[ ! -x "$(command -v sd)" ]]; then
	cargo install sd
fi

# Installing node
if [[ ! $(nvm --version 2>/dev/null) ]]; then
	mkdir -p "${NVM_DIR}"
	decho "node does not exist"
	echo ""
	echo "<======================================== installing node"
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
	source "${NVM_DIR}/nvm.sh"
	nvm install --lts

	echo ""
	echo "<======================================== installing yarn"
	curl -o- -L https://yarnpkg.com/install.sh | zsh
	echo "export PATH=$(yarn global bin):$PATH" >> ~/.zprofile
	source ~/.zprofile
	yarn global add gtop
fi

if [[ ! -f "${HOME}/.dotfiles/fonts/.installed" ]] && [[ $HOST_LOCATION == 'desktop' ]] && [[ $HOST_OS == 'linux' ]]; then
	cd "${HOME}/.dotfiles"/fonts
	mkdir installations
	unzip "*.zip" -d installations
	source "${HOME}/.dotfiles/zsh/aliases.zsh"
	install-font-subdirectories "${HOME}/.dotfiles/fonts/installations"
	rm -rf "${HOME}/.dotfiles/fonts/installations"
	touch "${HOME}/.dotfiles/fonts/.installed"
	cd "${HOME}/.dotfiles"
fi

mkdir -p "${BACKUP_DIR}"
updateFiles "${HOME}/.dotfiles/zsh/.zshrc" "${HOME}/.zshrc"
updateFiles "${HOME}/.dotfiles/.vimrc" "${HOME}/.vimrc"
updateFiles "${HOME}/.dotfiles/.vim" "${HOME}/.vim"
updateFiles "${HOME}/.dotfiles/.gitconfig" "${HOME}/.gitconfig"
updateFiles "${HOME}/.dotfiles/zsh" "${HOME}/.config/zsh"
updateFiles "${HOME}/.dotfiles/ranger" "${HOME}/.config/ranger"
updateFiles "${HOME}/.dotfiles/sheldon" "${HOME}/.config/sheldon"
updateFiles "${HOME}/.dotfiles/ripgrep" "${HOME}/.config/ripgrep"
updateFiles "${HOME}/.dotfiles/kitty" "${HOME}/.config/kitty"
updateFiles "${HOME}/.dotfiles/broot" "${HOME}/.config/broot"
updateFiles "${HOME}/.dotfiles/alacritty" "${HOME}/.config/alacritty"
updateFiles "${HOME}/.dotfiles/tmux" "${HOME}/.config/tmux"
updateFiles "${HOME}/.dotfiles/fzf/fzf.zsh" "${HOME}/.config/fzf/fzf.zsh"
updateFiles "${HOME}/.dotfiles/.Xresources" "${HOME}/.Xresources"
updateFiles "${HOME}/.dotfiles/rc.sh" "${HOME}/.ssh/rc"

if [[ $HOST_OS == 'wsl' ]]; then
	WINDOWS_HOME_DIRECTORY=$(wslpath $(wslvar USERPROFILE))
	updateFiles "${HOME}/.dotfiles/.wslconfig" "${WINDOWS_HOME_DIRECTORY}/.wslconfig"
fi

# Installing vim plugins
echo ""
echo "<======================================== installing vim plugins"
vim -E -c PlugInstall -c qall!
