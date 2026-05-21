Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Management

if (-not $global:ScriptContext) {
    $global:ScriptContext = @{}
}

# C12 (modo compilado único): Main.ps1 não deve executar via dot-source.
if ($global:ScriptContext.IsCompiled -ne $true -or
    [string]::IsNullOrWhiteSpace($global:ScriptContext.CompiledScriptPath) -or
    -not (Test-Path -LiteralPath $global:ScriptContext.CompiledScriptPath)) {
    Write-Host "[ERRO] Execução não suportada via fonte. Use o artefato compilado PostInstall.ps1." -ForegroundColor Red
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
    } catch {
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
                    } catch {
                        Show-MessageDialog -Title "Post-Install" -Message "Sem notas disponíveis" -MessageType "Info"
                    }
                })  
        }
        # Exibir a MainWindow (bloqueante)
        $xamlWindow.ShowDialog() | Out-Null
    } catch {
        # Garantir que a splash screen seja fechada em caso de erro
        if ($SplashScreen -and $SplashScreen.IsVisible) {
            $SplashScreen.Close()
        }
        Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
        Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
        Invoke-ApplicationShutdown -Reason $_.Exception.Message
        exit 1
    }
} catch {
    Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
    Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
    Invoke-ApplicationShutdown -Reason $_.Exception.Message
    exit
} finally {
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
    } catch {
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
