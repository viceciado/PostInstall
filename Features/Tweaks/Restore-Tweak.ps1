function Restore-Tweak {
    <#
    .SYNOPSIS
        Desfaz um tweak especÃ­fico, restaurando os valores originais de registro.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Name
    )
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-InstallLog "Erro em Restore-Tweak: parâmetro Name vazio." -Status "ERRO"
        return $false
    }

    try {
        $tweak = Get-TweakByName -Name $Name
        if ($null -eq $tweak) {
            Write-InstallLog "Tweak não encontrado (desfazer): $Name" -Status "ERRO"
            return $false
        }

        #  Restaurar entradas de registro 
        $regOk = $true
        if ($tweak.Registry) {
            foreach ($entry in $tweak.Registry) {
                if ($entry.PSObject.Properties[$global:PSConst.Registry.DeleteKeyType] -and $entry.DeleteKey) {
                    $ok = Restore-RegistryEntry -Path $entry.Path -OriginalValue $entry.OriginalValue -Type $global:PSConst.Registry.DeleteKeyType
                }
                else {
                    $ok = Restore-RegistryEntry -Path $entry.Path -Name $entry.Name -OriginalValue $entry.OriginalValue -Type $entry.Type
                }
                if (-not $ok) { $regOk = $false }
            }
        }

        #  Executar scripts de desfazer 
        $undoScripts = @()
        if ($tweak.PSObject.Properties['UndoCommand'] -and $tweak.UndoCommand) { $undoScripts += $tweak.UndoCommand }
        if ($tweak.PSObject.Properties['UndoScript']  -and $tweak.UndoScript)  { $undoScripts += $tweak.UndoScript }

        $scriptOk = $true
        foreach ($line in $undoScripts) {
            try {
                Invoke-Expression $line
                Write-InstallLog "Undo script executado para '$Name': $line"
            }
            catch {
                Write-InstallLog "Erro em Restore-Tweak (script '$Name'): $($_.Exception.Message)" -Status "ERRO"
                $scriptOk = $false
            }
        }

        return ($regOk -and $scriptOk)
    }
    catch {
        Write-InstallLog "Erro em Restore-Tweak ('$Name'): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

