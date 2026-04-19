function Initialize-And-Upgrade-All {
    <#
    .SYNOPSIS
        Inicializa o Winget e atualiza todos os programas instalados.
        Projetado para ser chamado via Invoke-ElevatedProcess em nova janela.
    #>
    [CmdletBinding()]
    param()

    $Host.UI.RawUI.WindowTitle = "PostInstall - Preparando Atualização"
    [Console]::OutputEncoding  = [System.Text.Encoding]::UTF8
    Clear-Host
    Write-Host "=== PREPARAÇÃO DO WINGET ===" -ForegroundColor Cyan
    Write-Host "Verificando componentes necessÃ¡rios..."
    Write-Host ""

    try {
        $wingetPath = Install-WinGet
        if (-not $wingetPath) { throw "Falha crÃ­tica: ExecutÃ¡vel do Winget não retornado." }
        Update-AllPrograms -WingetPath $wingetPath
        return $true
    }
    catch {
        Write-InstallLog "Erro em Initialize-And-Upgrade-All: $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        Write-Host "`nERRO FATAL: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
}

