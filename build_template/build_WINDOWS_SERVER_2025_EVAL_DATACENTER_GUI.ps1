$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot "top_dir"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}
$pipelines = Join-Path $repoRoot "build_template\pipelines"
$buildPipelineScript = $(Join-Path $pipelines "Build-WindowsTemplate.ps1")

& $buildPipelineScript `
    -IsoId "WINDOWS_SERVER_2025_EVAL" `
    -ImageOption "Windows Server 2025 Datacenter Evaluation (Desktop Experience)" `
    -OverwriteDownloadedIso $false `
    -CompareChecksums $false `
    -Use_No_Prompt_Iso $false `
    -OverwriteNoPromptIso $false