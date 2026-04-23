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

    Write-InstallLog "Aplicação WPF inicializada com recursos compartilhados de estilos"
}
