function Test-WinGet {
    <#
    .SYNOPSIS
        Verifica o estado da instalação do Winget e retorna informações detalhadas.
    .OUTPUTS
        PSCustomObject com Status ('NotInstalled'|'Installed'|'Outdated'), Path, Version, IsPreview.
    #>
    [CmdletBinding()]
    param()

    $result = @{
        Status = "NotInstalled"
        Path = $null
        Version = $null
        IsPreview = $false
    }

    # 1. Tentar encontrar via PATH
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) {
        $result.Path = $cmd.Source
    } else {
        # 2. Fallback para locais conhecidos
        $candidates = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
            "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            if ($c -like '*\**') {
                $expanded = Get-ChildItem $c -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($expanded) { $result.Path = $expanded.FullName; break }
            } elseif (Test-Path $c) { $result.Path = $c; break }
        }
    }

    if ($result.Path -and (Test-Path $result.Path)) {
        try {
            $verStr = (& $result.Path --version).Trim()
            if ($verStr) {
                $result.Version = $verStr
                $result.IsPreview = $verStr -match '-preview'
                try {
                    $latestJson = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -ErrorAction Stop
                    $latestTag = $latestJson.tag_name.TrimStart('v')
                    $currentClean = $verStr -replace '-preview.*', ''
                    $result.Status = if ([System.Version]$currentClean -lt [System.Version]$latestTag) { "Outdated" } else { "Installed" }
                } catch {
                    $result.Status = "Installed"
                    Write-InstallLog "Aviso: Não foi possível verificar atualização online do Winget." -Status "AVISO"
                }
            }
        } catch { $result.Status = "NotInstalled" }
    }

    return [PSCustomObject]$result
}

