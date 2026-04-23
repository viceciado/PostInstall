param(
    [ValidateSet('Check', 'Fix')]
    [string]$Mode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[Format-All] $Message" -ForegroundColor Cyan
}

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Test-FileHasUtf8Bom {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 3) {
        return $false
    }

    return ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Read-YesNoAnswer {
    param([Parameter(Mandatory)][string]$Prompt)

    while ($true) {
        $answer = Read-Host "$Prompt [S/N]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            continue
        }

        $normalized = $answer.Trim().ToUpperInvariant()
        if ($normalized -in @('S', 'SIM', 'Y', 'YES')) {
            return $true
        }

        if ($normalized -in @('N', 'NAO', 'NÃO', 'NO')) {
            return $false
        }

        Write-Info "Resposta inválida: '$answer'. Digite S ou N."
    }
}

function Write-DotNetSdkInstallSuggestion {
    Write-Info 'Sugestão: instale o .NET SDK 8+ para habilitar a formatação de XAML.'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info 'Comando sugerido: winget install --id Microsoft.DotNet.SDK.8 -e'
    }

    Write-Info 'Download oficial: https://aka.ms/dotnet/download'
}

function Test-DotNetSdkInstalled {
    $sdks = & dotnet --list-sdks 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace(($sdks | Out-String))
}

function Install-DotNetSdkIfUserApproves {
    if (-not [Environment]::UserInteractive) {
        Write-Info 'AVISO: ambiente não interativo; não é possível instalar o .NET SDK automaticamente.'
        Write-DotNetSdkInstallSuggestion
        return $false
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Info 'AVISO: winget não disponível para instalação automática do .NET SDK.'
        Write-DotNetSdkInstallSuggestion
        return $false
    }

    if (-not (Read-YesNoAnswer -Prompt 'Deseja instalar automaticamente o .NET SDK 8+ agora?')) {
        Write-DotNetSdkInstallSuggestion
        return $false
    }

    Write-Info 'Instalando .NET SDK 8+ via winget...'
    & winget install --id Microsoft.DotNet.SDK.8 -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Info 'AVISO: falha na instalação automática do .NET SDK.'
        Write-DotNetSdkInstallSuggestion
        return $false
    }

    if (Test-DotNetSdkInstalled) {
        Write-Info '.NET SDK detectado com sucesso.'
        return $true
    }

    Write-Info 'AVISO: instalação concluída, mas nenhum SDK detectado na sessão atual.'
    Write-Info 'Abra um novo terminal e execute o Format-All novamente.'
    Write-DotNetSdkInstallSuggestion
    return $false
}

function Get-XamlStylerExecutablePath {
    return (Join-Path (Join-Path $env:USERPROFILE '.dotnet\tools') 'xstyler.exe')
}

function Ensure-GlobalXamlStylerAvailable {
    $toolPath = Get-XamlStylerExecutablePath
    if (Test-Path $toolPath) {
        return $true
    }

    $shouldInstall = $true
    if ([Environment]::UserInteractive) {
        $shouldInstall = Read-YesNoAnswer -Prompt 'xstyler.exe não encontrado. Deseja instalar XamlStyler.Console globalmente agora?'
    }

    if (-not $shouldInstall) {
        Write-Info 'Sugestão: dotnet tool install --global xamlstyler.console --version 3.2501.8'
        return $false
    }

    & dotnet tool install --global xamlstyler.console --version 3.2501.8 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -and -not (Test-Path $toolPath)) {
        Write-Info 'AVISO: falha ao instalar xamlstyler.console globalmente.'
        Write-Info 'Sugestão: dotnet tool update --global xamlstyler.console'
        return $false
    }

    if (-not (Test-Path $toolPath)) {
        Write-Info 'AVISO: instalação concluída, mas xstyler.exe não localizado na pasta global de tools.'
        return $false
    }

    Write-Info 'XamlStyler.Console instalado com sucesso.'
    return $true
}

function Invoke-PowerShellFormatting {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunMode
    )

    $settingsPath = Join-Path $RepoRoot 'PSScriptAnalyzerSettings.psd1'
    if (-not (Test-Path $settingsPath)) {
        throw "Arquivo de configuração não encontrado: $settingsPath"
    }

    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        throw 'PSScriptAnalyzer não encontrado. Execute: Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck'
    }

    Import-Module PSScriptAnalyzer -ErrorAction Stop

    $psFiles = Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.ps1' -File |
        Where-Object {
            $_.FullName -notmatch '\\.git\\' -and
            $_.Name -ne 'PostInstall.ps1'
        }

    if (-not $psFiles) {
        Write-Info 'Nenhum arquivo .ps1 encontrado para verificar.'
        return
    }

    $violations = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $psFiles) {
        $original = [System.IO.File]::ReadAllText($file.FullName)
        $formatted = Invoke-Formatter -ScriptDefinition $original -Settings $settingsPath
        $hasBom = Test-FileHasUtf8Bom -Path $file.FullName

        if ($RunMode -eq 'Fix') {
            if ($formatted -ne $original -or -not $hasBom) {
                Write-Utf8BomFile -Path $file.FullName -Content $formatted
                Write-Info "Atualizado .ps1: $($file.FullName)"
            }

            continue
        }

        if ($formatted -ne $original) {
            $violations.Add("Formato PowerShell divergente: $($file.FullName)")
        }

        if (-not $hasBom) {
            $violations.Add("Sem UTF-8 BOM: $($file.FullName)")
        }
    }

    if ($violations.Count -gt 0) {
        $details = $violations -join [Environment]::NewLine
        throw "Validação de PowerShell falhou:$([Environment]::NewLine)$details"
    }
}

function Invoke-XamlFormatting {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunMode
    )

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Info 'AVISO: comando dotnet não encontrado. Pulando validação de XAML.'
        if (-not (Install-DotNetSdkIfUserApproves)) {
            return
        }
    }

    if (-not (Test-DotNetSdkInstalled)) {
        Write-Info 'AVISO: dotnet encontrado, mas nenhum SDK instalado. Pulando validação de XAML.'
        if (-not (Install-DotNetSdkIfUserApproves)) {
            return
        }
    }

    if (-not (Ensure-GlobalXamlStylerAvailable)) {
        Write-Info 'AVISO: xstyler global indisponível. Pulando validação de XAML.'
        return
    }

    $toolPath = Get-XamlStylerExecutablePath
    $xstylerArgs = @('-d', 'Windows', '-r', '-c', 'Settings.XamlStyler')
    if ($RunMode -eq 'Check') {
        $xstylerArgs += '-p'
    }

    Push-Location $RepoRoot
    try {
        $nativePrefVar = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
        if ($nativePrefVar) {
            $savedNativePref = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }

        $output = & $toolPath @xstylerArgs 2>&1
        $exitCode = $LASTEXITCODE

        if ($nativePrefVar) {
            $PSNativeCommandUseErrorActionPreference = $savedNativePref
        }

        if ($exitCode -ne 0) {
            $details = $output | Out-String
            if ($RunMode -eq 'Check') {
                throw "Validação de XAML falhou. Execute ./Scripts/Format-All.ps1 -Mode Fix para corrigir.$([Environment]::NewLine)$details"
            }

            throw "Formatação de XAML falhou.$([Environment]::NewLine)$details"
        }
    } finally {
        Pop-Location
    }
}

function Invoke-JsonFormatting {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunMode
    )

    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Info 'AVISO: npx não encontrado. Pulando validação de JSON. Instale o Node.js 18+ para formatação local.'
        return
    }

    $jsonArgs = @('--yes', 'prettier@3.3.3', '--config', '.prettierrc.json', '--ignore-path', '.prettierignore')
    if ($RunMode -eq 'Check') {
        $jsonArgs += '--check'
    } else {
        $jsonArgs += '--write'
    }

    $jsonArgs += 'Data/**/*.json'

    Push-Location $RepoRoot
    try {
        & npx @jsonArgs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            if ($RunMode -eq 'Check') {
                throw 'Validação de JSON falhou. Execute ./Scripts/Format-All.ps1 -Mode Fix para corrigir.'
            }

            throw 'Formatação de JSON falhou.'
        }
    } finally {
        Pop-Location
    }
}


$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Info "Modo: $Mode"
Write-Info 'Validando/formatando PowerShell (.ps1)...'
Invoke-PowerShellFormatting -RepoRoot $repoRoot -RunMode $Mode

Write-Info 'Validando/formatando XAML (.xaml)...'
Invoke-XamlFormatting -RepoRoot $repoRoot -RunMode $Mode

Write-Info 'Validando/formatando JSON (.json)...'
Invoke-JsonFormatting -RepoRoot $repoRoot -RunMode $Mode

Write-Info 'Concluído com sucesso.'