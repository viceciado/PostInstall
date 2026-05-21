#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Smoke test do contrato C12: runtime compilado único (sem fallback dot-source).
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:CompiledPath = Join-Path $script:ProjectRoot 'PostInstall.ps1'

    if (-not (Test-Path -LiteralPath $script:CompiledPath)) {
        throw "Artefato compilado não encontrado em: $script:CompiledPath. Execute ./Builder.ps1 antes dos testes."
    }

    $script:CompiledContent = Get-Content -LiteralPath $script:CompiledPath -Raw -Encoding UTF8
}

Describe 'Contrato C12 do artefato compilado' -Tag 'Smoke', 'Compiled' {
    It 'Contém Start-PostInstallMain como entrypoint encapsulado' {
        $script:CompiledContent | Should -Match 'function\s+Start-PostInstallMain\s*\{'
    }

    It 'Define IsCompiled como true no ScriptContext' {
        $script:CompiledContent | Should -Match 'IsCompiled\s*=\s*\$true'
    }

    It 'Inicializa CompiledScriptPath em runtime' {
        $script:CompiledContent | Should -Match 'CompiledScriptPath\s*=\s*\$MyInvocation\.MyCommand\.Path'
    }

    It 'Não contém fallback dot-source de Core no async' {
        $script:CompiledContent.Contains("Get-ChildItem '$rp\Core' -Recurse -Filter '*.ps1'") | Should -BeFalse
    }

    It 'Não contém fallback dot-source de Features no async' {
        $script:CompiledContent.Contains("Get-ChildItem '$rp\Features' -Recurse -Filter '*.ps1'") | Should -BeFalse
    }

    It 'Não contém fallback dot-source de DialogInitializers no async' {
        $script:CompiledContent.Contains("Get-ChildItem '$rp\DialogInitializers' -Filter '*.ps1'") | Should -BeFalse
    }
}
