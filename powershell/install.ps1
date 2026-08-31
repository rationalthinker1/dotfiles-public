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
# 2. CLI tools via winget
#
# IDs are checked against the installed command name first, so an equivalent already
# installed by scoop/chocolatey/mise is left alone. A failed ID is reported, never fatal —
# winget package IDs drift, and one bad ID must not abort the whole bootstrap.
#---------------------------------------------------------------------------------------

if (-not $SkipTools) {
    Write-Step 'CLI tools (winget)'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn 'winget not found — install App Installer from the Microsoft Store, or use scoop'
    } else {
        $tools = @(
            @{ Command = 'fzf';         Id = 'junegunn.fzf' }
            @{ Command = 'zoxide';      Id = 'ajeetdsouza.zoxide' }
            @{ Command = 'atuin';       Id = 'Atuinsh.Atuin' }
            @{ Command = 'bat';         Id = 'sharkdp.bat' }
            @{ Command = 'fd';          Id = 'sharkdp.fd' }
            @{ Command = 'rg';          Id = 'BurntSushi.ripgrep.MSVC' }
            @{ Command = 'eza';         Id = 'eza-community.eza' }
            @{ Command = 'delta';       Id = 'dandavison.delta' }
            @{ Command = 'jq';          Id = 'jqlang.jq' }
            @{ Command = 'gh';          Id = 'GitHub.cli' }
            @{ Command = 'lazygit';     Id = 'JesseDuffield.lazygit' }
            @{ Command = 'oh-my-posh';  Id = 'JanDeDobbeleer.OhMyPosh' }
        )

        foreach ($tool in $tools) {
            if (Get-Command $tool.Command -CommandType Application -ErrorAction SilentlyContinue) {
                Write-Skip "$($tool.Command) already on PATH"
                $script:Skipped += $tool.Command
                continue
            }

            try {
                $null = winget install --exact --id $tool.Id `
                    --accept-source-agreements --accept-package-agreements `
                    --disable-interactivity 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Ok "$($tool.Command) ($($tool.Id))"
                    $script:Installed += $tool.Command
                } else {
                    Write-Warn "$($tool.Command): winget exit $LASTEXITCODE for id '$($tool.Id)'"
                    $script:Failed += $tool.Command
                }
            } catch {
                Write-Warn "$($tool.Command) failed: $($_.Exception.Message)"
                $script:Failed += $tool.Command
            }
        }
    }
} else {
    Write-Step 'CLI tools — skipped (-SkipTools)'
}

#---------------------------------------------------------------------------------------
# 3. Link the profile
#
# Target is CurrentUserAllHosts (profile.ps1), so the config applies to the terminal,
# VS Code's integrated shell and any other host alike.
#
# A symlink needs Developer Mode or an elevated shell, and cannot be created on a UNC
# path (\\wsl$\...). When it is unavailable a one-line stub that dot-sources the repo
# copy is written instead — same effect, no privilege needed.
#---------------------------------------------------------------------------------------

Write-Step 'Profile'

$profileSource = Join-Path $PSScriptRoot 'profile.ps1'
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
# Symlinking was unavailable, so this stub dot-sources the tracked profile instead.
. '${profileSource}'
"@
        Set-Content -LiteralPath $profileTarget -Value $stub -Encoding UTF8
        Write-Ok "stub profile written to ${profileTarget}"
    }
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
