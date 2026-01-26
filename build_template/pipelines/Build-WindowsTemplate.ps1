<#
.SYNOPSIS
Builds customized Windows virtual machines templates.
Running on packer and Hyper-V.

.PARAMETER IsoId
Easier-to-understand name for the Microsoft .iso image (e.g., "WINDOWS_SERVER_2025_EVAL").
Follows the pattern Product (Windows_Server/Windows_11), Version (2022/2025/25H2), and Channel (Consumer/LTSC/Enterprise).
Mandatory parameter, maps to and must be defined in windows_image_catalog.json.
Must correspond to the same ISO entry as *ImageOption*; only image options defined under this IsoId are valid.
(Determines url, sumcheck value, and image options) 

.PARAMETER ImageOption
Name of one of the Windows Images inside <ISO>:\sources\install.wim. Determines the Windows Edition/SKU and
installation type (Core/Desktop) and other properties. 
For WINDOWS_SERVER_2025_EVAL, it will be e.g. "Windows Server 2025 Standard Evaluation" or "Windows Server 2025 Datacenter Evaluation", with or without
"Desktop Experience". Use Get-WindowsImage -ImagePath <mounted_iso>:\sources\install.wim to list available images, or see the content of windows_image_catalog.json.
Mandatory parameter, maps to and must be defined in windows_image_catalog.json.
Must correspond to the same ISO entry as *IsoId*; only image options belonging to the selected ISO may be used.
(Determines which autounattend.xml is to be used and what will be provisioned to finished template)

.PARAMETER OverwriteDownloadedIso
Overwrite existing downloaded .iso image.

.PARAMETER OverwriteExistingSshKey
Overwrite existing SSH key pair used by packer.

.PARAMETER OverwriteExistingLocalStoreCred
Overwrite existing local store credentials for admin-deploy.

.PARAMETER CompareChecksums
Calculates and compare images' SHA-265 checksum with original's to assure the image file was not corrupted. 
Also, informs about result to console.

.PARAMETER Use_No_Prompt_Iso
If true, no-prompt ISO (efisys_noPrompt.bin injected image to skip "Press any key to boot…") is generated. 

.PARAMETER OverwriteNoPromptIso
Overwrite existing no-prompt .iso image.

.PARAMETER NoPromptBootFile
Full path to no‑prompt boot sector (efisys_noPrompt.bin) file, 
used to create media that boots automatically without the "Press any key to boot…" prompt,
avoiding reliance on Packer’s boot_command keystroke injection or on user input.

.PARAMETER EnableNestedVirtualisation
Requires other conditions to be met, some of them are: 
Enabled Virtualisation Extension and Mac Spoofing, Disabled Dynamoc Memory and at least 4GB of RAM.
NOT IMPLEMENTED

.PARAMETER BypassTPM
Mandatory for e.g  Windows 11, handled via Packer files and setting in autounattend.xml
NOT IMPLEMENTED

#>
param (
    [Parameter(Mandatory = $true)]
    [string]$IsoId,

    [Parameter(Mandatory = $true)]
    [string]$ImageOption, 
    
    [Parameter(Mandatory = $false)]
    [bool]$OverwriteDownloadedIso = $false,

    [Parameter(Mandatory = $false)]
    [bool]$OverwriteExistingSshKey = $false,

    [Parameter(Mandatory = $false)]
    [bool]$OverwriteExistingLocalStoreCred = $false,

    [Parameter(Mandatory = $false)]
    [bool]$CompareChecksums = $true,

    [Parameter(Mandatory = $false)]
    [bool]$Use_No_Prompt_Iso = $false,

    [Parameter(Mandatory = $false)]
    [bool]$OverwriteNoPromptIso = $false,

    [Parameter(Mandatory = $false)]
    [string]$NoPromptBootFile = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys_noPrompt.bin",

    [Parameter(Mandatory = $false)]
    [bool]$EnableNestedVirtualisation = $false
)
$startTime = Get-Date
#region Setup
$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot "top_dir"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}

if (-not $repoRoot -or -not (Test-Path (Join-Path $repoRoot "top_dir"))) {
    throw "Failed to locate repository root. Ensure 'top_dir' marker exists and script is in the repo."
}

Write-Host "Repository root: $repoRoot" -ForegroundColor Green

$helpers = Join-Path $repoRoot "build_template\helpers"
$packerOutput = Join-Path $repoRoot "output\packer"
$windowsImageCatalog = Join-Path $repoRoot "files\windows\windows_image_catalog.json"
$autounattendDirectory = Join-Path $repoRoot "files\windows\autounattend"

# Block with scripts' call strings
$newStructuredDirectory = Join-Path $helpers "New-StructuredDirectory.ps1"
$showTreeStructure = Join-Path $helpers "Show-TreeStructure.ps1"
$newIsoFile = Join-Path $helpers "New-IsoFile.ps1"
$downloadWindowsIso = Join-Path $helpers "Download-WindowsIso.ps1"
$validateFileHash = Join-Path $helpers "Validate-FileHash.ps1"
$newNoPromptIso = Join-Path $helpers "New-NoPromptIso.ps1"
$ensureSshKeyPair = Join-Path $helpers "Ensure-SshKeyPair.ps1"
$newLocalStoreCredentials = Join-Path $helpers "New-LocalStoreCredentials.ps1"
$invokePackerBuild = Join-Path $helpers "Invoke-PackerBuild.ps1"
#endregion

#region Catalog lookup
$catalogContent = Get-Content -Path $windowsImageCatalog -Raw | ConvertFrom-Json  # whole catalog
$catalogEntry = $catalogContent | Where-Object { $_.IsoId -eq $IsoId }  # entry matching the $IsoId
$windowsImage = $catalogEntry.WindowsImages | Where-Object { $_.Name -eq $ImageOption } # particular $windowsImage by name
#endregion

<#
Here script should tell user if the parameters script was called with are making sense,
aka are defined on .json catalog
(so script don't try to install Win 11 with core experience etc., as only some options are possible)
But, wrapper build scripts have reasonable parameters preset, so this is handled on build scripts level.
#>

Write-Host "$($MyInvocation.MyCommand.Name) executed at $startTime" -ForegroundColor Green

#region Download ISO
$downloadedIsoDir = Join-Path $repoRoot "iso\original"
$downloadedIso = Join-Path $downloadedIsoDir "$($IsoId).iso"

if ($OverwriteDownloadedIso) {
    & $downloadWindowsIso `
        -DownloadUrl $catalogEntry.DownloadUrl `
        -DownloadedIso $downloadedIso `
        -Force
} else {
    & $downloadWindowsIso `
        -DownloadUrl $catalogEntry.DownloadUrl `
        -DownloadedIso $downloadedIso
}
#endregion

#region Validate File Hash
if ($CompareChecksums) {
    & $validateFileHash `
        -FilePath  $downloadedIso `
        -ExpectedHash $catalogEntry.Sha256
} else {
    Write-Host "Skipping checksum validation ..." -ForegroundColor DarkMagenta
}
#endregion

#region No Prompt ISO
if ($Use_No_Prompt_Iso) {
    #region Create No Prompt ISO
    $downloadedIsoBaseName = (Get-Item $downloadedIso).BaseName
    $noPromptBootFileBaseName = (Get-Item $NoPromptBootFile).BaseName # efisys_noPrompt

    $noPromptIsoFullName = "${downloadedIsoBaseName}_${noPromptBootFileBaseName}.iso"
    $noPromptIso = Join-Path $repoRoot "iso\no_prompt\$noPromptIsoFullName"
    $title = "${downloadedIsoBaseName}_${noPromptBootFileBaseName}"

    if ($OverwriteNoPromptIso) {
        & $newNoPromptIso `
            -SourceIso $downloadedIso `
            -NoPromptBootFile $NoPromptBootFile `
            -DestinationNoPromptIso $noPromptIso `
            -Title $title `
            -Force
    } else {
        & $newNoPromptIso `
            -SourceIso $downloadedIso `
            -NoPromptBootFile $NoPromptBootFile `
            -DestinationNoPromptIso $noPromptIso `
            -Title $title
    }
}
#endregion

#region SSH Key Pair 
if ($OverwriteExistingSshKey) {
    $sshKeyPair = & $ensureSshKeyPair `
        -KeyName "ed25519_packer_hyperv_vm" `
        -KeyDir "$env:USERPROFILE\.ssh" `
        -Force
} else {
    $sshKeyPair = & $ensureSshKeyPair `
        -KeyName "ed25519_packer_hyperv_vm" `
        -KeyDir "$env:USERPROFILE\.ssh"
}
#endregion

#region Build secondary_iso
# Sanitazing "Names Containing (Brackets and Spaces)" to "names_ontaining_no_brackets_and_spaces)"
$buildName = $ImageOption -replace '[()]', '' -replace '\s+', '_' 
$buildName = $buildName.Trim('_').ToLower()

$secondaryIsoStagingDir = (Join-Path $repoRoot "output\$buildName\secondary_iso")
# Remove secondary iso staging directory BEFORE it is created and populated
Remove-Item -Path $secondaryIsoStagingDir -Recurse -Force -ErrorAction SilentlyContinue

# Create secondary iso staging directory
New-Item -Path $secondaryIsoStagingDir -ItemType Directory -Force -ErrorAction Continue | Out-Null

# set autounattend file, the one associated with $windowsImage from images catalog
$autounattendFile = Join-Path $autounattendDirectory $windowsImage.Autounattend

$unattendFile = (Join-Path $autounattendDirectory unattend.xml)

# Get content of public key and add it to authorized_keys 
$authorized_keys = Join-Path $repoRoot "files\windows\sshd\authorized_keys"
New-Item -Path (Split-Path $authorized_keys -Parent) -ItemType Directory -Force | Out-Null
New-Item -Path $authorized_keys -ItemType File -Force | Out-Null
(Get-Content $sshKeyPair.PublicKey -Raw) | Set-Content $authorized_keys

# Map source to destination, destination is secondary_iso staging directory
$itemsToCopy = @(
    @{ source = "$repoRoot\files\windows\scripts"; destination = "scripts" }
    @{ source = "$repoRoot\files\windows\sshd"; destination = "sshd" }
    @{ source = "$repoRoot\files\windows\configs"; destination = "configs" }
    @{ source = $autounattendFile; destination = "autounattend.xml" }
    @{ source = $unattendFile; destination = "unattend.xml" }
    @{ source = "$repoRoot\files\windows\bootstrap.ps1"; destination = "bootstrap.ps1" }
)

& $newStructuredDirectory `
    -destinationRoot $secondaryIsoStagingDir `
    -items $itemsToCopy

& $showTreeStructure $secondaryIsoStagingDir

$secondaryIso = "$secondaryIsoStagingDir.iso"
# Remove existing secondary .iso before 
Remove-Item $secondaryIso -Force -ErrorAction SilentlyContinue | Out-Null

# Must be called with -Force, otherwise throws error when $DestinationIso already exists
& $newIsoFile `
    -Source $secondaryIsoStagingDir `
    -DestinationIso $secondaryIso `
    -Title $buildName `
    -Force
#endregion

#region Credential Manager
# Ensure Credential Manager entry for admin-deploy exists (helper handles module check)
# Packer then (when connection via SSH works) runs inline Create-LocalUser and passes these credentials  
if ($OverwriteExistingLocalStoreCred) {
    & $newLocalStoreCredentials `
        -CredentialTarget "packer_admin-deploy" `
        -UserName "admin-deploy" `
        -Force
} else {
    & $newLocalStoreCredentials `
        -CredentialTarget "packer_admin-deploy" `
        -UserName "admin-deploy"
}
# Read admin-deploy credential from Windows Credential Manager for Packer variables
Import-Module TUN.CredentialManager
$adminDeployCredential = Get-StoredCredential -Target "packer_admin-deploy"
$adminDeployUsername = $adminDeployCredential.UserName
$adminDeployPassword = $adminDeployCredential.GetNetworkCredential().Password
#endregion

#region Packer Build
$runPackerBuild = $true 
# 

$primaryIso = if ($Use_No_Prompt_Iso) { $noPromptIso } else { $downloadedIso }
$sshPrivateKeyFile = $sshKeyPair.PrivateKey

if ($runPackerBuild) {
    $packerDir = Join-Path $repoRoot "packer\windows"

    & $invokePackerBuild `
        -PackerDir $packerDir `
        -VmName $buildName `
        -PrimaryIso $primaryIso `
        -IsoChecksum $isoChecksum `
        -SecondaryIso $secondaryIso `
        -SshPrivateKeyFile $sshPrivateKeyFile `
        -OutputDirectory $packerOutput `
        -AdminDeployPassword $adminDeployPassword
}
#endregion 

$endTime = Get-Date
Write-Host "$($MyInvocation.MyCommand.Name) executed at $endTime" -ForegroundColor Green
$duration = ($endTime - $startTime).ToString("hh\:mm\:ss")
Write-Host "Total time for build "$buildName" was "$duration"" -ForegroundColor DarkMagenta