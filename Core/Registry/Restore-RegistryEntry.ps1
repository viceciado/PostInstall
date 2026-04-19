function Restore-RegistryEntry {
    <#
    .SYNOPSIS
        Desfaz uma entrada de registro (restaura valor original ou recria/remove chave).
    .NOTES
        Use OriginalValue = '<RemoveEntry>' para remover a propriedade.
        Use OriginalValue = '<RestoreKey>' em conjunto com Type = 'DeleteKey' para recriar a chave.
    #>
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $false)][string]$Name,
        [Parameter(Mandatory = $false)]$OriginalValue,
        [Parameter(Mandatory = $false)][string]$Type
    )
    try {
        $norm      = ConvertTo-RegistryType -Type $Type
        $typeUpper = $norm.Up

        if ($typeUpper -eq 'DELETEKEY') {
            if (($OriginalValue -as [string]) -eq '<RestoreKey>') {
                if (-not (Test-Path -Path $Path)) {
                    New-Item -Path $Path -Force | Out-Null
                    Write-InstallLog "Chave restaurada (recriada): $Path"
                }
                else {
                    Write-InstallLog "Chave jÃ¡ existe; nada a restaurar: $Path" -Status "AVISO"
                }
                return $true
            }
            else {
                Write-InstallLog "Nada a desfazer para DeleteKey: $Path" -Status "AVISO"
                return $true
            }
        }

        if (-not (Test-Path -Path $Path)) {
            Write-InstallLog "Chave nÃ£o existe para restaurar: $Path" -Status "AVISO"
            return $false
        }

        if ($Name) {
            if ($null -ne $OriginalValue) {
                if (($OriginalValue -as [string]) -eq '<RemoveEntry>') {
                    $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                    if ($null -ne $existing) {
                        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                        Write-InstallLog "Entrada de registro removida: $Path :: $Name"
                    }
                    else {
                        Write-InstallLog "Entrada nÃ£o existe para remover: $Path :: $Name" -Status "AVISO"
                    }
                    return $true
                }

                $converted = $OriginalValue
                switch ($typeUpper) {
                    'DWORD'       { $converted = [int]$OriginalValue }
                    'QWORD'       { $converted = [long]$OriginalValue }
                    'MULTISTRING' { if ($OriginalValue -isnot [array]) { $converted = @([string]$OriginalValue) } }
                    default       { $converted = $OriginalValue }
                }
                Set-ItemProperty -Path $Path -Name $Name -Value $converted -ErrorAction Stop
                Write-InstallLog "Registro restaurado: $Path :: $Name = $converted"
                return $true
            }
            else {
                Write-InstallLog "Valor original ausente para desfazer: $Path::$Name" -Status "AVISO"
                return $false
            }
        }
        return $false
    }
    catch {
        Write-InstallLog "Erro em Restore-RegistryEntry ($Path::$Name): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

# Wrapper de compatibilidade com cÃ³digo anterior
function Undo-RegistryEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $false)][string]$Name,
        [Parameter(Mandatory = $false)]$OriginalValue,
        [Parameter(Mandatory = $false)][string]$Type
    )

    Write-InstallLog "Undo-RegistryEntry esta depreciada. Use Restore-RegistryEntry." -Status "AVISO"
    return Restore-RegistryEntry @PSBoundParameters
}

