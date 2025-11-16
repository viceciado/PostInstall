@echo off
setlocal
MODE CON: COLS=98 LINES=40

:: ============================================================================
:: == 0. CABECALHO E TITULO DA JANELA
:: ============================================================================
title Post-Install Downloader
cls

echo.
echo.
echo.
echo.
echo ================================================================================================
echo.
echo MMMMM       MMMMMM  AAAAAAAAAAAAAAA  SSSSSSSSSSSSSSS TTTTTTTTTTTTT EEEEEEEEEEEEE RRRRRRRRRRRRRRR  
echo MMMMMMM    MMMMMMM  AAAAAAAAAAAAAAA SSSSSSSSSSSSSSS  TTTTTTTTTTTTT EEEEEEEEEEEEE RRRRRRRRRRRRRRR 
echo MMMMMMMM  MMMMMMMM  AAAAA     AAAAA SSSSS                TTTTT     EEEEE         RRRRR     RRRRR 
echo MMMMMMMMMMMMMMMMMM  AAAAA     AAAAA SSSSSSSSSSSSSS       TTTTT     EEEEEEEEEEE   RRRRR     RRRRR 
echo MMMMMMMMMMMMMMMMMM  AAAAA     AAAAA  SSSSSSSSSSSSSSS     TTTTT     EEEEEEEEEEE   RRRRRRRRRRRRRR  
echo MMMM  MMMMM  MMMMM  AAAAAAAAAAAAAAA           SSSSSS     TTTTT     EEEEE         RRRRR  RRRRR    
echo MMMM   MMMM  MMMMM  AAAAAAAAAAAAAAA           SSSSSS     TTTTT     EEEEE         RRRRR    RRRRR 
echo MMMM    M    MMMMM  AAAAA     AAAAA SSSSSSSSSSSSSSSS     TTTTT     EEEEEEEEEEEEE RRRRR     RRRRR 
echo MMMM         MMMMM  AAAAA     AAAAA SSSSSSSSSSSSSSS      TTTTT     EEEEEEEEEEEEE RRRRR     RRRRR
echo.
echo                          PostInstall - Script de pos-instalacao do Windows
echo ================================================================================================
echo.


:: ============================================================================
:: == 1. VERIFICACAO DE PERMISSAO DE ADMINISTRADOR
:: ============================================================================
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo                -----------------------------------------------------------------------
    echo                      ERRO: Este script precisa ser executado como Administrador.
    echo.
    echo                         Por favor, clique com o botao direito no arquivo .bat
    echo                             e selecione "Executar como administrador".
    echo                -----------------------------------------------------------------------
    echo.
    pause
    goto :eof
)


:: ============================================================================
:: == 2. DEFINICAO DE VARIAVEIS
:: ============================================================================
set "TARGET_DIR=%windir%\Setup\Scripts"
set "TARGET_FILE=%TARGET_DIR%\PostInstall.ps1"
set "REPO_API_URL=https://api.github.com/repos/viceciado/PostInstall/releases/latest"
set "ASSET_NAME=PostInstall.ps1"


:: ============================================================================
:: == 3. ESPERAR PELA CONEXAO COM A INTERNET
:: ============================================================================
:waitForNet
echo Verificando conexao
ping -n 1 api.github.com | find "TTL=" >nul
if errorlevel 1 (
    echo Tentando novamente em 10 segundos...
    timeout /t 10 /nobreak >nul
    goto waitForNet
)


:: ============================================================================
:: == 4. DOWNLOAD DO SCRIPT (Usando PowerShell)
:: ============================================================================
echo Baixando PostInstall.ps1...
echo Destino: %TARGET_FILE%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $p = '%TARGET_DIR%'; $t = '%TARGET_FILE%'; $f_temp = Join-Path $env:TEMP 'PostInstall_temp.ps1'; $apiUrl = '%REPO_API_URL%'; $assetName = '%ASSET_NAME%'; if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force -ErrorAction Stop | Out-Null; Write-Host 'Diretorio criado: $p'; }; Write-Host 'Consultando API do GitHub...'; $r = Invoke-RestMethod -Uri $apiUrl -Headers @{'User-Agent'='PowerShell'} -TimeoutSec 30 -ErrorAction Stop; $a = $r.assets | Where-Object { $_.name -eq $assetName }; if ($null -eq $a) { Write-Error 'Asset [$assetName] nao encontrado.'; exit 1; }; Write-Host 'Baixando $($a.browser_download_url)...'; $w = New-Object System.Net.WebClient; $w.Headers.Add('User-Agent', 'PowerShell'); $w.DownloadFile($a.browser_download_url, $f_temp); $c = Get-Content -Path $f_temp -Raw -Encoding UTF8; $u = New-Object System.Text.UTF8Encoding $true; [System.IO.File]::WriteAllText($t, $c, $u); Remove-Item $f_temp -Force -ErrorAction SilentlyContinue; $w.Dispose(); Write-Host 'Download e re-codificacao concluidos: $t'; exit 0; } catch { Write-Host '--- ERRO FATAL NO POWERSHELL ---'; Write-Error $_; Write-Host '--- FIM DO ERRO ---'; exit 1; }"

:: Verificar se o comando PowerShell falhou
if %errorLevel% NEQ 0 (
    echo.
    echo                -----------------------------------------------------------------------
    echo                               ERRO: Falha ao baixar o script do GitHub.
    echo                        Verifique sua conexão com a internet e tente novamente.
    echo                -----------------------------------------------------------------------
    echo.
    pause
    goto :eof
)

:: ============================================================================
:: == 5. EXECUCAO EM SEGUNDO PLANO (HIDDEN)
:: ============================================================================
echo.
echo Iniciando PostInstall.ps1...
echo.

start "" powershell -NoProfile -ExecutionPolicy Bypass -Command "powershell -WindowStyle Hidden -File '%TARGET_FILE%'"

:: ============================================================================
:: == 6. CONCLUSAO
:: ============================================================================
    echo.
    echo                -----------------------------------------------------------------------
    echo                                  O script Post-Install foi iniciado.
    echo                                     Essa janela pode ser fechada.
    echo                -----------------------------------------------------------------------
    echo.

pause
goto :eof