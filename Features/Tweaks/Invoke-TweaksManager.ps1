function Invoke-TweaksManager {
    <#
    .SYNOPSIS
        Orquestra aplicação ou desfazimento em lote de tweaks.

    .PARAMETER Tweaks
        Array de CheckBox WPF (com .Tag.Name) ou objetos tweak.

    .PARAMETER Names
        Array de nomes de tweaks (string[]).

    .PARAMETER Mode
        'Apply' para aplicar; 'Undo' para desfazer.

    .PARAMETER SkipPowerActions
        Quando presente, ignora comandos de desligamento/reinício nos scripts de tweak.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][array]$Tweaks,
        [Parameter(Mandatory = $false)][array]$Names,
        [Parameter(Mandatory = $true)][ValidateSet('Apply', 'Undo')][string]$Mode,
        [switch]$SkipPowerActions
    )

    if (-not $global:ScriptContext) { $global:ScriptContext = @{} }
    if ($null -eq $global:ScriptContext.AppliedTweaks) { $global:ScriptContext.AppliedTweaks = @{} }

    # Normalizar para lista de nomes
    $targetNames = @()
    if ($Tweaks -and $Tweaks.Count -gt 0) {
        $targetNames += $Tweaks | ForEach-Object {
            if ($_.Tag) { $_.Tag.Name }
            elseif ($_.Name) { $_.Name }
            else { $_ }
        }
    }
    if ($Names -and $Names.Count -gt 0) { $targetNames += $Names }
    $targetNames = $targetNames | Where-Object { $_ } | Select-Object -Unique

    if ($targetNames.Count -eq 0) {
        $msg = "Nenhum tweak selecionado para $Mode. Informe -Tweaks ou -Names com ao menos um item."
        Write-InstallLog $msg -Status "ERRO"
        throw $msg
    }

    $successCount = 0
    foreach ($name in $targetNames) {
        if ($Mode -eq 'Apply') {
            $result = Invoke-ElevatedProcess -FunctionName 'Set-Tweak' -Parameters @{ Name = $name; SkipPowerActions = [bool]$SkipPowerActions } -PassThru
            if ($result -match 'True') { $successCount++ }
        } else {
            $result = Invoke-ElevatedProcess -FunctionName 'Restore-Tweak' -Parameters @{ Name = $name } -PassThru
            if ($result -match 'True') {
                $successCount++
                if ($global:ScriptContext.AppliedTweaks.ContainsKey($name)) {
                    $global:ScriptContext.AppliedTweaks.Remove($name) | Out-Null
                }
            }
        }
    }

    $label = if ($Mode -eq 'Apply') { "aplicados" } else { "desfeitos" }
    Write-InstallLog "Tweaks $label com sucesso: $successCount de $($targetNames.Count)"

    # Reiniciar Explorer se algum tweak requereu refresh
    try {
        $needsRefresh = $false
        foreach ($n in $targetNames) {
            $tw = Get-TweakByName -Name $n
            if ($tw -and $tw.RefreshRequired) { $needsRefresh = $true; break }
        }
        if ($needsRefresh) { Restart-Explorer }
    } catch {
        Write-InstallLog "Aviso em Invoke-TweaksManager (refresh do Explorer): $($_.Exception.Message)" -Status "AVISO"
    }
}

