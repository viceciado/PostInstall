#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests para funções de registro: ConvertTo-RegistryType,
    Set-RegistryEntry e Restore-RegistryEntry.

.NOTES
    - Todas as chamadas a Write-InstallLog são Mockadas (sem I/O real).
    - New-Item, Set-ItemProperty, New-ItemProperty, Remove-Item, Remove-ItemProperty
      e Test-Path são Mockados para isolar a lógica sem tocar no registro.
    - Para testes com registro real em HKCU, ver Integration/Registry.Integration.Tests.ps1.
#>

BeforeAll {
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # Pré-requisito de ambiente
    $global:LogPath = Join-Path $env:TEMP 'PostInstall-Unit-Registry-Test.log'

    # Dot-source apenas os arquivos necessários (sem módulos completos)
    . (Join-Path $script:ProjectRoot 'Core\Logging\Write-InstallLog.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\ConvertTo-RegistryType.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Set-RegistryEntry.ps1')
    . (Join-Path $script:ProjectRoot 'Core\Registry\Restore-RegistryEntry.ps1')
}

AfterAll {
    Remove-Item $global:LogPath -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name 'LogPath' -Scope Global -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'ConvertTo-RegistryType' -Tag 'Unit' {

    It 'REG_DWORD retorna DWORD / DWord' {
        $r = ConvertTo-RegistryType 'REG_DWORD'
        $r.Up | Should -Be 'DWORD'
        $r.Ps | Should -Be 'DWord'
    }

    It 'DWORD (sem prefixo REG_) é aceito' {
        $r = ConvertTo-RegistryType 'DWORD'
        $r.Up | Should -Be 'DWORD'
        $r.Ps | Should -Be 'DWord'
    }

    It 'Case-insensitive: dword retorna DWORD' {
        $r = ConvertTo-RegistryType 'dword'
        $r.Up | Should -Be 'DWORD'
    }

    It 'REG_QWORD retorna QWORD / QWord' {
        $r = ConvertTo-RegistryType 'REG_QWORD'
        $r.Up | Should -Be 'QWORD'
        $r.Ps | Should -Be 'QWord'
    }

    It 'REG_SZ retorna STRING / String' {
        $r = ConvertTo-RegistryType 'REG_SZ'
        $r.Up | Should -Be 'STRING'
        $r.Ps | Should -Be 'String'
    }

    It 'REG_EXPAND_SZ retorna EXPANDSTRING / ExpandString' {
        $r = ConvertTo-RegistryType 'REG_EXPAND_SZ'
        $r.Up | Should -Be 'EXPANDSTRING'
        $r.Ps | Should -Be 'ExpandString'
    }

    It 'REG_MULTI_SZ retorna MULTISTRING / MultiString' {
        $r = ConvertTo-RegistryType 'REG_MULTI_SZ'
        $r.Up | Should -Be 'MULTISTRING'
        $r.Ps | Should -Be 'MultiString'
    }

    It 'REG_BINARY retorna BINARY / Binary' {
        $r = ConvertTo-RegistryType 'REG_BINARY'
        $r.Up | Should -Be 'BINARY'
        $r.Ps | Should -Be 'Binary'
    }

    It 'Tipo desconhecido é retornado como passthrough' {
        $r = ConvertTo-RegistryType 'CUSTOM_TYPE'
        $r.Up | Should -Be 'CUSTOM_TYPE'
        $r.Ps | Should -Be 'CUSTOM_TYPE'
    }

    It 'String vazia não gera erro' {
        { ConvertTo-RegistryType '' } | Should -Not -Throw
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Set-RegistryEntry' -Tag 'Unit' {

    Context 'Criação de nova entrada (chave não existe)' {
        BeforeAll {
            Mock Write-InstallLog {}
            Mock Test-Path        { $false }
            Mock New-Item         {}
            Mock Set-ItemProperty {}
            Mock New-ItemProperty {}
            Mock Remove-Item      {}
            Mock Get-ItemProperty { $null }
        }

        It 'Chama New-Item para criar a chave quando ela não existe' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 1
            Should -Invoke New-Item -Exactly 1
        }

        It 'Chama New-ItemProperty quando a propriedade não existe' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 42
            Should -Invoke New-ItemProperty -Exactly 1
        }

        It 'Retorna $true em sucesso' {
            $result = Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'STRING' -Value 'test'
            $result | Should -BeTrue
        }
    }

    Context 'Atualização de entrada existente' {
        BeforeAll {
            Mock Write-InstallLog {}
            Mock Test-Path        { $true }
            Mock New-Item         {}
            Mock Set-ItemProperty {}
            Mock New-ItemProperty {}
            Mock Remove-Item      {}
            Mock Get-ItemProperty { [PSCustomObject]@{ Val = 0 } }
        }

        It 'Não chama New-Item quando a chave já existe' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 1
            Should -Invoke New-Item -Exactly 0
        }

        It 'Chama Set-ItemProperty quando a propriedade já existe' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 1
            Should -Invoke Set-ItemProperty -Exactly 1
        }
    }

    Context 'DELETEKEY — chave existe' {
        BeforeAll {
            Mock Write-InstallLog {}
            Mock Test-Path        { $true }
            Mock New-Item         {}
            Mock Remove-Item      {}
            Mock Get-ItemProperty { $null }
        }

        It 'Chama Remove-Item quando a chave existe e tipo é DELETEKEY' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name '' -Type 'DELETEKEY' -Value $null
            Should -Invoke Remove-Item -Exactly 1
        }

        It 'Retorna $true' {
            $result = Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name '' -Type 'DELETEKEY' -Value $null
            $result | Should -BeTrue
        }
    }

    Context 'DELETEKEY — chave não existe' {
        BeforeAll {
            Mock Write-InstallLog {}
            Mock Test-Path        { $false }
            Mock New-Item         {}
            Mock Remove-Item      {}
            Mock Get-ItemProperty { $null }
        }

        It 'Não chama Remove-Item quando a chave não existe' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name '' -Type 'DELETEKEY' -Value $null
            Should -Invoke Remove-Item -Exactly 0
        }

        It 'Retorna $true (DELETEKEY idempotente)' {
            $result = Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name '' -Type 'DELETEKEY' -Value $null
            $result | Should -BeTrue
        }
    }

    Context 'Falha de Set-ItemProperty' {
        BeforeAll {
            Mock Write-InstallLog {}
            Mock Test-Path        { $true }
            Mock New-Item         {}
            Mock Remove-Item      {}
            Mock Get-ItemProperty { [PSCustomObject]@{ Val = 0 } }
            Mock Set-ItemProperty { throw 'Access denied' }
        }

        It 'Retorna $false quando Set-ItemProperty lança exceção' {
            $result = Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 1
            $result | Should -BeFalse
        }

        It 'Chama Write-InstallLog com status ERRO' {
            Set-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD' -Value 1
            Should -Invoke Write-InstallLog -ParameterFilter { $Status -eq 'ERRO' } -Exactly 1
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Restore-RegistryEntry' -Tag 'Unit' {

    Context 'Restaurar valor original' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $true }
            Mock Set-ItemProperty    {}
            Mock New-Item            {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { $null }
        }

        It 'Chama Set-ItemProperty com o valor original' {
            Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -OriginalValue 0 -Type 'DWORD'
            Should -Invoke Set-ItemProperty -Exactly 1
        }

        It 'Retorna $true em sucesso' {
            $result = Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -OriginalValue 'oldval' -Type 'STRING'
            $result | Should -BeTrue
        }
    }

    Context '<RemoveEntry> remove a propriedade' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $true }
            Mock Set-ItemProperty    {}
            Mock New-Item            {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { [PSCustomObject]@{ Val = 1 } }
        }

        It 'Chama Remove-ItemProperty quando OriginalValue é <RemoveEntry>' {
            Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -OriginalValue '<RemoveEntry>' -Type 'DWORD'
            Should -Invoke Remove-ItemProperty -Exactly 1
        }

        It 'Retorna $true' {
            $result = Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -OriginalValue '<RemoveEntry>' -Type 'DWORD'
            $result | Should -BeTrue
        }
    }

    Context 'DELETEKEY — chave não existe (RestoreKey)' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $false }
            Mock New-Item            {}
            Mock Set-ItemProperty    {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { $null }
        }

        It 'Cria a chave quando OriginalValue é <RestoreKey> e ela não existe' {
            Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -OriginalValue '<RestoreKey>' -Type 'DeleteKey'
            Should -Invoke New-Item -Exactly 1
        }

        It 'Retorna $true para <RestoreKey>' {
            $result = Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -OriginalValue '<RestoreKey>' -Type 'DeleteKey'
            $result | Should -BeTrue
        }
    }

    Context 'DELETEKEY — chave já existe (RestoreKey)' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $true }
            Mock New-Item            {}
            Mock Set-ItemProperty    {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { $null }
        }

        It 'Não recria a chave quando ela já existe' {
            Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -OriginalValue '<RestoreKey>' -Type 'DeleteKey'
            Should -Invoke New-Item -Exactly 0
        }
    }

    Context 'Chave ausente (modo normal)' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $false }
            Mock New-Item            {}
            Mock Set-ItemProperty    {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { $null }
        }

        It 'Retorna $false quando a chave não existe e não é DeleteKey' {
            $result = Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -OriginalValue 0 -Type 'DWORD'
            $result | Should -BeFalse
        }
    }

    Context 'OriginalValue ausente' {
        BeforeAll {
            Mock Write-InstallLog    {}
            Mock Test-Path           { $true }
            Mock New-Item            {}
            Mock Set-ItemProperty    {}
            Mock Remove-ItemProperty {}
            Mock Get-ItemProperty    { $null }
        }

        It 'Retorna $false quando OriginalValue não é fornecido' {
            $result = Restore-RegistryEntry -Path 'HKCU:\Foo\Bar' -Name 'Val' -Type 'DWORD'
            $result | Should -BeFalse
        }
    }
}
