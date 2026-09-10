#=======================================================================================
# Directory hooks — the PowerShell counterpart to config/zsh/hooks.zsh
#
# ZSH's chpwd_functions has a direct equivalent here:
# $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction. It fires on every
# location change, INCLUDING ones made by zoxide's `cd`, which is why this file must be
# sourced after tools.ps1 — zoxide replaces `cd` there, and registering first would still
# work but leaves the ordering dependency unstated.
#
# Unlike zsh's chpwd, this handler does NOT fire inside command substitutions, so the
# "keep stdout silent" constraint documented in hooks.zsh does not apply. Output still
# goes to Write-Host/Write-Warning rather than the pipeline, so nothing leaks into a
# caller that happens to capture the result of a Set-Location.
#
# Deliberately NOT ported: reset_cursor (hooks.zsh:11-14). Windows Terminal sets cursor
# shape per profile, so emitting `\e[5 q` on every prompt would fight the profile.
#=======================================================================================

# Additive registration. Assigning directly would silently drop a handler installed by
# something else (or by a re-source of this file appending a duplicate).
$script:DotfilesLocationHandlers = @()

# --------------------------------------------------------------------------------------
# Auto-activate a Python virtualenv on entering its project directory.
#
# Windows venvs put the activation script at .venv\Scripts\Activate.ps1; under
# pwsh-in-WSL it is .venv/bin/Activate.ps1. Probe both so the hook works in either.
# --------------------------------------------------------------------------------------
$script:DotfilesLocationHandlers += {
    if ($env:VIRTUAL_ENV) { return }

    foreach ($candidate in @('.venv/Scripts/Activate.ps1', '.venv/bin/Activate.ps1')) {
        $activate = Join-Path $PWD.Path $candidate
        if (Test-Path -LiteralPath $activate) {
            . $activate
            return
        }
    }
}

# --------------------------------------------------------------------------------------
# Auto-source .dirrc, but only from trusted locations.
#
# The trust check is the whole point: a .dirrc is arbitrary code, and cd-ing into a
# cloned repo must not execute it. Only paths under $HOME are auto-sourced; anywhere
# else warns and leaves it to the user, matching hooks.zsh:43-61.
# --------------------------------------------------------------------------------------
$script:DotfilesLocationHandlers += {
    $dirrc = Join-Path $PWD.Path '.dirrc.ps1'
    if (-not (Test-Path -LiteralPath $dirrc)) { return }

    # Compare canonical paths with a trailing separator, so a sibling directory such as
    # C:\Users\razaf-evil does not read as being inside C:\Users\razaf.
    $home_ = [IO.Path]::GetFullPath($HOME).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $here  = [IO.Path]::GetFullPath($PWD.Path).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $trusted = $here -eq $home_ -or
               $here.StartsWith($home_ + [IO.Path]::DirectorySeparatorChar,
                                [StringComparison]::OrdinalIgnoreCase)

    if ($trusted) {
        . $dirrc
    } else {
        Write-Warning "Found .dirrc.ps1 in untrusted location: ${here}"
        Write-Warning "Run '. ./.dirrc.ps1' to load it manually"
    }
}

# --------------------------------------------------------------------------------------
# Dispatch
#
# One handler throwing must not kill the others, or take the prompt down with it — a
# broken .dirrc would otherwise make every subsequent cd print an error.
# --------------------------------------------------------------------------------------
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($currentSession, $newLocation)

    foreach ($handler in $script:DotfilesLocationHandlers) {
        try { & $handler }
        catch { Write-Warning "dotfiles hook: $($_.Exception.Message)" }
    }
}
