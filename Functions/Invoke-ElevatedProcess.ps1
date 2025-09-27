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
    
    # Escolher host (pwsh se existir, senão powershell.exe)
    $hostExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    
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
    
    # Preparar caminhos locais para importação na sessão elevada
    $compiledPathLocal = $null
    try {
        if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath -and (Test-Path $global:ScriptContext.CompiledScriptPath)) {
            $compiledPathLocal = $global:ScriptContext.CompiledScriptPath
        }
    } catch {}

    # Diretório das funções (este arquivo reside em ...\Functions)
    $functionsPathLocal = $PSScriptRoot

    # Construir comando PowerShell
    $commandParts = @()
    
    # 1) Garantir que, na sessão elevada, não executaremos o entrypoint ao importar
    $commandParts += '$global:ScriptContext = if ($global:ScriptContext) { $global:ScriptContext } else { @{} }'
    $commandParts += '$global:ScriptContext.SkipEntryPoint = $true'
    
    # 2) Importação de funções / script
    if ($ScriptPath -and (Test-Path $ScriptPath)) {
        $sp = $ScriptPath -replace "'", "''"
        $commandParts += ". '$sp'"
    }

    if ($compiledPathLocal) {
        $cp = $compiledPathLocal -replace "'", "''"
        $commandParts += ". '$cp'"
    }
    else {
        if ($functionsPathLocal -and (Test-Path $functionsPathLocal)) {
            $fp = $functionsPathLocal -replace "'", "''"
            # Usar string formatada para evitar expansão de $_ no momento da construção
            $importLine = ("Get-ChildItem '{0}\\*.ps1' | Sort-Object Name | ForEach-Object {{ . $_.FullName }}" -f $fp)
            $commandParts += $importLine
        }
    }
    
    # 3) Construir chamada da função com parâmetros robustos
    $functionCall = $FunctionName
    if ($Parameters.Count -gt 0) {
        $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
            $k = $_.Key
            $v = $_.Value
            if ($v -is [bool]) {
                $boolLiteral = if ($v) { '$true' } else { '$false' }
                "-$k $boolLiteral"
            } elseif ($v -is [array]) {
                $arrayString = ($v | ForEach-Object {
                    if ($_ -is [string]) {
                        $e = $_ -replace "'", "''"
                        "'$e'"
                    }
                    elseif ($_ -is [bool]) {
                        if ($_ ) { '$true' } else { '$false' }
                    }
                    else {
                        "$_"
                    }
                }) -join ","
                "-$k @($arrayString)"
            } elseif ($v -is [string]) {
                $escaped = $v -replace "'", "''"
                "-$k '$escaped'"
            } else {
                "-$k $v"
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
            FilePath     = $hostExe
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
            FilePath     = $hostExe
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
        # Neste caso, poderíamos adicionar Verb RunAs, mas como é genérico e pode ser usado sem elevação, mantemos simples
    }
    
    if ($PSCmdlet.ShouldProcess("'$FilePath $ArgumentList'", "Executar com privilégios elevados (se necessário)")) {
        $process = Start-Process @processArgs
        if ($PassThru -or $ForceAsync) {
            return $process
        }
    }
}