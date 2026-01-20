Write-Host "Running script: $($MyInvocation.MyCommand.Name)" -ForegroundColor Green
# determines where is bootstrap iso mounted and copies all to C:\bootstrap\
$isoLetter = Split-Path -Parent $PSCommandPath
$bootstrapFolder = "C:\bootstrap\"
New-Item -ItemType Directory -Path $bootstrapFolder -Force | Out-Null
Copy-Item -Path "$isoLetter\*" -Destination $bootstrapFolder -Recurse -Force

# logging
$logPath = Join-Path $bootstrapFolder "bootstrap.log"
Start-Transcript -Path $logPath -Append -Force | Out-Null

$scriptsRoot = Join-Path $bootstrapFolder "scripts"

#region scoop
# Crucial - will be later used by sysprep
Copy-Item -Path C:\bootstrap\unattend.xml -Destination "C:\Windows\System32\Sysprep\unattend.xml" -Force

# Installs scoop package mgmt and through it powershell 7 (core), 
# also adds CLI text editor micro, file manager far and enhanced "cat" utility bat.
# 
Write-Host "Installing Scoop globally..." -ForegroundColor White
[Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", "C:\ProgramData\scoop_config", "Machine")

$installerPath = "$env:TEMP\scoopInstaller.ps1"
Invoke-WebRequest https://get.scoop.sh -OutFile $installerPath -UseBasicParsing

& $installerPath -RunAsAdmin -ScoopDir "C:\ProgramData\scoop" -ScoopGlobalDir "C:\ProgramData\scoop\" -ScoopCacheDir "C:\ProgramData\scoop\cache"

# This fixed things afterwards ... 
[Environment]::SetEnvironmentVariable("SCOOP", "C:\ProgramData\Scoop", "Machine")
$path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$newPath = $path + ";C:\ProgramData\Scoop\shims"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")

# PowerShell 7
scoop install pwsh --global
# text editor
scoop install micro --global
# file manager
scoop install far --global
# file manager
scoop install bat --global
#endregion

#region UI and OOBE tweaks
# powershell profile for both 5 and 7, 
# with prompt showing user@host, for convenience ... 
# copy profile to defaul user directory, all nbew users should get this profile ...
# for pwsh 
New-Item -ItemType Directory -Path "C:\Users\Default\Documents\PowerShell\" -Force  | Out-Null
Copy-Item -Path "C:\bootstrap\configs\Microsoft.PowerShell_profile.ps1" `
    -Destination "C:\Users\Default\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force

 # for PowerShell   
New-Item -ItemType Directory -Path "C:\Users\Default\Documents\WindowsPowerShell\" -Force  | Out-Null
Copy-Item -Path "C:\bootstrap\configs\Microsoft.PowerShell_profile.ps1" `
    -Destination "C:\Users\Default\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force

# Disable sconfig, core only
New-Item -Path "HKLM:\SOFTWARE\Microsoft\SConfig" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\SConfig" -Name "AutoLaunch" -Value 0 -PropertyType DWord -Force

# Disable Server Manager auto-start at logon, gui only
Write-Host "Disabling Server Manager auto-start at logon" -ForegroundColor White
if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\ServerManager")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\ServerManager" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager" -Name "DoNotOpenServerManagerAtLogon" -Value 1 -Type DWord -Force

# Show hidden files, protected system files and file extensions by default in explorer
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced Hidden 1
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced ShowSuperHidden 1
Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced HideFileExt 0

# Disable product key request during OOBE
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE" -Name "SetupDisplayedProductKey" -Value 1 -Type DWord -Force

# Disable privacy experience prompts during OOBE
Write-Host "Disabling privacy experience prompts" -ForegroundColor White
if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE" -Name "DisablePrivacyExperience" -Value 1 -Type DWord -Force
#endregion

#region Set ssh connection for packer
# Last step, allows packer to execute from "outside"
& (Join-Path $scriptsRoot "Enable-Connector-SSH_packer.ps1")
Write-Host "SSH enabled. Allowing sshd to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
<#
after this, packer should take over and execute
"packerRun_Prepare-ForSysprep.ps1"
#> 
#endregion

Stop-Transcript | Out-Null

