param(
  [string]$FilePath,
  [string]$ExpectedHash,
  [string]$Algorithm = "SHA256"
)

Write-Host "Computing $Algorithm hash for $(Split-Path -Leaf $FilePath)..." -ForegroundColor DarkGray
$computedHash = (Get-FileHash -Path $FilePath -Algorithm $Algorithm).Hash
$match = ($computedHash -eq $ExpectedHash)

Write-Output ([PSCustomObject]@{
    FilePath      = $FilePath
    ExpectedHash  = $ExpectedHash
    ComputedHash  = $computedHash
    Match         = $match
    Algorithm     = $Algorithm
  })

# Log results, but don't halt pipeline
if ($match) {
  Write-Host "✓ Hash MATCH: File integrity verified" -ForegroundColor Green
} else {
  Write-Host "✗ Hash MISMATCH: Expected $ExpectedHash, got $computedHash" -ForegroundColor Red
  Write-Host "  Pipeline continues - caller decides if this is fatal" -ForegroundColor Yellow
}
