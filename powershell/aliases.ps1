#=======================================================================================
# Aliases and helper functions
#
# TWO PowerShell facts drive everything in this file:
#
#   1. Set-Alias cannot carry arguments. `alias ll='eza -la'` has no direct translation;
#      anything with flags MUST become a function.
#   2. Aliases resolve BEFORE functions. PowerShell ships built-in aliases for ls, cat,
#      gc, gl, h, ps, rm, cp, mv and more — defining a function of the same name is
#      silently ignored until the alias is removed. Hence the removal loop below.
#=======================================================================================

# Free every name this file later defines as a function.
#
# This is a bare loop rather than a helper function on purpose. `cp` is an AllScope
# alias, so each scope holds its own copy; a removal issued from inside a helper drops
# only that call's copy and the global one survives — even with -Scope Global — and goes
# on shadowing `function cp`. Running at file scope works because profile.ps1 dot-sources
# the fragments at global scope. -Force is needed as well: many built-ins are ReadOnly.
foreach ($builtinAlias in @(
    'ls', 'cat', 'gc', 'gl', 'gp', 'gcm', 'h', 'history', 'ps', 'rm', 'cp', 'mv', 'diff', 'man',
    # `ni` is New-Item; without this, `function ni { npm install }` below never resolves.
    'ni'
)) {
    Remove-Alias -Name $builtinAlias -Scope Global -Force -ErrorAction SilentlyContinue
}

#---------------------------------------------------------------------------------------
# Listing — eza, matching the definitions in config/zsh/aliases.zsh
#---------------------------------------------------------------------------------------

if (Test-Command 'eza') {
    # Splatting only accepts an unqualified variable name (@name), never a scope-
    # qualified one (@script:name), so each function copies the base into a local first.
    $global:EzaBase = @('--color=auto', '--long', '--header', '--group', '--group-directories-first')

    function l   { $o = $global:EzaBase; eza @o @args }
    function ll  { $o = $global:EzaBase; eza @o --all @args }
    function lls { $o = $global:EzaBase; eza @o --all --sort size @args }
    function lt  { $o = $global:EzaBase; eza @o --all --reverse --sort oldest @args }
    function ld  { $o = $global:EzaBase; eza @o --all --only-dirs @args }
    function ls  { eza --color=auto --group-directories-first @args }

    # Dotfiles only — config/zsh/aliases.zsh:268. A period is legal in a PowerShell
    # function name, so this defines and invokes as plain `l.`.
    function l. { $o = $global:EzaBase; eza @o --list-dirs .* @args }

    # Tree views. `tree` keeps its level-2 default; the llt family matches the zsh
    # depth ladder (config/zsh/aliases.zsh:262-266).
    function tree  { eza --color=auto --tree --level=2 --group-directories-first @args }
    function llt   { eza --color=auto --tree --level=2 --git-ignore --ignore-glob=.git @args }
    function lllt  { eza --color=auto --tree --level=3 --git-ignore --ignore-glob=.git @args }
    function llllt { eza --color=auto --tree --level=4 --git-ignore --ignore-glob=.git @args }
} else {
    function l  { Get-ChildItem @args }
    function ll { Get-ChildItem -Force @args }
    function ls { Get-ChildItem @args }
}

#---------------------------------------------------------------------------------------
# Modern replacements for the classics — each guarded, each falling through to the
# PowerShell cmdlet when the tool is not installed.
#---------------------------------------------------------------------------------------

if (Test-Command 'bat') {
    function cat { bat --style=plain --paging=never @args }
    function less { bat --paging=always @args }
} else {
    function cat { Get-Content @args }
}

if (Test-Command 'rg')    { function grep { rg @args } }
if (Test-Command 'fd')    { function find { fd @args } }
if (Test-Command 'dust')  { function du   { dust @args } }
if (Test-Command 'duf')   { function df   { duf @args } }
if (Test-Command 'procs') { function ps   { procs @args } } else { function ps { Get-Process @args } }
if (Test-Command 'btm')   { function top  { btm @args } }
if (Test-Command 'xh')    { function http { xh @args } }
if (Test-Command 'doggo') { function dig  { doggo @args } }
if (Test-Command 'tldr')  { function man  { tldr @args } } else { function man { Get-Help @args } }

# Further wrappers from config/zsh/aliases.zsh:1728-1923. Each guarded at SOURCE time —
# the zsh originals check inside the function body only because zinit turbo means the
# binaries are not on PATH when aliases.zsh is sourced. PowerShell has no turbo, so the
# cheaper source-time guard used throughout this file is correct here.
if (Test-Command 'dust')       { function ncdu  { dust @args } }
if (Test-Command 'hyperfine')  { function bench { hyperfine @args } }
if (Test-Command 'lazydocker') { function lzd   { lazydocker @args } }
if (Test-Command 'gping')      { function ping  { gping @args } }
if (Test-Command 'hexyl')      { function xxd   { hexyl @args } }
if (Test-Command 'rga')        { function rga   { & (Get-CommandPath 'rga') @args } }
elseif (Test-Command 'rg')     { function rga   { rg @args } }
if (Test-Command 'batgrep')    { function bgrep { batgrep @args } }
if (Test-Command 'batdiff')    { function bdiff { batdiff @args } }
if (Test-Command 'batwatch')   { function bwatch { batwatch @args } }
if (Test-Command 'delta') {
    $env:GIT_PAGER = 'delta'
    function diff { delta @args }
} else {
    function diff { Compare-Object @args }
}

#---------------------------------------------------------------------------------------
# File operations
#
# The loop at the top frees rm/cp/mv so functions can take those names — but until a
# function actually claims one, the name simply stops resolving. These restore them.
#
# The wrappers exist because PowerShell cannot parse Unix short flags: `-rf` is an
# unknown parameter, and even a lone `-f` is an ambiguous prefix of -Filter and -Force.
#
# Switches are hoisted into a hashtable and splatted by name; what remains is splatted
# as an array of paths. Both halves matter — an array splat passes its elements
# POSITIONALLY, so a `-Recurse` left sitting in it would bind as a path, not a switch.
# That is why the long forms are hoisted alongside the short ones. The trade-off is that
# these wrappers understand switches and paths only: for -Filter, -Include and friends,
# call Remove-Item / Copy-Item / Move-Item directly.
#---------------------------------------------------------------------------------------

function script:ConvertFrom-UnixFlag {
    param([object[]] $Arguments)

    $switches = @{}
    $rest = [System.Collections.Generic.List[object]]::new()

    foreach ($arg in $Arguments) {
        if ($arg -is [string]) {
            # Long form, already spelled the PowerShell way.
            if ($arg -match '^-(Recurse|Force|Confirm|Verbose|WhatIf)$') {
                # Casing is whatever was typed; both hashtable keys and PowerShell
                # parameter binding are case-insensitive, so it does not matter.
                $switches[$Matches[1]] = $true
                continue
            }
            # Short-flag bundle: -r, -rf, -vf. Case-insensitive, so -R lands on 'r'.
            if ($arg -match '^-[rfiv]+$') {
                foreach ($flag in $arg.Substring(1).ToCharArray()) {
                    switch ($flag) {
                        'r' { $switches['Recurse'] = $true }
                        'f' { $switches['Force']   = $true }
                        'i' { $switches['Confirm'] = $true }
                        'v' { $switches['Verbose'] = $true }
                    }
                }
                continue
            }
        }
        $rest.Add($arg)
    }

    return @{ Switches = $switches; Rest = $rest.ToArray() }
}

function rm {
    $parsed = ConvertFrom-UnixFlag $args
    $sw = $parsed.Switches; $rest = $parsed.Rest
    Remove-Item @rest @sw
}

function cp {
    $parsed = ConvertFrom-UnixFlag $args
    $sw = $parsed.Switches; $rest = $parsed.Rest
    Copy-Item @rest @sw
}

function mv {
    $parsed = ConvertFrom-UnixFlag $args
    $sw = $parsed.Switches; $rest = $parsed.Rest
    # Move-Item has no -Recurse: a move is recursive by nature, so `mv -r` is just `mv`.
    $sw.Remove('Recurse')
    Move-Item @rest @sw
}

# `mkdir -pv` from config/zsh/aliases.zsh. New-Item already creates intermediate directories
# and echoes what it made, so the flags are swallowed rather than translated.
function mkdir {
    $paths = @($args | Where-Object { $_ -notmatch '^-[pv]+$' })
    New-Item -ItemType Directory -Path $paths -Force
}

# Create empty files, or bump the timestamp of ones that already exist.
function touch {
    foreach ($target in $args) {
        if (Test-Path -LiteralPath $target) {
            (Get-Item -LiteralPath $target).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $target -Force | Out-Null
        }
    }
}

#---------------------------------------------------------------------------------------
# Navigation
#---------------------------------------------------------------------------------------

function ..    { Set-Location .. }
function ...   { Set-Location ../.. }
function ....  { Set-Location ../../.. }

function mkcd {
    param([Parameter(Mandatory)][string] $Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -LiteralPath $Path
}

#---------------------------------------------------------------------------------------
# Git — mirrors the short aliases in config/zsh/aliases.zsh.
# Note `gc` and `gl` shadow built-in aliases removed above.
#
# `gcheck`, not `gco`, is plain `git checkout` — matching zsh, where forgit claims
# `gco` for its interactive commit-checkout picker. `gco` is deliberately left
# undefined here rather than bound to a different operation than it has in zsh.
#---------------------------------------------------------------------------------------

function gs { git status @args }
function gc { git commit -am @args }
function gd { git diff @args }
function gl { git log --graph --oneline --decorate --all @args }
function ga { git add @args }
function gcheck { git checkout @args }

# Staging
function gaa { git add --all @args }
function gap { git add --patch @args }
function grst { git restore --staged @args }   # `grs` belongs to forgit::restore

# Committing
function gcam { git commit -a --amend @args }
function gcan { git commit --amend --no-edit @args }

# Conventional-commit helper. Usage: gcm feat add user authentication
function gcm {
    param([Parameter(Mandatory)][string] $Type)
    git commit -m "${Type}: $($args -join ' ')"
}

# Branches
function b { git branch @args }
function c { git checkout @args }
function gcob { git checkout -b @args }
function gcom { git checkout master; if ($LASTEXITCODE -ne 0) { git checkout main } }

# Fetching, pulling, pushing
function gf  { git fetch @args }
function gfa { git fetch --all @args }
function gfp { git fetch --prune @args }
function gp  { git pull @args }
function gpl { git pull @args }

# Pushes the first time without needing `-u` spelled out, matching zsh's gpu.
function gpu {
    $branch = git symbolic-ref --short HEAD 2>$null
    $tracked = if ($branch) { git config "branch.${branch}.merge" 2>$null }
    if ($tracked) { git push @args } else { git push -u origin $branch @args }
}

# Log
function glg  { git log --graph --oneline --decorate @args }
function glga { git log --graph --oneline --decorate --all @args }
function glgp { git log -p @args }

# Stash
function gst  { git stash @args }
function gstp { git stash pop @args }
function gstl { git stash list @args }
function gsts { git stash show -p @args }

# Reset. `ghard` (git reset --hard) is deliberately absent: in zsh it routes through
# git_reset for a confirmation prompt, and an unguarded copy here would be a footgun.
function grsoft { git reset --soft @args }

# Work in progress
function gwip { git add -A; git commit -m 'WIP' --no-verify }
function gunwip {
    if ((git log -1 --pretty=%B) -match 'WIP') { git reset HEAD~1 }
}

# Jump to the repository root.
function groot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) {
        Write-Error 'Not in a git repository'
        return
    }
    Set-Location -LiteralPath $root
}
function gr { groot }

if (Test-Command 'lazygit') { function lg { lazygit @args } }

# Hard reset to HEAD~N, with a summary and confirmation — config/zsh/aliases.zsh:750.
#
# This is what makes `ghard` safe to define. The plain alias was deliberately absent
# before precisely because an unguarded `git reset --hard` is a footgun; the guard is
# the feature, so it is ported rather than the raw command.
function git_reset {
    param([int] $Count = 1)

    if (-not (git rev-parse --is-inside-work-tree 2>$null)) {
        Write-Error 'Not in a git repository'
        return
    }
    if ($Count -lt 1) { Write-Error 'git_reset: count must be >= 1'; return }

    $target = "HEAD~${Count}"
    if (-not (git rev-parse --verify --quiet $target 2>$null)) {
        Write-Error "git_reset: ${target} does not exist (not enough history)"
        return
    }

    $dropped = @(git log --oneline "${target}..HEAD")
    $dirty   = @(git status --porcelain)

    Write-Host "The following $($dropped.Count) commit(s) will be DROPPED:"
    $dropped | ForEach-Object { Write-Host "  $_" }
    if ($dirty.Count -gt 0) {
        Write-Host "…and $($dirty.Count) uncommitted change(s) will be DISCARDED." -ForegroundColor Yellow
    }

    if ((Read-Host "Hard reset to ${target}? (y/n)") -ne 'y') { Write-Host '❌ Cancelled'; return }
    git reset --hard $target
}

function gre   { git_reset @args }
function ghard { git_reset @args }

# Search every commit in history for a string.
function gse {
    param([Parameter(Mandatory)][string] $Pattern)
    git rev-list --all | git grep $Pattern --stdin
}
function git_search { gse @args }

# Clone, then cd into the directory git actually created.
function git-clone {
    git clone @args
    if ($LASTEXITCODE -ne 0) { return }

    # An explicit target dir is the last non-flag argument when there are two of them;
    # otherwise derive it from the URL, stripping .git and any --bare/--mirror suffix.
    $positional = @($args | Where-Object { $_ -notlike '-*' })
    $dir = if ($positional.Count -ge 2) {
        $positional[-1]
    } else {
        $name = ($positional[0] -split '[/:]')[-1] -replace '\.git$', ''
        if ($args -contains '--bare' -or $args -contains '--mirror') { "${name}.git" } else { $name }
    }

    if (Test-Path -LiteralPath $dir) { Set-Location -LiteralPath $dir }
    else { Write-Warning "git-clone: cloned, but could not resolve directory '${dir}'" }
}

function gpuf { git push --force @args }

# Stage everything and hand the commit message to Claude Code.
function cc {
    git status --short
    Write-Host '--- last commit ---'
    git log -1 --oneline
    git add -A
    claude -p '/commit'
}

#---------------------------------------------------------------------------------------
# Shell utilities
#---------------------------------------------------------------------------------------

function h { Get-History @args }
function history { Get-History @args }

# Reload the profile in place — the `exec zsh` equivalent, minus the exec.
function reload {
    if (Test-Path $PROFILE.CurrentUserAllHosts) {
        . $PROFILE.CurrentUserAllHosts
        Write-Host "✓ profile reloaded" -ForegroundColor Green
    }
}

# Print $env:PATH one entry per line — the `echo $path` habit from ZSH.
function path { $env:PATH -split [IO.Path]::PathSeparator }

function which {
    param([Parameter(Mandatory)][string] $Name)

    $cmd = Get-Command $Name -ErrorAction Ignore | Select-Object -First 1
    if (-not $cmd) {
        Write-Host "${Name} not found" -ForegroundColor Yellow
        return
    }
    if ($cmd.Source) { return $cmd.Source }
    return $cmd.Definition
}

function myip { (Invoke-RestMethod -Uri 'https://api.ipify.org').Trim() }
function myip_public { myip }

# The zsh version parses `ip -4 addr` / `ifconfig`; Windows has a real cmdlet.
function myip_local {
    if (Get-Command Get-NetIPAddress -ErrorAction Ignore) {
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -ExpandProperty IPAddress
    } elseif (Test-Command 'ip') {
        # pwsh-in-WSL
        (ip -4 -o addr show | ForEach-Object { ($_ -split '\s+')[3] -replace '/.*' }) |
            Where-Object { $_ -ne '127.0.0.1' }
    }
}

# Process grep — config/zsh/aliases.zsh:341
function psg {
    param([Parameter(Mandatory)][string] $Pattern)
    Get-Process | Where-Object { $_.ProcessName -match $Pattern } |
        Select-Object Id, ProcessName, @{n = 'WS(MB)'; e = { [math]::Round($_.WS / 1MB, 1) } } |
        Format-Table -AutoSize
}

# History grep — config/zsh/aliases.zsh:356
function hgrep {
    param([Parameter(Mandatory)][string] $Pattern)
    Get-History | Where-Object CommandLine -match $Pattern
}

# All listening TCP sockets — config/zsh/aliases.zsh:1411.
# Get-ListeningPort (defined below) already does the collection work.
function ports { Get-ListeningPort | Format-Table -AutoSize }

#---------------------------------------------------------------------------------------
# Backups — config/zsh/aliases.zsh:431,459
#---------------------------------------------------------------------------------------

# Swap file <-> file.bak. Three-way move, so running it twice returns to the start.
function bak {
    param([Parameter(Mandatory)][string] $Path)

    $target = $Path.TrimEnd('/', '\')
    $backup = "${target}.bak"

    if ((Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $backup)) {
        $tmp = "${target}.bak.swap"
        Move-Item -LiteralPath $backup -Destination $tmp
        Move-Item -LiteralPath $target -Destination $backup
        Move-Item -LiteralPath $tmp -Destination $target
        Write-Host "⇄ swapped ${target} and ${backup}"
    } elseif (Test-Path -LiteralPath $target) {
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "→ ${backup}"
    } elseif (Test-Path -LiteralPath $backup) {
        Move-Item -LiteralPath $backup -Destination $target
        Write-Host "→ ${target}"
    } else {
        Write-Error "bak: neither ${target} nor ${backup} exists"
    }
}

# Timestamped copy, leaving the original in place.
function bakt {
    param([Parameter(Mandatory)][string] $Path)

    $target = $Path.TrimEnd('/', '\')
    if (-not (Test-Path -LiteralPath $target)) { Write-Error "bakt: ${target} not found"; return }

    $dest = '{0}.{1}.bak' -f $target, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $target -Destination $dest -Recurse
    Write-Host "→ ${dest}"
}

# Where this profile was deployed FROM. After install the running profile is a local-disk
# copy (see install.ps1 §3), so $script:DotfilesRoot is that copy, not the git repo.
function Get-DotfilesSource {
    $marker = Join-Path $script:DotfilesRoot '.source'
    if (Test-Path -LiteralPath $marker) {
        $src = (Get-Content -LiteralPath $marker -Raw).Trim()
        if ($src) { return $src }
    }
    return $null
}

# cd to the git repo for editing, falling back to the deployed copy.
# The source lives in WSL, so it is only reachable while WSL is running.
function dotfiles {
    $src = Get-DotfilesSource
    if ($src -and (Test-Path -LiteralPath $src)) { Set-Location -LiteralPath $src; return }
    if ($src) { Write-Warning "dotfiles: source '${src}' unreachable (WSL not running?) — opening the deployed copy" }
    Set-Location -LiteralPath $script:DotfilesRoot
}

# Refresh the deployed copy from the repo, without a full install run.
# Use after editing powershell/*.ps1 in the repo: `dotsync; reload`.
function dotsync {
    $src = Get-DotfilesSource
    if (-not $src)                          { Write-Error 'dotsync: no .source marker — run install.ps1 first'; return }
    if (-not (Test-Path -LiteralPath $src)) { Write-Error "dotsync: source '${src}' unreachable (is WSL running?)"; return }

    # Globbed, not listed — see install.ps1 §3. A hardcoded list here cannot deploy a
    # fragment added after the running aliases.ps1 was copied, which is the one case that
    # matters: the new fragment is exactly what you are trying to sync.
    #
    # local.ps1 is excluded because it is machine-specific and exists only in the
    # deployed directory; install.ps1 because it is the bootstrap, not the profile.
    $n = 0
    foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $src 'powershell') -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notin @('local.ps1', 'install.ps1') })) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $script:ProfileDir $f.Name) -Force
        $n++
    }
    foreach ($rel in 'config/ripgrep/.ripgreprc', 'config/mise/config.toml', 'config/atuin', 'config/zsh/references') {
        $from = Join-Path $src $rel
        if (-not (Test-Path -LiteralPath $from)) { continue }
        $to = Join-Path $script:DotfilesRoot ($rel -replace '/', '\')
        $toParent = Split-Path -Parent $to
        if (-not (Test-Path -LiteralPath $toParent)) { New-Item -ItemType Directory -Path $toParent -Force | Out-Null }
        Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
    }

    Get-ChildItem -LiteralPath $script:DotfilesRoot -Recurse -File -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue

    Write-Host "✓ synced ${n} file(s) from ${src}" -ForegroundColor Green
    Write-Host "  run 'reload' to apply" -ForegroundColor DarkGray
}

#---------------------------------------------------------------------------------------
# Ports — mirrors `lsp` and `killport` in config/zsh/aliases.zsh
#---------------------------------------------------------------------------------------

function Get-ListeningPort {
    # Windows has the real API. On pwsh-in-WSL (or Linux) Get-NetTCPConnection does not
    # exist, so fall back to lsof and parse it the same way the zsh helper does.
    if (Get-Command Get-NetTCPConnection -ErrorAction Ignore) {
        # One Get-Process call up front: resolving names per-connection is O(n) spawns.
        $names = @{}
        Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $names[$_.Id] = $_.ProcessName }

        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            $owner = [int] $_.OwningProcess
            [pscustomobject]@{
                Port      = [int] $_.LocalPort
                ProcessId = $owner
                Command   = if ($names.ContainsKey($owner)) { $names[$owner] } else { '?' }
                Address   = '{0}:{1}' -f $_.LocalAddress, $_.LocalPort
            }
        } | Sort-Object Port, ProcessId -Unique
        return
    }

    if (Test-Command 'lsof') {
        # +c 0 stops lsof truncating COMMAND to 9 characters. A LISTEN row ends in a
        # literal "(LISTEN)" column, so strip that before taking the address field.
        lsof +c 0 -nP -iTCP -sTCP:LISTEN 2>$null | Select-Object -Skip 1 | ForEach-Object {
            $fields = ($_ -replace '\s*\(LISTEN\)\s*$', '') -split '\s+'
            $addr = $fields[-1]
            [pscustomobject]@{
                Port      = [int] ($addr -split ':')[-1]
                ProcessId = [int] $fields[1]
                Command   = $fields[0]
                Address   = $addr
            }
        } | Sort-Object Port, ProcessId -Unique
    }
}

# Port listening checker — the `lsp` alias from config/zsh/aliases.zsh
function lsp { Get-ListeningPort | Format-Table -AutoSize }

# Kill process by port number.
# With a port argument it kills whatever is listening there. With no argument it opens
# an fzf picker over the listening sockets — Tab to select several, Enter to confirm.
# Usage: killport [port]
# Example: killport 3000
#          killport          # pick interactively
function killport {
    param([int] $Port = 0)

    $listeners = @(Get-ListeningPort)
    if ($listeners.Count -eq 0) {
        Write-Host '❌ No listening ports found'
        return
    }

    $targets = @()

    if ($Port -gt 0) {
        $targets = @($listeners | Where-Object { $_.Port -eq $Port })
        if ($targets.Count -eq 0) {
            Write-Host "❌ No process found on port ${Port}"
            return
        }
    } else {
        if (-not (Test-Command 'fzf')) {
            Write-Host 'Usage: killport <port>'
            Write-Host '(install fzf to pick a port interactively)'
            return
        }

        $rows = $listeners | ForEach-Object {
            '{0,-7} {1,-8} {2,-22} {3}' -f $_.Port, $_.ProcessId, $_.Command, $_.Address
        }
        $picked = @($rows | fzf --multi --exit-0 `
            --header='PORT    PID      COMMAND                ADDRESS' `
            --height=40% --layout=reverse --border --info=inline)

        # Esc / Ctrl-C returns nothing.
        if ($picked.Count -eq 0) {
            Write-Host '❌ Cancelled'
            return
        }

        $pickedIds = $picked | ForEach-Object { [int] (($_ -split '\s+')[1]) }
        $targets = @($listeners | Where-Object { $pickedIds -contains $_.ProcessId })
    }

    # One process often listens on several ports; without -Unique it would be reported
    # killed once per selected row.
    $ids = @($targets | Select-Object -ExpandProperty ProcessId -Unique)

    Write-Host 'Selected:'
    foreach ($t in $targets) {
        Write-Host ('  {0,-7} {1,-8} {2,-22} {3}' -f $t.Port, $t.ProcessId, $t.Command, $t.Address)
    }

    $confirm = Read-Host "Kill $($ids.Count) process(es)? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host '❌ Cancelled'
        return
    }

    foreach ($id in $ids) {
        try {
            Stop-Process -Id $id -Force -ErrorAction Stop
            Write-Host "✓ Killed ${id}"
        } catch {
            Write-Host "⚠ Could not kill ${id} (try an elevated shell)"
        }
    }
}

#---------------------------------------------------------------------------------------
# WSL interop — the counterpart to the pwsh.exe calls already in .zshrc
#---------------------------------------------------------------------------------------

if (Test-Command 'wsl') {
    function wsls  { wsl --list --verbose }
    function wslsd { wsl --shutdown }
}

#---------------------------------------------------------------------------------------
# Docker — config/zsh/aliases.zsh:1048-1310
#
# Guarded as a block: the Windows session this targets is used for Node work, so on a
# machine without Docker Desktop none of these are defined rather than being defined and
# failing at call time.
#
# The zsh `dc` prefixes IP_ADDRESS=$(ip route list default…) — Linux iproute2. The
# equivalent here is Get-NetRoute, computed once per call and only when something is
# actually going to read it.
#---------------------------------------------------------------------------------------

if (Test-Command 'docker') {

    function script:Get-DockerHostIp {
        if (-not (Get-Command Get-NetRoute -ErrorAction Ignore)) { return $null }
        $idx = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric | Select-Object -First 1).InterfaceIndex
        if (-not $idx) { return $null }
        (Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object -First 1).IPAddress
    }

    function dc {
        $ip = Get-DockerHostIp
        if ($ip) { $env:IP_ADDRESS = $ip }
        docker compose @args
    }

    function dcu {
        # Mirrors the zsh helper: a project-local docker.sh wins over a bare `up -d`.
        if (Test-Path 'docker/docker.sh')  { & 'docker/docker.sh' @args; return }
        if (Test-Path './docker.sh')       { & './docker.sh' @args; return }
        dc up -d @args
    }

    function dce   { dc exec @args }
    function dclo  { dc logs -tf @args }
    function dcp   { dc ps @args }

    function script:Get-DcContainerId {
        param([Parameter(Mandatory)][string] $Service)
        $id = (dc ps -q $Service 2>$null | Select-Object -First 1)
        if (-not $id) { Write-Error "No running container for service '${Service}'" }
        return $id
    }

    function dexec {
        param([Parameter(Mandatory)][string] $Service)
        $id = Get-DcContainerId $Service
        if ($id) { docker exec -it $id @($args) }
    }

    function drexec {
        param([Parameter(Mandatory)][string] $Service)
        $id = Get-DcContainerId $Service
        if ($id) { docker exec -it --user root $id @($args) }
    }

    function dceb  { dexec @args /bin/bash }
    function dcebr { drexec @args /bin/bash }

    function dl  { docker ps -l -q @args }
    function dps { docker ps @args }
    function dpa { docker ps -a @args }
    function di  { docker images @args }

    function dip {
        docker inspect --format '{{.Name}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' `
            @(docker ps -q)
    }

    function dstop {
        $running = @(docker ps -q)
        if ($running.Count -eq 0) { Write-Host 'No running containers'; return }
        docker ps
        if ((Read-Host "Stop $($running.Count) container(s)? (y/n)") -ne 'y') { Write-Host '❌ Cancelled'; return }
        docker stop @running
    }

    function drmf {
        $all = @(docker ps -aq)
        if ($all.Count -eq 0) { Write-Host 'No containers'; return }
        docker ps -a
        if ((Read-Host "Stop AND REMOVE $($all.Count) container(s)? (y/n)") -ne 'y') { Write-Host '❌ Cancelled'; return }
        docker stop @all
        docker rm @all
    }

    function docker-clean {
        Write-Host 'This removes ALL images, containers, networks and volumes.' -ForegroundColor Yellow
        if ((Read-Host 'Prune ALL Docker data? (y/n)') -ne 'y') { Write-Host '❌ Cancelled'; return }
        docker system prune -af --volumes
    }
}

#---------------------------------------------------------------------------------------
# Editor dispatch
#
# $env:EDITOR may carry flags ('code --wait'), which `& $env:EDITOR file` cannot run —
# PowerShell would look for an executable literally named "code --wait". Split it.
#---------------------------------------------------------------------------------------

function Invoke-Editor {
    param([Parameter(Mandatory)][string[]] $Path)

    if (-not $env:EDITOR) {
        Write-Warning 'No $env:EDITOR set (see tools.ps1); falling back to notepad.'
        notepad @Path
        return
    }

    $parts = $env:EDITOR -split '\s+' | Where-Object { $_ }
    $exe   = $parts[0]
    $flags = @($parts | Select-Object -Skip 1)
    & $exe @flags @Path
}

#---------------------------------------------------------------------------------------
# Node — npm / yarn / pnpm, mirroring config/zsh/aliases.zsh:623-665
#
# Unguarded on purpose. These are one-line pass-throughs, and a "npm is not recognised"
# from the shell is a clearer error than a missing function; guarding each on
# Test-Command would also hide them when a version manager puts npm on PATH later.
#---------------------------------------------------------------------------------------

# npm
function ni   { npm install @args }
function nid  { npm install --save-dev @args }
function nig  { npm install -g @args }
function nrd  { npm run dev @args }
function nrb  { npm run build @args }
function nrs  { npm run start @args }
function nrt  { npm run test @args }
function nrl  { npm run lint @args }
function nrf  { npm run format @args }
function nci  { npm ci @args }                  # clean install from package-lock.json
function ncc  { npm cache clean --force @args }
function nou  { npm outdated @args }
function nup  { npm update @args }

# yarn
function yi    { yarn install @args }
function yag   { yarn global add @args }
function yrm   { yarn remove @args }
function yup   { yarn upgrade @args }
function yui   { yarn upgrade-interactive @args }
function yout  { yarn outdated @args }
function ycc   { yarn cache clean @args }
function yd    { yarn dev @args }
function yb    { yarn build @args }

# pnpm
function pi    { pnpm install @args }
function pna   { pnpm add @args }
function pnad  { pnpm add -D @args }
function pr    { pnpm remove @args }

# package.json
function pkg  { Invoke-Editor 'package.json' }
function pkgj {
    if (Test-Command 'jq') { Get-Content -Raw package.json | jq @args }
    else { Get-Content -Raw package.json | ConvertFrom-Json | ConvertTo-Json -Depth 100 }
}

# Smart package-manager runner — config/zsh/aliases.zsh:1535
#
# bun is checked first: it writes bun.lockb (<1.2) or bun.lock (1.2+), but bun projects
# frequently still carry a package-lock.json from before the switch, which would
# otherwise fall through to npm.
function run {
    if ($args.Count -lt 1) {
        Write-Host 'Usage: run <script>'
        Write-Host 'Example: run dev'
        return
    }

    if ((Test-Path 'bun.lockb') -or (Test-Path 'bun.lock')) {
        Write-Host '📦 Using Bun'; bun run @args
    } elseif (Test-Path 'yarn.lock') {
        Write-Host '📦 Using Yarn'; yarn @args
    } elseif (Test-Path 'pnpm-lock.yaml') {
        Write-Host '📦 Using pnpm'; pnpm @args
    } elseif ((Test-Path 'package-lock.json') -or (Test-Path 'package.json')) {
        Write-Host '📦 Using npm'; npm run @args
    } else {
        Write-Host '❌ No package.json found'
    }
}

#---------------------------------------------------------------------------------------
# Development workflow — config/zsh/aliases.zsh:1422-1727
#---------------------------------------------------------------------------------------

# 7-Zip installs to Program Files without adding itself to PATH, so Test-Command '7z'
# is false on a machine that has it. Probe the standard locations too, and memoize —
# extract may call this several times per invocation.
$script:SevenZipPath = $null
function script:Resolve-SevenZip {
    if ($script:SevenZipPath) { return $script:SevenZipPath }

    $found = Get-CommandPath '7z'
    if (-not $found) {
        $candidates = @(
            (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
            (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        $found = $candidates | Select-Object -First 1
    }

    $script:SevenZipPath = $found
    return $found
}

# Extract any archive. Prefers ouch (universal decompressor); the per-format fallbacks
# below are the WINDOWS toolbox, not the Unix one from zsh — tar ships with Windows 10+,
# Expand-Archive handles .zip natively, and 7z covers the rest.
function extract {
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "File '${Path}' not found"
        return
    }

    if (Test-Command 'ouch') { ouch decompress $Path; return }

    # `break` in every branch is load-bearing: switch -Regex runs EVERY matching branch,
    # and "x.tar.gz" matches both the tar pattern and the bare .gz one — without break it
    # would untar the archive and then hand the same file to 7z.
    $full = (Resolve-Path -LiteralPath $Path).Path
    $sevenZip = Resolve-SevenZip
    switch -Regex ($full) {
        '\.(tar\.(gz|bz2|xz|zst)|tgz|tbz2|tar)$' { tar -xf $full; break }
        '\.zip$' {
            if ($sevenZip) { & $sevenZip x $full } else { Expand-Archive -LiteralPath $full -Force }
            break
        }
        '\.(7z|rar|gz|bz2|xz|zst|lz4|Z)$' {
            if ($sevenZip) { & $sevenZip x $full }
            else { Write-Error "extract: 7-Zip is required for '${Path}' (winget install 7zip.7zip)" }
            break
        }
        default { Write-Error "Cannot extract '${Path}' - unknown format" }
    }
}

# Decompress into a directory named after the archive.
function unzipd {
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "File '${Path}' not found"
        return
    }

    # Strip compound suffixes (.tar.gz -> name), matching the zsh helper.
    $dir = [IO.Path]::GetFileName($Path) -replace '\.(tar\.(gz|bz2|xz|zst)|tgz|tbz2|tar|zip|7z|rar)$', ''

    if (Test-Command 'ouch') { ouch decompress --dir $dir $Path; return }
    Expand-Archive -LiteralPath $Path -DestinationPath $dir -Force
}

# Quick HTTP server in the current directory.
# `python3` is frequently absent on Windows even when Python is installed, so probe the
# names Windows actually ships (`py` launcher, bare `python`) before giving up.
function serve {
    param([int] $Port = 8000)

    $py = @('python3', 'python', 'py') | Where-Object { Test-Command $_ } | Select-Object -First 1
    if (-not $py) {
        if (Test-Command 'npx') {
            Write-Host "🌐 Starting HTTP server on http://localhost:${Port} (npx serve)"
            npx --yes serve --listen $Port .
            return
        }
        Write-Error 'serve: no python or npx found'
        return
    }

    Write-Host "🌐 Starting HTTP server on http://localhost:${Port}"
    & $py -m http.server $Port
}

# Generate a random password.
# The zsh version shells out to openssl, which is not standard on Windows; .NET's CSPRNG
# is always available and avoids the dependency entirely.
function genpass {
    param([int] $Length = 20)

    # Same alphabet as the zsh helper: base64 minus the +/= characters.
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
    $bytes = [byte[]]::new($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)

    # Reject-free modulo bias is not a concern at this alphabet size for a shell helper,
    # but taking the byte modulo the alphabet length keeps the distribution near-uniform.
    -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
}

# Quick note taking — dated markdown under ~/notes.
function note {
    $notesDir = Join-Path $HOME 'notes'
    if (-not (Test-Path $notesDir)) { New-Item -ItemType Directory -Path $notesDir -Force | Out-Null }

    if ($args.Count -eq 0) {
        Write-Host '📝 Recent notes:'
        Get-ChildItem -LiteralPath $notesDir -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10 Name, LastWriteTime, Length |
            Format-Table -AutoSize
        return
    }

    $slug = $args -join '-'
    $noteFile = Join-Path $notesDir ('{0}-{1}.md' -f (Get-Date -Format 'yyyy-MM-dd'), $slug)
    if (-not (Test-Path -LiteralPath $noteFile)) {
        Set-Content -LiteralPath $noteFile -Encoding UTF8 -Value @(
            "# ${slug}", '', "Date: $(Get-Date)", ''
        )
    }
    Invoke-Editor $noteFile
}

# Quick directory size check.
function dirsize {
    if (Test-Command 'dust') {
        if ($args.Count -lt 1) { dust -d 1 } else { dust -d 1 @args }
        return
    }

    $targets = if ($args.Count -lt 1) { Get-ChildItem -Directory } else { $args | Get-Item }
    $targets | ForEach-Object {
        $bytes = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        [pscustomobject]@{
            Size = '{0,8:N1} MB' -f ($bytes / 1MB)
            Name = $_.Name
        }
    } | Sort-Object { [double]($_.Size -replace '[^\d.]') } -Descending | Format-Table -AutoSize
}

# Find and replace text across files, with confirmation.
function replace-in-files {
    param(
        [Parameter(Mandatory)][string] $Search,
        [Parameter(Mandatory)][string] $Replace,
        [string] $Pattern = '*'
    )

    if (-not (Test-Command 'rg')) { Write-Error 'replace-in-files: ripgrep (rg) is required'; return }

    $files = @(rg --files-with-matches --fixed-strings --glob $Pattern -- $Search 2>$null)
    if ($files.Count -eq 0) { Write-Host "No files matching '${Search}'"; return }

    Write-Host "Found ${Search} in $($files.Count) file(s):"
    $files | ForEach-Object { Write-Host "  $_" }

    if ((Read-Host "Replace with '${Replace}'? (y/n)") -ne 'y') { Write-Host '❌ Cancelled'; return }

    foreach ($file in $files) {
        # -Raw + literal Replace() avoids regex-escaping bugs on both search and
        # replacement, which is the same reason the zsh helper uses perl -0777 over sed.
        $content = Get-Content -LiteralPath $file -Raw
        Set-Content -LiteralPath $file -Value $content.Replace($Search, $Replace) -NoNewline
    }
    Write-Host "✓ Replaced in $($files.Count) file(s)"
}

# Kill a process interactively with fzf — the counterpart to killport.
function killp {
    if (-not (Test-Command 'fzf')) { Write-Error 'killp: fzf is required'; return }

    $rows = Get-Process | Sort-Object -Property WS -Descending | ForEach-Object {
        '{0,-8} {1,-30} {2,10:N1} MB' -f $_.Id, $_.ProcessName, ($_.WS / 1MB)
    }

    $picked = @($rows | fzf --multi --exit-0 `
        --header='PID      NAME                                   MEMORY' `
        --height=40% --layout=reverse --border --info=inline)

    if ($picked.Count -eq 0) { Write-Host '❌ Cancelled'; return }

    $ids = @($picked | ForEach-Object { [int] (($_ -split '\s+')[0]) })
    if ((Read-Host "Kill $($ids.Count) process(es)? (y/n)") -ne 'y') { Write-Host '❌ Cancelled'; return }

    foreach ($id in $ids) {
        try { Stop-Process -Id $id -Force -ErrorAction Stop; Write-Host "✓ Killed ${id}" }
        catch { Write-Host "⚠ Could not kill ${id} (try an elevated shell)" }
    }
}

#---------------------------------------------------------------------------------------
# ref — cheat-sheet viewer over config/zsh/references/*.md
#
# The reference files are shell-agnostic markdown, so both shells read the same tracked
# copies. Path is derived from $script:DotfilesRoot rather than ZDOTDIR, which pwsh has no
# equivalent of.
#---------------------------------------------------------------------------------------

function script:Show-RefUsage {
    Write-Host @'
Usage: ref <topic>           Print reference content to stdout
       ref -e <topic>        Open reference in $env:EDITOR
       ref -ls | --list      List all available reference topics
       ref --help | -h       Show this help message

Examples:
  ref fd                     Print the fd cheat sheet
  ref -e rg                  Edit the rg reference in $env:EDITOR
  ref --list                 Show all available topics
'@
}

function ref {
    $referencesDir = Join-Path $script:DotfilesRoot 'config/zsh/references'

    if ($args.Count -eq 0) { Show-RefUsage; return }

    switch ($args[0]) {
        { $_ -in '--help', '-h' } { Show-RefUsage; return }

        { $_ -in '-ls', '--list' } {
            if (-not (Test-Path $referencesDir)) { Write-Error "ref: no references at ${referencesDir}"; return }
            Write-Host 'Available reference topics:'
            Get-ChildItem -LiteralPath $referencesDir -Filter '*.md' |
                ForEach-Object { Write-Host "  $($_.BaseName)" }
            return
        }

        '-e' {
            if ($args.Count -lt 2) { Write-Error 'ref -e: no topic given'; return }
            if (-not (Test-Path $referencesDir)) {
                New-Item -ItemType Directory -Path $referencesDir -Force | Out-Null
            }
            $target = Join-Path $referencesDir "$($args[1]).md"
            if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType File -Path $target -Force | Out-Null }
            Invoke-Editor $target
            return
        }

        default {
            $target = Join-Path $referencesDir "$($args[0]).md"
            if (-not (Test-Path -LiteralPath $target)) {
                Write-Error "ref: no reference for '$($args[0])' (try: ref --list)"
                return
            }
            # bat renders the markdown; plain Get-Content is the guaranteed fallback.
            if (Test-Command 'bat') { bat --style=plain --paging=auto --language=markdown $target }
            else { Get-Content -LiteralPath $target }
        }
    }
}
