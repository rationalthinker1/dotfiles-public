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
if [[ $? -eq 0 ]]; then
	LOCATION="desktop"
else
	LOCATION="server"
fi
decho "LOCATION $LOCATION"

export HOST_OS="${HOST_OS}"
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
export CODENAME=$(lsb_release -a 2>&1 | grep Codename | sed -E "s/Codename:\s+//g")
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
	sudo apt-get -y update
	sudo apt-get -y upgrade
	for package in \
		git \
		vim \
		tmux \
		curl \
		zsh \
		powerline \
		fonts-powerline \
		python3-venv \
		python3-pip \
		python-pip \
		jq \
		csvtool \
		xclip \
		htop \
		p7zip-full \
		rename \
		unzip \
		unrar \
		wipe \
		net-tools \
		bd \
		xsel \
		xclip \
		bat \
		ripgrep \
		glances \
		exuberant-ctags \
		golang-go \
		; do
			echo ""
			echo "<======================================== installing ${package} ========================================>"
			sudo apt-get install --assume-yes --ignore-missing "${package}"
		done

		pip3 install --user pynvim
		sudo echo $(which zsh) | sudo tee -a /etc/shells
		sudo chsh -s $(which zsh)
		curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

# Installing rust
if  [[ ! -x "$(command -v cargo)" ]]; then
	curl https://sh.rustup.rs -sSf | RUSTUP_HOME="${XDG_CONFIG_HOME}/.rustup" CARGO_HOME="${XDG_CONFIG_HOME}/.cargo" sh -s -- -y
	source "${XDG_CONFIG_HOME}/.cargo/env"
fi

# Installing sd
# sed s/before/after/g -> sd before after;  sd before after file.txt -> sed -i -e 's/before/after/g' file.txt
if  [[ ! -x "$(command -v sd)" ]]; then
	cargo install sd
fi

# Installing BLACKHOSTS
if [[ ! $(blackhosts --help 2>/dev/null) ]] && [[ $LOCATION == 'desktop' ]] && [[ $HOST_OS == 'linux' ]]; then
	decho "blackhosts does not exist"
	echo ""
	echo "<======================================== installing blackhosts"
	link=$(curl -s https://api.github.com/repos/Lateralus138/blackhosts/releases/latest | grep -P "browser_download_url" | grep -vE "musl" | grep "blackhosts.deb" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi

# Installing broot
if [[ ! $(broot --version 2>/dev/null) ]]; then
	decho "broot does not exist"
	echo ""
	echo "<======================================== installing broot"
	wget https://dystroy.org/broot/download/x86_64-linux/broot
	sudo mv broot /usr/local/bin
	sudo chmod +x /usr/local/bin/broot
fi

# Installing node
if [[ ! $(nvm --version 2>/dev/null) ]]; then
	mkdir -p "${NVM_DIR}"
	decho "node does not exist"
	echo ""
	echo "<======================================== installing node"
	curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
	nvm install --lts

	echo ""
	echo "<======================================== installing yarn"
	curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	sudo apt-get update -y && sudo apt-get install -y yarn
	echo "export PATH=$(yarn global bin):$PATH" >> ~/.zprofile
	source ~/.zprofile
	yarn global add gtop
fi

# Installing fd
if [[ ! $(fd --version 2>/dev/null) ]]; then
	decho "fd does not exist"
	echo ""
	echo "<======================================== installing fd"
	link=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest | grep -P "browser_download_url" | grep "amd64" | grep -vE "musl" | grep "deb" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi

# Installing eza (newer version of exa)
if  [[ ! -x "$(command -v eza)" ]]; then
	decho "eza does not exist"
	echo ""
	echo "<======================================== installing eza"
	cargo install eza
fi

# Installing fzf
if [[ ! $(fzf --version 2>/dev/null) ]]; then
	decho "fzf does not exist"
	echo ""
	echo "<======================================== installing fzf"
	# link=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep -P "browser_download_url" | grep "amd64" | grep "linux" | grep -vE "musl" | grep "tar.gz" | head -n 1 |  cut -d '"' -f 4)
	# download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	# wget -q $link -P /tmp/
	# tar xf "/tmp/${download_filename}"
	# sudo mv fzf /usr/local/bin/
	rm -rf "${XDG_CONFIG_HOME}/.fzf"
	git clone --depth 1 https://github.com/junegunn/fzf.git "${XDG_CONFIG_HOME}/.fzf"
	"${XDG_CONFIG_HOME}/.fzf/install" --xdg --key-bindings --completion  --no-bash  --no-fish --no-update-rc  
fi

# Installing up
if [[ ! $(which up 2>/dev/null) ]]; then
	decho "up does not exist"
	echo ""
	echo "<======================================== installing up"
	link=$(curl -s https://api.github.com/repos/akavel/up/releases/latest | grep -P "browser_download_url" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	sudo wget -q $link -P /usr/local/bin/
	sudo chmod +x /usr/local/bin/up
fi

if [[ ! -f "${HOME}/.dotfiles/fonts/.installed" ]] && [[ $LOCATION == 'desktop' ]] && [[ $HOST_OS == 'linux' ]]; then
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


# Installing vim plugins
echo ""
echo "<======================================== installing vim plugins"
vim -E -c PlugInstall -c qall!
