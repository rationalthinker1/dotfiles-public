#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstrap the PowerShell side of this dotfiles repo.

.DESCRIPTION
    Idempotent by design — safe to re-run whenever tools or modules need refreshing.
    Every step checks for existing state first and reports what it skipped.

    Run from a native Windows PowerShell 7 session:
        pwsh -File .\powershell\install.ps1

.PARAMETER SkipTools
    Skip the winget CLI-tool installation step (modules and profile linking still run).
#>
[CmdletBinding()]
param(
    [switch] $SkipTools
)

$ErrorActionPreference = 'Stop'
$script:DotfilesRoot = Split-Path -Parent $PSScriptRoot
$script:Skipped = @()
$script:Installed = @()
$script:Failed = @()

function Write-Step { param([string] $Message) Write-Host "`n▶ ${Message}" -ForegroundColor Cyan }
function Write-Ok   { param([string] $Message) Write-Host "  ✓ ${Message}" -ForegroundColor Green }
function Write-Skip { param([string] $Message) Write-Host "  • ${Message}" -ForegroundColor DarkGray }
function Write-Warn { param([string] $Message) Write-Host "  ⚠ ${Message}" -ForegroundColor Yellow }

#---------------------------------------------------------------------------------------
# 1. PowerShell modules
#---------------------------------------------------------------------------------------

Write-Step 'PowerShell modules'

$modules = @(
    @{ Name = 'PSReadLine';          Min = '2.3.4'; Why = 'autosuggestions, syntax colour, history' }
    @{ Name = 'PSFzf';               Min = '2.5.0'; Why = 'fzf integration (Ctrl+T, fuzzy tab)' }
    @{ Name = 'CompletionPredictor'; Min = '0.1.1'; Why = 'IntelliSense-style completion predictions' }
    @{ Name = 'posh-git';            Min = '1.1.0'; Why = 'git argument completers' }
)

# Install-PSResource (PSResourceGet) is the modern path; fall back to PowerShellGet.
$useResourceGet = [bool](Get-Command Install-PSResource -ErrorAction SilentlyContinue)

foreach ($module in $modules) {
    $existing = Get-Module -ListAvailable -Name $module.Name |
        Sort-Object Version -Descending | Select-Object -First 1

    if ($existing -and $existing.Version -ge [version]$module.Min) {
        Write-Skip "$($module.Name) $($existing.Version) already present"
        $script:Skipped += $module.Name
        continue
    }

    try {
        if ($useResourceGet) {
            Install-PSResource -Name $module.Name -Scope CurrentUser -TrustRepository -Reinstall:$false -ErrorAction Stop
        } else {
            Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        Write-Ok "$($module.Name) — $($module.Why)"
        $script:Installed += $module.Name
    } catch {
        Write-Warn "$($module.Name) failed: $($_.Exception.Message)"
        $script:Failed += $module.Name
    }
}

#---------------------------------------------------------------------------------------
# 2. CLI tools via winget, falling back to scoop
#
# Packages are checked against the installed command name first, so an equivalent already
# installed by scoop/chocolatey/mise is left alone. A failed package is reported, never
# fatal — package ids drift, and one bad id must not abort the whole bootstrap.
#
# Each entry carries the id for BOTH package managers:
#   Winget = $null   the tool is not in the winget repository at all; only scoop has it
#   Scoop  = $null   no scoop fallback known (or not needed)
#   Probe            extra paths to treat as "already installed", for packages that do
#                    not put their binary on PATH
#---------------------------------------------------------------------------------------

# Get-Command alone is not enough: 7-Zip installs to Program Files without touching PATH,
# so a PATH-only check would reinstall it on every bootstrap and report a failure each
# time (winget exits non-zero for an already-installed package). Probe covers that.
function Test-ToolPresent {
    param([Parameter(Mandatory)][hashtable] $Tool)

    if (Get-Command $Tool.Command -CommandType Application -ErrorAction SilentlyContinue) {
        return $true
    }
    foreach ($candidate in @($Tool.Probe)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $true }
    }
    return $false
}

if (-not $SkipTools) {
    Write-Step 'CLI tools (winget → scoop)'

    $hasWinget = [bool] (Get-Command winget -ErrorAction SilentlyContinue)
    $hasScoop  = [bool] (Get-Command scoop  -ErrorAction SilentlyContinue)

    if (-not $hasWinget -and -not $hasScoop) {
        Write-Warn 'neither winget nor scoop found — install App Installer from the Microsoft Store, or scoop from https://scoop.sh'
    } else {
        if (-not $hasWinget) { Write-Warn 'winget not found — using scoop where a package is known' }

        $tools = @(
            @{ Command = 'fzf';         Winget = 'junegunn.fzf';            Scoop = 'fzf' }
            @{ Command = 'zoxide';      Winget = 'ajeetdsouza.zoxide';      Scoop = 'zoxide' }
            @{ Command = 'atuin';       Winget = 'Atuinsh.Atuin';           Scoop = 'atuin' }
            @{ Command = 'bat';         Winget = 'sharkdp.bat';             Scoop = 'bat' }
            @{ Command = 'fd';          Winget = 'sharkdp.fd';              Scoop = 'fd' }
            @{ Command = 'rg';          Winget = 'BurntSushi.ripgrep.MSVC'; Scoop = 'ripgrep' }
            @{ Command = 'eza';         Winget = 'eza-community.eza';       Scoop = 'eza' }
            @{ Command = 'delta';       Winget = 'dandavison.delta';        Scoop = 'delta' }
            @{ Command = 'jq';          Winget = 'jqlang.jq';               Scoop = 'jq' }
            @{ Command = 'gh';          Winget = 'GitHub.cli';              Scoop = 'gh' }
            # lazygit is the one name here NOT in scoop's `main` bucket; Bucket makes the
            # scoop route add `extras` first, but only if that fallback actually fires.
            @{ Command = 'lazygit';     Winget = 'JesseDuffield.lazygit';   Scoop = 'lazygit'; Bucket = 'extras' }
            @{ Command = 'oh-my-posh';  Winget = 'JanDeDobbeleer.OhMyPosh'; Scoop = 'oh-my-posh' }

            # Tools that aliases.ps1 already wraps. Without these the wrappers are dead:
            # du/df/top/http/dig have no fallback branch, so the names simply stop
            # resolving on a machine where the guard is false.
            @{ Command = 'dust';        Winget = 'bootandy.dust';           Scoop = 'dust' }      # du
            @{ Command = 'duf';         Winget = 'muesli.duf';              Scoop = 'duf' }       # df
            @{ Command = 'procs';       Winget = 'dalance.procs';           Scoop = 'procs' }     # ps
            @{ Command = 'btm';         Winget = 'Clement.bottom';          Scoop = 'bottom' }    # top
            @{ Command = 'xh';          Winget = 'ducaale.xh';              Scoop = 'xh' }        # http
            @{ Command = 'doggo';       Winget = 'MrKaran.Doggo';           Scoop = 'doggo' }     # dig
            @{ Command = 'tldr';        Winget = 'dbrgn.tealdeer';          Scoop = 'tealdeer' }  # man
            @{ Command = 'sd';          Winget = 'chmln.sd';                Scoop = 'sd' }        # replace-in-files
            @{ Command = 'mise';        Winget = 'jdx.mise';                Scoop = 'mise' }      # completions in tools.ps1

            # Previously unlisted or problematic tools resolved below:
            #   ouch — not in the winget repository at all, so scoop is the only route.
            #   7z   — winget has it, but installs to Program Files WITHOUT touching
            #          PATH. Probe is what stops that looking uninstalled on every run:
            #          without it the next bootstrap retries winget (which exits non-zero
            #          for an already-installed package) and then falls through to scoop,
            #          landing a second copy. A scoop install shims 7z onto PATH and is
            #          found by the Get-Command check regardless.
            @{ Command = 'ouch';        Winget = $null;                     Scoop = 'ouch' }
            @{ Command = '7z';          Winget = '7zip.7zip';               Scoop = '7zip'
               Probe = @(
                   (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
                   (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
               ) }
        )

        foreach ($tool in $tools) {
            if (Test-ToolPresent $tool) {
                Write-Skip "$($tool.Command) already installed"
                $script:Skipped += $tool.Command
                continue
            }

            # NOT named $installed: this loop runs at SCRIPT scope, and PowerShell
            # variable names are case-insensitive, so `$installed` and the `$script:Installed`
            # results array are the same variable. Assigning $false to it replaced the
            # array with a Boolean, and the next `$script:Installed += 'delta'` became
            # `$false + 'delta'` — Boolean arithmetic — throwing "Cannot convert value
            # 'delta' to type System.Int32". The throw skipped the success flag, so scoop
            # then reinstalled everything winget had just installed.
            $toolResolved = $false
            $reasons = @()

            if ($hasWinget -and $tool.Winget) {
                try {
                    $null = winget install --exact --id $tool.Winget `
                        --accept-source-agreements --accept-package-agreements `
                        --disable-interactivity 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Ok "$($tool.Command) (winget: $($tool.Winget))"
                        $script:Installed += $tool.Command
                        $toolResolved = $true
                    } else {
                        $reasons += "winget exit $LASTEXITCODE for '$($tool.Winget)'"
                    }
                } catch {
                    $reasons += "winget: $($_.Exception.Message)"
                }
            } elseif (-not $tool.Winget) {
                $reasons += 'no winget package'
            }

            # Scoop is tried whenever winget did not land it — a missing id, a drifted
            # id, or no winget at all all end up here.
            if (-not $toolResolved -and $hasScoop -and $tool.Scoop) {
                try {
                    # Every other package lives in `main`, which scoop adds itself. Only
                    # pull in an extra bucket when the entry names one and it is absent.
                    #
                    # `scoop bucket list` returns PSCustomObjects with a .Name on current
                    # scoop and bare strings on older builds, so normalise both shapes —
                    # reading .Name off a string yields $null and would re-add the bucket
                    # on every run.
                    if ($tool.Bucket) {
                        $buckets = @(scoop bucket list 6>$null | ForEach-Object {
                            if ($_ -is [string]) { $_.Trim() } else { $_.Name }
                        })
                        if ($tool.Bucket -notin $buckets) {
                            Write-Step "adding scoop bucket '$($tool.Bucket)' for $($tool.Command)"
                            $null = scoop bucket add $tool.Bucket 2>&1
                        }
                    }

                    $null = scoop install $tool.Scoop 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Ok "$($tool.Command) (scoop: $($tool.Scoop))"
                        $script:Installed += $tool.Command
                        $toolResolved = $true
                    } else {
                        $reasons += "scoop exit $LASTEXITCODE for '$($tool.Scoop)'"
                    }
                } catch {
                    $reasons += "scoop: $($_.Exception.Message)"
                }
            }

            if (-not $toolResolved) {
                if (-not $tool.Winget -and -not $hasScoop) {
                    # Nothing could have worked; say so rather than calling it a failure.
                    Write-Skip "$($tool.Command) needs scoop (scoop install $($tool.Scoop))"
                    $script:Skipped += $tool.Command
                } else {
                    Write-Warn "$($tool.Command): $($reasons -join '; ')"
                    $script:Failed += $tool.Command
                }
            }
        }
    }
} else {
    Write-Step 'CLI tools — skipped (-SkipTools)'
}

#---------------------------------------------------------------------------------------
# 3. Deploy the profile to LOCAL DISK
#
# The shell must not depend on WSL. Pointing $PROFILE at the repo over \\wsl.localhost\
# fails in three separate ways, all of them silent or confusing:
#
#   1. WSL shut down  -> the profile cannot be read at all.
#   2. Execution policy -> a UNC path is the "Internet" zone, so every fragment is
#      refused as "not digitally signed", even with the repo fully trusted.
#   3. Speed -> every shell start pays 9p/UNC round-trips for five files.
#
# So the tracked files are COPIED to local disk and $PROFILE points there. After
# install, nothing the profile touches lives in WSL.
#
# Destination is %LOCALAPPDATA%, deliberately not Documents\PowerShell: Documents is
# OneDrive-redirected on this machine, which adds cloud sync and its own placeholder
# problems to something that must simply always be readable.
#
# The repo layout is mirrored (dotfiles\powershell\ + dotfiles\config\) so profile.ps1's
# `DotfilesRoot = Split-Path $ProfileDir` keeps working unchanged, and the shared tool
# configs it points at resolve locally too.
#---------------------------------------------------------------------------------------

Write-Step 'Deploy to local disk'

$deployRoot  = Join-Path $env:LOCALAPPDATA 'dotfiles'
$deployPwsh  = Join-Path $deployRoot 'powershell'
$repoRoot    = Split-Path -Parent $PSScriptRoot

foreach ($d in @($deployRoot, $deployPwsh)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Globbed rather than listed, because THREE places copy this set — here, `dotsync` in
# aliases.ps1, and the PowerShell step of config/zsh/functions/maintain.zsh — and a
# hand-maintained list in three trees drifts. It already did: a newly added fragment is
# invisible to `dotsync` until the deployed aliases.ps1 is itself refreshed, which needs
# the very sync that does not know about it yet.
#
# Two exclusions:
#   local.ps1    machine-specific, exists only in the deployment — never copy over it.
#   install.ps1  the bootstrap, not part of the runtime profile.
$fragments = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File |
    Where-Object { $_.Name -notin @('local.ps1', 'install.ps1') }
$copied = 0
foreach ($f in $fragments) {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $deployPwsh $f.Name) -Force
    $copied++
}
Write-Ok "${copied} profile file(s) -> ${deployPwsh}"

# Shared, shell-agnostic configs the profile reads at runtime. Without these the env
# vars in tools.ps1 would point back into WSL and reintroduce the dependency.
$shared = @(
    'config/ripgrep/.ripgreprc',
    'config/mise/config.toml',
    'config/atuin',
    'config/zsh/references'
)
foreach ($rel in $shared) {
    $src = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $dst = Join-Path $deployRoot ($rel -replace '/', '\')
    $dstParent = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
}
Write-Ok "shared configs -> ${deployRoot}\config"

# Files copied off a UNC share can carry a Zone.Identifier marking them as downloaded,
# which would reproduce the "not digitally signed" refusal on local disk too.
Get-ChildItem -LiteralPath $deployRoot -Recurse -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

# Record where this was deployed from, so `dotsync` can refresh it later.
Set-Content -LiteralPath (Join-Path $deployRoot '.source') -Value $repoRoot -Encoding UTF8

Write-Step 'Profile'

$profileSource = Join-Path $deployPwsh 'profile.ps1'
$profileTarget = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profileTarget

if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

function Test-AlreadyLinked {
    param([string] $Target, [string] $Source)

    if (-not (Test-Path -LiteralPath $Target)) { return $false }

    $item = Get-Item -LiteralPath $Target -Force
    if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -contains $Source) { return $true }

    # Stub form: already dot-sources our profile.
    $content = Get-Content -LiteralPath $Target -Raw -ErrorAction SilentlyContinue
    return ($content -and $content -match [regex]::Escape($Source))
}

if (Test-AlreadyLinked -Target $profileTarget -Source $profileSource) {
    Write-Skip "profile already points at ${profileSource}"
} else {
    # Back up whatever was there, matching install.sh's non-destructive behaviour.
    if (Test-Path -LiteralPath $profileTarget) {
        $backup = "${profileTarget}.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $profileTarget -Destination $backup -Force
        Write-Warn "backed up existing profile to ${backup}"
    }

    $linked = $false
    try {
        New-Item -ItemType SymbolicLink -Path $profileTarget -Target $profileSource -Force -ErrorAction Stop | Out-Null
        Write-Ok "symlinked ${profileTarget} -> ${profileSource}"
        $linked = $true
    } catch {
        Write-Skip 'symlink unavailable (no Developer Mode / UNC path) — writing stub instead'
    }

    if (-not $linked) {
        $stub = @"
# Generated by dotfiles/powershell/install.ps1 — do not edit.
# Symlinking was unavailable, so this stub dot-sources the deployed profile instead.
. '${profileSource}'
"@
        Set-Content -LiteralPath $profileTarget -Value $stub -Encoding UTF8
        Write-Ok "stub profile written to ${profileTarget}"
    }
}

# The old arrangement pointed $PROFILE straight at the repo over \\wsl.localhost\. Say so
# plainly if that link is still there, because it is the cause of both the "not digitally
# signed" refusals and the dead shell after `wsl --shutdown`.
$existingLink = Get-Item -LiteralPath $profileTarget -Force -ErrorAction SilentlyContinue
if ($existingLink -and @($existingLink.Target) -match '^\\\\wsl') {
    Write-Warn 'profile still points into WSL — re-run this script to repoint it at local disk'
}

#---------------------------------------------------------------------------------------
# 4. Summary
#---------------------------------------------------------------------------------------

Write-Step 'Summary'
Write-Host "  installed: $($script:Installed.Count)  skipped: $($script:Skipped.Count)  failed: $($script:Failed.Count)"

if ($script:Failed.Count -gt 0) {
    Write-Warn "failed: $($script:Failed -join ', ')"
    Write-Host '    winget package IDs drift over time — verify with: winget search <name>' -ForegroundColor DarkGray
}

Write-Host "`nRestart pwsh (or run 'reload') to pick up the new profile.`n" -ForegroundColor Cyan
