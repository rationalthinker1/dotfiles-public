#=======================================================================================
# PSReadLine — replaces zsh-autosuggestions, zsh-syntax-highlighting and history search
#
# Ships with PowerShell 7, so this is guaranteed available. Predictive IntelliSense
# (the inline grey suggestion, ZSH's autosuggest equivalent) needs PSReadLine 2.2+;
# ListView needs 2.2+ as well. Both are version-guarded below.
#=======================================================================================

Import-Module PSReadLine -ErrorAction SilentlyContinue
$psrl = Get-Module PSReadLine
if (-not $psrl) { return }

Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount 100000
Set-PSReadLineOption -ShowToolTips

#---------------------------------------------------------------------------------------
# Predictive IntelliSense — the zsh-autosuggestions analogue
#---------------------------------------------------------------------------------------

if ($psrl.Version -ge [version]'2.2.0') {
    # HistoryAndPlugin picks up CompletionPredictor when it is installed; falls back to
    # plain History when it is not, so this is safe either way.
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin

    # InlineView renders the suggestion as trailing grey text on the current line —
    # the faithful zsh-autosuggestions equivalent. ListView drops a dropdown of
    # candidates below the prompt instead; switch in local.ps1 if you prefer it:
    #   Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -PredictionViewStyle InlineView

    # Accept the inline suggestion word-by-word, like zsh-autosuggestions' forward-word.
    Set-PSReadLineKeyHandler -Key 'Ctrl+f' -Function ForwardWord
    Set-PSReadLineKeyHandler -Key 'Alt+Enter' -Function AcceptSuggestion
}

#---------------------------------------------------------------------------------------
# Key bindings
#---------------------------------------------------------------------------------------

# Prefix history search on the arrow keys — the single most useful ZSH habit to keep.
Set-PSReadLineKeyHandler -Key 'UpArrow'   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key 'DownArrow' -Function HistorySearchForward

# Readline muscle memory that Windows edit mode does not bind by default.
Set-PSReadLineKeyHandler -Key 'Ctrl+w'     -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key 'Ctrl+u'     -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Key 'Ctrl+a'     -Function BeginningOfLine
Set-PSReadLineKeyHandler -Key 'Ctrl+e'     -Function EndOfLine
Set-PSReadLineKeyHandler -Key 'Alt+Backspace' -Function BackwardKillWord

# Menu completion instead of cycling — the closest built-in analogue to fzf-tab.
# PSFzf overrides this in tools.ps1 when it is installed.
Set-PSReadLineKeyHandler -Key 'Tab'       -Function MenuComplete
Set-PSReadLineKeyHandler -Key 'Shift+Tab' -Function TabCompletePrevious

# Ctrl+R stays on the built-in reverse search here; atuin rebinds it in tools.ps1
# when present. Keeping the fallback means history search always works.
Set-PSReadLineKeyHandler -Key 'Ctrl+r' -Function ReverseSearchHistory

#---------------------------------------------------------------------------------------
# Don't persist obviously sensitive command lines to the history file
#---------------------------------------------------------------------------------------

Set-PSReadLineOption -AddToHistoryHandler {
    param([string] $line)

    if ($line.Length -lt 4) { return $false }
    if ($line -match '(?i)(password|passwd|secret|token|apikey|api_key|credential|-AsPlainText)') {
        return $false
    }
    return $true
}
