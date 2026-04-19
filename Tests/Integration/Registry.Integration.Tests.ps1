#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Integration tests de registro — usa sandbox real em HKCU:\SOFTWARE\_PostInstall_Tests\.

.NOTES
    - Todos os testes operam em HKCU (sem admin necessário).
    - AfterAll remove a chave sandbox por completo.
    - Write-InstallLog é Mockado para evitar I/O de log em disco.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:SandboxPath = 'HKCU:\SOFTWARE\_PostInstall_Tests'

    $global:LogPath = Join-Path $env:TEMP 'PostInstall-Integration-Registry-Test.log'

    . (Join-Path $script:ProjectRoot 'Core\Logging\Write-InstallLog.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\ConvertTo-RegistryType.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Set-RegistryEntry.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Restore-RegistryEntry.ps1')

    # Criar chave raiz do sandbox (limpo)
    if (Test-Path $script:SandboxPath) {
        Remove-Item $script:SandboxPath -Recurse -Force
    }
    New-Item -Path $script:SandboxPath -Force | Out-Null

    Mock Write-InstallLog {}
}

AfterAll {
    # Garantir limpeza total do sandbox
    if (Test-Path $script:SandboxPath) {
        Remove-Item $script:SandboxPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $global:LogPath -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name 'LogPath' -Scope Global -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Set-RegistryEntry — HKCU sandbox' -Tag 'Integration' {

    Context 'DWORD' {
        BeforeAll { $script:DwordPath = "$($script:SandboxPath)\DWORD" }
        AfterAll  { Remove-Item $script:DwordPath -Recurse -Force -ErrorAction SilentlyContinue }

        It 'Cria a chave e grava valor DWORD 42' {
            $r = Set-RegistryEntry -Path $script:DwordPath -Name 'TestVal' -Type 'DWORD' -Value 42
            $r | Should -BeTrue
            (Get-ItemProperty -Path $script:DwordPath -Name 'TestVal').TestVal | Should -Be 42
        }

        It 'Atualiza valor DWORD existente para 99' {
            Set-RegistryEntry -Path $script:DwordPath -Name 'TestVal' -Type 'DWORD' -Value 42
            $r = Set-RegistryEntry -Path $script:DwordPath -Name 'TestVal' -Type 'DWORD' -Value 99
            $r | Should -BeTrue
            (Get-ItemProperty -Path $script:DwordPath -Name 'TestVal').TestVal | Should -Be 99
        }
    }

    Context 'STRING' {
        BeforeAll { $script:StringPath = "$($script:SandboxPath)\STRING" }
        AfterAll  { Remove-Item $script:StringPath -Recurse -Force -ErrorAction SilentlyContinue }

        It 'Cria a chave e grava valor String' {
            $r = Set-RegistryEntry -Path $script:StringPath -Name 'StrVal' -Type 'STRING' -Value 'PostInstallTest'
            $r | Should -BeTrue
            (Get-ItemProperty -Path $script:StringPath -Name 'StrVal').StrVal | Should -Be 'PostInstallTest'
        }
    }

    Context 'QWORD' {
        BeforeAll { $script:QwordPath = "$($script:SandboxPath)\QWORD" }
        AfterAll  { Remove-Item $script:QwordPath -Recurse -Force -ErrorAction SilentlyContinue }

        It 'Grava valor QWORD (Int64)' {
            $r = Set-RegistryEntry -Path $script:QwordPath -Name 'BigVal' -Type 'QWORD' -Value 9999999999
            $r | Should -BeTrue
            (Get-ItemProperty -Path $script:QwordPath -Name 'BigVal').BigVal | Should -Be 9999999999
        }
    }

    Context 'MULTISTRING' {
        BeforeAll { $script:MultiPath = "$($script:SandboxPath)\MULTI" }
        AfterAll  { Remove-Item $script:MultiPath -Recurse -Force -ErrorAction SilentlyContinue }

        It 'Grava valor MultiString' {
            $r = Set-RegistryEntry -Path $script:MultiPath -Name 'MultiVal' -Type 'MULTISTRING' -Value @('A', 'B', 'C')
            $r | Should -BeTrue
            $v = (Get-ItemProperty -Path $script:MultiPath -Name 'MultiVal').MultiVal
            $v | Should -Contain 'A'
            $v | Should -Contain 'C'
        }
    }

    Context 'DELETEKEY' {
        BeforeAll {
            $script:DelKeyPath = "$($script:SandboxPath)\DELETE_ME"
            New-Item -Path $script:DelKeyPath -Force | Out-Null
        }

        It 'Remove a chave quando existe' {
            $r = Set-RegistryEntry -Path $script:DelKeyPath -Name '' -Type 'DELETEKEY' -Value $null
            $r | Should -BeTrue
            Test-Path $script:DelKeyPath | Should -BeFalse
        }

        It 'Retorna $true mesmo quando a chave já não existe (idempotente)' {
            # A chave já foi removida no It anterior
            $r = Set-RegistryEntry -Path $script:DelKeyPath -Name '' -Type 'DELETEKEY' -Value $null
            $r | Should -BeTrue
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Restore-RegistryEntry — HKCU sandbox' -Tag 'Integration' {

    BeforeEach {
        # Garantir que a chave de trabalho existe e está limpa antes de cada teste
        $script:RestorePath = "$($script:SandboxPath)\RESTORE"
        if (Test-Path $script:RestorePath) {
            Remove-Item $script:RestorePath -Recurse -Force
        }
        New-Item -Path $script:RestorePath -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:RestorePath) {
            Remove-Item $script:RestorePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Restaura valor DWORD original' {
        # Aplicar valor modificado
        Set-ItemProperty -Path $script:RestorePath -Name 'DwordProp' -Value 99
        # Restaurar valor original
        $r = Restore-RegistryEntry -Path $script:RestorePath -Name 'DwordProp' -OriginalValue 0 -Type 'DWORD'
        $r | Should -BeTrue
        (Get-ItemProperty -Path $script:RestorePath -Name 'DwordProp').DwordProp | Should -Be 0
    }

    It 'Restaura valor STRING original' {
        New-ItemProperty -Path $script:RestorePath -Name 'StrProp' -Value 'modified' -PropertyType String -Force | Out-Null
        $r = Restore-RegistryEntry -Path $script:RestorePath -Name 'StrProp' -OriginalValue 'original' -Type 'STRING'
        $r | Should -BeTrue
        (Get-ItemProperty -Path $script:RestorePath -Name 'StrProp').StrProp | Should -Be 'original'
    }

    It '<RemoveEntry> remove propriedade existente' {
        New-ItemProperty -Path $script:RestorePath -Name 'ToRemove' -Value 1 -PropertyType DWord -Force | Out-Null
        $r = Restore-RegistryEntry -Path $script:RestorePath -Name 'ToRemove' -OriginalValue '<RemoveEntry>' -Type 'DWORD'
        $r | Should -BeTrue
        (Get-ItemProperty -Path $script:RestorePath -Name 'ToRemove' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }

    It 'DELETEKEY + <RestoreKey> recria chave removida' {
        $keyToDelete = "$($script:SandboxPath)\RECREATE"
        if (Test-Path $keyToDelete) { Remove-Item $keyToDelete -Recurse -Force }

        $r = Restore-RegistryEntry -Path $keyToDelete -OriginalValue '<RestoreKey>' -Type 'DeleteKey'
        $r | Should -BeTrue
        Test-Path $keyToDelete | Should -BeTrue

        # Cleanup
        Remove-Item $keyToDelete -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Retorna $false quando chave não existe (modo normal)' {
        $r = Restore-RegistryEntry -Path "$($script:SandboxPath)\NONEXISTENT" -Name 'Val' -OriginalValue 0 -Type 'DWORD'
        $r | Should -BeFalse
    }
}
