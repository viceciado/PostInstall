function global:Test-InternetConnection {
    <#
    .SYNOPSIS
    Verifica se há conexão com a internet
    
    .DESCRIPTION
    Testa a conectividade com a internet usando ping para um host confiável
    
    .PARAMETER HostName
    Host para testar conectividade. Padrão: www.google.com
    
    .PARAMETER Count
    Número de pings a serem enviados. Padrão: 1
    
    .PARAMETER Timeout
    Timeout em segundos para cada ping. Padrão: 5
    
    .PARAMETER ShowDialog
    Se verdadeiro, mostra diálogo ao usuário quando não há conexão
    
    .EXAMPLE
    if (Test-InternetConnection) {
        Write-Host "Conexão com internet disponível"
    }
    
    .EXAMPLE
    Test-InternetConnection -ShowDialog $true -HostName "8.8.8.8"
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$HostName = "www.google.com",
        
        [Parameter(Mandatory = $false)]
        [int]$Count = 1,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowDialog = $false
    )
    
    # Função interna para testar conexão
    function Test-ConnectionInternal {
        try {
            Write-InstallLog "Verificando conexão com a internet ($HostName)..." 
            
            $hasInternet = Test-Connection -ComputerName $HostName -Count $Count -Quiet -ErrorAction SilentlyContinue
            
            if ($hasInternet) {
                Write-InstallLog "Conexão com a internet confirmada" -Status "SUCESSO"
                return $true
            }
            else {
                Write-InstallLog "Sem conexão com a internet" -Status "AVISO"
                return $false
            }
        }
        catch {
            Write-InstallLog "Erro ao verificar conexão com a internet: $($_.Exception.Message)" -Status "ERRO"
            return $false
        }
    }
    
    # Testar conexão inicial
    $hasInternet = Test-ConnectionInternal
    
    # Se há internet, retornar sucesso
    if ($hasInternet) {
        return $true
    }
    
    # Se não há internet e não deve mostrar diálogo, retornar falso
    if (-not $ShowDialog) {
        return $false
    }
    
    # Loop para tentar novamente até ter sucesso ou usuário cancelar
    do {
        $result = Show-MessageDialog -Message "Não foi possível estabelecer conexão com a internet.`n`nVerifique sua conexão e clique em 'Tentar novamente' para continuar ou 'Sair' para encerrar o programa." -Title "Conexão com a Internet" -MessageType "Connection" -Buttons "RetryCancel"        
        if ($result -eq "Retry") { $hasInternet = Test-ConnectionInternal }
        else { return $false }
    } while (-not $hasInternet)
    return $true
}