<#
.SYNOPSIS
    Runner centralizado da suite de testes Pester v5 do projeto PostInstall.

.PARAMETER Tag
    Executar apenas testes com esta tag (Unit, Integration, Smoke).

.PARAMETER Path
    Caminho específico de arquivo ou diretório a executar. Padrão: toda a pasta Tests/.

.EXAMPLE
    .\Run-Tests.ps1
    Executa todos os testes.

.EXAMPLE
    .\Run-Tests.ps1 -Tag Unit
    Executa apenas os unit tests.

.EXAMPLE
    .\Run-Tests.ps1 -Path .\Tests\Unit\Core.Registry.Tests.ps1
    Executa apenas o arquivo especificado.
#>
param(
    [string]$Tag,
    [string]$Path
)

# Garantir Pester v5
$pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester -or $pester.Version.Major -lt 5) {
    throw "Pester v5 não encontrado. Execute: Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0.0"
}
Import-Module Pester -MinimumVersion 5.0.0 -Force

$rootPath = if ($Path) { $Path } else { $PSScriptRoot }

$config = New-PesterConfiguration
$config.Run.Path             = $rootPath
$config.Output.Verbosity     = 'Detailed'
$config.TestResult.Enabled   = $true
$config.TestResult.OutputPath = (Join-Path $PSScriptRoot 'TestResults.xml')

if ($Tag) {
    $config.Filter.Tag = $Tag
}

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    Write-Host ""
    Write-Host "FALHOU: $($result.FailedCount) teste(s) falharam." -ForegroundColor Red
    exit 1
}
else {
    Write-Host ""
    Write-Host "PASSOU: Todos os $($result.PassedCount) teste(s) passaram." -ForegroundColor Green
    exit 0
}
