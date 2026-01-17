Write-Host "Running script: $($MyInvocation.MyCommand.Name)" -ForegroundColor Green

New-Item -ItemType Directory -Path "C:\ProgramData\ssh" -Force | Out-Null
Copy-Item -Path "C:\bootstrap\sshd\sshd_config" -Destination "C:\ProgramData\ssh\sshd_config" -Force

# Per-user authorized_keys for packer
$packerSshDir = "C:\Users\packer\.ssh"
New-Item -ItemType Directory -Path $packerSshDir -Force | Out-Null
Copy-Item -Path "C:\bootstrap\sshd\authorized_keys" -Destination (Join-Path $packerSshDir "authorized_keys") -Force

# Lock down ACL to packer and SYSTEM
$acl = Get-Acl $packerSshDir
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("packer", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
Set-Acl -Path $packerSshDir -AclObject $acl

Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"

Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

Get-Service sshd | Select-Object Name, Status, StartType

New-NetFirewallRule -Name "Allow-SSH" -DisplayName "Allow SSH" -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -Profile Any
