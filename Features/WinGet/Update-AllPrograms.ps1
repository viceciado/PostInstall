function Update-AllPrograms {
    <#
    .SYNOPSIS
        Atualiza todos os programas instalados via Winget (upgrade --all).
        Projetado para rodar em processo separado (janela de console visÃ­vel).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath
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
    $proc = Start-Process -FilePath $WingetPath `
        -ArgumentList @("upgrade", "--all", "--source", "winget", "--accept-source-agreements",
                        "--accept-package-agreements", "--silent", "--force", "--include-unknown") `
        -PassThru -Wait -NoNewWindow

    Write-Host "Revertendo configurações de segurança..." -ForegroundColor Yellow
    Start-Process -FilePath $WingetPath -ArgumentList "settings --disable BypassCertificatePinningForMicrosoftStore" -Wait -NoNewWindow | Out-Null

    if ($proc.ExitCode -eq 0) {
        Write-Host "`nAtualização concluída com sucesso. Fechando em 5 segundos..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
    else {
        Write-Host "`nO processo terminou com código: $($proc.ExitCode)." -ForegroundColor Yellow
        Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Wrapper de compatibilidade com código anterior
function Upgrade-AllPrograms {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$WingetPath
    )

    Write-InstallLog "Upgrade-AllPrograms esta depreciada. Use Update-AllPrograms." -Status "AVISO"
    return Update-AllPrograms @PSBoundParameters
}

