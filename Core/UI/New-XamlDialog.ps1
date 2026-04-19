function New-XamlDialog {
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
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlContent,
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner
    )
    
    try {
        [xml]$xamlParsed = $XamlContent
        $dialog = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xamlParsed))

        # Merge estilos compartilhados para reduzir duplicação entre diálogos.
        if (Get-Command -Name Get-SharedDialogResourceDictionary -ErrorAction SilentlyContinue) {
            $sharedResources = Get-SharedDialogResourceDictionary
            if ($sharedResources) {
                $dialog.Resources.MergedDictionaries.Add($sharedResources)
            }
        }
        
        if ($Owner) {
            $dialog.Owner = $Owner
        }
        
        return $dialog
    }
    catch {
            Write-InstallLog "Erro em New-XamlDialog: $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}
