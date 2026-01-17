function prompt {
    Write-Host $env:USERNAME -NoNewline -ForegroundColor DarkGreen
    Write-Host "@" -NoNewline -ForegroundColor DarkRed
    Write-Host $env:COMPUTERNAME -NoNewline -ForegroundColor DarkGreen
    Write-Host " $(Get-Location)" -ForegroundColor DarkYellow
    return "> "
}

# Microsoft.PowerShell_profile.ps1 paths for default user:
# C:\Users\Default\Documents\PowerShell\Microsoft.PowerShell_profile.ps1          - pwsh
# C:\Users\Default\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1   - PowerShell