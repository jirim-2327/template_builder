param(
	[string]$KeyName,
	[string]$KeyDir,
	[switch]$Force
)

$privateKey = Join-Path $KeyDir $KeyName
$publicKey = "$privateKey.pub"

if ($Force) {
	Write-Host "Generating new public/private ssh key (-Force)" -ForegroundColor DarkYellow
	'y' | ssh-keygen -t ed25519 -f $privateKey -N "" -C $KeyName
} elseif (-not (Test-Path $privateKey)) {
	Write-Host "Generating new public/private ssh key" -ForegroundColor DarkGray
	ssh-keygen -t ed25519 -f $privateKey -N "" -C $KeyName
}

[PSCustomObject]@{
	PublicKey  = $publicKey
	PrivateKey = $privateKey
}