param(
    [ValidateSet('Check', 'Fix')]
    [string]$Mode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$formatterScript = Join-Path $repoRoot 'Scripts\Format-All.ps1'

if (-not (Test-Path $formatterScript)) {
    throw "Script não encontrado: $formatterScript"
}

& $formatterScript -Mode $Mode
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Lint/format check concluído com sucesso (Mode=$Mode)." -ForegroundColor Green
exit 0
