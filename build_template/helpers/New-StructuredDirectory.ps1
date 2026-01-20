param(
    [string]$destinationRoot,
    [array]$items  # @{ source='...'; destination='...' }
)

Write-Host "Creating directory $destinationRoot" -ForegroundColor DarkGray
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

Write-Host "Copying files ..." -ForegroundColor DarkGray
foreach ($item in $items) {
    $sourcePath = $item.source
    $destRelativePath = $item.destination
    
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "Source does not exist: $sourcePath"
        continue
    }
    
    $destPath = Join-Path $destinationRoot $destRelativePath
    
    $destParent = Split-Path $destPath -Parent
    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    Write-Host "Source.......: $sourcePath" -ForegroundColor DarkGray
    Write-Host "Destination..: $destPath" -ForegroundColor DarkGray
    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force | Out-Null
}
