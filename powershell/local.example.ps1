#=======================================================================================
# Machine-specific PowerShell overrides — the counterpart to zsh/local.zsh
#
# Copy to `local.ps1` (gitignored) and edit. Sourced LAST by profile.ps1, so anything
# here wins over the tracked configuration.
#=======================================================================================

# --- Environment -----------------------------------------------------------------
# $env:EDITOR = 'nvim'
# $env:SOME_API_HOST = 'internal.example.com'

# NOTE: secrets do not belong here even though this file is gitignored. Use the
# SecretManagement module or `pass` via WSL:
#   Get-Secret -Name 'my-token' -AsPlainText

# --- Machine-specific PATH entries ------------------------------------------------
# $env:PATH = "C:\tools\bin;${env:PATH}"

# --- Overrides --------------------------------------------------------------------
# function ll { eza --long --all --icons @args }

# --- Work-only helpers ------------------------------------------------------------
# function vpn { rasdial 'Work VPN' }

# --- Opt-in extras ----------------------------------------------------------------
# Terminal-Icons adds file-type icons to Get-ChildItem, but costs ~380ms to import —
# a third of a cold start. eza --icons covers the same ground for free, so it is left
# out of the tracked profile. Uncomment if you want it anyway:
#   Install-PSResource Terminal-Icons -Scope CurrentUser -TrustRepository
#   Import-Module Terminal-Icons

# ListView shows prediction candidates in a dropdown instead of inline grey text:
#   Set-PSReadLineOption -PredictionViewStyle ListView
