param(
    [string]$PackerDir,
    [string]$VmName,
    [string]$PrimaryIso,
    [string]$SecondaryIso,
    [string]$SshPrivateKeyFile,
    [string]$OutputDirectory
)

$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot "top_dir"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}

# Enable Packer debug logging
$env:PACKER_LOG = 1

$logDir = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$env:PACKER_LOG_PATH = Join-Path $logDir "packer_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

$packerTemplate = Join-Path $PackerDir "windows_shared.pkr.hcl"
$localVarFile = Join-Path $PackerDir "local.auto.pkrvars.hcl"

$packerArgs = @(
    "build"
    "-force"
    "-var-file", $localVarFile
    "-var", "vm_name=$VmName"
    "-var", "primary_iso=$PrimaryIso"
    "-var", "secondary_iso=$SecondaryIso"
    "-var", "ssh_private_key_file=$SshPrivateKeyFile"
    "-var", "output_base_path=$OutputDirectory"
)

$packerArgs += $packerTemplate

# Run packer from the template directory and display resolved variables
Write-Host "=== Packer Build Configuration ===" -ForegroundColor Cyan
Write-Host "Template: $packerTemplate" -ForegroundColor DarkYellow
Write-Host "Var File: $localVarFile" -ForegroundColor DarkYellow
Write-Host "PackerDir: $PackerDir" -ForegroundColor DarkYellow

Write-Host "=== CLI Variables ===" -ForegroundColor Cyan 
Write-Host "vm_name: $VmName" -ForegroundColor DarkYellow
Write-Host "primary_iso: $PrimaryIso" -ForegroundColor DarkYellow
Write-Host "secondary_iso: $SecondaryIso" -ForegroundColor DarkYellow
Write-Host "ssh_private_key_file: $SshPrivateKeyFile" -ForegroundColor DarkYellow
Write-Host "output_base_path: $OutputDirectory" -ForegroundColor DarkYellow

Push-Location $PackerDir
try {
    Write-Host "Running: packer $($packerArgs -join ' ')" -ForegroundColor DarkYellow
    Write-Host ""
    & packer @packerArgs
}
finally {
    Pop-Location
}

