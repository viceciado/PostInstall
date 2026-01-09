function global:Test-WinGet {
    <#
    .SYNOPSIS
        Verifica o estado da instalação do Winget e retorna informações detalhadas.
    #>
    [CmdletBinding()]
    param()

    $result = @{
        Status = "NotInstalled"
        Path = $null
        Version = $null
        IsPreview = $false
    }

    # 1. Tentar encontrar via Get-Command (PATH)
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) {
        $result.Path = $cmd.Source
    } else {
        # 2. Tentar locais padrão conhecidos
        $localAppData = $env:LOCALAPPDATA
        $programFiles = $env:ProgramFiles
        $candidates = @(
            "$localAppData\Microsoft\WindowsApps\winget.exe",
            "$programFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe"
        )
        foreach ($c in $candidates) {
            # Se for wildcard, expandir
            if ($c -like "*\**") {
                $expanded = Get-ChildItem $c -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($expanded) {
                    $result.Path = $expanded.FullName
                    break
                }
            } elseif (Test-Path $c) {
                $result.Path = $c
                break
            }
        }
    }

    if ($result.Path -and (Test-Path $result.Path)) {
        try {
            # Verificar versão
            $verStr = & $result.Path --version
            if ($verStr) {
                $verStr = $verStr.Trim()
                $result.Version = $verStr
                if ($verStr -match "-preview") { $result.IsPreview = $true }

                # Verificar se está atualizado (comparando com GitHub Latest)
                try {
                    $latestJson = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -ErrorAction Stop
                    $latestTag = $latestJson.tag_name.Trim('v')
                    $currentVerClean = $verStr -replace '-preview.*',''
                    
                    if ([System.Version]$currentVerClean -lt [System.Version]$latestTag) {
                        $result.Status = "Outdated"
                    } else {
                        $result.Status = "Installed"
                    }
                } catch {
                    # Se falhar checagem online, assume instalado
                    $result.Status = "Installed" 
                    Write-InstallLog "Aviso: Não foi possível verificar atualização online do Winget." -Status "AVISO"
                }
            }
        } catch {
            $result.Status = "NotInstalled" # Executável existe mas falha ao rodar
        }
    }

    return [PSCustomObject]$result
}

function global:Install-WinGet {
    <#
    .SYNOPSIS
        Instala ou atualiza o Winget, garantindo que esteja funcional.
        Retorna o caminho do executável em caso de sucesso.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    Write-InstallLog "Verificando instalação do Winget..."
    $info = Test-WinGet

    if ($info.Status -eq "Installed" -and -not $Force) {
        Write-InstallLog "Winget já está instalado e atualizado ($($info.Version))."
        return $info.Path
    }

    if ($info.Status -eq "Outdated") {
        Write-InstallLog "Winget desatualizado ($($info.Version)). Tentando atualizar..."
    } else {
        Write-InstallLog "Winget não encontrado. Iniciando instalação..."
    }

    # Tentativa 1: Via Winget (se existir e for apenas update)
    if ($info.Path -and (Test-Path $info.Path)) {
        try {
            Write-InstallLog "Tentando atualizar via self-update..."
            $proc = Start-Process -FilePath $info.Path -ArgumentList "install --id Microsoft.AppInstaller --source winget --accept-source-agreements --accept-package-agreements --silent --force" -PassThru -Wait -NoNewWindow
            if ($proc.ExitCode -eq 0) {
                Write-InstallLog "Winget atualizado com sucesso."
                $newInfo = Test-WinGet
                return $newInfo.Path
            }
        } catch {
            Write-InstallLog "Falha no self-update: $($_.Exception.Message)" -Status "AVISO"
        }
    }

    # Tentativa 2: Download manual do GitHub (Mais robusto para Win10 e cenários quebrados)
    try {
        Write-InstallLog "Baixando última versão do GitHub..."
        $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        
        $msixBundle = $release.assets | Where-Object { $_.name -like "Microsoft.DesktopAppInstaller_*.msixbundle" } | Select-Object -First 1
        if (-not $msixBundle) { throw "Asset msixbundle não encontrado." }

        $tempBundle = Join-Path $env:TEMP $msixBundle.name
        Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $tempBundle -ErrorAction Stop

        # Dependências
        $depsAsset = $release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" } | Select-Object -First 1
        if ($depsAsset) {
            $depsZip = Join-Path $env:TEMP "Dependencies.zip"
            $depsDir = Join-Path $env:TEMP "WingetDeps"
            Invoke-WebRequest -Uri $depsAsset.browser_download_url -OutFile $depsZip -ErrorAction Stop
            
            Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force
            
            # Instalar dependências da arquitetura correta
            $arch = if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") { "arm64" } elseif ($env:PROCESSOR_ARCHITECTURE -match "x86") { "x86" } else { "x64" }
            $targetDir = Join-Path $depsDir $arch
            
            if (Test-Path $targetDir) {
                Get-ChildItem "$targetDir\*.appx" | ForEach-Object {
                    Write-InstallLog "Instalando dependência: $($_.Name)"
                    Add-AppxPackage -Path $_.FullName -ErrorAction SilentlyContinue
                }
            }
            Remove-Item $depsDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $depsZip -Force -ErrorAction SilentlyContinue
        }

        Write-InstallLog "Instalando AppInstaller bundle..."
        Add-AppxPackage -Path $tempBundle -ErrorAction Stop
        Remove-Item $tempBundle -Force -ErrorAction SilentlyContinue

        Write-InstallLog "Instalação concluída. Verificando..."
        Start-Sleep -Seconds 2
        
        # Re-verificar
        $finalInfo = Test-WinGet
        if ($finalInfo.Path) {
            Write-InstallLog "Winget pronto: $($finalInfo.Path)"
            return $finalInfo.Path
        } else {
            throw "Winget instalado mas não detectado."
        }

    } catch {
        Write-InstallLog "Erro crítico na instalação do Winget: $($_.Exception.Message)" -Status "ERRO"
        return $null
    }
}

function global:Install-Programs {
    <#
    .SYNOPSIS
        Instala lista de programas usando um caminho específico do Winget.
        Projetado para rodar em processo separado.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProgramIDs,

        [Parameter(Mandatory = $true)]
        [string]$WingetPath
    )

    # Configuração visual do console
    $Host.UI.RawUI.WindowTitle = "PostInstall - Instalando $($ProgramIDs.Count) programas"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    Clear-Host
    Write-Host "=== INSTALAÇÃO DE PROGRAMAS ===" -ForegroundColor Cyan
    Write-Host "Winget: $WingetPath" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path $WingetPath)) {
        Write-Host "ERRO CRÍTICO: Executável do Winget não encontrado em $WingetPath" -ForegroundColor Red
        Read-Host "Pressione ENTER para sair"
        return
    }

    # 1. Aplicar Bypass de Certificado (Solução para 0x8a15005e)
    Write-Host "Aplicando configurações de segurança (BypassCertificatePinning)..." -ForegroundColor Yellow
    $p = Start-Process -FilePath $WingetPath -ArgumentList "settings --enable BypassCertificatePinningForMicrosoftStore" -PassThru -Wait -NoNewWindow
    
    $total = $ProgramIDs.Count
    $current = 0
    $successCount = 0
    $failCount = 0
    $failedItems = @()

    foreach ($id in $ProgramIDs) {
        $current++
        Write-Host "[$current/$total] Instalando: " -NoNewline
        Write-Host "$id" -ForegroundColor White

        $argsList = @(
            "install",
            "--id", "$id",
            "--source", "winget",
            "--exact",
            "--accept-source-agreements",
            "--accept-package-agreements",
            "--silent",
            "--force"
        )

        # Tenta machine scope primeiro
        $procArgs = $argsList + "--scope", "machine"
        
        Write-Host "    Tentando escopo Machine..." -ForegroundColor DarkGray
        $proc = Start-Process -FilePath $WingetPath -ArgumentList $procArgs -PassThru -Wait -NoNewWindow
        
        $ok = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq -1978335189) # Sucesso ou Sem Atualização

        if (-not $ok) {
            Write-Host "    Falha Machine (Code $($proc.ExitCode)). Tentando User..." -ForegroundColor DarkGray
            $procArgsUser = $argsList + "--scope", "user"
            $proc = Start-Process -FilePath $WingetPath -ArgumentList $procArgsUser -PassThru -Wait -NoNewWindow
            $ok = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq -1978335189)
        }

        if ($ok) {
            Write-Host "    SUCESSO" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "    FALHA (Exit Code: $($proc.ExitCode))" -ForegroundColor Red
            $failCount++
            $failedItems += $id
        }
        Write-Host ""
    }

    # 2. Reverter Bypass
    Write-Host "Revertendo configurações de segurança..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --disable BypassCertificatePinningForMicrosoftStore" -Wait -NoNewWindow | Out-Null

    # Resumo
    Write-Host "=== RESUMO ===" -ForegroundColor Cyan
    Write-Host "Total: $total | Sucesso: $successCount | Falha: $failCount"
    if ($failedItems) {
        Write-Host "Itens com falha:" -ForegroundColor Red
        $failedItems | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    }

    if ($failCount -gt 0) {
        Write-Host "`nPressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "`nConcluído com sucesso. Fechando em 5 segundos..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
}

function global:Upgrade-AllPrograms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath
    )

    $Host.UI.RawUI.WindowTitle = "PostInstall - Atualizar Tudo"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Clear-Host
    Write-Host "=== ATUALIZAÇÃO DE TODOS OS PROGRAMAS ===" -ForegroundColor Cyan
    Write-Host "Winget: $WingetPath" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path $WingetPath)) {
        Write-Host "ERRO: Winget não encontrado." -ForegroundColor Red
        Read-Host "Pressione ENTER para sair"
        return
    }

    Write-Host "Aplicando configurações de segurança..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --enable BypassCertificatePinningForMicrosoftStore" -Wait -NoNewWindow | Out-Null

    Write-Host "Iniciando atualização geral..." -ForegroundColor White
    $argsList = @("upgrade", "--all", "--source", "winget", "--accept-source-agreements", "--accept-package-agreements", "--silent", "--force", "--include-unknown")
    
    $proc = Start-Process -FilePath $WingetPath -ArgumentList $argsList -PassThru -Wait -NoNewWindow
    
    Write-Host "Revertendo configurações de segurança..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --disable BypassCertificatePinningForMicrosoftStore" -Wait -NoNewWindow | Out-Null

    if ($proc.ExitCode -eq 0) {
        Write-Host "`nAtualização concluída com sucesso. Fechando em 5 segundos..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    } else {
        Write-Host "`nO processo terminou com código: $($proc.ExitCode)." -ForegroundColor Yellow
        Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
