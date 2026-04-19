function Install-WinGet {
    <#
    .SYNOPSIS
        Instala ou atualiza o Winget, garantindo que esteja funcional.
    .OUTPUTS
        String com o caminho do executÃ¡vel em caso de sucesso; $null em caso de falha.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    Write-InstallLog "Verificando instalaÃ§Ã£o do Winget..."
    $info = Test-WinGet

    if ($info.Status -eq "Installed" -and -not $Force) {
        Write-InstallLog "Winget jÃ¡ estÃ¡ instalado e atualizado ($($info.Version))."
        return $info.Path
    }

    if ($info.Status -eq "Outdated") {
        Write-InstallLog "Winget desatualizado ($($info.Version)). Tentando atualizar..."
    }
    else {
        Write-InstallLog "Winget nÃ£o encontrado. Iniciando instalaÃ§Ã£o..."
    }

    # Tentativa 1: self-update via winget (apenas quando jÃ¡ instalado)
    if ($info.Path -and (Test-Path $info.Path)) {
        try {
            Write-InstallLog "Tentando atualizar via self-update..."
            $proc = Start-Process -FilePath $info.Path `
                -ArgumentList "install --id Microsoft.AppInstaller --source winget --accept-source-agreements --accept-package-agreements --silent --force" `
                -PassThru -Wait -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-InstallLog "Winget atualizado com sucesso."
                return (Test-WinGet).Path
            }
        }
        catch {
            Write-InstallLog "Falha no self-update: $($_.Exception.Message)" -Status "AVISO"
        }
    }

    # Tentativa 2: download manual do GitHub
    try {
        Write-InstallLog "Baixando Ãºltima versÃ£o do GitHub..."
        $release    = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -ErrorAction Stop
        $msixBundle = $release.assets | Where-Object { $_.name -like "Microsoft.DesktopAppInstaller_*.msixbundle" } | Select-Object -First 1
        if (-not $msixBundle) { throw "Asset msixbundle nÃ£o encontrado." }

        $tempBundle = Join-Path $env:TEMP $msixBundle.name
        Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $tempBundle -ErrorAction Stop

        # Instalar dependÃªncias opcionais
        $depsAsset = $release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" } | Select-Object -First 1
        if ($depsAsset) {
            $depsZip = Join-Path $env:TEMP "Dependencies.zip"
            $depsDir = Join-Path $env:TEMP "WingetDeps"
            Invoke-WebRequest -Uri $depsAsset.browser_download_url -OutFile $depsZip -ErrorAction Stop
            Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force

            $arch      = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { "arm64" } elseif ($env:PROCESSOR_ARCHITECTURE -match 'x86') { "x86" } else { "x64" }
            $targetDir = Join-Path $depsDir $arch
            if (Test-Path $targetDir) {
                Get-ChildItem "$targetDir\*.appx" | ForEach-Object {
                    Write-InstallLog "Instalando dependÃªncia: $($_.Name)"
                    Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue
                }
            }
            Remove-Item $depsDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $depsZip -Force -ErrorAction SilentlyContinue
        }

        Write-InstallLog "Instalando AppInstaller bundle..."
        Add-AppxPackage -Path $tempBundle -ErrorAction Stop
        Remove-Item $tempBundle -Force -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2
        $finalInfo = Test-WinGet
        if ($finalInfo.Path) {
            Write-InstallLog "Winget pronto: $($finalInfo.Path)"
            return $finalInfo.Path
        }
        throw "Winget instalado mas nÃ£o detectado."
    }
    catch {
        Write-InstallLog "Erro crÃ­tico na instalaÃ§Ã£o do Winget: $($_.Exception.Message)" -Status "ERRO"
        return $null
    }
}

