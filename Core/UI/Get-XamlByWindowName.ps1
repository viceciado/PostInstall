function Get-XamlByWindowName {
    param([string]$WindowName)

    $xamlWindows = $global:ScriptContext.UI.XamlWindows
    
    if ($xamlWindows -and $xamlWindows.ContainsKey($WindowName)) {
        $variableName = $xamlWindows[$WindowName]
        return Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue
    }
    
    $availableWindows = if ($xamlWindows) { $xamlWindows.Keys -join ', ' } else { '-' }
    Write-InstallLog "Janela '$WindowName' não encontrada. Janelas disponíveis: $availableWindows" -Status "AVISO"
    return $null
}
