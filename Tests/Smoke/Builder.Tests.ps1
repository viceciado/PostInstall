#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Smoke test do Builder: compila o projeto e valida o artefato gerado.

.NOTES
    - Compila para _TestBuild.ps1 (separado de PostInstall-Compiled.ps1 real).
    - Verifica tamanho, sintaxe e presença das funções esperadas.
    - Limpa o artefato em AfterAll independente de falha.
    - Pode levar 10-30s (compilação completa).
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:OutputName = '_TestBuild.ps1'
    $script:OutputPath = Join-Path $script:ProjectRoot $script:OutputName
    $script:BuilderPath = Join-Path $script:ProjectRoot 'Builder.ps1'

    # Limpar artefato anterior se existir
    if (Test-Path $script:OutputPath) { Remove-Item $script:OutputPath -Force }

    # Executar builder num processo filho para isolar contexto
    $script:BuildResult = & powershell.exe -NoProfile -NonInteractive -File $script:BuilderPath `
        -OutputName $script:OutputName 2>&1

    $script:BuildExitCode = $LASTEXITCODE
}

AfterAll {
    if (Test-Path $script:OutputPath) {
        Remove-Item $script:OutputPath -Force -ErrorAction SilentlyContinue
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Builder — compilação e artefato' -Tag 'Smoke' {

    It 'Builder.ps1 executou sem código de saída de erro' {
        $script:BuildExitCode | Should -Be 0
    }

    It 'Arquivo compilado foi criado' {
        Test-Path $script:OutputPath | Should -BeTrue
    }

    It 'Arquivo compilado tem tamanho > 100KB (sanidade)' {
        $size = (Get-Item $script:OutputPath).Length
        $size | Should -BeGreaterThan 102400
    }

    It 'Arquivo compilado tem sintaxe PowerShell válida' {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:OutputPath, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    Context 'Funções obrigatórias presentes no compilado' {

        It 'Write-InstallLog está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Write-InstallLog'
        }

        It 'ConvertTo-RegistryType está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function ConvertTo-RegistryType'
        }

        It 'Set-RegistryEntry está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Set-RegistryEntry'
        }

        It 'Restore-RegistryEntry está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Restore-RegistryEntry'
        }

        It 'Get-AvailableItems está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Get-AvailableItems'
        }

        It 'Set-Tweak está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Set-Tweak'
        }

        It 'Install-WinGet está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Install-WinGet'
        }

        It 'Get-DefaultDialogConfiguration está declarada' {
            $script:OutputPath | Should -FileContentMatch 'function Get-DefaultDialogConfiguration'
        }

        It 'Bloco ENTRYPOINT está presente' {
            $script:OutputPath | Should -FileContentMatch '#region ENTRYPOINT|INICIALIZAÇÃO DAS JANELAS PRINCIPAIS'
        }
    }
}

Describe 'Builder — hardening de erro de compilação' -Tag 'Smoke' {
    It 'Falha com código != 0 quando há erro em arquivo de função' {
        $brokenFile = Join-Path $script:ProjectRoot 'Core\_TempBuilderBroken.ps1'
        $failOutputName = '_TestBuild-Fail.ps1'
        $failOutputPath = Join-Path $script:ProjectRoot $failOutputName

        try {
            if (Test-Path $brokenFile) { Remove-Item $brokenFile -Force }
            if (Test-Path $failOutputPath) { Remove-Item $failOutputPath -Force }

            @'
function Test-BrokenBuilderSyntax {
    param(
        [string]$Name
    # Deliberadamente inválido: parêntese/fechamento ausente
'@ | Set-Content -Path $brokenFile -Encoding UTF8

            $result = & powershell.exe -NoProfile -NonInteractive -File $script:BuilderPath -OutputName $failOutputName 2>&1
            $exitCode = $LASTEXITCODE

            $exitCode | Should -Not -Be 0
            ($result | Out-String) | Should -Match 'Falha na compilação de blocos'
            (Test-Path $failOutputPath) | Should -BeFalse
        } finally {
            if (Test-Path $brokenFile) { Remove-Item $brokenFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $failOutputPath) { Remove-Item $failOutputPath -Force -ErrorAction SilentlyContinue }
        }
    }
}

