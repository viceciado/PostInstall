function global:Get-AvailableWindows {
    <#
    .SYNOPSIS
    Lista todas as janelas XAML disponíveis no sistema
    
    .DESCRIPTION
    Retorna uma lista de todas as janelas XAML que foram descobertas e carregadas automaticamente
    
    .EXAMPLE
    Get-AvailableWindows
    #>
    
    if ($global:ScriptContext.XamlWindows) {
        return $global:ScriptContext.XamlWindows.Keys | Sort-Object
    }
    else {
        Write-Warning "Nenhuma janela XAML foi carregada ainda"
        return @()
    }
}