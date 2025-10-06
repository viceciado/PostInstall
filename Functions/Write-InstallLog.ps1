
function Initialize-LogPath {
    # Definir caminhos
    $global:PrimaryLogPath = "$env:windir\Setup\Scripts\Install.log"
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

function global:Initialize-LogFile {
    <#
    .SYNOPSIS
    Inicializa o arquivo de log e retorna se é a primeira execução
    
    .DESCRIPTION
    Verifica se o arquivo de log já existe. Se não existir, cria um novo arquivo
    e retorna $true indicando que é a primeira execução. Se já existir, retorna $false.
    
    .PARAMETER IsFirstRun
    Parâmetro que indica se é a primeira execução do script
    
    .OUTPUTS
    Boolean - $true se é a primeira execução, $false caso contrário
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsFirstRun
    )
    
    if (-not $global:LogPath) {
        $global:LogPath = Initialize-LogPath
    }
    
    if ($IsFirstRun) {
        # Na primeira execução, recriar o arquivo de log completamente
        $header = @"
================================================================================
                        LOG DE INSTALAÇÃO - POST INSTALL
================================================================================
Início da sessão: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
================================================================================

"@
        $header | Out-File -FilePath $global:LogPath
        Write-Host "Novo arquivo de log criado: $global:LogPath" -ForegroundColor Green
    }
    else {
        # Adicionar separador para nova sessão
        $separator = @"

================================================================================
Nova sessão iniciada: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
================================================================================
"@
        $separator | Out-File -FilePath $global:LogPath -Append
        Write-Host "Continuando log existente: $global:LogPath" -ForegroundColor Cyan
    }
    
    return $IsFirstRun
}

# Inicializar caminho do log
$global:LogPath = Initialize-LogPath

function global:Write-InstallLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Status = "INFO",
        [string]$Component = "Post Install"
    )

    # Garantir que o log está inicializado
    if (-not $global:LogPath) {
        $global:LogPath = Initialize-LogPath
    }

    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logMessage = "$timestamp   [$Component] [$Status] $Message"
    
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

function global:Write-SystemInfoToLog {
    <#
    .SYNOPSIS
    Escreve as informações do sistema diretamente no log
    
    .DESCRIPTION
    Agora aceita um objeto de informações de sistema e o formata em texto para o log,
    mantendo compatibilidade com string caso recebida.
    
    .PARAMETER SystemInfoData
    Objeto contendo as informações do sistema

    .PARAMETER SystemInfo
    String contendo as informações do sistema (compatibilidade)
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$SystemInfoData,
        [Parameter(Mandatory = $false)]
        [string]$SystemInfo
    )
    
    $textToWrite = $null

    if ($SystemInfoData) {
        # Renderizar objeto em texto amigável
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("INFORMAÇÕES DO SISTEMA")
        [void]$sb.AppendLine("="*50)
        if ($SystemInfoData.Machine) {
            [void]$sb.AppendLine("Máquina: $($SystemInfoData.Machine.ChassisSKUNumber) $($SystemInfoData.Machine.Manufacturer) $($SystemInfoData.Machine.Model)")
        }
        [void]$sb.AppendLine("Número de série / Service Tag: $($SystemInfoData.SerialNumber)")
        if ($SystemInfoData.Processor) {
            [void]$sb.AppendLine("Processador: $($SystemInfoData.Processor.Name)")
        }
        [void]$sb.AppendLine("Memória RAM: $($SystemInfoData.TotalMemoryGB) GB")
        if ($SystemInfoData.OS) {
            [void]$sb.AppendLine("$($SystemInfoData.OS.Caption) de $($SystemInfoData.OS.Architecture)")
            [void]$sb.AppendLine("Build: $($SystemInfoData.OS.DisplayVersion)")
        }
        if ($SystemInfoData.Boot) {
            [void]$sb.AppendLine("Tipo de Boot: $($SystemInfoData.Boot.Description)")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("DISCOS:")
        [void]$sb.AppendLine("-"*20)
        if ($SystemInfoData.Disks) {
            $SystemInfoData.Disks | ForEach-Object {
                [void]$sb.AppendLine("Disco $($_.Index): $($_.Model) ($($_.SizeGB) GB)")
            }
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("GPUS:")
        [void]$sb.AppendLine("-"*20)
        if ($SystemInfoData.GPUs) {
            $SystemInfoData.GPUs | ForEach-Object {
                $mem = if ($_.MemoryMB) { "$($_.MemoryMB) MB" } else { "Desconhecida" }
                [void]$sb.AppendLine("GPU: $($_.Name) - Memória: $mem")
            }
        }
        $textToWrite = $sb.ToString()
    }
    elseif ($SystemInfo) {
        $textToWrite = $SystemInfo
    }

    if ($global:LogPath -and $textToWrite) {
        $textToWrite | Out-File -FilePath $global:LogPath -Append
        "`n" + "="*80 + "`n" | Out-File -FilePath $global:LogPath -Append
    }
}