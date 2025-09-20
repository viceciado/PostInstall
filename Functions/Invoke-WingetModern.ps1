function global:Invoke-WingetModern {
    <#
    .SYNOPSIS
    Executa comandos winget de forma moderna sem arquivos temporários
    
    .DESCRIPTION
    Versão modernizada que executa winget diretamente capturando saída em tempo real,
    sem dependência de arquivos temporários e com logging transparente.
    
    .PARAMETER Command
    Comando winget a ser executado (install, upgrade, uninstall, etc.)
    
    .PARAMETER PackageId
    ID do pacote para operações específicas
    
    .PARAMETER Scope
    Escopo da instalação (machine, user)
    
    .PARAMETER Source
    Fonte específica (winget, msstore)
    
    .PARAMETER AdditionalArgs
    Argumentos adicionais para o comando
    
    .PARAMETER TimeoutSeconds
    Timeout em segundos (padrão: 300)
    
    .EXAMPLE
    Invoke-WingetModern -Command "install" -PackageId "Google.Chrome" -Scope "machine"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("install", "upgrade", "uninstall", "list", "search", "show")]
        [string]$Command,
        
        [Parameter(Mandatory = $false)]
        [string]$PackageId,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("machine", "user")]
        [string]$Scope,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("winget", "msstore")]
        [string]$Source,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AdditionalArgs = @(),
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )
    
    # Verificar se winget está disponível
    try {
        $wingetPath = (Get-Command winget -ErrorAction Stop).Source
        Write-InstallLog "Winget encontrado em: $wingetPath"
    }
    catch {
        Write-InstallLog "Winget não encontrado no sistema" -Status "ERRO"
        return @{
            Success = $false
            ExitCode = -1
            Error = "Winget não está instalado ou não está no PATH"
            Output = @()
        }
    }
    
    # Construir argumentos do comando
    $arguments = @($Command)
    
    if ($PackageId) {
        $arguments += "--id", "`"$PackageId`""
    }
    
    if ($Scope) {
        $arguments += "--scope", $Scope
    }
    
    if ($Source) {
        $arguments += "--source", $Source
    }
    
    # Adicionar argumentos padrão para instalação
    if ($Command -eq "install") {
        $arguments += "--silent", "--accept-source-agreements", "--accept-package-agreements"
    }
    
    # Adicionar argumentos extras
    if ($AdditionalArgs.Count -gt 0) {
        $arguments += $AdditionalArgs
    }
    
    $argumentString = $arguments -join " "
    Write-InstallLog "Executando: winget $argumentString"
    
    # Executar comando com captura de saída em tempo real
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $wingetPath
    $processInfo.Arguments = $argumentString
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    
    # Coleções para armazenar saída
    $outputLines = [System.Collections.Generic.List[string]]::new()
    $errorLines = [System.Collections.Generic.List[string]]::new()
    
    # Event handlers para captura em tempo real
    $outputHandler = {
        param($sender, $e)
        if (-not [string]::IsNullOrEmpty($e.Data)) {
            $outputLines.Add($e.Data)
            Write-InstallLog "$($e.Data)" -Status "INFO"
        }
    }
    
    $errorHandler = {
        param($sender, $e)
        if (-not [string]::IsNullOrEmpty($e.Data)) {
            $errorLines.Add($e.Data)
            Write-InstallLog "$($e.Data)" -Status "AVISO"
        }
    }
    
    # Registrar event handlers
    $process.add_OutputDataReceived($outputHandler)
    $process.add_ErrorDataReceived($errorHandler)
    
    try {
        # Iniciar processo
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # Aguardar conclusão com timeout
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            Write-InstallLog "Comando winget excedeu timeout de $TimeoutSeconds segundos" -Status "ERRO"
            $process.Kill()
            return @{
                Success = $false
                ExitCode = -2
                Error = "Timeout excedido"
                Output = $outputLines.ToArray()
            }
        }
        
        $exitCode = $process.ExitCode
        
        # Aguardar um pouco mais para garantir que toda saída foi capturada
        Start-Sleep -Milliseconds 100
        
        # Determinar sucesso baseado no código de saída
        $success = ($exitCode -eq 0) -or ($exitCode -eq -1978335189) # -1978335189 = já instalado
        
        if ($success) {
            if ($exitCode -eq -1978335189) {
                Write-InstallLog "Operação concluída - pacote já instalado ou nenhuma atualização disponível" -Status "SUCESSO"
            } else {
                Write-InstallLog "Operação concluída com sucesso" -Status "SUCESSO"
            }
        } else {
            Write-InstallLog "Operação falhou com código de saída: $exitCode" -Status "ERRO"
        }
        
        return @{
            Success = $success
            ExitCode = $exitCode
            Error = if ($errorLines.Count -gt 0) { $errorLines -join "`n" } else { $null }
            Output = $outputLines.ToArray()
        }
    }
    catch {
        Write-InstallLog "Erro ao executar winget: $($_.Exception.Message)" -Status "ERRO"
        return @{
            Success = $false
            ExitCode = -3
            Error = $_.Exception.Message
            Output = $outputLines.ToArray()
        }
    }
    finally {
        # Limpeza
        if ($process -and -not $process.HasExited) {
            try { $process.Kill() } catch { }
        }
        if ($process) {
            $process.Dispose()
        }
    }
}

function global:Install-ProgramModern {
    <#
    .SYNOPSIS
    Instala um programa usando a versão modernizada do winget
    
    .PARAMETER ProgramId
    ID do programa a ser instalado
    
    .PARAMETER MaxRetries
    Número máximo de tentativas (padrão: 3)
    
    .EXAMPLE
    Install-ProgramModern -ProgramId "Google.Chrome"
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgramId,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )
    
    Write-InstallLog "Iniciando instalação moderna de '$ProgramId'..."
    
    $attempt = 1
    $lastError = $null
    
    while ($attempt -le $MaxRetries) {
        if ($attempt -gt 1) {
            Write-InstallLog "Tentativa $attempt de $MaxRetries para '$ProgramId'" -Status "AVISO"
            Start-Sleep -Seconds (2 * $attempt) # Backoff simples
        }
        
        # Tentar instalação no escopo machine primeiro
        Write-InstallLog "Tentando instalação no escopo 'machine' para '$ProgramId'"
        $result = Invoke-WingetModern -Command "install" -PackageId $ProgramId -Scope "machine"
        
        if ($result.Success) {
            Write-InstallLog "'$ProgramId' instalado com sucesso no escopo 'machine'" -Status "SUCESSO"
            return $true
        }
        
        $lastError = $result.Error
        
        # Se falhou no machine, tentar no user
        Write-InstallLog "Instalação 'machine' falhou, tentando escopo 'user' para '$ProgramId'" -Status "AVISO"
        $result = Invoke-WingetModern -Command "install" -PackageId $ProgramId -Scope "user"
        
        if ($result.Success) {
            Write-InstallLog "'$ProgramId' instalado com sucesso no escopo 'user'" -Status "SUCESSO"
            return $true
        }
        
        # Se ainda falhou, verificar se é erro de fonte e tentar com fonte específica
        if ($result.ExitCode -in @(-1978335173, -1978335164, -1978335217, -1978335221)) {
            Write-InstallLog "Erro de fonte detectado, tentando com fonte 'winget' para '$ProgramId'" -Status "AVISO"
            $result = Invoke-WingetModern -Command "install" -PackageId $ProgramId -Scope "machine" -Source "winget"
            
            if ($result.Success) {
                Write-InstallLog "'$ProgramId' instalado com sucesso usando fonte 'winget'" -Status "SUCESSO"
                return $true
            }
        }
        
        $lastError = $result.Error
        $attempt++
    }
    
    Write-InstallLog "Falha ao instalar '$ProgramId' após $MaxRetries tentativas. Último erro: $lastError" -Status "ERRO"
    return $false
}

function global:Update-AllProgramsModern {
    <#
    .SYNOPSIS
    Atualiza todos os programas instalados usando winget de forma moderna
    
    .DESCRIPTION
    Executa 'winget upgrade --all' usando a implementação moderna sem arquivos temporários
    
    .EXAMPLE
    Update-AllProgramsModern
    #>
    
    [CmdletBinding()]
    param()
    
    Write-InstallLog "Iniciando atualização moderna de todos os programas instalados..."
    
    $result = Invoke-WingetModern -Command "upgrade" -AdditionalArgs @("--all", "--silent", "--accept-source-agreements", "--accept-package-agreements")
    
    if ($result.Success) {
        Write-InstallLog "Atualização de todos os programas concluída com sucesso" -Status "SUCESSO"
        return $true
    } else {
        Write-InstallLog "Falha na atualização de programas. Código: $($result.ExitCode), Erro: $($result.Error)" -Status "ERRO"
        return $false
    }
}

function global:Install-ProgramsModern {
    <#
    .SYNOPSIS
    Instala múltiplos programas usando execução assíncrona moderna
    
    .PARAMETER ProgramIDs
    Array de IDs dos programas a serem instalados
    
    .PARAMETER MaxConcurrent
    Número máximo de instalações simultâneas (padrão: 2)
    
    .EXAMPLE
    Install-ProgramsModern -ProgramIDs @("Google.Chrome", "Mozilla.Firefox")
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProgramIDs,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxConcurrent = 2
    )
    
    # Log de debug para verificar se a função está sendo chamada
    Write-InstallLog "[DEBUG] Install-ProgramsModern iniciada com $($ProgramIDs.Count) programas: $($ProgramIDs -join ', ')" -Status "INFO"
    
    if (-not $ProgramIDs -or $ProgramIDs.Count -eq 0) {
        Write-InstallLog "Nenhum programa especificado para instalação" -Status "AVISO"
        return
    }
    
    Write-InstallLog "Iniciando instalação moderna de $($ProgramIDs.Count) programas"
    
    # Verificar se winget está disponível antes de começar
    try {
        $null = Get-Command winget -ErrorAction Stop
    }
    catch {
        Write-InstallLog "Winget não está disponível. Tentando instalar/atualizar..." -Status "AVISO"
        $wingetReady = Install-WingetWrapper
        if (-not $wingetReady) {
            Write-InstallLog "Não foi possível preparar o Winget. Cancelando instalações." -Status "ERRO"
            return
        }
    }
    
    # Para evitar problemas com PowerShell Jobs, vamos usar uma abordagem mais simples
    # Instalação sequencial com melhor feedback
    $completed = @()
    $failed = @()
    $totalPrograms = $ProgramIDs.Count
    
    try {
        for ($i = 0; $i -lt $totalPrograms; $i++) {
            $programId = $ProgramIDs[$i]
            $currentNumber = $i + 1
            
            Write-InstallLog "Instalando programa $currentNumber de ${totalPrograms}: '$programId'"
            
            # Atualizar progresso
            $percentComplete = [math]::Round(($i / $totalPrograms) * 100)
            Write-Progress -Activity "Instalando programas" -Status "Instalando $programId ($currentNumber de $totalPrograms)" -PercentComplete $percentComplete
            
            $startTime = Get-Date
            $installSuccess = Install-ProgramModern -ProgramId $programId
            $duration = (Get-Date) - $startTime
            
            if ($installSuccess) {
                $completed += $programId
                Write-InstallLog "'$programId' instalado com sucesso em $([math]::Round($duration.TotalSeconds, 1))s" -Status "SUCESSO"
            } else {
                $failed += $programId
                Write-InstallLog "Instalação de '$programId' falhou após $([math]::Round($duration.TotalSeconds, 1))s" -Status "ERRO"
            }
        }
        
        Write-Progress -Activity "Instalando programas" -Status "Concluído" -PercentComplete 100 -Completed
        
        # Relatório final
        Write-InstallLog "Instalação moderna concluída: $($completed.Count) sucessos, $($failed.Count) falhas"
        if ($completed.Count -gt 0) {
            Write-InstallLog "Programas instalados com sucesso: $($completed -join ', ')" -Status "SUCESSO"
        }
        if ($failed.Count -gt 0) {
            Write-InstallLog "Programas que falharam: $($failed -join ', ')" -Status "ERRO"
        }
        
        # Pausa para manter janela aberta quando executado de forma elevada
        Write-InstallLog "[DEBUG] Instalação concluída. Pressione qualquer tecla para fechar..." -Status "INFO"
        if ([Environment]::UserInteractive) {
            try {
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            catch {
                Start-Sleep -Seconds 10
            }
        }
    }
    catch {
        Write-InstallLog "Erro inesperado durante instalação: $($_.Exception.Message)" -Status "ERRO"
        Write-InstallLog "[DEBUG] Erro capturado. Pressione qualquer tecla para fechar..." -Status "ERRO"
        if ([Environment]::UserInteractive) {
            try {
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            catch {
                Start-Sleep -Seconds 10
            }
        }
    }
}