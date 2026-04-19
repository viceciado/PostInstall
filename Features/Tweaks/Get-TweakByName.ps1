function Get-TweakByName {
    <#
    .SYNOPSIS
        Localiza um tweak pelo nome no arquivo JSON de tweaks disponÃ­veis.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )
    try {
        $allTweaks = Get-AvailableItems -ItemType "Tweaks"
        return $allTweaks | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    }
    catch {
        Write-InstallLog "Erro em Get-TweakByName ('$Name'): $($_.Exception.Message)" -Status "ERRO"
        return $null
    }
}

