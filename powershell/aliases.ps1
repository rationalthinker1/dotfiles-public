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
    'ls', 'cat', 'gc', 'gl', 'gp', 'gcm', 'h', 'history', 'ps', 'rm', 'cp', 'mv', 'diff', 'man'
)) {
    Remove-Alias -Name $builtinAlias -Scope Global -Force -ErrorAction SilentlyContinue
}

#---------------------------------------------------------------------------------------
# Listing — eza, matching the definitions in zsh/aliases.zsh
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
    function tree { eza --color=auto --tree --level=2 --group-directories-first @args }
    function ls  { eza --color=auto --group-directories-first @args }
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

# `mkdir -pv` from zsh/aliases.zsh. New-Item already creates intermediate directories
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
# Git — mirrors the short aliases in zsh/aliases.zsh.
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

# Open the dotfiles repo, wherever it is mounted.
function dotfiles { Set-Location -LiteralPath $script:DotfilesRoot }

#---------------------------------------------------------------------------------------
# Ports — mirrors `lsp` and `killport` in zsh/aliases.zsh
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

# Port listening checker — the `lsp` alias from zsh/aliases.zsh
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
