param(
    [string]$CredentialTarget = "packer_admin-deploy",
    [string]$UserName = "admin-deploy",
    [int]$PasswordLength = 35,
    [switch]$Force
)

# Check if TUN.CredentialManager module is installed
if (-not (Get-Module -ListAvailable -Name TUN.CredentialManager)) {
    Write-Host "ERROR: Module 'TUN.CredentialManager' is not installed." -ForegroundColor Red
    Write-Host "Install it with: Install-Module -Name TUN.CredentialManager -Scope CurrentUser" -ForegroundColor Yellow
    return
}


Import-Module TUN.CredentialManager

function New-RandomPassword {
    param([int]$Length = 35)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    $password = -join ($bytes | ForEach-Object { $chars[[int]($_ % $chars.Length)] })
    $rng.Dispose()
    return $password
}

# Get-StoredCredentials is not reliable and somehow always returns 
# credentials with UserName admin-deploy, 
# even if credentials from credential manager were deleted and 
# Remove-StoredCredential -Target 'packer_admin-deploy' throws:
# Remove-StoredCredential: DeleteCred failed with the error code 1168 (credential not found). 
# So there must the credentials exist in some way or another, so for this script to work, 
# I just check if there are credentials with UserName matching 'admin-deploy'
# because it works, but if there will be more than one 'admin-deploy', 
# false positive will occur, but I have no way to find it by target, native methods like 
# Advapi32 tested, shows that credentiakls exist w=if I use Target to get them ... 


# Simple logic: only skip if username exists and -Force not used
$existingByUser = Get-StoredCredential -Type Generic | Where-Object { $_.UserName -eq $UserName }
if ($existingByUser -and -not $Force) {
    Write-Host "✓ Credential for username '$UserName' already exists. Use -Force to overwrite." -ForegroundColor Green
    return
}

$password = New-RandomPassword -Length $PasswordLength
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
New-StoredCredential -Target $CredentialTarget -UserName $UserName -SecurePassword $securePassword -Type Generic | Out-Null
Write-Host "✓ Credential stored successfully" -ForegroundColor Green
Write-Host "Target:    $CredentialTarget"
Write-Host "Username:  $UserName"