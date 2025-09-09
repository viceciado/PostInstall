function global:New-XamlDialog {
    <#
    .SYNOPSIS
    Cria uma nova instância de um diálogo XAML
    
    .DESCRIPTION
    Cria uma nova instância de um diálogo XAML a partir do conteúdo XAML carregado,
    evitando problemas de estado ao reutilizar janelas fechadas
    
    .PARAMETER XamlContent
    O conteúdo XAML da janela a ser criada
    
    .PARAMETER Owner
    A janela pai que será proprietária do diálogo
    
    .EXAMPLE
    $dialog = New-XamlDialog -XamlContent $activationDialogXaml -Owner $xamlWindow
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlContent,
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner
    )
    
    try {
        [xml]$xamlParsed = $XamlContent
        $dialog = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xamlParsed))
        
        if ($Owner) {
            $dialog.Owner = $Owner
        }
        
        return $dialog
    }
    catch {
        Write-InstallLog "Erro ao criar diálogo XAML: $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}