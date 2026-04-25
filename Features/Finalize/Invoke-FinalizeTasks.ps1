function Invoke-FinalizeTasks {
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
    [CmdletBinding()]
    param(
        [string]$Owner,
        [string]$Organization,
        [array]$TweakNames
    )

    $hadErrors = $false
    
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
    } catch {
        Write-InstallLog "Erro em Invoke-FinalizeTasks (registro): $($_.Exception.Message)" -Status "ERRO"
        $hadErrors = $true
    }
    
    # 2. Aplicar Tweaks
    if ($TweakNames -and $TweakNames.Count -gt 0) {
        try {
            Write-InstallLog "Iniciando aplicação de $($TweakNames.Count) tweaks..."
            # Chama Invoke-TweaksManager. Como já estamos elevados (esta função é chamada via Invoke-ElevatedProcess),
            # as chamadas internas de Invoke-TweaksManager detectarão que são Admin e rodarão diretamente.
            Invoke-TweaksManager -Names $TweakNames -Mode "Apply" -SkipPowerActions
        } catch {
            Write-InstallLog "Erro em Invoke-FinalizeTasks (tweaks): $($_.Exception.Message)" -Status "ERRO"
            $hadErrors = $true
        }
    }

    return (-not $hadErrors)
}

