$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot "top_dir"))) {
    $repoRoot = Split-Path $repoRoot -Parent
}
$pipelines = Join-Path $repoRoot "build_template\pipelines"
$buildPipelineScript = $(Join-Path $pipelines "Build-WindowsTemplate.ps1")

& $buildPipelineScript `
    -IsoId "WINDOWS_11_25H2_ENTERPRISE_EVAL" `
    -ImageOption "Windows 11 Enterprise Evaluation" `
    -OverwriteDownloadedIso $false `
    -CompareChecksums $true `
    -Use_No_Prompt_Iso $false `
    -OverwriteNoPromptIso $false

