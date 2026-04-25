function Initialize-And-Install-Programs {
    <#
    .SYNOPSIS
        Inicializa o Winget e instala programas em sequência.
        Projetado para ser chamado via Invoke-ElevatedProcess em nova janela.
    #>
    [CmdletBinding()]
    param(
        [string[]]$ProgramIDs
    )

    $Host.UI.RawUI.WindowTitle = "PostInstall - Preparando Ambiente"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Clear-Host
    Write-Host "=== PREPARAÇÃO DO WINGET ===" -ForegroundColor Cyan
    Write-Host "Verificando componentes necessários..."
    Write-Host ""

    try {
        $wingetPath = Install-WinGet
        if (-not $wingetPath) { throw "Falha crítica: Executável do Winget não retornado." }
        Install-Programs -ProgramIDs $ProgramIDs -WingetPath $wingetPath
        return $true
    } catch {
        Write-InstallLog "Erro em Initialize-And-Install-Programs: $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        Write-Host "`nERRO FATAL: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
}

