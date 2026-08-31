#=======================================================================================
# PowerShell 7 profile — dotfiles entry point
#
# Linked from $PROFILE.CurrentUserAllHosts by install.ps1. Mirrors the role of .zshrc:
# interactive setup only. PowerShell has no .zshenv/.zprofile split, so environment
# variables that must exist for non-interactive sessions belong in the machine
# environment (setx / System Properties), NOT here.
#
# Load order matters: PSReadLine before tools (tools bind keys on top of it),
# aliases last so they can shadow anything a module defined.
#=======================================================================================

# Non-interactive sessions (scripts, CI, `pwsh -c ...`) get nothing but a fast exit.
if (-not [Environment]::UserInteractive -or $Host.Name -eq 'Default Host') { return }

# $PSScriptRoot points at the directory of the file PowerShell *opened*, which for the
# symlinked $PROFILE is ~/.config/powershell — not this repo. Resolve the link so the
# fragments below are found next to the real profile.ps1 rather than beside the symlink.
$script:ProfileDir = $PSScriptRoot
try {
    $self = Get-Item -LiteralPath $PSCommandPath -Force -ErrorAction Stop
    if ($self.LinkType -eq 'SymbolicLink') {
        $resolved = $self.ResolveLinkTarget($true)
        if ($resolved) {
            $script:ProfileDir = Split-Path -Parent $resolved.FullName
        } elseif ($self.Target) {
            # Fallback for older link representations: Target may be a relative path.
            $target = @($self.Target)[0]
            if (-not [IO.Path]::IsPathRooted($target)) {
                $target = Join-Path (Split-Path -Parent $PSCommandPath) $target
            }
            $script:ProfileDir = Split-Path -Parent ([IO.Path]::GetFullPath($target))
        }
    }
} catch {
    # Keep $PSScriptRoot; a stub profile that dot-sources the repo copy lands here too.
}

$script:DotfilesRoot = Split-Path -Parent $script:ProfileDir
$env:DOTFILES_ROOT = $script:DotfilesRoot

#---------------------------------------------------------------------------------------
# Helpers shared by the sourced fragments
#---------------------------------------------------------------------------------------

# ZSH's `(( $+commands[cmd] ))`.
#
# The obvious implementation — Get-Command -CommandType Application — rescans every
# PATH directory on EVERY call and builds a full CommandInfo object. With ~25 probes
# across tools.ps1 and aliases.ps1 that measured ~615ms of a ~680ms startup.
#
# Instead the PATH is enumerated exactly once, lazily, into a name -> path map. Startup
# drops to roughly a tenth of that, and lookups afterwards are O(1).
$script:PathCommandMap = $null

function Get-PathCommandMap {
    if ($null -ne $script:PathCommandMap) { return $script:PathCommandMap }

    $map = [System.Collections.Generic.Dictionary[string, string]]::new(
        [StringComparer]::OrdinalIgnoreCase)

    # On Windows a bare name resolves through PATHEXT (fd -> fd.exe); on Unix the
    # filename is the command name and the executable bit decides.
    $pathExt = @()
    if ($IsWindows) {
        $raw = if ($env:PATHEXT) { $env:PATHEXT } else { '.COM;.EXE;.BAT;.CMD' }
        $pathExt = $raw -split ';' | Where-Object { $_ }
    }

    foreach ($dir in ($env:PATH -split [IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }

        try {
            $files = [IO.Directory]::EnumerateFiles($dir)
        } catch {
            # Nonexistent or unreadable PATH entry — normal, skip it.
            continue
        }

        foreach ($file in $files) {
            $name = [IO.Path]::GetFileName($file)
            if (-not $map.ContainsKey($name)) { $map[$name] = $file }

            if ($IsWindows) {
                $ext = [IO.Path]::GetExtension($name)
                if ($ext -and ($pathExt -contains $ext)) {
                    $stem = [IO.Path]::GetFileNameWithoutExtension($name)
                    if (-not $map.ContainsKey($stem)) { $map[$stem] = $file }
                }
            }
        }
    }

    $script:PathCommandMap = $map
    return $map
}

function Test-Command {
    param([Parameter(Mandatory)][string] $Name)
    return (Get-PathCommandMap).ContainsKey($Name)
}

function Get-CommandPath {
    param([Parameter(Mandatory)][string] $Name)

    $map = Get-PathCommandMap
    if ($map.ContainsKey($Name)) { return $map[$Name] }
    return $null
}

# Tool init scripts (`zoxide init`, `atuin init`, `oh-my-posh init`) cost a process spawn
# each. PowerShell has no zi-turbo equivalent, so cache the generated script and re-run
# the generator only when the tool binary itself changes.
#
# This returns the PATH TO the cached script rather than sourcing it, and callers must
# dot-source the result themselves:
#
#     $init = Get-ToolInitScript -Name 'zoxide' -Generator { zoxide init powershell }
#     if ($init) { . $init }
#
# That is not ceremony. Dot-sourcing *inside* this function would place the init
# script's functions and aliases in the function's own scope, where they are discarded
# the moment it returns — the tool would appear to load and then simply not exist.
function Get-ToolInitScript {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $Generator
    )

    $exe = Get-CommandPath $Name
    if (-not $exe) { return $null }

    $cacheRoot = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME '.cache' }
    $cacheDir = Join-Path $cacheRoot 'dotfiles-pwsh'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }

    # Key on the binary's identity, so an upgrade invalidates the cache automatically.
    $stamp = Get-Item $exe
    $key = "{0}-{1}-{2}" -f $Name, $stamp.LastWriteTimeUtc.Ticks, $stamp.Length
    $cacheFile = Join-Path $cacheDir "${key}.ps1"

    if (Test-Path $cacheFile) { return $cacheFile }

    # Drop stale generations for this tool before writing the new one.
    Get-ChildItem -Path $cacheDir -Filter "${Name}-*.ps1" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    try {
        $generated = & $Generator | Out-String
    } catch {
        Write-Warning "dotfiles: '${Name}' init failed: $($_.Exception.Message)"
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($generated)) { return $null }

    Set-Content -Path $cacheFile -Value $generated -Encoding UTF8
    return $cacheFile
}

#---------------------------------------------------------------------------------------
# Fragments
#---------------------------------------------------------------------------------------

foreach ($fragment in @('psreadline.ps1', 'tools.ps1', 'aliases.ps1')) {
    $path = Join-Path $script:ProfileDir $fragment
    if (Test-Path $path) { . $path }
}

# Machine-specific overrides — gitignored, mirrors config/zsh/local.zsh. Always last.
$localProfile = Join-Path $script:ProfileDir 'local.ps1'
if (Test-Path $localProfile) { . $localProfile }
