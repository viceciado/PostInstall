function Invoke-FinalizeTasks {
    <#
    .SYNOPSIS
    Executa tarefas de finalizaÃ§Ã£o (Registro e Tweaks) em uma Ãºnica sessÃ£o elevada.
    
    .PARAMETER Owner
    Nome do proprietÃ¡rio registrado.
    
    .PARAMETER Organization
    Nome da organizaÃ§Ã£o registrada.
    
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
    }
    catch {
        Write-InstallLog "Erro em Invoke-FinalizeTasks (registro): $($_.Exception.Message)" -Status "ERRO"
        $hadErrors = $true
    }
    
    # 2. Aplicar Tweaks
    if ($TweakNames -and $TweakNames.Count -gt 0) {
        try {
            Write-InstallLog "Iniciando aplicaÃ§Ã£o de $($TweakNames.Count) tweaks..."
            # Chama Invoke-TweaksManager. Como jÃ¡ estamos elevados (esta funÃ§Ã£o Ã© chamada via Invoke-ElevatedProcess),
            # as chamadas internas de Invoke-TweaksManager detectarÃ£o que sÃ£o Admin e rodarÃ£o diretamente.
            Invoke-TweaksManager -Names $TweakNames -Mode "Apply" -SkipPowerActions
        }
        catch {
            Write-InstallLog "Erro em Invoke-FinalizeTasks (tweaks): $($_.Exception.Message)" -Status "ERRO"
            $hadErrors = $true
        }
    }

    return (-not $hadErrors)
}

