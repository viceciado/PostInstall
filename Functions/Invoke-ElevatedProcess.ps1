function global:Invoke-ElevatedProcess {
    <#
    .SYNOPSIS
    Executa processos externos ou funções PowerShell com privilégios elevados quando necessário
    
    .DESCRIPTION
    Esta função unificada permite executar tanto processos externos quanto funções PowerShell internas
    com privilégios elevados de forma modular.
    
    .PARAMETER FilePath
    Caminho para o executável (para processos externos)
    
    .PARAMETER ArgumentList
    Argumentos para o processo (para processos externos)
    
    .PARAMETER FunctionName
    Nome da função PowerShell a ser executada (para funções internas)
    
    .PARAMETER Parameters
    Hashtable com os parâmetros para a função PowerShell
    
    .PARAMETER ScriptPath
    Caminho para o script que contém a função (opcional)
    
    .PARAMETER Wait
    Aguarda a conclusão do processo
    
    .PARAMETER PassThru
    Retorna o processo ou resultado da execução
    
    .PARAMETER WorkingDirectory
    Diretório de trabalho para o processo
    
    .PARAMETER RequireElevation
    Força a execução com privilégios elevados
    
    .EXAMPLE
    # Executar processo externo
    Invoke-ElevatedProcess -FilePath "notepad.exe" -ArgumentList "test.txt" -Wait
    
    .EXAMPLE
    # Executar função PowerShell
    $params = @{ RequireAdmin = $true }
    $result = Invoke-ElevatedProcess -FunctionName "Get-SystemInfo" -Parameters $params -PassThru
    #>
    
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Process')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Process')]
        [string]$FilePath,

        [Parameter(Mandatory = $false, ParameterSetName = 'Process')]
        [string]$ArgumentList,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Function')]
        [string]$FunctionName,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Function')]
        [hashtable]$Parameters = @{},
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Function')]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'Function')]
        [switch]$RequireElevation,

        [Parameter(Mandatory = $false)]
        [switch]$Wait,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$ForceAsync,

        [Parameter(Mandatory = $false, ParameterSetName = 'Process')]
        [string]$WorkingDirectory
    )

    try {
        # Verificar se já está executando como administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
        
        # Determinar o tipo de execução baseado no ParameterSet
        switch ($PSCmdlet.ParameterSetName) {
            'Function' {
                # Executar função PowerShell
                return Invoke-PowerShellFunction -FunctionName $FunctionName -Parameters $Parameters -ScriptPath $ScriptPath -RequireElevation:$RequireElevation -PassThru:$PassThru -IsAdmin $isAdmin -ForceAsync:$ForceAsync
            }
            'Process' {
                # Executar processo externo
                return Invoke-ExternalProcess -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait:$Wait -PassThru:$PassThru -IsAdmin $isAdmin -ForceAsync:$ForceAsync
            }
        }
    }
    catch {
        $errorMessage = "Erro ao executar com privilégios elevados: $($_.Exception.Message)"
        Write-InstallLog  $errorMessage -Status "ERRO" -ErrorAction SilentlyContinue
        throw $_
    }
}

# Função auxiliar para executar funções PowerShell
function global:Invoke-PowerShellFunction {
    param(
        [string]$FunctionName,
        [hashtable]$Parameters,
        [string]$ScriptPath,
        [bool]$RequireElevation,
        [bool]$PassThru,
        [bool]$IsAdmin,
        [bool]$ForceAsync
    )
    
    # Se já é admin e não forçar async, executar diretamente
    if ($IsAdmin -and -not $ForceAsync) {
        Write-InstallLog "Executando $FunctionName diretamente (Admin: $IsAdmin)"
        
        # Carregar script se especificado
        if ($ScriptPath -and (Test-Path $ScriptPath)) {
            . $ScriptPath
        }
        
        # Executar função com parâmetros
        if ($Parameters.Count -gt 0) {
            $result = & $FunctionName @Parameters
        } else {
            $result = & $FunctionName
        }
        
        if ($PassThru) {
            return $result
        }
        return
    }
    
    # Executar com privilégios elevados ou forçar execução assíncrona
    if ($ForceAsync) {
        Write-InstallLog "Executando $FunctionName em processo separado (ForceAsync: $ForceAsync)"
    } else {
        Write-InstallLog "Executando $FunctionName com privilégios elevados"
    }
    
    # Construir comando PowerShell
    $commandParts = @()
    
    # Adicionar importação do script se especificado
    if ($ScriptPath -and (Test-Path $ScriptPath)) {
        $commandParts += ". '$ScriptPath'"
    }
    
    # Adicionar importação de todas as funções do diretório atual
    $functionsPath = Split-Path $PSScriptRoot -Parent
    $functionsPath = Join-Path $functionsPath "Functions"
    if (Test-Path $functionsPath) {
        $commandParts += "Get-ChildItem '$functionsPath\*.ps1' | ForEach-Object { . `$_.FullName }"
    }
    
    # Construir chamada da função
    $functionCall = $FunctionName
    if ($Parameters.Count -gt 0) {
        $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
            if ($_.Value -is [bool]) {
                "-$($_.Key) `$$($_.Value.ToString().ToLower())"
            } elseif ($_.Value -is [string]) {
                "-$($_.Key) '$($_.Value)'"
            } elseif ($_.Value -is [array]) {
                $arrayString = ($_.Value | ForEach-Object { "'$_'" }) -join ","
                "-$($_.Key) @($arrayString)"
            } else {
                "-$($_.Key) $($_.Value)"
            }
        }) -join " "
        $functionCall += " $paramString"
    }
    
    $commandParts += $functionCall
    $fullCommand = $commandParts -join "; "
    
    # Executar com privilégios elevados
    if ($PassThru) {
        $tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
        $elevatedCommand = "$fullCommand | Out-File -FilePath '$tempFile' -Encoding UTF8"
        
        $processArgs = @{
            FilePath     = "powershell.exe"
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -Command `"$elevatedCommand`""
            Wait         = -not $ForceAsync
            PassThru     = $false
            ErrorAction  = 'Stop'
            Verb         = "RunAs"
        }
        
        $process = Start-Process @processArgs
        
        # Se não for async, ler resultado
        if (-not $ForceAsync -and (Test-Path $tempFile)) {
            $result = Get-Content $tempFile -Raw -Encoding UTF8
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $result.Trim()
        }
        
        # Se for async, retornar o processo
        if ($ForceAsync) {
            return $process
        }
    } else {
        $processArgs = @{
            FilePath     = "powershell.exe"
            ArgumentList = "-NoProfile -ExecutionPolicy Bypass -Command `"$fullCommand`""
            Wait         = -not $ForceAsync
            PassThru     = $ForceAsync
            ErrorAction  = 'Stop'
            Verb         = "RunAs"
        }
        
        $process = Start-Process @processArgs
        
        # Se for async, retornar o processo
        if ($ForceAsync) {
            return $process
        }
    }
    
    Write-InstallLog "$FunctionName executada com sucesso com privilégios elevados"
}

# Função auxiliar para executar processos externos
function global:Invoke-ExternalProcess {
    param(
        [string]$FilePath,
        [string]$ArgumentList,
        [string]$WorkingDirectory,
        [bool]$Wait,
        [bool]$PassThru,
        [bool]$IsAdmin,
        [bool]$ForceAsync
    )
    
    # Modificar Wait se ForceAsync for true
    $actualWait = if ($ForceAsync) { $false } else { $Wait }
    
    $processArgs = @{
        FilePath      = $FilePath
        ArgumentList  = $ArgumentList
        Wait          = $actualWait
        PassThru      = $PassThru
        ErrorAction   = 'Stop'
    }
    
    if ($WorkingDirectory) {
        $processArgs.Add("WorkingDirectory", $WorkingDirectory)
    }
    
    if (-not $IsAdmin -or $ForceAsync) {
        $processArgs.Add("Verb", "RunAs")
    }
    
    if ($PSCmdlet.ShouldProcess("'$FilePath $ArgumentList'", "Executar com privilégios elevados (se necessário)")) {
        $process = Start-Process @processArgs
        if ($PassThru -or $ForceAsync) {
            return $process
        }
    }
}