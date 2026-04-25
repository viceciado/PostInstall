function Set-Tweak {
    <#
    .SYNOPSIS
        Aplica um tweak específico pelo nome.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name,
        [switch]$SkipPowerActions
    )
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-InstallLog "Erro em Set-Tweak: parâmetro Name vazio." -Status "ERRO"
        return $false
    }

    try {
        $tweak = Get-TweakByName -Name $Name
        if ($null -eq $tweak) {
            Write-InstallLog "Tweak não encontrado: $Name" -Status "ERRO"
            return $false
        }

        # Coletar scripts a executar (suporta Command ou InvokeScript)
        $scripts = @()
        if ($tweak.PSObject.Properties['Command'] -and $tweak.Command) { $scripts += $tweak.Command }
        if ($tweak.PSObject.Properties['InvokeScript'] -and $tweak.InvokeScript) { $scripts += $tweak.InvokeScript }

        #  Aplicar entradas de registro
        $regOk = $true
        if ($tweak.Registry) {
            foreach ($entry in $tweak.Registry) {
                if ($entry.PSObject.Properties[$global:PSConst.Registry.DeleteKeyType] -and $entry.DeleteKey) {
                    try {
                        if (Test-Path -Path $entry.Path) {
                            Remove-Item -Path $entry.Path -Force -Recurse -ErrorAction SilentlyContinue
                            Write-InstallLog "Chave removida: $($entry.Path)"
                        } else {
                            Write-InstallLog "Chave não encontrada para remover: $($entry.Path)" -Status "AVISO"
                        }
                    } catch {
                        Write-InstallLog "Erro em Set-Tweak ($($global:PSConst.Registry.DeleteKeyType) '$($entry.Path)'): $($_.Exception.Message)" -Status "ERRO"
                        $regOk = $false
                    }
                    continue
                }
                $ok = Set-RegistryEntry -Path $entry.Path -Name $entry.Name -Type $entry.Type -Value $entry.Value
                if (-not $ok) { $regOk = $false }
            }
        }

        #  Executar scripts 
        $scriptOk = $true
        foreach ($line in $scripts) {
            if ($SkipPowerActions -and ($line -match '(?i)Stop-Computer|Restart-Computer|\bshutdown(\.exe)?\b')) {
                Write-InstallLog "Ação de energia ignorada em '$Name': $line" -Status "AVISO"
                continue
            }
            try {
                Invoke-Expression $line
                Write-InstallLog "Script executado para '$Name': $line"
            } catch {
                Write-InstallLog "Erro em Set-Tweak (script '$Name'): $($_.Exception.Message)" -Status "ERRO"
                $scriptOk = $false
            }
        }

        $success = $regOk -and $scriptOk

        # Registrar apenas tweaks reversíveis (IsBoolean: true)
        if ($success -and $tweak.IsBoolean -eq $true) {
            $global:ScriptContext.AppliedTweaks[$Name] = (Get-Date)
        }

        return $success
    } catch {
        Write-InstallLog "Erro em Set-Tweak ('$Name'): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

