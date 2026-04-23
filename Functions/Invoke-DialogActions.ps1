function Invoke-XamlDialog {
    <#
    .SYNOPSIS
    Configura e exibe qualquer dialogo XAML com configuracao especifica
    
    .DESCRIPTION
    Funcao generica para abrir dialogos XAML com configuracoes especificas.
    Carrega automaticamente o XAML pelo nome da janela e aplica configuracoes especificas.
    
    .PARAMETER WindowName
    Nome da janela XAML a ser carregada (ex: 'ActivationDialog', 'AboutDialog')
    
    .PARAMETER ConfigureDialog
    ScriptBlock que sera executado para configurar eventos especificos do dialogo
    
    .PARAMETER ShowModal
    Se verdadeiro, exibe o dialogo como modal. Padrao: $true
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowName,
        
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$ConfigureDialog,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowModal = $true
    )
    
    try {
        $xamlContent = Get-XamlByWindowName -WindowName $WindowName
        if (-not $xamlContent) {
            throw "Janela '$WindowName' nao encontrada. Janelas disponiveis: $(Get-AvailableWindows -join ', ')"
        }
        
        if (-not $ConfigureDialog) {
            $ConfigureDialog = Get-DefaultDialogConfiguration -WindowName $WindowName
        }
        
        $owner = $null
        if ($global:ScriptContext.UI.MainWindow -is [System.Windows.Window]) {
            $owner = $global:ScriptContext.UI.MainWindow
        }
        
        Show-XamlDialog -XamlContent $xamlContent -Owner $owner -ConfigureDialog $ConfigureDialog -ShowModal $ShowModal
    }
    catch {
        Write-InstallLog "Erro ao abrir dialogo '$WindowName': $($_.Exception.Message)" -Status "ERRO"
    }
}

function Get-DefaultDialogConfiguration {
    <#
    .SYNOPSIS
        Dispatcher: mapeia o nome da janela para a funcao de configuracao do dialogo correspondente.
        Cada configuracao fica em DialogInitializers/Initialize-<Nome>.ps1.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowName
    )

    switch ($WindowName) {
        'AboutDialog'       { return Get-AboutDialogConfiguration }
        'TweaksDialog'      { return Get-TweaksDialogConfiguration }
        'AppInstallDialog'  { return Get-AppInstallDialogConfiguration }
        'ActivationDialog'  { return Get-ActivationDialogConfiguration }
        'LogViewer'         { return Get-LogViewerConfiguration }
        'FinalizeDialog'    { return Get-FinalizeDialogConfiguration }
        default             { return $null }
    }
}
