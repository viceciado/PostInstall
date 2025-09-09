function global:Get-XamlContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$XamlFileName,
        
        [Parameter(Mandatory=$true)]
        [string]$WindowsPath
    )
    
    try {
        $xamlPath = Join-Path $WindowsPath $XamlFileName
        if (-not (Test-Path $xamlPath)) {
            throw "Arquivo XAML não encontrado: $xamlPath"
        }
        
        $content = Get-Content -Path $xamlPath -Raw -ErrorAction Stop
        Write-InstallLog "XAML carregado com sucesso: $XamlFileName" -Status "SUCESSO"
        return $content
    }
    catch {
        Write-InstallLog "Erro ao carregar XAML '$XamlFileName': $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}