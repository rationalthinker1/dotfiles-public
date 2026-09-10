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
# A file that must sit beside the real profile.ps1. Any resolution result that does not
# contain it is wrong, however plausible the path looks — so every candidate is verified
# rather than trusted.
$script:ProfileAnchor = 'aliases.ps1'

$script:ProfileDir = $PSScriptRoot
try {
    $self = Get-Item -LiteralPath $PSCommandPath -Force -ErrorAction Stop
    if ($self.LinkType -eq 'SymbolicLink') {

        # ORDER MATTERS, and ResolveLinkTarget($true) is deliberately LAST.
        #
        # `$true` means "return the final target" and is the obvious call, but it is
        # wrong for a link pointing at a UNC path: it splices the raw reparse data
        # (\??\UNC\server\share\...) onto the link's own directory, producing e.g.
        #
        #   \\wsl.localhost\Ubuntu\home\razaf\.dotfiles\UNC\wsl.localhost\...\profile.ps1
        #
        # from a link whose target is plainly \\wsl.localhost\...\powershell\profile.ps1.
        # ProfileDir then points somewhere that exists in name only, every fragment
        # Test-Path fails, and the profile loads as a silent no-op — no aliases, no
        # prompt, no keybindings, with nothing logged. The raw LinkTarget is correct, so
        # it goes first.
        $candidates = [System.Collections.Generic.List[string]]::new()

        foreach ($raw in @($self.LinkTarget, @($self.Target)[0])) {
            if ($raw) { $candidates.Add($raw) }
        }
        foreach ($final in @($false, $true)) {
            try {
                $r = $self.ResolveLinkTarget($final)
                if ($r -and $r.FullName) { $candidates.Add($r.FullName) }
            } catch {
                # This overload throws on some link/filesystem combinations; the raw
                # target above is the answer in those cases anyway.
            }
        }

        foreach ($candidate in $candidates) {
            $target = $candidate
            # Target may be relative on older link representations.
            if (-not [IO.Path]::IsPathRooted($target)) {
                $target = Join-Path (Split-Path -Parent $PSCommandPath) $target
            }
            $dir = Split-Path -Parent $target
            if ($dir -and (Test-Path -LiteralPath (Join-Path $dir $script:ProfileAnchor))) {
                $script:ProfileDir = $dir
                break
            }
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

# hooks.ps1 last of the four: it registers a LocationChangedAction that zoxide's `cd`
# (installed in tools.ps1) triggers, and aliases.ps1 may define functions it calls.
$script:LoadedFragments = 0
foreach ($fragment in @('psreadline.ps1', 'tools.ps1', 'aliases.ps1', 'hooks.ps1')) {
    $path = Join-Path $script:ProfileDir $fragment
    if (Test-Path -LiteralPath $path) {
        . $path
        $script:LoadedFragments++
    }
}

# Never fail silently again. A wrong ProfileDir used to leave a shell that looked normal
# but had no aliases, no prompt and no keybindings, with nothing said about it.
if ($script:LoadedFragments -eq 0) {
    Write-Warning "dotfiles: no profile fragments found in '${script:ProfileDir}' — the profile loaded as a no-op."
    Write-Warning "dotfiles: `$PROFILE is '${PSCommandPath}'; check that its link target resolves to the repo's powershell/ directory."
}

# Machine-specific overrides — gitignored, mirrors config/zsh/local.zsh. Always last.
$localProfile = Join-Path $script:ProfileDir 'local.ps1'
if (Test-Path $localProfile) { . $localProfile }
