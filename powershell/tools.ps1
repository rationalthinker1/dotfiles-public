#=======================================================================================
# External tool integration
#
# Every block is guarded by a command/module availability check — this file must load
# cleanly on a machine where none of these are installed yet. Generated init scripts go
# through Get-ToolInitScript (defined in profile.ps1) so they are cached rather than
# regenerated on every shell start, and dot-sourced HERE so their definitions land in
# the profile's scope rather than being trapped inside the helper.
#=======================================================================================

#---------------------------------------------------------------------------------------
# Environment for the shared CLI tools (these configs are already tracked in the repo)
#---------------------------------------------------------------------------------------

if (Test-Command 'bat') {
    # Matches the BAT_THEME already exported in .zshrc
    if (-not $env:BAT_THEME) { $env:BAT_THEME = 'OneHalfDark' }
    if (-not $env:PAGER)     { $env:PAGER = 'bat --plain' }
}

if (Test-Command 'fzf') {
    # Mirrors the FZF_* exports in .zshrc so both shells search identically.
    if (-not $env:FZF_DEFAULT_OPTS) {
        $env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border --info=inline'
    }
    if (Test-Command 'rg') {
        $env:FZF_DEFAULT_COMMAND = "rg --files --smart-case --hidden --follow --glob '!{.git,node_modules,vendor,build,*.lock}'"
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
    }
    if (Test-Command 'fd')  { $env:FZF_ALT_C_COMMAND = 'fd --type d' }
    if (Test-Command 'bat') {
        $env:FZF_CTRL_T_OPTS = "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
    }
}

# Point ripgrep at the config already tracked in this repo, if it is reachable.
$rgConfig = Join-Path $script:DotfilesRoot 'ripgrep/.ripgreprc'
if ((Test-Command 'rg') -and (Test-Path $rgConfig) -and -not $env:RIPGREP_CONFIG_PATH) {
    $env:RIPGREP_CONFIG_PATH = $rgConfig
}

#---------------------------------------------------------------------------------------
# zoxide — smarter cd. Officially supports PowerShell.
#---------------------------------------------------------------------------------------

$init = Get-ToolInitScript -Name 'zoxide' -Generator { zoxide init powershell --cmd cd }
if ($init) { . $init }

#---------------------------------------------------------------------------------------
# atuin — shared shell history. PowerShell support landed in atuin 18.11.
# Binds Ctrl+R itself, overriding the PSReadLine fallback set in psreadline.ps1.
#---------------------------------------------------------------------------------------

# Global, not script-scoped: the lazy PSFzf key handlers below are scriptblocks that
# run long after this file has finished, and would not see a $script: variable.
$global:DotfilesHasAtuin = Test-Command 'atuin'
if ($global:DotfilesHasAtuin) {
    $init = Get-ToolInitScript -Name 'atuin' -Generator { atuin init powershell }
    if ($init) { . $init }
}

#---------------------------------------------------------------------------------------
# PSFzf — fuzzy finding over PSReadLine, loaded lazily.
#
# Importing PSFzf measured ~330ms, a third of a cold start, for a feature that is not
# used on most prompts. So the chords are bound to a stub that imports the module on
# first press. Set-PsFzfOption then rebinds them to the real handlers, meaning the stub
# runs exactly once per session.
#
# The Test-Command guard is load-bearing, not defensive: PSFzf raises a TERMINATING
# error at import when the fzf binary is absent, which -ErrorAction cannot suppress.
#---------------------------------------------------------------------------------------

if ((Test-Command 'fzf') -and (Get-Module -ListAvailable PSFzf -ErrorAction SilentlyContinue)) {

    function Initialize-PSFzf {
        if ($global:PSFzfReady) { return $true }

        Import-Module PSFzf -ErrorAction SilentlyContinue
        if (-not (Get-Module PSFzf)) { return $false }

        if ($global:DotfilesHasAtuin) {
            # atuin owns Ctrl+R. Handing the same chord to PSFzf means whichever binds
            # last silently wins and the other stops working — so only take Ctrl+T.
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
        } else {
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        }
        Set-PsFzfOption -TabExpansion

        $global:PSFzfReady = $true
        return $true
    }

    Set-PSReadLineKeyHandler -Key 'Ctrl+t' -Description 'Fuzzy file search (loads PSFzf on first use)' -ScriptBlock {
        if (Initialize-PSFzf) { Invoke-FzfPsReadlineHandlerProvider }
    }

    if (-not $global:DotfilesHasAtuin) {
        Set-PSReadLineKeyHandler -Key 'Ctrl+r' -Description 'Fuzzy history (loads PSFzf on first use)' -ScriptBlock {
            if (Initialize-PSFzf) { Invoke-FzfPsReadlineHandlerHistory }
        }
    }
}

#---------------------------------------------------------------------------------------
# Prompt — oh-my-posh. Chosen over starship so the existing p10k zsh setup is untouched;
# both read Nerd Fonts, which this repo already installs.
#---------------------------------------------------------------------------------------

if (Test-Command 'oh-my-posh') {
    # A repo-local theme wins; otherwise a bundled p10k-alike, otherwise the default.
    $ompTheme = Join-Path $PSScriptRoot 'theme.omp.json'
    $bundled = if ($env:POSH_THEMES_PATH) {
        Join-Path $env:POSH_THEMES_PATH 'powerlevel10k_rainbow.omp.json'
    } else { $null }

    $ompConfig = if (Test-Path $ompTheme) { $ompTheme }
                 elseif ($bundled -and (Test-Path $bundled)) { $bundled }
                 else { $null }

    $init = if ($ompConfig) {
        Get-ToolInitScript -Name 'oh-my-posh' -Generator { oh-my-posh init pwsh --config $ompConfig }
    } else {
        Get-ToolInitScript -Name 'oh-my-posh' -Generator { oh-my-posh init pwsh }
    }
    if ($init) { . $init }
}

#---------------------------------------------------------------------------------------
# Optional quality-of-life modules
#---------------------------------------------------------------------------------------

# posh-git, loaded lazily. Import measured ~290ms, and oh-my-posh already renders git
# state in the prompt, so the only thing wanted here is `git <tab>` completion. This
# registers a stand-in completer that imports posh-git on the first git completion;
# posh-git's own completer then replaces this one for every subsequent Tab.
if (Get-Module -ListAvailable posh-git -ErrorAction SilentlyContinue) {
    $env:POSH_GIT_ENABLED = $false

    Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        Import-Module posh-git -ErrorAction SilentlyContinue
        if (-not (Get-Command Expand-GitCommand -ErrorAction Ignore)) { return }

        # Serve the keystroke that triggered the load. Expand-GitCommand expects the
        # trailing space PowerShell strips from `git checkout <tab>`, so pad it back
        # the same way posh-git's own completer does.
        $padLength = $cursorPosition - $commandAst.Extent.StartOffset
        $textToComplete = $commandAst.ToString().PadRight($padLength, ' ').Substring(0, $padLength)
        Expand-GitCommand $textToComplete
    }
}

#---------------------------------------------------------------------------------------
# Argument completers — the Register-ArgumentCompleter equivalent of compinit + zstyle
#---------------------------------------------------------------------------------------

if (Test-Command 'gh') {
    $init = Get-ToolInitScript -Name 'gh' -Generator { gh completion -s powershell }
    if ($init) { . $init }
}

if (Test-Command 'mise') {
    $init = Get-ToolInitScript -Name 'mise' -Generator { mise completion powershell }
    if ($init) { . $init }
}

