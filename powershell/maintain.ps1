#=======================================================================================
# maintain.ps1 — full-spectrum Windows maintenance
#
# Defines `maintain` (alias: `update-all`) plus its Write-Maintain* / Invoke-MaintainStep
# helpers. The pwsh counterpart of config/zsh/functions/maintain.zsh, and a separate
# fragment for the same reason: a six-phase maintenance run with log rotation and a
# bootstrap prompt is a subsystem, not an alias.
#
# Sourced by: profile.ps1, between aliases.ps1 and hooks.ps1.
#
# The phases are NOT a 1:1 port. zsh's phases 1/4/5 are apt/snap/flatpak, container
# hygiene and Linux cache paths — none of which exist here. What carries over is the
# CONTRACT, which is the part worth copying:
#
#   * every step is self-guarded — a missing tool is skipped, never an error;
#   * a step that fails is RECORDED, never fatal, so one bad package id cannot cost you
#     the remaining five phases;
#   * the run ends with a summary of reclaimed disk plus every step that failed, and
#     returns non-zero if any did;
#   * the whole run is transcribed to %LOCALAPPDATA%\dotfiles\logs\maintain\ (10 kept).
#
# Windows-specific phase map:
#   1. Package managers      winget, scoop (+bucket/self update), chocolatey
#   2. Runtimes & modules    PowerShell modules, mise, rustup, gh extensions, Claude Code
#   3. Global packages       npm, pnpm, yarn, uv, pipx, cargo, atuin sync
#   4. Dotfiles deployment   refresh the local-disk copy from the repo (`dotsync`)
#   5. Cleanup & caches      scoop/npm/pnpm/yarn/pip/uv/go caches, %TEMP% older than 30d
#   6. Health & integrity    PATH shadows, dead PATH entries, pending reboot, disk report
#
# Phase 4 is the one with no zsh equivalent, and it is the reason this function matters
# on Windows at all. powershell/ is COPIED to local disk, not symlinked (see
# powershell/README.md §Why), so repo edits are invisible to pwsh until something copies
# them. From WSL, `update-all` closes that gap in its phase 2; this closes it from the
# Windows side.
#
# It calls `dotsync` rather than re-implementing the copy. The zsh side deliberately does
# NOT do that — there, dotsync is defined by the profile being synced, so a bad edit that
# breaks the profile also deletes the only command that could repair it. That argument
# does not apply here: maintain is itself part of the same profile, so if the profile is
# broken this function is gone too and the repair route is install.ps1 either way.
#
# (dotsync overwrites this file mid-run. Harmless — PowerShell has already parsed the
# function into memory; the new copy takes effect at the next `reload`.)
#=======================================================================================

#---------------------------------------------------------------------------------------
# State and formatting
#---------------------------------------------------------------------------------------

# Deliberately NOT named $Failures/$Ok: PowerShell variable names are case-insensitive
# and these live at the same scope as anything a step body might declare. install.ps1 §2
# carries the scar from exactly that collision.
$script:MaintainFailures = @()
$script:MaintainRan      = 0
$script:MaintainSkipped  = 0

# winget returns a HRESULT-shaped code that PowerShell surfaces as a signed int32. Two of
# them mean "there was simply nothing to do" and must not be recorded as failures:
#   0x8A150014 NO_APPLICATIONS_FOUND  -> -1978335212   nothing installed matched
#   0x8A15002B UPDATE_NOT_APPLICABLE  -> -1978335189   everything already current/pinned
# Anything else — including 0x8A15002C UPDATE_ALL_HAS_FAILURE — is a real partial failure
# and is reported as one.
$script:MaintainWingetOk = @(0, -1978335212, -1978335189)

# Modules installed by install.ps1 §1. Keep the two lists in step.
$script:MaintainModules = @('PSReadLine', 'PSFzf', 'CompletionPredictor', 'posh-git')

# Commands allowed to resolve from more than one install location (phase 6). Starts
# EMPTY on purpose. Add an entry only once you have verified the shadow is deliberate,
# and keep the reason on the line — the zsh side learned that a duplicate report you
# train yourself to skip past is worse than no report, because it still looks like
# coverage. An entry whose reason stops being true must come back out.
$script:MaintainPathDupeAllow = @()

function script:Write-MaintainPhase { param([string] $Message) Write-Host "`n▸ ${Message}" -ForegroundColor Cyan }
function script:Write-MaintainStep  { param([string] $Message) Write-Host "`n  ── ${Message} ────────────────────" -ForegroundColor DarkCyan }
function script:Write-MaintainOk    { param([string] $Message) Write-Host "  ✓ ${Message}" -ForegroundColor Green }
function script:Write-MaintainSkip  { param([string] $Message) Write-Host "  • ${Message}" -ForegroundColor DarkGray }
function script:Write-MaintainWarn  { param([string] $Message) Write-Host "  ⚠ ${Message}" -ForegroundColor Yellow }

# Run one step under the "record, never abort" contract.
#
# $LASTEXITCODE is zeroed first because it is STALE otherwise: it holds whatever the last
# native command in the session returned, so a step made only of cmdlets would inherit the
# previous step's failure. It is also only meaningful for the LAST native command in the
# body, which is why multi-command bodies chain with `;` and are judged on their final
# call — the same semantics as the zsh side's `{ a && b } || failures+=(…)`.
function script:Invoke-MaintainStep {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][scriptblock] $Body,
        # Exit codes to treat as success. winget needs more than just 0; see above.
        [int[]] $OkExit = @(0)
    )

    Write-MaintainStep $Name
    $global:LASTEXITCODE = 0

    try {
        # A non-terminating error inside a step is information, not a reason to stop.
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { & $Body } finally { $ErrorActionPreference = $previous }

        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -notin $OkExit) {
            Write-MaintainWarn "${Name}: exit ${LASTEXITCODE}"
            $script:MaintainFailures += $Name
            return
        }
        $script:MaintainRan++
    } catch {
        Write-MaintainWarn "${Name}: $($_.Exception.Message)"
        $script:MaintainFailures += $Name
    }
}

# Skip-with-a-reason, so "nothing happened" is always distinguishable from "it worked".
function script:Write-MaintainStepSkipped {
    param([Parameter(Mandatory)][string] $Message)
    Write-MaintainSkip $Message
    $script:MaintainSkipped++
}

#---------------------------------------------------------------------------------------
# Elevation
#
# Windows has NO sudo credential cache. The zsh side primes `sudo -v` once and refreshes
# it in a keep-alive loop, so a ten-minute unattended run never re-asks; there is no
# equivalent here. UAC consent is granted per *process*, at process creation, and cannot
# be held, cached or renewed. (Microsoft's own `sudo.exe` — Windows 11 24H2+, and disabled
# by default behind Settings ▸ System ▸ For developers — is a launcher, not a cache: it
# prompts on every invocation. Third-party gsudo is the only thing with a real cache.)
#
# So the only way to get ONE prompt instead of N is to elevate ONE process and do all the
# privileged work inside it. That is what this does: every command that needs admin is
# batched into a single elevated pwsh child, which costs exactly one UAC dialog.
#
# Without it, `winget upgrade --all` prints "The installer will request to run as
# administrator. Expect a prompt." per package, and you sit through one dialog each.
#
# What deliberately does NOT go in the batch: scoop. Scoop is a per-user install by
# design and refuses, or corrupts its own state, when run elevated — files land owned by
# the admin token and later user-mode updates fail on them. Elevation here is scoped to
# winget and chocolatey for that reason, never applied to the whole run.
#---------------------------------------------------------------------------------------

function script:Test-MaintainElevated {
    if (-not $IsWindows) { return $false }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal] $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Run several named commands inside ONE elevated pwsh, then fold the results back into
# this run's step accounting as though they had run here.
#
# -Verb RunAs is what raises the UAC dialog, and it forces ShellExecute, which is
# mutually exclusive with -RedirectStandardOutput/-Error. Hence the child tees its own
# output to a file: you watch it live in the elevated console, and the parent replays the
# capture afterwards so the transcript is complete.
#
# Per-step exit codes come back through a JSON file rather than the process exit code,
# because one child process has only one exit code and this runs several commands.
# -WhileWaiting runs in THIS process while the elevated child works, turning the dead wait
# into useful time. Phase 1 passes the scoop steps: the elevated window grinds through
# winget's machine-scope installers — routinely several minutes — while scoop updates its
# buckets and apps here, and the run finishes in roughly the longer of the two rather than
# their sum.
#
# The two are genuinely independent: winget writes to Program Files / WindowsApps and the
# machine PATH, scoop to ~\scoop and the user PATH. Different stores, different registry
# values, no shared lock — which is also why scoop must stay in the PARENT rather than
# joining the elevated batch (see above).
#
# The one shared resource that could bite is Windows Installer's global `_MSIExecute`
# mutex: only one MSI may install machine-wide at a time, and the loser fails with 1618
# ("another installation is already in progress"). winget hits MSIs constantly. Scoop
# almost never does — its manifests are overwhelmingly portable archives — so the overlap
# is safe in practice rather than by guarantee. If it ever does fire it surfaces as an
# ordinary failed scoop step, recorded not fatal, and a re-run fixes it.
function script:Invoke-MaintainElevatedBatch {
    param(
        [Parameter(Mandatory)][hashtable[]] $Steps,
        [scriptblock] $WhileWaiting
    )

    $stamp       = Get-Date -Format 'yyyyMMdd-HHmmss'
    $childScript = Join-Path $env:TEMP "maintain-elevated-${stamp}.ps1"
    $childLog    = Join-Path $env:TEMP "maintain-elevated-${stamp}.log"
    $resultFile  = Join-Path $env:TEMP "maintain-elevated-${stamp}.json"

    $lines = @(
        "`$ErrorActionPreference = 'Continue'"
        "`$results = [ordered]@{}"
        "Write-Host 'Elevated maintenance — this window closes when it finishes.' -ForegroundColor Cyan"
    )
    foreach ($step in $Steps) {
        $lines += "Write-Host ''"
        $lines += "Write-Host '  ── $($step.Name) ────────────────────' -ForegroundColor DarkCyan"
        $lines += "`$global:LASTEXITCODE = 0"
        # Tee, not redirect: live in the elevated console AND captured for the parent.
        # $LASTEXITCODE survives the pipeline — Tee-Object is a cmdlet and does not set it.
        $lines += "$($step.Command) 2>&1 | Tee-Object -FilePath '${childLog}' -Append"
        $lines += "`$results['$($step.Name)'] = `$LASTEXITCODE"
    }
    $lines += "`$results | ConvertTo-Json -Compress | Set-Content -LiteralPath '${resultFile}' -Encoding UTF8"

    Set-Content -LiteralPath $childScript -Value ($lines -join [Environment]::NewLine) -Encoding UTF8

    $child = $null
    try {
        # The RUNNING pwsh, not whatever 'pwsh' resolves to on PATH — this must not
        # silently elevate a different PowerShell than the one you are in.
        #
        # -PassThru and NOT -Wait: waiting here would serialise the very thing
        # -WhileWaiting exists to overlap. The wait happens below, after that work.
        $pwshPath = (Get-Process -Id $PID).Path
        $child = Start-Process -FilePath $pwshPath -Verb RunAs -PassThru `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $childScript)
    } catch {
        # Cancelling the UAC dialog lands here. Not a failure — it is an answer. Fall back
        # to running the same commands unelevated, which is what would have happened
        # anyway, and let each one report its own outcome.
        Write-MaintainWarn "elevation declined ($($_.Exception.Message)) — running unelevated"
        Remove-Item -LiteralPath $childScript, $childLog, $resultFile -Force -ErrorAction SilentlyContinue
        foreach ($step in $Steps) {
            Invoke-MaintainStep $step.Name ([scriptblock]::Create($step.Command)) -OkExit $step.OkExit
        }
        # Still owed, and now the only work left.
        if ($WhileWaiting) { & $WhileWaiting }
        return
    }

    if ($WhileWaiting) {
        Write-MaintainSkip 'elevated window is running winget/chocolatey — continuing with scoop here'
        & $WhileWaiting
    }

    # Wait-Process rather than $child.WaitForExit(): with -Verb RunAs the object comes back
    # from ShellExecute, whose handle is not always usable for WaitForExit.
    Write-MaintainSkip 'waiting for the elevated window to finish'
    Wait-Process -Id $child.Id -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $childLog) {
        Get-Content -LiteralPath $childLog | Write-Host
    }

    $codes = @{}
    if (Test-Path -LiteralPath $resultFile) {
        $json = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
        foreach ($property in $json.PSObject.Properties) { $codes[$property.Name] = [int] $property.Value }
    }

    foreach ($step in $Steps) {
        Write-MaintainStep "$($step.Name) [elevated]"
        if (-not $codes.ContainsKey($step.Name)) {
            # The child died before recording this one — a crash, or the window was closed.
            Write-MaintainWarn "$($step.Name): no result recorded (elevated run interrupted?)"
            $script:MaintainFailures += $step.Name
            continue
        }
        $code = $codes[$step.Name]
        $ok = if ($step.OkExit) { $step.OkExit } else { @(0) }
        if ($code -in $ok) {
            Write-MaintainOk "exit ${code}"
            $script:MaintainRan++
        } else {
            Write-MaintainWarn "$($step.Name): exit ${code}"
            $script:MaintainFailures += $step.Name
        }
    }

    Remove-Item -LiteralPath $childScript, $childLog, $resultFile -Force -ErrorAction SilentlyContinue
}

#---------------------------------------------------------------------------------------
# Phase 6 helpers
#---------------------------------------------------------------------------------------

# Commands resolvable from more than one directory on PATH.
#
# This catches the failure mode where a tool installed two ways leaves the OLDER copy
# winning on PATH forever, in silence — a scoop shim shadowing a winget install, or a
# WindowsApps execution-alias stub shadowing a real python. Strictly read-only: it prints
# and never reorders PATH or deletes anything.
function script:Get-MaintainPathDuplicate {
    $extensions = @(($env:PATHEXT -split ';') | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
    if (-not $extensions) { $extensions = @('.exe', '.cmd', '.bat', '.ps1') }

    $seen = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new(
        [StringComparer]::OrdinalIgnoreCase)

    foreach ($dir in ($env:PATH -split [IO.Path]::PathSeparator)) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
            if ($file.Extension.ToLowerInvariant() -notin $extensions) { continue }
            $name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            if ($name -in $script:MaintainPathDupeAllow) { continue }
            if (-not $seen.ContainsKey($name)) {
                $seen[$name] = [System.Collections.Generic.List[string]]::new()
            }
            # Same name via two PATHEXT extensions in ONE directory is not a shadow — it
            # is how PowerShell and cmd wrappers ship. Only cross-directory counts.
            if ($seen[$name] -notcontains $file.DirectoryName) { $seen[$name].Add($file.DirectoryName) }
        }
    }

    foreach ($entry in $seen.GetEnumerator()) {
        if ($entry.Value.Count -gt 1) {
            [pscustomobject]@{ Command = $entry.Key; Paths = $entry.Value }
        }
    }
}

# PATH entries pointing at directories that no longer exist. Each one is a wasted stat on
# every command resolution, and usually the fossil of an uninstalled tool.
function script:Get-MaintainDeadPath {
    ($env:PATH -split [IO.Path]::PathSeparator) |
        Where-Object { $_ -and -not (Test-Path -LiteralPath $_) }
}

function script:Test-MaintainPendingReboot {
    if (-not $IsWindows) { return $false }

    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) { return $true }
    }

    $sessionManager = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $pending = Get-ItemProperty -LiteralPath $sessionManager -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    return [bool] $pending.PendingFileRenameOperations
}

# Free bytes on the system drive, or $null where that cannot be read (pwsh on Linux).
function script:Get-MaintainFreeSpace {
    $drive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':') } else { $null }
    if (-not $drive) { return $null }
    return (Get-PSDrive -Name $drive -ErrorAction SilentlyContinue).Free
}

function script:Format-MaintainBytes {
    param([double] $Bytes)
    $units = 'B', 'KB', 'MB', 'GB', 'TB'
    $i = 0
    $value = [math]::Abs($Bytes)
    while ($value -ge 1024 -and $i -lt $units.Count - 1) { $value /= 1024; $i++ }
    $sign = if ($Bytes -lt 0) { '-' } else { '' }
    return '{0}{1:N1} {2}' -f $sign, $value, $units[$i]
}

#---------------------------------------------------------------------------------------
# Usage
#---------------------------------------------------------------------------------------

function script:Show-MaintainUsage {
    @'
Usage: maintain [-Install] [-SkipCleanup] [-Elevate|-NoElevate] [-Help]   (alias: update-all)

Full-spectrum Windows maintenance — update, sync, clean, and verify — in six phases:
  1. Package managers      winget upgrade --all, scoop update/cleanup, chocolatey
  2. Runtimes & modules    PowerShell modules, mise, rustup, gh extensions, Claude Code
  3. Global packages       npm, pnpm, yarn, uv, pipx, cargo, atuin sync
  4. Dotfiles deployment   refresh %LOCALAPPDATA%\dotfiles from the repo (dotsync)
  5. Cleanup & caches      scoop/npm/pnpm/yarn/pip/uv/go caches, %TEMP% older than 30 days
  6. Health & integrity    PATH shadows, dead PATH entries, pending reboot, disk report

Options:
  -Install      Run powershell/install.ps1 first (skips its prompt). Needs WSL running,
                since the repo lives there.
  -SkipCleanup  Skip phase 5. Nothing in it is destructive beyond 30-day-old temp files,
                but it is the only phase that deletes anything.
  -Elevate      Run winget and chocolatey in one elevated process: ONE UAC prompt for the
                whole phase, instead of one per machine-scope package. Skips the question.
  -NoElevate    Never elevate. winget still upgrades user-scope packages and prompts for
                the rest; chocolatey is skipped entirely.
  -Help         This text.

Windows has no sudo credential cache — UAC consent is per-process and cannot be held — so
one elevated child process doing all the privileged work is the only way to get a single
prompt. scoop is never elevated: it is a per-user install and breaks its own state when
run as admin.

Both questions are asked BEFORE the transcript starts and before the long phases, so
nothing prompts ten minutes into what should be an unattended run — and in particular the
UAC dialog lands while you are still at the keyboard. The install step defaults to N;
elevation defaults to Y, because declining it does not avoid a dialog, it multiplies one
into one-per-package. A non-interactive session takes neither.

Skips any tool that is not installed; records — never aborts on — failures, and prints a
summary of reclaimed disk plus every step that failed. Returns non-zero if any did.
Every run is transcribed to %LOCALAPPDATA%\dotfiles\logs\maintain\ (10 kept).

Phases 1 and 2 update commands in place, so finish with 'reload' (or a new pwsh) to pick
up changed paths and completers.
'@ | Write-Host
}

#---------------------------------------------------------------------------------------
# maintain
#---------------------------------------------------------------------------------------

function maintain {
    [CmdletBinding()]
    param(
        [switch] $Install,
        [switch] $SkipCleanup,
        [switch] $Elevate,
        [switch] $NoElevate,
        [switch] $Help
    )

    if ($Help) { Show-MaintainUsage; return }

    $script:MaintainFailures = @()
    $script:MaintainRan      = 0
    $script:MaintainSkipped  = 0

    $repoSource = Get-DotfilesSource

    # Asked HERE, ahead of the transcript and the phases, for the same reason the zsh side
    # asks outside its tee pipe: a prompt written into a capture stream is the trap that
    # made apt's debconf dialog un-steerable. Default is N — a bare Enter, or any
    # non-interactive host, means skip.
    $runInstall = [bool] $Install
    $installScript = if ($repoSource) { Join-Path $repoSource 'powershell\install.ps1' } else { $null }

    $interactive = [bool] ([Environment]::UserInteractive -and $Host.UI.RawUI)

    if (-not $runInstall -and $installScript -and (Test-Path -LiteralPath $installScript) -and $interactive) {
        $reply = Read-Host '▸ Run the dotfiles install.ps1 bootstrap as part of this run? [y/N]'
        if ($reply -match '^[yY]') { $runInstall = $true }
    }

    # Elevation is decided HERE too, and for a stronger reason than the install prompt: the
    # UAC dialog itself must land now. Deferring it means a modal system dialog appearing
    # several minutes into a run you walked away from — and if nobody answers, winget sits
    # there instead of failing.
    #
    # Default is Y, unlike every other prompt in this function. Declining does not save you
    # a dialog; it trades ONE for one-per-package, which is strictly worse. The flags
    # -Elevate / -NoElevate answer it in advance and suppress the question.
    $alreadyElevated = Test-MaintainElevated
    $useElevation = $false
    if ($alreadyElevated) {
        # Nothing to ask: this session already holds the token.
        $useElevation = $true
    } elseif ($NoElevate) {
        $useElevation = $false
    } elseif ($Elevate) {
        $useElevation = $true
    } elseif ($interactive -and $IsWindows -and ((Test-Command 'winget') -or (Test-Command 'choco'))) {
        Write-Host '▸ winget will otherwise prompt once PER PACKAGE ("The installer will request to run'
        Write-Host '  as administrator"). Elevating runs winget and chocolatey in one elevated process,'
        Write-Host '  for a single UAC dialog. scoop is never elevated — it is a per-user install.'
        $reply = Read-Host '  Elevate the winget/chocolatey step? [Y/n]'
        $useElevation = ($reply -notmatch '^[nN]')
    } else {
        # Non-interactive: UAC would still raise a modal dialog with nobody to answer it,
        # which hangs the run rather than failing it. Scheduled runs stay unelevated.
        $useElevation = $false
    }

    #-----------------------------------------------------------------------------------
    # Transcript. Start-Transcript throws if one is already running, which must not cost
    # you the maintenance run — so a failure here degrades to an un-transcribed run.
    #-----------------------------------------------------------------------------------
    $logRoot = Join-Path $env:LOCALAPPDATA 'dotfiles\logs\maintain'
    $logFile = Join-Path $logRoot ('maintain-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $transcribing = $false
    try {
        if (-not (Test-Path -LiteralPath $logRoot)) {
            New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
        }
        Start-Transcript -LiteralPath $logFile -ErrorAction Stop | Out-Null
        $transcribing = $true
    } catch {
        Write-MaintainWarn "transcript unavailable: $($_.Exception.Message)"
    }

    $started   = Get-Date
    $freeStart = Get-MaintainFreeSpace

    try {
        Write-Host ''
        Write-Host '==================================================' -ForegroundColor Cyan
        Write-Host '          🚀 Starting System Maintenance          ' -ForegroundColor Cyan
        Write-Host '==================================================' -ForegroundColor Cyan

        # Said once, up front, rather than as N confusing per-step prompts or failures.
        if ($alreadyElevated) {
            Write-MaintainSkip 'session is already elevated — no UAC prompt needed'
        } elseif ($useElevation) {
            Write-MaintainSkip 'winget/chocolatey will run in one elevated process — expect a single UAC prompt'
        } else {
            Write-MaintainSkip 'not elevated — winget will prompt per machine-scope package, and chocolatey is skipped'
        }

        # Unnumbered, like the sudo prime on the zsh side, because it is not one of the
        # six phases. Runs BEFORE them on purpose: install.ps1 is idempotent and may add
        # new tools, which phases 1-3 then update in the same pass.
        if ($runInstall) {
            if ($installScript -and (Test-Path -LiteralPath $installScript)) {
                Invoke-MaintainStep 'Dotfiles bootstrap (install.ps1)' {
                    # -ExecutionPolicy Bypass is REQUIRED, not defensive. $installScript is
                    # the repo copy, which lives in WSL and is reached over \\wsl.localhost\
                    # — a UNC path is the Internet zone, so pwsh refuses the script as "not
                    # digitally signed" however much you trust the repo. Same flag, same
                    # reason, as the install command in README.md §Install.
                    #
                    # -NoProfile keeps the bootstrap from loading the very profile it is
                    # about to overwrite.
                    & pwsh -NoProfile -ExecutionPolicy Bypass -File $installScript
                }
            } else {
                Write-MaintainStepSkipped 'install.ps1 unreachable (is WSL running?)'
            }
        }

        #-------------------------------------------------------------------------------
        # 1. PACKAGE MANAGERS
        #-------------------------------------------------------------------------------
        Write-MaintainPhase '[1/6] Package managers'

        # winget and chocolatey are collected FIRST and run together, because the whole
        # point of the batch is that N privileged commands cost one UAC dialog rather
        # than one each.
        #
        # --include-unknown covers packages whose installed version winget cannot read,
        # which is most things installed outside winget — without it they are silently
        # never upgraded.
        $privileged = @()
        if (Test-Command 'winget') {
            $privileged += @{
                Name    = 'winget (upgrade --all)'
                Command = 'winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements --disable-interactivity'
                OkExit  = $script:MaintainWingetOk
            }
        } else { Write-MaintainStepSkipped 'winget not installed' }

        if (Test-Command 'choco') {
            if ($useElevation) {
                $privileged += @{
                    Name    = 'chocolatey'
                    Command = 'choco upgrade all -y --no-progress'
                    OkExit  = @(0)
                }
            } else {
                # Unlike winget, chocolatey cannot do anything useful unelevated — it
                # would fail on every package rather than prompt.
                Write-MaintainStepSkipped 'chocolatey needs elevation (re-run with -Elevate)'
            }
        } else { Write-MaintainStepSkipped 'chocolatey not installed' }

        # NOT part of the elevated batch, ever. Scoop is a per-user install by design: run
        # elevated it writes files owned by the admin token into ~\scoop, and subsequent
        # user-mode updates then fail on them. Scoop itself warns about this.
        #
        # Deferred into a scriptblock so it can run CONCURRENTLY with the elevated winget
        # window rather than after it — see Invoke-MaintainElevatedBatch -WhileWaiting.
        # `scoop update` refreshes scoop itself and every bucket; `update *` then upgrades
        # the installed apps. Both are needed — the second alone works off stale manifests.
        $scoopWork = $null
        if (Test-Command 'scoop') {
            $scoopWork = {
                Invoke-MaintainStep 'scoop (self + buckets)' { scoop update }
                Invoke-MaintainStep 'scoop (apps)'           { scoop update '*' }
                Invoke-MaintainStep 'scoop (cleanup)'        { scoop cleanup '*' }
            }
        }

        if ($privileged.Count -eq 0) {
            if ($scoopWork) { & $scoopWork } else { Write-MaintainStepSkipped 'scoop not installed' }
        } elseif ($useElevation -and -not $alreadyElevated) {
            # The only path with a background process to overlap. Scoop's minutes disappear
            # inside winget's instead of following them.
            Invoke-MaintainElevatedBatch -Steps $privileged -WhileWaiting $scoopWork
            if (-not $scoopWork) { Write-MaintainStepSkipped 'scoop not installed' }
        } else {
            # Already elevated (no child process), or elevation refused — everything runs
            # inline here, so there is nothing to overlap with.
            foreach ($step in $privileged) {
                Invoke-MaintainStep $step.Name ([scriptblock]::Create($step.Command)) -OkExit $step.OkExit
            }
            if ($scoopWork) { & $scoopWork } else { Write-MaintainStepSkipped 'scoop not installed' }
        }

        #-------------------------------------------------------------------------------
        # 2. RUNTIMES, VERSION MANAGERS & MODULES
        #-------------------------------------------------------------------------------
        Write-MaintainPhase '[2/6] Runtimes, version managers & modules'

        # PSResourceGet where available, PowerShellGet otherwise — the same fork
        # install.ps1 §1 makes.
        $useResourceGet = [bool] (Get-Command Update-PSResource -ErrorAction SilentlyContinue)
        foreach ($module in $script:MaintainModules) {
            # Ask the PACKAGE MANAGER what it installed, not the module loader what it can
            # see. Get-Module -ListAvailable also returns copies that nothing here can
            # update — the one bundled with pwsh under $PSHOME, and the Windows PowerShell
            # 5.1 system copy under Program Files\WindowsPowerShell\Modules. Updating either
            # fails with "No installed packages were found with name 'X' in scope
            # 'CurrentUser'", which is a false failure and the DEFAULT outcome for
            # PSReadLine on a stock machine (bundled 2.4.5 + a 5.1-era 2.0.0, neither of
            # them user-installed).
            $userInstalled = if ($useResourceGet) {
                Get-PSResource -Name $module -Scope CurrentUser -ErrorAction SilentlyContinue
            } else {
                Get-InstalledModule -Name $module -ErrorAction SilentlyContinue
            }

            if (-not $userInstalled) {
                if (Get-Module -ListAvailable -Name $module) {
                    Write-MaintainStepSkipped "${module} is a bundled copy (updated with pwsh itself)"
                } else {
                    Write-MaintainStepSkipped "${module} not installed"
                }
                continue
            }

            Invoke-MaintainStep "module: ${module}" {
                # PSReadLine is loaded into this very session, so an update installs
                # side-by-side and takes effect on the next pwsh — not an error.
                if ($useResourceGet) {
                    Update-PSResource -Name $module -Scope CurrentUser -TrustRepository -ErrorAction Stop
                } else {
                    Update-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                }
            }
        }

        if (Test-Command 'mise') {
            # No `mise self-update` here: mise is installed by winget/scoop in this setup
            # and refuses to self-update when a package manager owns the binary. Phase 1
            # already updated it.
            Invoke-MaintainStep 'mise (upgrade tools)' { mise upgrade --yes }
        } else { Write-MaintainStepSkipped 'mise not installed' }

        if (Test-Command 'rustup') {
            Invoke-MaintainStep 'rustup' { rustup update }
        } else { Write-MaintainStepSkipped 'rustup not installed' }

        if (Test-Command 'gh') {
            Invoke-MaintainStep 'gh extensions' { gh extension upgrade --all }
        } else { Write-MaintainStepSkipped 'gh not installed' }

        if (Test-Command 'claude') {
            Invoke-MaintainStep 'Claude Code' { claude update }
        } else { Write-MaintainStepSkipped 'Claude Code not installed' }

        #-------------------------------------------------------------------------------
        # 3. GLOBAL PACKAGES & LANGUAGE TOOLCHAINS
        #-------------------------------------------------------------------------------
        Write-MaintainPhase '[3/6] Global packages'

        if (Test-Command 'npm')   { Invoke-MaintainStep 'npm (global)'  { npm update -g } }
                             else { Write-MaintainStepSkipped 'npm not installed' }
        if (Test-Command 'pnpm')  { Invoke-MaintainStep 'pnpm (global)' { pnpm update -g --latest } }
                             else { Write-MaintainStepSkipped 'pnpm not installed' }

        if (Test-Command 'uv') {
            # `uv self update` only supports the installer-owned copy in the user's
            # .local\bin.  winget/scoop/mise-owned copies reject it; their owning package
            # manager already updates them in phases 1-2, so do not turn that expected
            # refusal into a failed weekly maintenance run.
            $uvCommand = Get-Command uv -ErrorAction Stop
            $uvPath = if ($uvCommand.Path) { $uvCommand.Path } else { $uvCommand.Source }
            $standaloneUvDir = Join-Path $HOME '.local\bin'
            $standaloneUvPrefix = "${standaloneUvDir}$([IO.Path]::DirectorySeparatorChar)"
            if ($uvPath -and $uvPath.StartsWith($standaloneUvPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                Invoke-MaintainStep 'uv (self)' { uv self update }
            } else {
                Write-MaintainStepSkipped 'uv self-update (managed by its package/version manager)'
            }
            Invoke-MaintainStep 'uv (tools)' { uv tool upgrade --all }
        } else { Write-MaintainStepSkipped 'uv not installed' }

        if (Test-Command 'pipx') {
            Invoke-MaintainStep 'pipx' { pipx upgrade-all }
        } else { Write-MaintainStepSkipped 'pipx not installed' }

        # cargo-update is a separate crate; without it there is no way to upgrade
        # `cargo install`ed binaries at all, so its absence is a skip rather than a gap.
        if ((Test-Command 'cargo') -and (Test-Command 'cargo-install-update')) {
            Invoke-MaintainStep 'cargo (installed binaries)' { cargo install-update -a }
        } else { Write-MaintainStepSkipped 'cargo-update not installed (cargo install cargo-update)' }

        if (Test-Command 'atuin') {
            Invoke-MaintainStep 'atuin sync' { atuin sync }
        } else { Write-MaintainStepSkipped 'atuin not installed' }

        #-------------------------------------------------------------------------------
        # 4. DOTFILES DEPLOYMENT
        #-------------------------------------------------------------------------------
        Write-MaintainPhase '[4/6] Dotfiles deployment'

        if (-not $repoSource) {
            Write-MaintainStepSkipped 'no .source marker — run install.ps1 first'
        } elseif (-not (Test-Path -LiteralPath $repoSource)) {
            # Expected and routine, not a failure: the repo lives in WSL and this is a
            # native Windows shell.
            Write-MaintainStepSkipped "repo '${repoSource}' unreachable (is WSL running?)"
        } else {
            Invoke-MaintainStep "profile sync from ${repoSource}" { dotsync }
        }

        #-------------------------------------------------------------------------------
        # 5. CLEANUP & CACHES
        #-------------------------------------------------------------------------------
        if ($SkipCleanup) {
            Write-MaintainPhase '[5/6] Cleanup & caches — skipped (-SkipCleanup)'
        } else {
            Write-MaintainPhase '[5/6] Cleanup & caches'

            if (Test-Command 'scoop') { Invoke-MaintainStep 'scoop cache' { scoop cache rm '*' } }
            if (Test-Command 'npm')   { Invoke-MaintainStep 'npm cache'   { npm cache verify } }
            if (Test-Command 'pnpm')  { Invoke-MaintainStep 'pnpm store'  { pnpm store prune } }
            if (Test-Command 'yarn')  { Invoke-MaintainStep 'yarn cache'  { yarn cache clean } }
            if (Test-Command 'uv')    { Invoke-MaintainStep 'uv cache'    { uv cache prune } }
            if (Test-Command 'pip')   { Invoke-MaintainStep 'pip cache'   { pip cache purge } }

            # -cache only. NOT -modcache: the module cache is expensive to refetch and is
            # not stale in any sense that matters.
            if (Test-Command 'go') { Invoke-MaintainStep 'go build cache' { go clean -cache } }

            # Conservative by construction, same as the zsh side's trash handling: only
            # entries untouched for 30 days, and failures (locked files, in-use handles)
            # are expected and ignored.
            Invoke-MaintainStep 'temp files older than 30 days' {
                $cutoff = (Get-Date).AddDays(-30)
                Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt $cutoff } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        #-------------------------------------------------------------------------------
        # 6. HEALTH, INTEGRITY & SECURITY
        #-------------------------------------------------------------------------------
        Write-MaintainPhase '[6/6] Health & integrity'

        if (Test-Command 'mise') {
            Write-MaintainStep 'mise doctor'
            mise doctor 2>&1 | Write-Host
        }

        Write-MaintainStep 'PATH shadows'
        $duplicates = @(Get-MaintainPathDuplicate)
        if ($duplicates.Count -eq 0) {
            Write-MaintainOk 'no command resolves from more than one PATH directory'
        } else {
            Write-MaintainWarn "$($duplicates.Count) command(s) exist in more than one PATH directory:"
            foreach ($duplicate in ($duplicates | Sort-Object Command)) {
                Write-Host "      $($duplicate.Command)" -ForegroundColor Yellow
                foreach ($p in $duplicate.Paths) { Write-Host "        • ${p}" -ForegroundColor DarkGray }
            }
            Write-Host '      The FIRST path wins. Uninstall the loser, or allowlist it in maintain.ps1.' -ForegroundColor DarkGray
        }

        Write-MaintainStep 'dead PATH entries'
        $dead = @(Get-MaintainDeadPath)
        if ($dead.Count -eq 0) {
            Write-MaintainOk 'every PATH entry exists'
        } else {
            Write-MaintainWarn "$($dead.Count) PATH entries point at missing directories:"
            foreach ($d in $dead) { Write-Host "      • ${d}" -ForegroundColor DarkGray }
        }

        Write-MaintainStep 'pending reboot'
        if (Test-MaintainPendingReboot) {
            Write-MaintainWarn 'a reboot is pending — updates are not fully applied until then'
        } else {
            Write-MaintainOk 'no reboot pending'
        }
    } finally {
        #-------------------------------------------------------------------------------
        # Summary — in `finally` so Ctrl-C still stops the transcript and still tells you
        # what had run by then.
        #-------------------------------------------------------------------------------
        $elapsed  = (Get-Date) - $started
        $freeEnd  = Get-MaintainFreeSpace

        Write-Host ''
        Write-Host '==================================================' -ForegroundColor Cyan
        Write-Host '                    Summary                       ' -ForegroundColor Cyan
        Write-Host '==================================================' -ForegroundColor Cyan
        Write-Host ("  elapsed: {0:mm\:ss}   steps: {1} run, {2} skipped, {3} failed" -f `
            $elapsed, $script:MaintainRan, $script:MaintainSkipped, $script:MaintainFailures.Count)

        if ($null -ne $freeStart -and $null -ne $freeEnd) {
            $reclaimed = $freeEnd - $freeStart
            $label = if ($reclaimed -ge 0) { 'reclaimed' } else { 'consumed' }
            Write-Host ("  disk: {0} {1}   ({2} free on {3})" -f `
                (Format-MaintainBytes ([math]::Abs($reclaimed))), $label,
                (Format-MaintainBytes $freeEnd), $env:SystemDrive)
        }

        if ($script:MaintainFailures.Count -gt 0) {
            Write-MaintainWarn "failed: $($script:MaintainFailures -join ', ')"
        }
        if ($transcribing) {
            Write-Host "  log: ${logFile}" -ForegroundColor DarkGray
            try { Stop-Transcript | Out-Null } catch { }

            # Retention: filenames sort chronologically, so the 10 newest are the tail.
            Get-ChildItem -LiteralPath $logRoot -Filter 'maintain-*.log' -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                Select-Object -Skip 10 |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }

        Write-Host "`n  Run 'reload' to pick up updated command paths.`n" -ForegroundColor Cyan
    }

    # Non-zero on any failure, matching the zsh side. $LASTEXITCODE is not settable from a
    # function, so this is what a caller checks.
    if ($script:MaintainFailures.Count -gt 0) { return $false }
    return $true
}

# Set-Alias, not a wrapper function: an alias cannot BAKE IN arguments, but it passes
# through whatever the caller supplies, which is all this needs.
Set-Alias -Name update-all -Value maintain -Scope Global -Force
