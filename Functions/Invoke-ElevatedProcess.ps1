function global:Invoke-ElevatedProcess {
    <#
    .SYNOPSIS
    Executa processos externos ou funções PowerShell, opcionalmente em processo separado.
    
    .DESCRIPTION
    Simplificado para assumir que o processo atual já possui privilégios administrativos.
    Permite execução assíncrona em nova janela (ForceAsync).
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
        [switch]$RequireElevation, # Mantido para compatibilidade, mas ignorado na prática pois já somos admin

        [Parameter(Mandatory = $false)]
        [switch]$Wait,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru,

        [Parameter(Mandatory = $false)]
        [switch]$ForceAsync,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
        [string]$WindowStyle = 'Normal',

        [Parameter(Mandatory = $false, ParameterSetName = 'Process')]
        [string]$WorkingDirectory
    )

    try {
        switch ($PSCmdlet.ParameterSetName) {
            'Function' {
                return Invoke-PowerShellFunction -FunctionName $FunctionName -Parameters $Parameters -ScriptPath $ScriptPath -ForceAsync:$ForceAsync -WindowStyle $WindowStyle -PassThru:$PassThru
            }
            'Process' {
                return Invoke-ExternalProcess -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory -Wait:$Wait -PassThru:$PassThru -ForceAsync:$ForceAsync -WindowStyle $WindowStyle
            }
        }
    }
    catch {
        $errorMessage = "Erro ao executar processo: $($_.Exception.Message)"
        Write-InstallLog  $errorMessage -Status "ERRO" -ErrorAction SilentlyContinue
        throw $_
    }
}

function global:Invoke-PowerShellFunction {
    param(
        [string]$FunctionName,
        [hashtable]$Parameters,
        [string]$ScriptPath,
        [bool]$PassThru,
        [bool]$ForceAsync,
        [string]$WindowStyle = 'Normal'
    )
    
    # Se não forçar async, executar diretamente no processo atual
    if (-not $ForceAsync) {
        Write-InstallLog "Executando $FunctionName diretamente."
        
        if ($ScriptPath -and (Test-Path $ScriptPath)) {
            . $ScriptPath
        }
        
        if ($Parameters.Count -gt 0) {
            return & $FunctionName @Parameters
        } else {
            return & $FunctionName
        }
    }
    
    # Se for Async, preparar novo processo
    Write-InstallLog "Iniciando $FunctionName em novo processo..."
    
    $hostExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }
    
    # Preparar caminhos locais para importação
    $compiledPathLocal = $null
    try {
        if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath -and (Test-Path $global:ScriptContext.CompiledScriptPath)) {
            $compiledPathLocal = $global:ScriptContext.CompiledScriptPath
        }
    } catch {}

    $functionsPathLocal = $PSScriptRoot

    # Construir comando PowerShell
    $commandParts = @()
    
    # 1) Setup do contexto
    $commandParts += '$global:ScriptContext = if ($global:ScriptContext) { $global:ScriptContext } else { @{} }'
    $commandParts += '$global:ScriptContext.SkipEntryPoint = $true'
    
    # 2) Importação
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
            $importLine = "Get-ChildItem '$fp\\*.ps1' | Sort-Object Name | ForEach-Object { . `$_.FullName }"
            $commandParts += $importLine
        }
    }
    
    # 3) Chamada da função com parâmetros
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
    
    # 4) Executar
    $processArgs = @{
        FilePath     = $hostExe
        ArgumentList = "-WindowStyle $WindowStyle -NoProfile -ExecutionPolicy Bypass -Command `"$fullCommand`""
        PassThru     = $true # Sempre retorna o objeto processo
        ErrorAction  = 'Stop'
        # Verb RunAs removido pois já somos admin e queremos herdar o token sem prompt
    }
    
    $process = Start-Process @processArgs
    return $process
}

function global:Invoke-ExternalProcess {
    param(
        [string]$FilePath,
        [string]$ArgumentList,
        [string]$WorkingDirectory,
        [bool]$Wait,
        [bool]$PassThru,
        [bool]$ForceAsync,
        [string]$WindowStyle = 'Normal'
    )
    
    $actualWait = if ($ForceAsync) { $false } else { $Wait }
    
    $processArgs = @{
        FilePath      = $FilePath
        ArgumentList  = $ArgumentList
        Wait          = $actualWait
        PassThru      = $PassThru
        ErrorAction   = 'Stop'
        WindowStyle   = $WindowStyle
    }
    
    if ($WorkingDirectory) {
        $processArgs.Add("WorkingDirectory", $WorkingDirectory)
    }
    
    $process = Start-Process @processArgs
    
    if ($PassThru -or $ForceAsync) {
        return $process
    }
}
