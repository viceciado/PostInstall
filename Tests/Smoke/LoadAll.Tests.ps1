#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
.SYNOPSIS
    Smoke test: dot-source todos os arquivos do projeto e verifica que as
    funções esperadas estão definidas após o carregamento.

.NOTES
    - Usa a mesma ordem de carregamento do Main.ps1 (Core→Features→DialogInitializers→Functions)
    - Pré-define $global:LogPath para $env:TEMP a fim de evitar que Initialize-LogPath
      tente escrever em $env:windir\Setup\Scripts\ (sem permissão em desktop dev)
    - Não carrega DialogInitializers: requerem WPF/STAThread, fora de escopo headless
#>

BeforeAll {
    # Raiz do projeto (dois niveis acima de Tests/Smoke/)
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    # ── Pré-condições de ambiente para que os arquivos carreguem sem erros ──
    #    LogPath apantando para TEMP evita que Initialize-LogPath tente C:\Windows\...
    $global:LogPath = Join-Path $env:TEMP 'PostInstall-LoadAll-Test.log'

    #    ScriptContext mínimo esperado por Get-AvailableItems e Set-Tweak
    $global:ScriptContext = @{
        IsCompiled    = $false
        AppliedTweaks = @{}
        UI     = @{ XamlWindows = @{} }
        System = @{}
        Config = @{}
    }

    # ── Dot-source na ordem do Main.ps1 ─────────────────────────────────────
    $loadDirs = @(
        @{ Path = Join-Path $script:ProjectRoot 'Core';     Recurse = $true  }
        @{ Path = Join-Path $script:ProjectRoot 'Features'; Recurse = $true  }
        # DialogInitializers excluídos: WPF
        @{ Path = Join-Path $script:ProjectRoot 'Functions'; Recurse = $false }
    )

    $script:LoadErrors = @()
    foreach ($dir in $loadDirs) {
        if (-not (Test-Path $dir.Path)) { continue }
        $files = if ($dir.Recurse) {
            Get-ChildItem $dir.Path -Recurse -Filter '*.ps1' -File | Sort-Object FullName
        } else {
            Get-ChildItem $dir.Path -Filter '*.ps1' -File | Sort-Object Name
        }
        foreach ($f in $files) {
            try {
                . $f.FullName
            } catch {
                $script:LoadErrors += "$($f.Name): $($_.Exception.Message)"
            }
        }
    }
}

AfterAll {
    # Limpar arquivo de log temporário criado durante este teste
    if (Test-Path $global:LogPath) {
        Remove-Item $global:LogPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name 'LogPath', 'ScriptContext' -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Carregamento dos arquivos fonte' -Tag 'Smoke' {

    It 'Nenhum arquivo deve falhar ao ser dot-sourceado' {
        $script:LoadErrors | Should -BeNullOrEmpty
    }

    Context 'Core — Logging' {
        It 'Write-InstallLog está definida'     { Get-Command Write-InstallLog  -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Initialize-LogFile está definida'   { Get-Command Initialize-LogFile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Core — Registry' {
        It 'ConvertTo-RegistryType está definida' { Get-Command ConvertTo-RegistryType -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Set-RegistryEntry está definida'      { Get-Command Set-RegistryEntry      -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Restore-RegistryEntry está definida'  { Get-Command Restore-RegistryEntry  -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Apply-RegistryEntry legado removido'   { Get-Command Apply-RegistryEntry    -ErrorAction SilentlyContinue | Should -BeNullOrEmpty }
        It 'Undo-RegistryEntry legado removido'    { Get-Command Undo-RegistryEntry     -ErrorAction SilentlyContinue | Should -BeNullOrEmpty }
    }

    Context 'Core — Process' {
        It 'Invoke-ElevatedProcess está definida'     { Get-Command Invoke-ElevatedProcess     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Invoke-ExternalProcess está definida'     { Get-Command Invoke-ExternalProcess     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Invoke-PowerShellFunction está definida'  { Get-Command Invoke-PowerShellFunction  -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Core — System' {
        It 'Get-SystemInfo está definida'          { Get-Command Get-SystemInfo          -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Test-InternetConnection está definida' { Get-Command Test-InternetConnection -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Test-WindowsVersion está definida'     { Get-Command Test-WindowsVersion     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Set-AvoidSleep está definida'          { Get-Command Set-AvoidSleep          -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Set-WindowsTheme está definida'        { Get-Command Set-WindowsTheme        -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Core — UI' {
        It 'Get-AvailableItems está definida'       { Get-Command Get-AvailableItems       -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Get-AvailableWindows está definida'     { Get-Command Get-AvailableWindows     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Get-VariableNameFromFile está definida' { Get-Command Get-VariableNameFromFile -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Get-XamlContent está definida'          { Get-Command Get-XamlContent          -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Get-XamlByWindowName está definida'     { Get-Command Get-XamlByWindowName     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'New-XamlDialog está definida'           { Get-Command New-XamlDialog           -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Features — Tweaks' {
        It 'Get-TweakByName está definida'   { Get-Command Get-TweakByName  -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Set-Tweak está definida'         { Get-Command Set-Tweak        -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Restore-Tweak está definida'     { Get-Command Restore-Tweak    -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Undo-Tweak legado removido'      { Get-Command Undo-Tweak       -ErrorAction SilentlyContinue | Should -BeNullOrEmpty }
        It 'Invoke-TweaksManager está definida' { Get-Command Invoke-TweaksManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Features — WinGet' {
        It 'Test-WinGet está definida'       { Get-Command Test-WinGet        -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Install-WinGet está definida'    { Get-Command Install-WinGet     -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Install-Programs está definida'  { Get-Command Install-Programs   -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Update-AllPrograms está definida'{ Get-Command Update-AllPrograms -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Upgrade-AllPrograms legado removido'{ Get-Command Upgrade-AllPrograms -ErrorAction SilentlyContinue | Should -BeNullOrEmpty }
    }

    Context 'Features — Other' {
        It 'Invoke-FinalizeTasks está definida' { Get-Command Invoke-FinalizeTasks -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
        It 'Set-PersistExec está definida'      { Get-Command Set-PersistExec      -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty }
    }

    Context 'Functions — Dispatcher' {
        It 'Get-DefaultDialogConfiguration está definida' {
            Get-Command Get-DefaultDialogConfiguration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
