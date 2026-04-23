Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Management

$global:ScriptContext = @{
    # Metadados de build (lidos por dialogs e pelo Builder)
    ScriptVersion     = "pre-build"

    # Feature data — acesso de alta frequência por código de feature
    AvailablePrograms = @()
    AvailableTweaks   = @()
    AppliedTweaks     = @{}

    # Estado de UI
    UI = @{
        XamlWindows        = @{}
        MainWindow         = $null
        SplashScreenWindow = $null
    }

    # Estado do sistema
    System = @{
        IsAdministrator    = $false
        isWin11            = $null
        AvoidSleep         = $false
        Info               = $null
    }

    # Dados de sessão do usuário
    Config = @{
        OemKey                   = $null
        ClientName               = $null
        TechnicianName           = $null
        OsNumber                 = $null
        PersistedSelectedFolders = @()
    }
}

# === SISTEMA DE CARREGAMENTO DINÂMICO DE FUNÇÕES ===
# Carrega em ordem de dependência: Core → Features → DialogInitializers → Functions (legacy)
try {
    $sourceDirs = @(
        @{ Path = Join-Path $PSScriptRoot 'Core';               Recurse = $true }
        @{ Path = Join-Path $PSScriptRoot 'Features';           Recurse = $true }
        @{ Path = Join-Path $PSScriptRoot 'DialogInitializers'; Recurse = $false }
        @{ Path = Join-Path $PSScriptRoot 'Functions';          Recurse = $false }
    )

    $loadedCount = 0
    $failedFiles = @()

    foreach ($dir in $sourceDirs) {
        if (-not (Test-Path $dir.Path)) { continue }

        $files = if ($dir.Recurse) {
            Get-ChildItem $dir.Path -Recurse -Filter '*.ps1' -File | Sort-Object FullName
        }
        else {
            Get-ChildItem $dir.Path -Filter '*.ps1' -File | Sort-Object Name
        }

        foreach ($file in $files) {
            try {
                . $file.FullName
                $loadedCount++
            }
            catch {
                Write-Host "[ERRO] Falha ao carregar '$($file.Name)': $($_.Exception.Message)" -ForegroundColor Red
                $failedFiles += $file.Name
            }
        }
    }

    Write-Host "[SUCESSO] Funções carregadas: $loadedCount" -ForegroundColor Green
    if ($failedFiles.Count -gt 0) {
        Write-Host "[AVISO] Falha ao carregar: $($failedFiles -join ', ')" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[ERRO] Falha crítica no carregamento de funções: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === INICIALIZAÇÃO DO SCRIPT DOT-SOURCING ===

try {
    # Obter caminho base do script
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $windowsPath = Join-Path $scriptPath "Windows"

    $xamlFiles = Get-ChildItem -Path $windowsPath -Filter "*.xaml" -File
    
    if ($xamlFiles.Count -eq 0) {
        throw "Nenhum arquivo XAML encontrado na pasta Windows"
    }
    
    Write-Host "Descobertos $($xamlFiles.Count) arquivos XAML na pasta Windows" 
    
    # Carregar cada arquivo XAML dinamicamente
    foreach ($file in $xamlFiles) {
        $fileName = $file.Name
        $variableName = Get-VariableNameFromFile -FileName $fileName
        
        try {
            $content = Get-XamlContent -XamlFileName $fileName -WindowsPath $windowsPath
            Set-Variable -Name $variableName -Value $content -Scope Script
            Write-Host "Variável '$variableName' definida para '$fileName'" -Status "SUCESSO"
        }
        catch {
            Write-Host "Falha ao carregar '$fileName': $($_.Exception.Message)" -Status "ERRO"
            # Continuar com outros arquivos mesmo se um falhar
        }
    }
    
    # Listar todas as variáveis XAML carregadas
    $loadedVariables = $xamlFiles | ForEach-Object { Get-VariableNameFromFile -FileName $_.Name }
    Write-Host "Variáveis XAML disponíveis: $($loadedVariables -join ', ')" 
    Write-Host "Sistema de carregamento dinâmico de XAML inicializado com sucesso" -Status "SUCESSO"
    
    # Criar hashtable global para facilitar acesso às janelas
    foreach ($file in $xamlFiles) {
        $variableName = Get-VariableNameFromFile -FileName $file.Name
        $global:ScriptContext.UI.XamlWindows[$file.BaseName] = $variableName
    }
    
    Write-Host "Mapeamento de janelas criado: $($global:ScriptContext.UI.XamlWindows.Keys -join ', ')" 
}
catch {
    Write-Host "Falha crítica no carregamento de XAML: $($_.Exception.Message)" -Status "ERRO"
    Show-MessageDialog -Message "Erro ao carregar arquivos de interface. Verifique se os arquivos XAML estão presentes na pasta Windows.`n`nDetalhes: $($_.Exception.Message)" -Title "Erro Crítico" -MessageType "Error" 
    exit 1
}

try {
    # === INICIALIZAÇÃO DAS JANELAS PRINCIPAIS ===
    try {
        # Configurar persistência e determinar se é primeira execução
        $FirstRun = Set-PersistExec
        
        # Inicializar sistema de logging - LIMPA o log na primeira execução
        Initialize-LogFile -IsFirstRun $FirstRun
        
        # Coletar informações do sistema IMEDIATAMENTE após inicializar o log
        if ($FirstRun -eq $true) {
            # Primeira execução: coletar e escrever no log
            Get-SystemInfo -WriteToLog | Out-Null
        } else {
            # Execuções subsequentes: apenas atualizar variável
            Get-SystemInfo | Out-Null
            Write-InstallLog "Iniciando nova sessão"
        }
        
        Test-WindowsVersion

        # Inicializar Application WPF e registrar estilos compartilhados em Application.Resources.
        # Deve ocorrer antes de qualquer XamlReader.Load() para que StaticResource e BasedOn resolvam.
        Initialize-WpfApplication
        
        [xml]$splashScreenXamlParsed = $splashScreenXaml
        [xml]$mainWindowXamlParsed = $mainWindowXaml
    
        $SplashScreen = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $splashScreenXamlParsed))
        $xamlWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $mainWindowXamlParsed))
    
        # Tornar a MainWindow acessível globalmente como Owner para diálogos
        $global:ScriptContext.UI.MainWindow = $xamlWindow

        # Registrar todos os event handlers da MainWindow
        Initialize-MainWindow $xamlWindow
    }
    catch {
        Write-InstallLog "Erro fatal ao carregar XAML principal: $($_.Exception.Message)" -Status "ERRO"
        exit 1
    }

    # === FLUXO DE INICIALIZAÇÃO COM SPLASH ===
    try {
        # Exibir splash enquanto coleta informações
        $SplashScreen.Show()
    
        # Verificar conectividade (opcionalmente interativo)
        $hasInternet = Test-InternetConnection -ShowDialog $true
        if (-not $hasInternet) { 
            # Fechar splash screen antes de encerrar
            $SplashScreen.Close()
            Write-InstallLog "Aplicação encerrada: sem conexão com a internet" 
            exit 0
        }
    
        # Coletar informações do sistema (modular com auto-elevação)
        if (-not $global:ScriptContext.System.Info) {
            Get-SystemInfo -WriteToLog | Out-Null
        }
    
        $SplashScreen.Close()

        # Desativar a suspensão do computador
        Set-AvoidSleep -AvoidSleep $true -Silent $true
    
        # Exibir mensagem de novidades após a janela principal ser renderizada
        if ($FirstRun -eq $true) {
            $xamlWindow.Add_ContentRendered({
                try {
                    $headers = @{ 'User-Agent' = 'viceciado-PostInstall'; 'Accept' = 'application/vnd.github+json' }
                    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/viceciado/PostInstall/releases/latest" -Headers $headers -Method Get -ErrorAction Stop
                    $notes = $release.body
                    if ([string]::IsNullOrWhiteSpace($notes)) { $notes = "Sem notas disponíveis" }
                    Show-MessageDialog -Title "Post-Install $($release.tag_name)" -Message $notes -MessageType "Info"
                }
                catch {
                    Show-MessageDialog -Title "Post-Install" -Message "Sem notas disponíveis" -MessageType "Info"
                }
            })  
        }
        # Exibir a MainWindow (bloqueante)
        $xamlWindow.ShowDialog() | Out-Null
    }
    catch {
        # Garantir que a splash screen seja fechada em caso de erro
        if ($SplashScreen -and $SplashScreen.IsVisible) {
            $SplashScreen.Close()
        }
        Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
        Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
        Invoke-ApplicationShutdown -Reason $_.Exception.Message
        exit 1
    }
}
catch {
    Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
    Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
    Invoke-ApplicationShutdown -Reason $_.Exception.Message
    exit
}
finally {
    # === ROTINAS DE LIMPEZA ===
    Write-InstallLog "Executando rotinas de limpeza..."

    # Finalizar todos os jobs em execução
    try {
        $runningJobs = Get-Job -State Running -ErrorAction SilentlyContinue
        if ($runningJobs) {
            Write-InstallLog "Finalizando $($runningJobs.Count) job(s) em execução..."
            foreach ($job in $runningJobs) {
                Write-InstallLog "Finalizando job: $($job.Name)" -Status "INFO"
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Limpar todos os jobs restantes (incluindo jobs concluídos)
        $allJobs = Get-Job -ErrorAction SilentlyContinue
        if ($allJobs) {
            Write-InstallLog "Removendo $($allJobs.Count) job(s) restante(s)..."
            Remove-Job -Job $allJobs -Force -ErrorAction SilentlyContinue
        }
        
        Write-InstallLog "Limpeza de jobs concluída com sucesso" -Status "SUCESSO"
    }
    catch {
        Write-InstallLog "Erro durante a limpeza de jobs: $($_.Exception.Message)" -Status "AVISO"
    }

    # Restaurar as configurações de suspensão
    if ($global:ScriptContext.System.AvoidSleep) {
        Set-AvoidSleep -Silent $true
    }

    # Limpar o contexto global do script
    if ($global:ScriptContext) {
        Remove-Variable -Name ScriptContext -Scope Global -Force -ErrorAction SilentlyContinue
        Write-InstallLog "Contexto global do script limpo com sucesso" -Status "SUCESSO"
    }
    
    Write-InstallLog "Rotinas de limpeza concluídas" -Status "SUCESSO"
}
