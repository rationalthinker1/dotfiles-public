#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# termux/install.sh — install.sh for Termux (Android)
# ==============================================================================
# Why not just run ../install.sh: Termux has no sudo, no systemd, no /etc to write, and
# Android's bionic libc cannot run the glibc-linked binaries that install.sh (via mise) and
# .zshrc (via zinit gh-r) download. Termux's own `pkg` repo ships nearly every one of those
# tools built for bionic, so this script installs them from there instead, then links the
# same config/ tree install.sh does. .zshrc sees HOST_OS=termux (detect_os.sh) and skips
# its gh-r binary downloads, falling through to the pkg-installed copies on PATH.
#
# Bootstrap on a fresh phone (public repo over https — no SSH key needed):
#   pkg install -y curl && curl -fsSL \
#     https://raw.githubusercontent.com/rationalthinker1/dotfiles-public/master/termux/install.sh | bash
#
# Idempotent: every step checks before acting, so re-run it whenever the repo changes.
#
# OPTIONS:
#   --no-font   skip the Nerd Font (installed by default; the other fonts/ never are)
# ==============================================================================

set -euo pipefail

readonly DOTFILES_REPO="https://github.com/rationalthinker1/dotfiles-public.git"
readonly DOTFILES_ROOT="${HOME}/.dotfiles"
readonly BACKUP_DIR="${DOTFILES_ROOT}/backup"
readonly XDG_CONFIG_HOME="${HOME}/.config"

want_font=true
while [[ $# -gt 0 ]]; do
    case "${1}" in
        --no-font) want_font=false ;;
        -h|--help) sed -n '2,20p' "${0}"; exit 0 ;;
        *) echo "Unknown option: ${1}" >&2; exit 1 ;;
    esac
    shift
done

function hdr() {
    printf '\n━━━ %s ━━━\n' "${1}"
}

if [[ -z "${TERMUX_VERSION:-}" && "${PREFIX:-}" != */com.termux/* ]]; then
    echo "This is the Termux installer. Use ../install.sh on a regular Linux/macOS box." >&2
    exit 1
fi

#---------------------------------------------------------------------------------------
# Packages
#---------------------------------------------------------------------------------------
# Termux names, which differ from Debian's in places (7zip, nodejs-lts, git-delta). Each
# replaces something install.sh gets from apt, mise, or a zinit gh-r download. A name the
# repo does not carry is skipped with a warning rather than failing the whole install —
# Termux's repo moves faster than this list.
readonly -a TERMUX_PACKAGES=(
    # base
    git zsh tmux curl wget rsync openssh less man which procps tree file
    unzip zip 7zip make ncurses-utils termux-api termux-tools
    # remote: mosh survives network switches; termux-services runs sshd (boot/ starts it)
    mosh termux-services
    # editors
    vim neovim
    # CLI tools .zshrc installs from GitHub releases elsewhere
    fzf ripgrep fd bat eza zoxide atuin git-delta dust hyperfine jq yq
    lazygit gh direnv tealdeer duf glow broot yazi fastfetch
    sd ast-grep xh ouch gping hexyl grex pastel dua bottom procs doggo
    cloudflared jless jnv ripgrep-all
    # runtimes
    # No mise: .zshrc skips it on Termux — pkg already supplies these, built for bionic.
    python nodejs-lts uv
    # secrets
    gnupg pass
)

hdr "Installing Termux packages"
# Refresh indexes at most once a day — re-runs should not pay for a mirror round-trip.
apt_lists="${PREFIX}/var/lib/apt/lists"
if [[ -z "$(find "${apt_lists}" -maxdepth 1 -name '*Packages' -mmin -1440 2>/dev/null | head -1)" ]]; then
    pkg update -y
fi

missing=() unavailable=()
for p in "${TERMUX_PACKAGES[@]}"; do
    dpkg -s "${p}" &>/dev/null && continue
    if apt-cache show "${p}" &>/dev/null; then
        missing+=("${p}")
    else
        unavailable+=("${p}")
    fi
done
if (( ${#missing[@]} )); then
    echo "Installing: ${missing[*]}"
    pkg install -y "${missing[@]}"
else
    echo "✓ All packages already installed"
fi
(( ${#unavailable[@]} )) && echo "⚠ Not in this Termux repo, skipped: ${unavailable[*]}"

#---------------------------------------------------------------------------------------
# Repo
#---------------------------------------------------------------------------------------
hdr "Dotfiles repo"
if [[ -d "${DOTFILES_ROOT}/.git" ]]; then
    # Never pull over local work: a phone is the likeliest place for a forgotten edit.
    if [[ -z "$(git -C "${DOTFILES_ROOT}" status --porcelain)" ]]; then
        git -C "${DOTFILES_ROOT}" pull --ff-only || echo "⚠ git pull failed — continuing with the current checkout"
    else
        echo "⚠ ${DOTFILES_ROOT} has local changes — not pulling"
    fi
else
    git clone --depth 1 "${DOTFILES_REPO}" "${DOTFILES_ROOT}"
fi

#---------------------------------------------------------------------------------------
# Symlinks
#---------------------------------------------------------------------------------------
# The subset of install.sh's SHARED_LINKS + ZSH_LINKS that means anything on a phone: no
# X11/kitty/alacritty, no Claude Code, no password-store or .aws (neither syncs to public).
declare -A LINKS=(
    [.vimrc]="${HOME}/.vimrc"
    [.vim]="${HOME}/.vim"
    [config/zsh]="${XDG_CONFIG_HOME}/zsh"
    [config/atuin]="${XDG_CONFIG_HOME}/atuin"
    [config/ripgrep]="${XDG_CONFIG_HOME}/ripgrep"
    [config/tmux]="${XDG_CONFIG_HOME}/tmux"
    [config/nvim]="${XDG_CONFIG_HOME}/nvim"
    [config/broot]="${XDG_CONFIG_HOME}/broot"
    [config/ranger]="${XDG_CONFIG_HOME}/ranger"
    [config/gh/config.yml]="${XDG_CONFIG_HOME}/gh/config.yml"
    [config/git/ignore]="${XDG_CONFIG_HOME}/git/ignore"
    [config/git/aliases.gitconfig]="${XDG_CONFIG_HOME}/git/aliases.gitconfig"
    [config/zsh/.zshrc]="${HOME}/.zshrc"
    [config/zsh/.zshenv]="${HOME}/.zshenv"
    [config/zsh/.zprofile]="${HOME}/.zprofile"
    [config/zsh/.zlogin]="${HOME}/.zlogin"
    [config/zsh/.zlogout]="${HOME}/.zlogout"
    [config/fzf/fzf.zsh]="${XDG_CONFIG_HOME}/fzf/fzf.zsh"
    [config/zi/init.zsh]="${XDG_CONFIG_HOME}/zi/init.zsh"
    [termux/termux.properties]="${HOME}/.termux/termux.properties"
)

# Absolute links, unlike install.sh's relative ones: those exist so one link works from
# both a host and a container mounting the same $HOME, which never happens here.
function link_dotfile() {
    local src="${DOTFILES_ROOT}/${1}" target="${2}"
    [[ -e "${src}" ]] || return 0
    [[ -L "${target}" && "$(readlink "${target}")" == "${src}" ]] && return 0
    mkdir -p "$(dirname "${target}")" "${BACKUP_DIR}"
    if [[ -e "${target}" || -L "${target}" ]]; then
        if [[ ! -L "${target}" ]]; then
            echo "  Backing up existing: ${target}"
            cp -a "${target}" "${BACKUP_DIR}/" || { echo "  ⚠ Skipping ${target}: backup failed" >&2; return 0; }
        fi
        rm -rf "${target}"
    fi
    ln -s "${src}" "${target}"
    echo "  ✓ ${target}"
}

hdr "Linking dotfiles"
for src in "${!LINKS[@]}"; do
    link_dotfile "${src}" "${LINKS[${src}]}"
done

git_config_file="${XDG_CONFIG_HOME}/git/config"
if ! git config --file "${git_config_file}" --get-all include.path 2>/dev/null | grep -qx "aliases.gitconfig"; then
    git config --file "${git_config_file}" --add include.path "aliases.gitconfig"
    echo "  ✓ git aliases included"
fi
git config --file "${git_config_file}" --get user.name &>/dev/null \
    || echo "  ⚠ No git identity yet: git config --file ${git_config_file} user.name/user.email"

#---------------------------------------------------------------------------------------
# Zinit
#---------------------------------------------------------------------------------------
hdr "Zinit"
zinit_home="${HOME}/.local/share/zinit/zinit.git"
if [[ -f "${zinit_home}/zinit.zsh" ]]; then
    echo "✓ Zinit already installed"
else
    mkdir -p "$(dirname "${zinit_home}")"
    git clone https://github.com/zdharma-continuum/zinit.git "${zinit_home}"
fi

#---------------------------------------------------------------------------------------
# Font — Nerd Font only. p10k and eza icons need the glyphs; the rest of fonts/ is design
# fonts for desktops, and Termux renders exactly one file (~/.termux/font.ttf) anyway.
#---------------------------------------------------------------------------------------
if [[ "${want_font}" == true ]]; then
    hdr "Nerd Font"
    font_zip="$(find "${DOTFILES_ROOT}/fonts" -maxdepth 1 -iname '*nerd*.zip' 2>/dev/null | sort | head -1)"
    font_dest="${HOME}/.termux/font.ttf"
    if [[ -z "${font_zip}" ]]; then
        echo "⚠ No *Nerd*.zip in ${DOTFILES_ROOT}/fonts — keeping the current font"
    else
        tmp="$(mktemp -d)"
        unzip -qo "${font_zip}" -d "${tmp}"
        font="$(find "${tmp}" -iname '*.ttf' | sort | head -1)"
        if [[ -z "${font}" ]]; then
            echo "⚠ $(basename "${font_zip}") holds no .ttf — keeping the current font"
        elif cmp -s "${font}" "${font_dest}"; then
            echo "✓ $(basename "${font}") already installed"
        elif [[ -e "${font_dest}" ]]; then
            # A font.ttf that is not ours was chosen by hand — never clobber it.
            echo "✓ Keeping your existing ${font_dest} (delete it and re-run for $(basename "${font}"))"
        else
            mkdir -p "${font_dest%/*}"
            cp "${font}" "${font_dest}"
            echo "✓ Installed $(basename "${font}")"
        fi
        rm -rf "${tmp}"
    fi
fi

# Picks up termux.properties (linked above) and the font.
command -v termux-reload-settings &>/dev/null && termux-reload-settings || true

#---------------------------------------------------------------------------------------
# Termux:Widget shortcuts + Termux:Boot scripts
#---------------------------------------------------------------------------------------
# COPIED, unlike everything else here: Termux:Widget refuses a script whose real path is
# outside ~/.shortcuts, so a symlink into the repo never shows up; boot/ gets the same
# treatment so both behave alike. Only files that differ are rewritten, and nothing already
# in those dirs that the repo does not ship is touched.
hdr "Widget shortcuts + boot scripts"
function sync_scripts() {
    local src_dir="${1}" dest_dir="${2}" f dest
    [[ -d "${src_dir}" ]] || return 0
    mkdir -p "${dest_dir}"
    for f in "${src_dir}"/*; do
        [[ -f "${f}" ]] || continue
        dest="${dest_dir}/$(basename "${f}")"
        if cmp -s "${f}" "${dest}"; then
            continue
        fi
        install -m 700 "${f}" "${dest}"
        echo "  ✓ ${dest}"
    done
}
sync_scripts "${DOTFILES_ROOT}/termux/shortcuts" "${HOME}/.shortcuts"
sync_scripts "${DOTFILES_ROOT}/termux/boot" "${HOME}/.termux/boot"
echo "  (need the Termux:Widget and Termux:Boot apps; open Termux:Boot once to arm it)"

# sshd as a termux-services service, so the boot script brings it up. sv-enable only
# persists the setting; it reports an error until the service daemon runs (next session).
if command -v sv-enable &>/dev/null; then
    if [[ -e "${PREFIX}/var/service/sshd/down" ]]; then
        sv-enable sshd 2>/dev/null || true
        [[ -e "${PREFIX}/var/service/sshd/down" ]] \
            || echo "  ✓ sshd enabled (port 8022) — set a password with \`passwd\` or add ~/.ssh/authorized_keys"
    fi
fi


#---------------------------------------------------------------------------------------
# Plugins + default shell
#---------------------------------------------------------------------------------------
hdr "Zinit plugins"
# Turbo plugins only load from an idle prompt, so force the whole queue through once here
# rather than leaving the first interactive start to do it.
zsh -ic '@zinit-scheduler burst' </dev/null >/dev/null 2>&1 \
    && echo "✓ Plugins installed" \
    || echo "⚠ Some plugins failed — open zsh and run zi-audit"

hdr "Default shell"
if [[ "$(basename "${SHELL:-}")" == "zsh" ]]; then
    echo "✓ zsh is already the default shell"
else
    chsh -s zsh
    echo "✓ Default shell set to zsh — restart Termux"
fi

hdr "Done"
echo "Optional: termux-setup-storage   (expose shared storage as ~/storage)"
