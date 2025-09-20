
function Initialize-LogPath {
    # Definir caminhos
    $global:PrimaryLogPath = "$env:SystemRoot\Setup\Scripts\Install.log"
    $global:FallbackLogPath = "$env:APPDATA\Install.log"
    
    # Função para testar permissão de escrita sem criar arquivo
    function Test-WritePermission {
        param([string]$Path)
        
        try {
            # Verificar se o diretório existe e criar se necessário
            $directory = Split-Path -Path $Path -Parent
            if (-not (Test-Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            
            # Testar abertura para escrita (mais eficiente que escrever)
            $fileStream = [System.IO.File]::OpenWrite($Path)
            $fileStream.Close()
            return $true
        }
        catch {
            return $false
        }
    }
    
    # Testar caminho primário primeiro
    if (Test-WritePermission -Path $global:primaryLogPath) {
        Write-Host "Log configurado em: $global:primaryLogPath" -ForegroundColor Green
        return $global:primaryLogPath
    }
    else {
        Write-Host "Sem permissão no local padrão. Log redirecionado para: $global:fallbackLogPath" -ForegroundColor Yellow
        
        # Garantir que o fallback funcione
        $fallbackDir = Split-Path -Path $global:fallbackLogPath -Parent
        if (-not (Test-Path $fallbackDir)) {
            New-Item -Path $fallbackDir -ItemType Directory -Force | Out-Null
        }
        
        return $global:fallbackLogPath
    }
}

# Inicializar caminho do log
$global:LogPath = Initialize-LogPath

function global:Write-InstallLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Status = "INFO",
        [string]$Component = "Configuração Interativa"
    )

    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logMessage = "$timestamp [$Component] [$Status] $Message"
    if ($global:LogPath) {
        $logMessage | Out-File -FilePath $global:LogPath -Append
    }
    
    # Definir cores baseadas no status
    $statusColor = switch ($Status.ToUpper()) {
        "SUCESSO" { "Green" }
        "ERRO" { "DarkRed" }
        "AVISO" { "Yellow" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    
    # Exibir a mensagem com apenas o status colorido
    Write-Host "$timestamp [$Component] [" -NoNewline
    Write-Host $Status -ForegroundColor $statusColor -NoNewline
    Write-Host "] $Message"

    # Tentar acessar a janela principal usando a nova convenção de nomenclatura
    $mainWindow = Get-Variable -Name 'xamlWindow' -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $mainWindow) {
        try {
            if ($mainWindow.Dispatcher.CheckAccess()) {
                $footerStatus = $mainWindow.FindName("FooterStatusButton")
                if ($footerStatus) {
                    $footerStatus.Content = "Status: $Message"
                }
            }
            else {
                $mainWindow.Dispatcher.Invoke([action] {
                        $footerStatus = $mainWindow.FindName("FooterStatusButton")
                        if ($footerStatus) {
                            $footerStatus.Content = "Status: $Message"
                        }
                    })
            }
        }
        catch {
            # Evitar recursão infinita ao tentar logar erro do próprio Write-InstallLog
            Write-Host "Não foi possível atualizar o status no footer: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}