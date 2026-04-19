#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests para funções de tweaks: Get-TweakByName, Set-Tweak, Restore-Tweak.

.NOTES
    - Get-AvailableItems é Mockado para retornar dados da fixture JSON.
    - Set-RegistryEntry, Restore-RegistryEntry e Write-InstallLog são Mockados.
    - $global:ScriptContext.AppliedTweaks é verificado diretamente para Set-Tweak.
#>

BeforeAll {
    $script:ProjectRoot  = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:FixturePath  = Join-Path $script:ProjectRoot 'Tests\Fixtures\SampleTweaks.json'

    $global:LogPath = Join-Path $env:TEMP 'PostInstall-Unit-Tweaks-Test.log'

    # Dot-source dependências necessárias
    . (Join-Path $script:ProjectRoot 'Core\Logging\Write-InstallLog.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Process\Invoke-ElevatedProcess.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\ConvertTo-RegistryType.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Set-RegistryEntry.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Restore-RegistryEntry.ps1')
    . (Join-Path $script:ProjectRoot 'Core\UI\Get-AvailableWindows.ps1')   # Get-AvailableItems
    . (Join-Path $script:ProjectRoot 'Features\Tweaks\Get-TweakByName.ps1')
    . (Join-Path $script:ProjectRoot 'Features\Tweaks\Restart-Explorer.ps1')
    . (Join-Path $script:ProjectRoot 'Features\Tweaks\Invoke-TweaksManager.ps1')
    . (Join-Path $script:ProjectRoot 'Features\Tweaks\Set-Tweak.ps1')
    . (Join-Path $script:ProjectRoot 'Features\Tweaks\Restore-Tweak.ps1')

    # Carregar fixture JSON para uso nos mocks
    $script:SampleTweaks = (Get-Content -LiteralPath $script:FixturePath -Raw -Encoding UTF8 | ConvertFrom-Json).Tweaks
}

AfterAll {
    Remove-Item $global:LogPath -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name 'LogPath', 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-TweakByName' -Tag 'Unit' {

    BeforeAll {
        Mock Write-InstallLog {}
        Mock Get-AvailableItems { return $script:SampleTweaks }
    }

    It 'Encontra tweak existente pelo nome exato' {
        $t = Get-TweakByName -Name 'TestTweak-Registry'
        $t | Should -Not -BeNullOrEmpty
    }

    It 'Retorna o tweak correto (Name bate)' {
        $t = Get-TweakByName -Name 'TestTweak-Script'
        $t.Name | Should -Be 'TestTweak-Script'
    }

    It 'Retorna $null para nome inexistente' {
        $t = Get-TweakByName -Name 'NaoExiste'
        $t | Should -BeNullOrEmpty
    }

    It 'Retorna apenas um item (Select-Object -First 1)' {
        $t = Get-TweakByName -Name 'TestTweak-Registry'
        @($t).Count | Should -Be 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Set-Tweak' -Tag 'Unit' {

    Context 'Tweak com Registry (IsBoolean = $true)' {
        BeforeAll {
            Mock Write-InstallLog  {}
            Mock Get-AvailableItems { return $script:SampleTweaks }
            Mock Set-RegistryEntry  { return $true }
            Mock Invoke-Expression  {}
            Mock Test-Path          { $false }
            Mock Remove-Item        {}
        }
        BeforeEach {
            $global:ScriptContext = @{ IsCompiled = $false; AppliedTweaks = @{}; UI = @{}; System = @{}; Config = @{} }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $true em sucesso' {
            $result = Set-Tweak -Name 'TestTweak-Registry'
            $result | Should -BeTrue
        }

        It 'Chama Set-RegistryEntry para cada entrada de registro' {
            Set-Tweak -Name 'TestTweak-Registry'
            Should -Invoke Set-RegistryEntry -Exactly 1
        }

        It 'Grava no AppliedTweaks quando IsBoolean é $true e sucesso' {
            Set-Tweak -Name 'TestTweak-Registry'
            $global:ScriptContext.AppliedTweaks.ContainsKey('TestTweak-Registry') | Should -BeTrue
        }
    }

    Context 'Tweak com Script (IsBoolean = $false)' {
        BeforeAll {
            Mock Write-InstallLog  {}
            Mock Get-AvailableItems { return $script:SampleTweaks }
            Mock Set-RegistryEntry  { return $true }
            Mock Invoke-Expression  {}
            Mock Test-Path          { $false }
            Mock Remove-Item        {}
        }
        BeforeEach {
            $global:ScriptContext = @{ IsCompiled = $false; AppliedTweaks = @{}; UI = @{}; System = @{}; Config = @{} }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Chama Invoke-Expression para o script' {
            Set-Tweak -Name 'TestTweak-Script'
            Should -Invoke Invoke-Expression -Exactly 1
        }

        It 'NÃO grava no AppliedTweaks quando IsBoolean é $false' {
            Set-Tweak -Name 'TestTweak-Script'
            $global:ScriptContext.AppliedTweaks.ContainsKey('TestTweak-Script') | Should -BeFalse
        }
    }

    Context 'Tweak inexistente' {
        BeforeAll {
            Mock Write-InstallLog  {}
            Mock Get-AvailableItems { return $script:SampleTweaks }
            Mock Set-RegistryEntry  { return $true }
            Mock Invoke-Expression  {}
            Mock Test-Path          { $false }
            Mock Remove-Item        {}
        }
        BeforeEach {
            $global:ScriptContext = @{ IsCompiled = $false; AppliedTweaks = @{} }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $false quando o tweak não é encontrado' {
            $result = Set-Tweak -Name 'NaoExiste'
            $result | Should -BeFalse
        }

        It 'Chama Write-InstallLog com status ERRO' {
            $null = Set-Tweak -Name 'NaoExiste'
            Should -Invoke -CommandName Write-InstallLog -ParameterFilter { $Status -eq 'ERRO' } -Times 1 -Exactly
        }
    }

    Context 'Falha no Set-RegistryEntry' {
        BeforeAll {
            Mock Write-InstallLog  {}
            Mock Get-AvailableItems { return $script:SampleTweaks }
            Mock Set-RegistryEntry  { return $false }
            Mock Invoke-Expression  {}
            Mock Test-Path          { $false }
            Mock Remove-Item        {}
        }
        BeforeEach {
            $global:ScriptContext = @{ IsCompiled = $false; AppliedTweaks = @{} }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $false quando Set-RegistryEntry falha' {
            $result = Set-Tweak -Name 'TestTweak-Registry'
            $result | Should -BeFalse
        }

        It 'NÃO grava no AppliedTweaks quando registro falhou' {
            Set-Tweak -Name 'TestTweak-Registry'
            $global:ScriptContext.AppliedTweaks.ContainsKey('TestTweak-Registry') | Should -BeFalse
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Restore-Tweak' -Tag 'Unit' {

    Context 'Tweak com Registry' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Get-AvailableItems  { return $script:SampleTweaks }
            Mock Restore-RegistryEntry { return $true }
            Mock Invoke-Expression   {}
            $global:ScriptContext = @{ IsCompiled = $false }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $true em sucesso' {
            $result = Restore-Tweak -Name 'TestTweak-Registry'
            $result | Should -BeTrue
        }

        It 'Chama Restore-RegistryEntry para cada entrada de registro' {
            Restore-Tweak -Name 'TestTweak-Registry'
            Should -Invoke Restore-RegistryEntry -Exactly 1
        }
    }

    Context 'Tweak com UndoScript' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Get-AvailableItems  { return $script:SampleTweaks }
            Mock Restore-RegistryEntry { return $true }
            Mock Invoke-Expression   {}
            $global:ScriptContext = @{ IsCompiled = $false }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Chama Invoke-Expression para o UndoScript' {
            Restore-Tweak -Name 'TestTweak-Script'
            Should -Invoke Invoke-Expression -Exactly 1
        }
    }

    Context 'Tweak inexistente' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Get-AvailableItems  { return $script:SampleTweaks }
            Mock Restore-RegistryEntry { return $true }
            Mock Invoke-Expression   {}
            $global:ScriptContext = @{ IsCompiled = $false }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $false quando o tweak não é encontrado' {
            $result = Restore-Tweak -Name 'NaoExiste'
            $result | Should -BeFalse
        }
    }

    Context 'Falha no Restore-RegistryEntry' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Get-AvailableItems  { return $script:SampleTweaks }
            Mock Restore-RegistryEntry { return $false }
            Mock Invoke-Expression   {}
            $global:ScriptContext = @{ IsCompiled = $false }
        }
        AfterAll {
            Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
        }

        It 'Retorna $false quando Restore-RegistryEntry falha' {
            $result = Restore-Tweak -Name 'TestTweak-Registry'
            $result | Should -BeFalse
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-TweaksManager' -Tag 'Unit' {

    BeforeEach {
        $global:ScriptContext = @{ AppliedTweaks = @{} }
        Mock Write-InstallLog {}
        Mock Invoke-ElevatedProcess { return 'True' }
        Mock Get-TweakByName { return @{ RefreshRequired = $false } }
        Mock Restart-Explorer {}
    }

    AfterEach {
        Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Lança erro quando não recebe Tweaks nem Names' {
        { Invoke-TweaksManager -Mode Apply } | Should -Throw
    }

    It 'Aplica tweaks quando recebe Names válidos' {
        Invoke-TweaksManager -Mode Apply -Names @('TestTweak-Registry')
        Should -Invoke Invoke-ElevatedProcess -Exactly 1 -ParameterFilter { $FunctionName -eq 'Set-Tweak' }
    }
}
