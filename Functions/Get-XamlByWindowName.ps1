function global:Get-XamlByWindowName {
    param([string]$WindowName)
    
    if ($global:ScriptContext.XamlWindows -and $global:ScriptContext.XamlWindows.ContainsKey($WindowName)) {
        $variableName = $global:ScriptContext.XamlWindows[$WindowName]
        return Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue
    }
    
    Write-InstallLog "Janela '$WindowName' não encontrada. Janelas disponíveis: $($global:ScriptContext.XamlWindows.Keys -join ', ')" -Status "AVISO"
    return $null
}