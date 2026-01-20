param(
  [string]$DownloadedIso,
  [string]$DownloadUrl,
  [switch]$Force
)

# If .iso is missing or -Force is enabled
if ($Force -or -not (Test-Path $DownloadedIso)) {
  Write-Host "Downloading $DownloadedIso" -ForegroundColor DarkGray
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadedIso -UseBasicParsing 
}

# Return full name of downloaded file
Write-Output ([PSCustomObject]@{
    Path = $DownloadedIso
  })