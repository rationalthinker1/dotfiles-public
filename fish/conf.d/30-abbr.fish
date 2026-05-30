# 30-abbr.fish - Abbreviations (Fish-idiomatic replacement for simple aliases)
# Abbreviations expand inline as you type, so they double as an alias reminder
# (the ZSH `you-should-use` plugin becomes unnecessary). Anything with real
# logic lives in functions/ instead; this file is only 1:1 shortcuts.

status is-interactive; or return

# --- Config / navigation ---
abbr -a dot 'cd ~/.dotfiles'
abbr -a con 'cd ~/.config'
abbr -a h history
abbr -a hgrep 'history search'
abbr -a -- cd.. 'cd ..'
abbr -a -- .. 'cd ..'
abbr -a -- ... 'cd ../..'
abbr -a -- .... 'cd ../../..'
abbr -a -- ..... 'cd ../../../..'
abbr -a -- .4 'cd ../../../..'
abbr -a -- .5 'cd ../../../../..'
abbr -a -- r 'cd /'
abbr -a mkdir 'mkdir -pv'
abbr -a br broot
abbr -a tf 'tail -f'

# --- eza listing shortcuts ---
abbr -a l 'eza --color=auto --long --header --group --group-directories-first'
abbr -a ll 'eza --color=auto --long --header --group --all --group-directories-first'
abbr -a lls 'eza --color=auto --long --header --group --all --group-directories-first --sort size'
abbr -a lt 'eza --color=auto --long --header --group --all --group-directories-first --reverse --sort oldest'
abbr -a llt 'eza --color=auto --long --header --group --all --group-directories-first --tree --level=2'
abbr -a lllt 'eza --color=auto --long --header --group --all --group-directories-first --tree --level=3'
abbr -a llllt 'eza --color=auto --long --header --group --all --group-directories-first --tree --level=4'
abbr -a l. 'eza --color=auto --long --header --group --all --group-directories-first --list-dirs .*'
abbr -a ld 'eza --color=auto --long --header --group --all --group-directories-first --only-dirs'

# --- Modern CLI replacements ---
abbr -a htop btm
abbr -a top btm
abbr -a df duf
abbr -a ncdu dust
abbr -a lg lazygit
abbr -a lzd lazydocker
abbr -a pps procs
abbr -a bench hyperfine
abbr -a cloc tokei
abbr -a myip 'curl -s https://ipecho.net/plain && echo'
abbr -a myip_public 'curl -s https://api.ipify.org && echo'

# --- git ---
abbr -a c 'git checkout'
abbr -a b 'git branch'
abbr -a gcam 'git commit -a --amend'
abbr -a gc 'git commit -am'
abbr -a gs 'git status'
abbr -a gse git_search
abbr -a gr groot
abbr -a gst 'git stash'
abbr -a gstp 'git stash pop'
abbr -a gstl 'git stash list'
abbr -a gsts 'git stash show -p'
abbr -a gco 'git checkout'
abbr -a gcob 'git checkout -b'
abbr -a gcom 'git checkout master; or git checkout main'
abbr -a gf 'git fetch'
abbr -a gfa 'git fetch --all'
abbr -a gfp 'git fetch --prune'
abbr -a grsoft 'git reset --soft'
abbr -a glg 'git log --graph --oneline --decorate'
abbr -a glga 'git log --graph --oneline --decorate --all'
abbr -a glgp 'git log -p'
abbr -a gaa 'git add --all'
abbr -a gap 'git add --patch'
abbr -a gcan 'git commit --amend --no-edit'
abbr -a grs 'git restore --staged'
abbr -a gwip 'git add -A && git commit -m WIP --no-verify'

# forgit (interactive) has no fish port -> plain git fallbacks (matches the
# ZSH else-branch when forgit is unavailable).
abbr -a gl 'git log --graph --oneline --decorate --all'
abbr -a gd 'git diff'
abbr -a ga 'git add'
abbr -a gre 'git reset HEAD'
abbr -a gcf 'git checkout'
abbr -a gcb 'git checkout -b'
abbr -a gss 'git stash show -p'
abbr -a gcp 'git cherry-pick'
abbr -a grb 'git rebase'
abbr -a gfu 'git commit --fixup'
abbr -a gclean 'git clean -id'

# --- npm ---
abbr -a ni 'npm install'
abbr -a nid 'npm install --save-dev'
abbr -a nig 'npm install -g'
abbr -a nrd 'npm run dev'
abbr -a nrb 'npm run build'
abbr -a nrs 'npm run start'
abbr -a nrt 'npm run test'
abbr -a nrl 'npm run lint'
abbr -a nrf 'npm run format'
abbr -a nci 'npm ci'
abbr -a ncc 'npm cache clean --force'
abbr -a nou 'npm outdated'
abbr -a nup 'npm update'

# --- yarn ---
abbr -a ya 'yarn add'
abbr -a yad 'yarn add -D'
abbr -a yi 'yarn install'
abbr -a yag 'yarn global add'
abbr -a yrm 'yarn remove'
abbr -a yup 'yarn upgrade'
abbr -a yui 'yarn upgrade-interactive'
abbr -a yout 'yarn outdated'
abbr -a ycc 'yarn cache clean'
abbr -a yd 'yarn dev'
abbr -a yb 'yarn build'

# --- pnpm ---
abbr -a pi 'pnpm install'
abbr -a pna 'pnpm add'
abbr -a pnad 'pnpm add -D'
abbr -a pr 'pnpm remove'

# --- package.json ---
abbr -a pkg 'vim package.json'
abbr -a pkgj 'cat package.json | jq'

# --- Laravel / artisan (Docker-based via the `pa` function) ---
abbr -a pam 'pa migrate'
abbr -a par 'pa routes'
abbr -a mysqlr 'dce -it db mysql -u root -p123'
abbr -a pamf 'pa migrate:fresh'
abbr -a pamfs 'pa migrate:fresh --seed'
abbr -a pams 'pa migrate --seed'
abbr -a pamr 'pa migrate:rollback'
abbr -a pamrs 'pa migrate:reset'
abbr -a paq 'pa queue:work'
abbr -a paqf 'pa queue:failed'
abbr -a paqr 'pa queue:retry'
abbr -a pat 'pa tinker'
abbr -a pau 'pa up'
abbr -a pad 'pa down'
abbr -a parl 'pa route:list'
abbr -a parc 'pa route:cache'
abbr -a pacc 'pa config:cache'
abbr -a pavc 'pa view:cache'
abbr -a pao 'pa optimize'
abbr -a paoc 'pa optimize:clear'
abbr -a pat:u 'pa test --filter'
abbr -a pat:p 'pa test --parallel'
abbr -a pam:r 'php artisan migrate:refresh'
abbr -a pam:roll 'php artisan migrate:rollback'
abbr -a pam:rs 'php artisan migrate:refresh --seed'
abbr -a pda 'php artisan dumpautoload'
abbr -a cu 'composer update'
abbr -a ci 'composer install'
abbr -a cda 'dce php composer dump-autoload -o'
abbr -a dcomp 'dce php composer'
abbr -a dcompi 'dce php composer install'
abbr -a dcompu 'dce php composer update'
abbr -a dcompd 'dce php composer dump-autoload -o'
abbr -a llog 'tail -f storage/logs/laravel.log'
abbr -a llogl 'tail -100 storage/logs/laravel.log'
abbr -a llogc 'truncate -s 0 storage/logs/laravel.log'

# --- nginx ---
abbr -a html 'cd /var/www/html'
abbr -a ncon_enabled 'cd /etc/nginx/sites-enabled/'
abbr -a ncon_available 'cd /etc/nginx/sites-available/'
abbr -a ncon 'cd /etc/nginx/sites-enabled/'
abbr -a nerr 'cd /var/log/nginx/'
abbr -a npe 'tail -f /var/log/nginx/error*.log'
abbr -a npa 'tail -f /var/log/nginx/access*.log'
abbr -a nrel 'sudo nginx -t && sudo nginx -s reload'
abbr -a nlog 'tail -f /var/log/nginx/*.log'

# --- docker (simple shortcuts; logic-bearing ones are functions) ---
abbr -a dl 'docker ps -l -q'
abbr -a dps 'docker ps'
abbr -a dpa 'docker ps -a'
abbr -a di 'docker images'
abbr -a dip 'docker inspect --format \'{{ .NetworkSettings.IPAddress }}\''
abbr -a dkd 'docker run -d -P'
abbr -a dki 'docker run -i -t -P'

# --- systemd / system ---
abbr -a sctl 'sudo systemctl'
abbr -a sctle 'sudo systemctl enable --now'
abbr -a sctld 'sudo systemctl disable --now'
abbr -a sctls 'systemctl status'
abbr -a duh 'du -h --max-depth=1 | sort -hr'
abbr -a ports 'netstat -tulanp'
abbr -a lsp 'sudo lsof -iTCP -sTCP:LISTEN -n -P'
abbr -a hiberate 'sudo pm-suspend'
abbr -a update-zi 'zi update --all'
abbr -a update-all 'zi update --all && rustup update && sudo apt-get update && sudo apt-get upgrade -y'

# --- OS-specific local IP ---
if test "$HOST_OS" = darwin
    abbr -a myip_local "ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print \$2}'"
else
    abbr -a myip_local "ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1"
end

# --- apt helpers (Linux / WSL only) ---
if test "$HOST_OS" = linux; or test "$HOST_OS" = wsl
    abbr -a addrepo 'sudo add-apt-repository -y'
    abbr -a install 'sudo apt-get install -y'
    abbr -a remove 'sudo apt-get remove'
    abbr -a update 'sudo apt-get update -y'
    abbr -a upgrade 'sudo apt-get update && sudo apt-get upgrade'
    abbr -a dist-upgrade 'sudo apt-get update && sudo apt-get dist-upgrade'
end

# --- Global "pipe" abbreviations (port of ZSH global aliases via --position anywhere) ---
abbr -a --position anywhere -- G '| grep'
abbr -a --position anywhere -- H '| head'
abbr -a --position anywhere -- T '| tail'
abbr -a --position anywhere -- L '| less'
abbr -a --position anywhere -- J '| jq'
abbr -a --position anywhere -- F '| fzf'
abbr -a --position anywhere -- C '| wc -l'
abbr -a --position anywhere -- S '| sort -n'
abbr -a --position anywhere -- U '| uniq'
abbr -a --position anywhere -- X '| xsel -b'
