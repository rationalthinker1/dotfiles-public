#!/usr/bin/env bash
ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)/`basename "${BASH_SOURCE[0]}"`
BASE_DIR=$(dirname ${ABSOLUTE_PATH})
BACKUP_DIR="${HOME}/.dotfiles/backup"
LOCAL_CONFIG="${HOME}/.config"
export ZSH="${LOCAL_CONFIG}/zsh"

if [ -f "${LOCAL_CONFIG}"/zsh/.zprofile ]; then
	source "${LOCAL_CONFIG}"/zsh/.zprofile
fi

if [ -f "${HOME}"/.zprofile ]; then
	source "${HOME}"/.zprofile
fi

function decho() {
	if [[ "${DEBUG}" ]]; then
		echo "${1}"
	fi
}

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

function isDesktop() {
	x=$( dpkg -l ubuntu-desktop > /dev/null 2>&1)$?
	if [[ "${x}" == "0" ]]; then
		return 0
	else
		return 1
	fi
}

function isServer() {
	x=$( dpkg -l ubuntu-desktop > /dev/null 2>&1)$?
	if [[ "${x}" == "0" ]]; then
		return 1
	else
		return 0
	fi
}

function isDesktopOrServer() {
	if [[ isDesktop ]]; then
		echo "desktop"
	else
		echo "server"
	fi
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
		echo "Link created: ${2}"
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
	echo "Backed up ${filename} to ${BACKUP_DIR}"
}


# Installing zsh
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
		wipe \
		net-tools \
		bd \
		xsel \
		xclip \
		fzf \
		glances \
		; do
			echo "installing ${package}"
			sudo apt-get install --assume-yes --ignore-missing "${package}"
		done

		pip3 install --user pynvim
		sudo echo $(which zsh) | sudo tee -a /etc/shells
		sudo chsh -s $(which zsh)
		curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi



# Installing BLACKHOSTS
if [[ ! $(blackhosts --help 2>/dev/null) ]] && [[ isDesktop ]]; then
	decho "blackhosts does not exist"
	echo "installing blackhosts"
	link=$(curl -sL https://github.com/Lateralus138/blackhosts/releases/latest | grep -P "href=" | grep -vE "musl" | grep "blackhosts.deb" | head -n 1 | cut -d '"' -f 2 | sed -e "s|^|https://github.com|")
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi


# Installing Rust for exa
if [[ ! $(exa --help 2>/dev/null) ]]; then
	decho "exa does not exist"
	echo "installing rust and exa"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	echo "export PATH=$HOME/.cargo/bin:$PATH" >> ~/.zprofile
	source ~/.zprofile
	$HOME/.cargo/bin/cargo install exa --force
fi

# Installing fzf
if [[ ! -d "${LOCAL_CONFIG}/fzf" ]]; then
	decho "fzf does not exist"
	echo "installing fzf"
	git clone --depth 1 https://github.com/junegunn/fzf.git "${LOCAL_CONFIG}/"fzf
	"${LOCAL_CONFIG}/"fzf/install --xdg --no-bash --no-fish --key-bindings --completion --no-update-rc
fi

# Installing broot
if [[ ! $(broot --version 2>/dev/null) ]]; then
	decho "broot does not exist"
	echo "installing broot"
	wget https://dystroy.org/broot/download/x86_64-linux/broot
	sudo mv broot /usr/local/bin
	sudo chmod +x /usr/local/bin/broot
fi

# Installing mcfly
#if [[ ! $(mcfly --version 2>/dev/null) ]]; then
	#decho "mcfly does not exist"
	#echo "installing mcfly"
	#curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh | sudo sh -s -- --git cantino/mcfly
#fi

# Installing node
if [[ ! $(node --version 2>/dev/null) ]]; then
	decho "node does not exist"
	echo "installing node"
	curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
	sudo apt-get install nodejs

	# Installing yarn
	echo "installing yarn"
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
	echo "installing fd"
	link=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest | grep -P "browser_download_url" | grep "amd64" | grep -vE "musl" | grep "deb" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi

# Installing ripgrep
if [[ ! $(rg --version 2>/dev/null) ]]; then
	decho "ripgrep does not exist"
	echo "installing ripgrep"
	link=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep -P "browser_download_url" | grep "amd64" | grep "deb" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi

# Installing bat
if [[ ! $(bat --version 2>/dev/null) ]]; then
	decho "bat does not exist"
	echo "installing bat"
	link=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep -P "browser_download_url" | grep "amd64" | grep -vE "musl" |  grep "deb" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	wget -q $link -P /tmp/
	sudo dpkg -i --force-overwrite /tmp/$download_filename
fi

# Installing up
if [[ ! $(which up 2>/dev/null) ]]; then
	decho "up does not exist"
	echo "Installing up"
	link=$(curl -s https://api.github.com/repos/akavel/up/releases/latest | grep -P "browser_download_url" | head -n 1 |  cut -d '"' -f 4)
	download_filename=$(echo $link | rev | cut -d"/" -f1 | rev)
	sudo wget -q $link -P /usr/local/bin/
	sudo chmod +x /usr/local/bin/up
fi

# Installing glances
# if [[ ! $(which glances 2>/dev/null) ]]; then
# 	decho "glances does not exist"
# 	echo "Installing glances"
# 	sudo pip install glances
# fi

# Installing go-lang
#if [[ ! $(go verion 2>/dev/null) ]]; then
	#decho "go-lang does not exist"
	#go_file="go1.13.4.linux-amd64.tar.gz"
	#cd /tmp
	#wget -nc https://dl.google.com/go/"${go_file}"
	#sudo tar -C /usr/local/ -vzxf /tmp/"${go_file}" > /dev/null
	#echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/.go-projects/bin" >> ~/.zprofile
	#echo "export GOROOT=/usr/local/go" >> ~/.zprofile
	#echo "export GOPATH=\$HOME/.go-projects" >> ~/.zprofile
	#rm -rf /tmp/"${go_file}"
#fi

if [[ ! -f "${HOME}/.dotfiles/fonts/.installed" ]] && [[ isDesktop ]]; then
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
updateFiles "${HOME}/.dotfiles/kitty" "${HOME}/.config/kitty"
updateFiles "${HOME}/.dotfiles/broot" "${HOME}/.config/broot"
updateFiles "${HOME}/.dotfiles/alacritty" "${HOME}/.config/alacritty"
updateFiles "${HOME}/.dotfiles/tmux" "${HOME}/.config/tmux"
updateFiles "${HOME}/.dotfiles/fzf/fzf.zsh" "${HOME}/.config/fzf/fzf.zsh"
updateFiles "${HOME}/.dotfiles/.Xresources" "${HOME}/.Xresources"
updateFiles "${HOME}/.dotfiles/rc.sh" "${HOME}/.ssh/rc"

# Installing tmux plugin manager
if [[ ! -d "${LOCAL_CONFIG}/tmux/plugins/tpm" ]] && [[ isDesktop ]]; then
	decho "Installing tmux plugin manager"
	git clone https://github.com/tmux-plugins/tpm "${LOCAL_CONFIG}"/tmux/plugins/tpm
fi

# Installing zplug for zshrc
#if [[ type -w zplug | awk '{print $2}' != 'function' ]]; then
#	curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
#fi

# Installing vim plugins
decho "Installing vim plugins"
vim -E -c PlugInstall -c qall!

# Installing Oh My Zsh
#if [[ ! -d "${ZSH}" ]] ; then
	#decho "oh-my-zsh does not exist"
	#echo "installing oh-my-zsh"
	#sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
#fi
