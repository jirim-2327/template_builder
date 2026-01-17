Write-Host "Running script: $($MyInvocation.MyCommand.Name)" -ForegroundColor Green
$postSysprep = "C:\post_sysprep\"
New-Item -Path $postSysprep -ItemType Directory -Force
# logging
$logPath = Join-Path $postSysprep "bootstrap.log"
Start-Transcript -Path $logPath -Append -Force | Out-Null

function New-RandomPassword {
    param(
        [int]$Length = 35
    )
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*-_=+[]{}".ToCharArray()
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

#region Create svc-deploy account
# (Create account, set proper acl, force creation of properly named home folder)
$authorizedKeysOfflinePath = "C:\bootstrap\svc-deploy\authorized_keys"
if (Test-Path "$authorizedKeysOfflinePath") {
    Write-Host "authorised_keys present" -ForegroundColor Green
}
else {
    Write-Host "authorised_keys missing " -ForegroundColor Red
    Write-Host "Provide authorized_keys to offline image, path $authorizedKeysOfflinePath" -ForegroundColor Yellow
}
# Create deployment service account svc-deploy for Terraform/Ansible
$passwordPlain = New-RandomPassword 35
$securePassword = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
Remove-Variable passwordPlain 

New-LocalUser -Name "svc-deploy" -Password $securePassword -Description "Deployment automation account" -PasswordNeverExpires -UserMayNotChangePassword 
Add-LocalGroupMember -Group "Administrators" -Member "svc-deploy" 

# Here create user folder and set proper permissons 
$profilePath = "C:\Users\svc-deploy"
$sshDir = "$profilePath\.ssh"
$authorizedKeysFile = "$sshDir\authorized_keys"

# Copy default profile structure to initialize the profile properly,
Write-Host "Copying default profile structure to $profilePath..." -ForegroundColor Yellow
Copy-Item -Path "C:\Users\Default\*" -Destination $profilePath -Recurse -Force 

# Now profile folder exists, create .ssh and copy authorized_keys
New-Item -ItemType Directory $sshDir -Force
# C:\bootstrap\svc-deploy\authorized_keys - 
# should be already present
Copy-Item -Path "C:\bootstrap\svc-deploy\authorized_keys" -Destination $authorizedKeysFile -Force

# Set proper ACLs (SYSTEM, Administrators, and svc-deploy with FullControl)
Write-Host "Setting ACLs for profile and .ssh directory..." -ForegroundColor Yellow
$acl = Get-Acl $profilePath
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($systemRule)

$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($adminRule)

$svcDeployRule = New-Object System.Security.AccessControl.FileSystemAccessRule("svc-deploy", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($svcDeployRule)

Set-Acl -Path $profilePath -AclObject $acl
Set-Acl -Path $sshDir -AclObject $acl
Set-Acl -Path $authorizedKeysFile -AclObject $acl

Get-Acl -Path $sshDir | Select-Object -ExpandProperty Access
Get-Acl -Path $authorizedKeysFile | Select-Object -ExpandProperty Access

# Register profile in registries to prevent roaming profile creation
Write-Host "Registering svc-deploy profile in registry..." -ForegroundColor Yellow
$sid = (New-Object System.Security.Principal.NTAccount("svc-deploy")).Translate([System.Security.Principal.SecurityIdentifier]).Value
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"

New-Item -Path $regPath -Force 
New-ItemProperty -Path $regPath -Name "ProfileImagePath" -Value $profilePath -PropertyType String -Force
New-ItemProperty -Path $regPath -Name "State" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path $regPath -Name "Flags" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path $regPath -Name "FullProfile" -Value 1 -PropertyType DWord -Force

Write-Host "svc-deploy created" -ForegroundColor Yellow
Get-LocalUser -Name "svc-deploy" | Select-Object *
#endregion 

# Disable built-in Administrator account
Disable-LocalUser -Name "Administrator" 
Get-LocalUser -Name "Administrator" | Select-Object *
# Disable packer privileged account, delete also 
Remove-Item "C:\users\packer\.ssh\authorized_keys" -Force 
Disable-LocalUser -Name "packer" -ErrorAction Stop
Get-LocalUser -Name "packer" 

Stop-Transcript | Out-Null