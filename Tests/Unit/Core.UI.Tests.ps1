#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Unit tests para funções de UI: Get-VariableNameFromFile e Get-AvailableItems.

.NOTES
    - Get-VariableNameFromFile é função pura (sem side effects).
    - Get-AvailableItems em modo não-compilado lê arquivo JSON; usamos a fixture
      Tests/Fixtures/SampleTweaks.json / SamplePrograms.json para isolamento.
    - Write-InstallLog é Mockado para evitar I/O.
#>

BeforeAll {
    $script:ProjectRoot  = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:FixturesPath = Join-Path $script:ProjectRoot 'Tests\Fixtures'

    $global:LogPath = Join-Path $env:TEMP 'PostInstall-Unit-UI-Test.log'

    # Dot-source apenas os arquivos necessários
    . (Join-Path $script:ProjectRoot 'Core\Logging\Write-InstallLog.ps1')
    . (Join-Path $script:ProjectRoot 'Core\UI\Get-VariableNameFromFile.ps1')
    . (Join-Path $script:ProjectRoot 'Core\UI\Get-AvailableWindows.ps1')   # contém Get-AvailableItems
}

AfterAll {
    Remove-Item $global:LogPath -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name 'LogPath', 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-VariableNameFromFile' -Tag 'Unit' {

    It 'MainWindow.xaml → mainWindowXaml' {
        Get-VariableNameFromFile 'MainWindow.xaml' | Should -Be 'mainWindowXaml'
    }

    It 'SplashScreen.xaml → splashScreenXaml' {
        Get-VariableNameFromFile 'SplashScreen.xaml' | Should -Be 'splashScreenXaml'
    }

    It 'AboutDialog.xaml → aboutDialogXaml' {
        Get-VariableNameFromFile 'AboutDialog.xaml' | Should -Be 'aboutDialogXaml'
    }

    It 'ActivationDialog.xaml → activationDialogXaml' {
        Get-VariableNameFromFile 'ActivationDialog.xaml' | Should -Be 'activationDialogXaml'
    }

    It 'TweaksDialog.xaml → tweaksDialogXaml' {
        Get-VariableNameFromFile 'TweaksDialog.xaml' | Should -Be 'tweaksDialogXaml'
    }

    It 'Primeira letra é sempre minúscula (camelCase)' {
        $result = Get-VariableNameFromFile 'SomeDialog.xaml'
        $result[0] | Should -Be 's'
    }

    It 'Sufixo Xaml sempre é adicionado' {
        Get-VariableNameFromFile 'FinalizeDialog.xaml' | Should -Match 'Xaml$'
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Describe 'Get-AvailableItems' -Tag 'Unit' {

    BeforeAll {
        $global:ScriptContext = @{ IsCompiled = $false; UI = @{ XamlWindows = @{} }; System = @{}; Config = @{} }
        Mock Write-InstallLog {}
    }

    AfterAll {
        Remove-Variable -Name 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'Programs — fixture JSON' {

        It 'Retorna lista de programas do JSON fixture' {
            $programs = Get-AvailableItems -ItemType 'Programs' -JsonPath (Join-Path $script:FixturesPath 'SamplePrograms.json')
            $programs | Should -Not -BeNullOrEmpty
        }

        It 'Retorna exatamente 2 programas do fixture' {
            $programs = Get-AvailableItems -ItemType 'Programs' -JsonPath (Join-Path $script:FixturesPath 'SamplePrograms.json')
            $programs.Count | Should -Be 2
        }

        It 'Primeiro programa tem name TestApp-Alpha' {
            $programs = Get-AvailableItems -ItemType 'Programs' -JsonPath (Join-Path $script:FixturesPath 'SamplePrograms.json')
            $programs[0].name | Should -Be 'TestApp-Alpha'
        }

        It 'Programas têm propriedade programId' {
            $programs = Get-AvailableItems -ItemType 'Programs' -JsonPath (Join-Path $script:FixturesPath 'SamplePrograms.json')
            $programs[0].programId | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Tweaks — fixture JSON' {

        It 'Retorna lista de tweaks do JSON fixture' {
            $tweaks = Get-AvailableItems -ItemType 'Tweaks' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $tweaks | Should -Not -BeNullOrEmpty
        }

        It 'Retorna exatamente 3 tweaks do fixture' {
            $tweaks = Get-AvailableItems -ItemType 'Tweaks' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $tweaks.Count | Should -Be 3
        }

        It 'Tweaks têm propriedade Name' {
            $tweaks = Get-AvailableItems -ItemType 'Tweaks' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $tweaks[0].Name | Should -Not -BeNullOrEmpty
        }

        It 'Tweak registry tem propriedade IsBoolean' {
            $tweaks = Get-AvailableItems -ItemType 'Tweaks' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $tweaks | Where-Object Name -EQ 'TestTweak-Registry' | Select-Object -ExpandProperty IsBoolean | Should -Be $true
        }
    }

    Context 'TweaksCategories — fixture JSON' {

        It 'Retorna categorias do JSON fixture' {
            $cats = Get-AvailableItems -ItemType 'TweaksCategories' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $cats | Should -Not -BeNullOrEmpty
        }

        It 'Categoria Recommended está presente' {
            $cats = Get-AvailableItems -ItemType 'TweaksCategories' -JsonPath (Join-Path $script:FixturesPath 'SampleTweaks.json')
            $cats | Where-Object Name -EQ 'Recommended' | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Arquivo JSON inexistente' {

        It 'Retorna array vazio e não lança exceção' {
            $result = Get-AvailableItems -ItemType 'Programs' -JsonPath 'C:\nonexistent\file.json'
            $result | Should -BeNullOrEmpty
        }

        It 'Chama Write-InstallLog com status ERRO' {
            Get-AvailableItems -ItemType 'Programs' -JsonPath 'C:\nonexistent\file.json'
            Should -Invoke Write-InstallLog -ParameterFilter { $Status -eq 'ERRO' } -Exactly 1
        }
    }
}
