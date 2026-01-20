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

$existingCreds = Get-StoredCredential -Target $CredentialTarget -ErrorAction SilentlyContinue

if ($existingCreds -and -not $Force) {
    Write-Host "✓ Credential already exists." -ForegroundColor Green
    Write-Host "Target:    $CredentialTarget"
    Write-Host "Username:  $UserName"
    Write-Host "Use -Force to overwrite or remove it with: Remove-StoredCredential -Target '$CredentialTarget'" -ForegroundColor Yellow
    return
}

# Generate random password and convert to SecureString
$password = New-RandomPassword -Length $PasswordLength
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

# Create or overwrite credential
New-StoredCredential -Target $CredentialTarget -UserName $UserName -SecurePassword $securePassword -Type Generic | Out-Null

Write-Host "✓ Credential stored successfully" -ForegroundColor Green
Write-Host "Target:    $CredentialTarget"
Write-Host "Username:  $UserName"