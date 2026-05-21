function Get-XamlContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlFileName,
        
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    
    try {
        if ($global:ScriptContext -and $global:ScriptContext.IsCompiled) {
            throw "Get-XamlContent não é suportado no runtime compilado (C12). Use payload XAML embutido."
        }

        $xamlPath = Join-Path $WindowsPath $XamlFileName
        if (-not (Test-Path $xamlPath)) {
            throw "Arquivo XAML não encontrado: $xamlPath"
        }
        
        $content = Get-Content -Path $xamlPath -Raw -ErrorAction Stop
        Write-InstallLog "XAML carregado com sucesso: $XamlFileName" -Status "SUCESSO"
        return $content
    } catch {
        Write-InstallLog "Erro em Get-XamlContent ('$XamlFileName'): $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}
