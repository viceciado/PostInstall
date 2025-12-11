function global:Invoke-FinalizeTasks {
    <#
    .SYNOPSIS
    Executa tarefas de finalização (Registro e Tweaks) em uma única sessão elevada.
    
    .PARAMETER Owner
    Nome do proprietário registrado.
    
    .PARAMETER Organization
    Nome da organização registrada.
    
    .PARAMETER TweakNames
    Array com nomes dos tweaks a serem aplicados.
    #>
    param(
        [string]$Owner,
        [string]$Organization,
        [array]$TweakNames
    )
    
    # 1. Configurar Registro
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        
        if (-not [string]::IsNullOrWhiteSpace($Owner)) {
            Write-InstallLog "Definindo RegisteredOwner: $Owner"
            Set-ItemProperty -Path $regPath -Name "RegisteredOwner" -Value $Owner -ErrorAction Stop
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Organization)) {
            Write-InstallLog "Definindo RegisteredOrganization: $Organization"
            Set-ItemProperty -Path $regPath -Name "RegisteredOrganization" -Value $Organization -ErrorAction Stop
        }
    }
    catch {
        Write-InstallLog "Erro ao configurar registro: $($_.Exception.Message)" -Status "ERRO"
    }
    
    # 2. Aplicar Tweaks
    if ($TweakNames -and $TweakNames.Count -gt 0) {
        Write-InstallLog "Iniciando aplicação de $($TweakNames.Count) tweaks..."
        # Chama Invoke-TweaksManager. Como já estamos elevados (esta função é chamada via Invoke-ElevatedProcess),
        # as chamadas internas de Invoke-TweaksManager detectarão que são Admin e rodarão diretamente.
        Invoke-TweaksManager -Names $TweakNames -Mode "Apply" -SkipPowerActions
    }
}
