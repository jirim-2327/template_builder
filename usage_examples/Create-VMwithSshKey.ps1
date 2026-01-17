param(
    [Parameter(Mandatory = $true)]
    [string]$VmName,

    [Parameter(Mandatory = $true)]
    [string]$TemplateVhdx,

    [Parameter(Mandatory = $true)]
    [string]$DiffDiskPath,

    [Parameter(Mandatory = $false)]
    [string]$SwitchName = "Default Switch",

    [Parameter(Mandatory = $false)]
    [int64]$MemoryStartupBytes = 8GB,

    [Parameter(Mandatory = $false)]
    [int]$ProcessorCount = 4
)

# Check admin rights
$isAdmin = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
if (-not $isAdmin) {
    throw "This script requires elevated (Administrator) privileges to mount VHDs."
}

# SSH key generation

$sshKeyDir = "$env:USERPROFILE\.ssh"
$sshKeyName = "ed25519_svc-deploy_hyperv_vm"
$privateKey = Join-Path $SshKeyDir $SshKeyName
$publicKey = "$privateKey.pub"

if (-not (Test-Path $privateKey)) {
    New-Item -ItemType Directory -Path $SshKeyDir -Force | Out-Null
    Write-Host "Generating new public/private ssh key" -ForegroundColor Yellow
    Write-Host "$privateKey"
    ssh-keygen -t ed25519 -f $privateKey -N "" -C $SshKeyName
}

# Clean up existing diff disk if present
Remove-Item $DiffDiskPath -Force -ErrorAction SilentlyContinue

# Create diff. disk from template
New-VHD -Differencing -Path $DiffDiskPath -ParentPath $TemplateVhdx

# Mount the diff disk and get drive letter
$mount = Mount-VHD -Path $DiffDiskPath -PassThru
$disk = Get-Disk | Where-Object { $_.Number -eq $mount.DiskNumber }
Get-Partition -DiskNumber $disk.Number
$osPartition = Get-Partition -DiskNumber $disk.Number |
               Where-Object { $_.Type -eq 'Basic' } |
               Sort-Object Size -Descending |
               Select-Object -First 1

$driveLetter = $osPartition.DriveLetter

if (-not $driveLetter) {
    throw "Failed to mount disk or retrieve drive letter. Ensure the disk mounted correctly."
}
Write-Output "Offline disk mounted as: $driveLetter" -ForegroundColor Green


# Create svc-deploy directory under bootstrap directory and inject files
# FirstReboot.ps1 handles rest - e.g. creation of svc-deploy account, copying file, ACLs
# It is not possible to do so here as this is only offline disk and svc-deploy used within VM 
# is not known in this context
Write-Host "Injecting authorized_keys ..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "$($driveLetter):\bootstrap\svc-deploy\" -Force | Out-Null

Get-Content $publicKey | Add-Content "$($driveLetter):\bootstrap\svc-deploy\authorized_keys"

# you can change files on disk - e.g FirstBoot.ps1 :
# Copy-Item -Path $FirstBootScript -Destination "$($driveLetter):\bootstrap\scripts\FirstBoot.ps1" -Force
# Effective only for scripts running after sysprep, so changes to e.g. bootstrap.ps1 or any 
# script running before wouldn't work, as this affects VM only after is booted.

# Dismount the disk
Write-Host "Dismounting disk..." -ForegroundColor Yellow
Dismount-VHD -Path $DiffDiskPath

# Create and configure the VM, there e.g. terraform can take over
Write-Host "Creating VM '$VmName'..." -ForegroundColor Yellow
New-VM `
    -Name $VmName `
    -Generation 2 `
    -VHDPath $DiffDiskPath `
    -SwitchName $SwitchName

Set-VMMemory -VMName $VmName -DynamicMemoryEnabled $true -StartupBytes $MemoryStartupBytes
Set-VMProcessor -VMName $VmName -Count $ProcessorCount
Set-VMFirmware -VMName $VmName -EnableSecureBoot Off
Set-VMFirmware -VMName $VmName -FirstBootDevice (Get-VMHardDiskDrive -VMName $VmName)

Write-Host "VM '$VmName' created and ready to start" -ForegroundColor Green
Write-Host "You can test ssh conection:"
Write-Host "ssh -i $env:USERPROFILE\.ssh\ed25519_svc-deploy_hyperv_vm svc-deploy@<VM IP>"