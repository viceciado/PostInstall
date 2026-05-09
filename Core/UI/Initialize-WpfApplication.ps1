function Initialize-WpfApplication {
    <#
    .SYNOPSIS
        Inicializa a Application WPF e registra estilos compartilhados globalmente.

    .DESCRIPTION
        Instancia System.Windows.Application (se ainda não existe) e carrega o
        ResourceDictionary compartilhado em Application.Current.Resources.MergedDictionaries.

        Com isso, qualquer janela parseada por XamlReader.Load() pode usar
        {StaticResource ...} e BasedOn="{StaticResource ...}" referenciando
        os estilos comuns — exatamente como App.xaml funciona em projetos C# WPF.

        Deve ser chamada UMA única vez, após Add-Type e após as funções Core estarem
        carregadas, e ANTES de qualquer chamada a XamlReader.Load().
    #>

    [CmdletBinding()]
    param()

    # Instanciar Application apenas se não houver instância ativa
    if (-not [System.Windows.Application]::Current) {
        $null = [System.Windows.Application]::new()
    }

    # Garantir ShutdownMode correto: a Application não deve encerrar ao fechar janelas individuais
    [System.Windows.Application]::Current.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown

    # Carregar ResourceDictionary com os estilos compartilhados
    $sharedResources = Get-SharedDialogResourceDictionary
    if (-not $sharedResources) {
        throw "Initialize-WpfApplication: Get-SharedDialogResourceDictionary retornou nulo — estilos compartilhados não disponíveis."
    }

    # Adicionar ao MergedDictionaries apenas se ainda não estiver registrado
    if ([System.Windows.Application]::Current.Resources.MergedDictionaries.Count -eq 0) {
        [System.Windows.Application]::Current.Resources.MergedDictionaries.Add($sharedResources)
    }

    # Registrar handler global de exceções não tratadas no dispatcher WPF.
    # Em PS5.1/.NET Framework, exceções em event handlers (Add_Click etc.) sem try/catch
    # próprio propagam pelo Dispatcher e, sem este handler, chegam até ShowDialog()
    # fazendo-o lançar — o que encerra o script e "orfa" a MainWindow.
    # Com Handled = $true, a exceção é absorvida: o handler é logado e a UI continua.
    [System.Windows.Application]::Current.add_DispatcherUnhandledException({
            param($wpfSender, $wpfArgs)
            $null = $wpfSender
            try {
                Write-InstallLog "Exceção não tratada na interface: $($wpfArgs.Exception.Message)" -Status "ERRO"
            } catch {}
            $wpfArgs.Handled = $true
        })

    Write-InstallLog "Aplicação WPF inicializada com recursos compartilhados de estilos"
}
