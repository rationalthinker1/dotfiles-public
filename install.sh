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

function install-essential-packages() {
	if [[ "${HOST_OS}" == "darwin" ]]; then
		# installing homebrew
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
			jq \
			csvkit \
			xclip \
			htop \
			p7zip \
			rename \
			unzip \
			xsel \
			xclip \
			bat \
			ripgrep \
			glances \
			ctags \
			fd \
			up \
			eza \
			broot \
			pcre2-utils \
			rsync \
			go
	else 
		# this sets the clock correctly 
		sudo hwclock --hctosys

		sudo apt-get -y update
		sudo apt-get -y upgrade
		for package in \
			build-essential \
			git \
			curl \
			zsh \
			powerline \
			fonts-powerline \
			python3-venv \
			python3-dev \
			python3-pip \
			python-pip \
			xclip \
			p7zip-full \
			unzip \
			unrar \
			wipe \
			net-tools \
			xsel \
			xclip \
			exuberant-ctags \
			golang-go \
			rsync \
			libncurses5-dev \
			libncursesw5-dev \
			pcre2-utils \
			; do
				echo ""
				echo "<======================================== installing ${package} ========================================>"
				sudo apt-get install --assume-yes --ignore-missing "${package}"
			done
	fi

	pip3 install --user pynvim
	sudo echo $(which zsh) | sudo tee -a /etc/shells
	sudo chsh -s $(which zsh)
	curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
}

# Installing zsh and basic packages
if [[ ! $(zsh --version 2>/dev/null) ]]; then
	decho "zsh does not exist"
	install-essential-packages
fi

# Installing vim
# if version less than 9
vim_version=$(vim --version | awk 'NR==1 {print $5}')
if [[ $(echo "$vim_version" | awk '{print ($1 < 9)}') == 1 ]]; then
	sudo apt-get install -y \
    build-essential \
    libncurses5-dev \
    libncursesw5-dev \
    python3-dev \
    ruby-dev \
    lua5.3 liblua5.3-dev \
    libperl-dev \
    git \
    libx11-dev libxt-dev libxpm-dev libgtk-3-dev
	PY3_CONFIG=$(python3-config --configdir)

	git clone https://github.com/vim/vim.git
	cd vim/src
	./configure \
		--with-features=huge \
		--enable-multibyte \
		--enable-rubyinterp=yes \
		--enable-python3interp=yes \
		--with-python3-config-dir=$PY3_CONFIG \
		--enable-perlinterp=yes \
		--enable-luainterp=yes \
		--disable-gui \
		--without-x \
		--enable-cscope \
		--enable-fail-if-missing \
		--prefix=/usr/local \
		--with-tlib=ncurses

	# Full throttle compile
	make -j$(nproc)
	sudo make install

	cd ../..
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

# Installing BLACKHOSTS
if [[ ! $(blackhosts --help 2>/dev/null) ]] && [[ $HOST_LOCATION == 'desktop' ]] && [[ $HOST_OS == 'linux' ]]; then
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
	cargo install --locked --features clipboard broot
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

# Installing fd
if [[ ! $(fd --version 2>/dev/null) ]] && [[ $HOST_OS == 'linux' ]]; then
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

# Installing WSL Utils
if [[ ! $(which wslvar 2>/dev/null) ]] && [[ $HOST_OS == 'wsl' ]]; then
	decho "wslvar does not exist"
	echo ""
	echo "<======================================== installing wslvar"
	sudo add-apt-repository ppa:wslutilities/wslu -y
	sudo apt update -y
	sudo apt install -f -y wslu
fi

# Installing qsv
if [[ ! $(which qsv 2>/dev/null) ]]; then
	decho "qsv does not exist"
	echo ""
	echo "<======================================== installing qsv"
	wget -O - https://dathere.github.io/qsv-deb-releases/qsv-deb.gpg | sudo gpg --dearmor -o /usr/share/keyrings/qsv-deb.gpg
	echo "deb [signed-by=/usr/share/keyrings/qsv-deb.gpg] https://dathere.github.io/qsv-deb-releases ./" | sudo tee /etc/apt/sources.list.d/qsv.list
	sudo apt update
	sudo apt install qsv
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
updateFiles "${HOME}/.dotfiles/zsh" "${XDG_CONFIG_HOME}/zsh"
updateFiles "${HOME}/.dotfiles/ranger" "${XDG_CONFIG_HOME}/ranger"
updateFiles "${HOME}/.dotfiles/sheldon" "${XDG_CONFIG_HOME}/sheldon"
updateFiles "${HOME}/.dotfiles/ripgrep" "${XDG_CONFIG_HOME}/ripgrep"
updateFiles "${HOME}/.dotfiles/kitty" "${XDG_CONFIG_HOME}/kitty"
updateFiles "${HOME}/.dotfiles/broot" "${XDG_CONFIG_HOME}/broot"
updateFiles "${HOME}/.dotfiles/alacritty" "${XDG_CONFIG_HOME}/alacritty"
updateFiles "${HOME}/.dotfiles/tmux" "${XDG_CONFIG_HOME}/tmux"
updateFiles "${HOME}/.dotfiles/fzf/fzf.zsh" "${XDG_CONFIG_HOME}/fzf/fzf.zsh"
updateFiles "${HOME}/.dotfiles/.Xresources" "${HOME}/.Xresources"
updateFiles "${HOME}/.dotfiles/rc.sh" "${HOME}/.ssh/rc"

if [[ ! -d "${XDG_CONFIG_HOME}/zi" ]]; then
	mkdir -p "${XDG_CONFIG_HOME}/zi"
fi
updateFiles "${HOME}/.dotfiles/zi/init.zsh" "${XDG_CONFIG_HOME}/zi/init.zsh"

if [[ $HOST_OS == 'wsl' ]]; then
	WINDOWS_HOME_DIRECTORY=$(wslpath $(wslvar USERPROFILE))
	cp "${HOME}/.dotfiles/.wslconfig" "${WINDOWS_HOME_DIRECTORY}/.wslconfig"
fi

# Installing vim plugins
echo ""
echo "<======================================== installing vim plugins"
vim -E -c PlugInstall -c qall!
