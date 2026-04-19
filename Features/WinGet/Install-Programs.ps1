function Install-Programs {
    <#
    .SYNOPSIS
        Instala lista de programas usando um caminho especÃ­fico do Winget.
        Projetado para rodar em processo separado (janela de console visÃ­vel).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string[]]$ProgramIDs,
        [Parameter(Mandatory = $true)][string]$WingetPath
    )

    $Host.UI.RawUI.WindowTitle = "PostInstall - Instalando $($ProgramIDs.Count) programas"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Clear-Host
    Write-Host "=== INSTALAÃ‡ÃƒO DE PROGRAMAS ===" -ForegroundColor Cyan
    Write-Host "Winget: $WingetPath" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path $WingetPath)) {
        Write-Host "ERRO CRÃTICO: ExecutÃ¡vel do Winget nÃ£o encontrado em $WingetPath" -ForegroundColor Red
        Read-Host "Pressione ENTER para sair"
        return
    }

    # Aplicar bypass de certificado (soluÃ§Ã£o para 0x8A15005E)
    Write-Host "Aplicando configuraÃ§Ãµes de seguranÃ§a (BypassCertificatePinning)..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --enable BypassCertificatePinningForMicrosoftStore" -PassThru -Wait -NoNewWindow | Out-Null

    $total        = $ProgramIDs.Count
    $current      = 0
    $successCount = 0
    $failCount    = 0
    $failedItems  = @()

    foreach ($id in $ProgramIDs) {
        $current++
        Write-Host "[$current/$total] Instalando: " -NoNewline
        Write-Host $id -ForegroundColor White

        $baseArgs = @("install", "--id", $id, "--source", "winget", "--exact",
                      "--accept-source-agreements", "--accept-package-agreements", "--silent", "--force")

        # Tenta escopo machine primeiro
        Write-Host "    Tentando escopo Machine..." -ForegroundColor DarkGray
        $proc = Start-Process -FilePath $WingetPath -ArgumentList ($baseArgs + "--scope", "machine") -PassThru -Wait -NoNewWindow
        $ok   = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq $global:PSConst.WinGet.ExitCode_AlreadyLatest)

        if (-not $ok) {
            Write-Host "    Falha Machine (Code $($proc.ExitCode)). Tentando User..." -ForegroundColor DarkGray
            $proc = Start-Process -FilePath $WingetPath -ArgumentList ($baseArgs + "--scope", "user") -PassThru -Wait -NoNewWindow
            $ok   = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq $global:PSConst.WinGet.ExitCode_AlreadyLatest)
        }

        if ($ok) {
            Write-Host "    SUCESSO" -ForegroundColor Green
            $successCount++
        }
        else {
            Write-Host "    FALHA (Exit Code: $($proc.ExitCode))" -ForegroundColor Red
            $failCount++
            $failedItems += $id
        }
        Write-Host ""
    }

    # Reverter bypass
    Write-Host "Revertendo configuraÃ§Ãµes de seguranÃ§a..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --disable BypassCertificatePinningForMicrosoftStore" -Wait -NoNewWindow | Out-Null

    Write-Host "=== RESUMO ===" -ForegroundColor Cyan
    Write-Host "Total: $total | Sucesso: $successCount | Falha: $failCount"
    if ($failedItems) {
        Write-Host "Itens com falha:" -ForegroundColor Red
        $failedItems | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    }

    if ($failCount -gt 0) {
        Write-Host "`nPressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    else {
        Write-Host "`nConcluÃ­do com sucesso. Fechando em 5 segundos..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
}

