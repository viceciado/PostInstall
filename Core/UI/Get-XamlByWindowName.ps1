function Get-XamlByWindowName {
    param([string]$WindowName)

    $xamlWindows = $global:ScriptContext.UI.XamlWindows
    
    if ($xamlWindows -and $xamlWindows.ContainsKey($WindowName)) {
        $variableName = $xamlWindows[$WindowName]
        $xamlContent = Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($xamlContent)) {
            return $xamlContent
        }

        throw "Payload XAML ausente para '$WindowName' (variável '$variableName')."
    }
    
    $availableWindows = if ($xamlWindows) { $xamlWindows.Keys -join ', ' } else { '-' }
    $message = "Janela '$WindowName' não encontrada no payload compilado. Janelas disponíveis: $availableWindows"
    Write-InstallLog $message -Status "ERRO"
    throw $message
}
