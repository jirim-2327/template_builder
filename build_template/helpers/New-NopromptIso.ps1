param(
    [string]$SourceIso,
    [string]$NoPromptBootFile,
    [string]$DestinationNoPromptIso,
    [string]$Title,
    [switch]$Force
)

# Assumes New-IsoFile.ps1 beign in the same directory 
$newIsoFileScriptPath = Join-Path $PSScriptRoot 'New-IsoFile.ps1'
$alreadyExistingNoPromptIso = Test-Path $DestinationNoPromptIso

# New-IsoFile.ps1 must be called only with -Force, because it throws terminating error when file already exists.
# Therefore, it can't be called like most of my scripts which just ignore when file already exists unless forced overwrite is set.
# Therefore, the way to ommit termination when overwriting is not desired, is to skip execution of New-IsoFile.ps1 script.
# I'm not author of New-IsoFile.ps1 so I don't want to change how it handles errors.
# Callings of this script (New-NoPromptIso.ps1 will remain consistent with calling of my other scripts, 
# thus, if file exists, just continue, when forced. overwrite.
if ($Force -or -not $alreadyExistingNoPromptIso) {
    $mount = Mount-DiskImage -ImagePath $SourceIso -PassThru 
    $driveLetter = ($mount | Get-Volume).DriveLetter
    $sourceDrive = "${driveLetter}:"

    Write-Host "Creating new No-Prompt iso" -ForegroundColor DarkGray
    Write-Host "Source image: $SourceIso" -ForegroundColor DarkGray
    Write-Host "Altered image: $DestinationNoPromptIso" -ForegroundColor DarkGray

    & $newIsoFileScriptPath `
        -Source $sourceDrive `
        -DestinationIso $DestinationNoPromptIso `
        -BootFile $NoPromptBootFile `
        -Title $Title `
        -Force `
        -Verbose

    Dismount-DiskImage -ImagePath $SourceIso | Out-Null
}

#Should return path and also hash
Write-Output ([PSCustomObject]@{
        Path         = $DestinationNoPromptIso
    })
