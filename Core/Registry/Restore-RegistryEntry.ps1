function Restore-RegistryEntry {
    <#
    .SYNOPSIS
        Desfaz uma entrada de registro (restaura valor original ou recria/remove chave).
    .NOTES
        Use OriginalValue = '$($global:PSConst.Registry.RemoveEntrySentinel)' para remover a propriedade.
        Use OriginalValue = '$($global:PSConst.Registry.RestoreKeySentinel)' em conjunto com Type = '$($global:PSConst.Registry.DeleteKeyType)' para recriar a chave.
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

        if ($typeUpper -eq $global:PSConst.Registry.DeleteKeyTypeUpper) {
            if (($OriginalValue -as [string]) -eq $global:PSConst.Registry.RestoreKeySentinel) {
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
            Write-InstallLog "Chave não existe para restaurar: $Path" -Status "AVISO"
            return $false
        }

        if ($Name) {
            if ($null -ne $OriginalValue) {
                if (($OriginalValue -as [string]) -eq $global:PSConst.Registry.RemoveEntrySentinel) {
                    $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                    if ($null -ne $existing) {
                        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                        Write-InstallLog "Entrada de registro removida: $Path :: $Name"
                    }
                    else {
                        Write-InstallLog "Entrada não existe para remover: $Path :: $Name" -Status "AVISO"
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

# Wrapper de compatibilidade com código anterior
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

