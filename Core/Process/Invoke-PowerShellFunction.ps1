function Invoke-PowerShellFunction {
    <#
    .SYNOPSIS
        Executa uma função PowerShell diretamente ou em um novo processo filho.
    .NOTES
        Quando ForceAsync=$true, um processo filho pwsh/powershell.exe é criado.
        Em modo dev (sem CompiledScriptPath), importa todos os arquivos de função
        dos sub-diretórios Core/, Features/ e DialogInitializers/ relativos Ã  raiz do projeto.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]  $FunctionName,
        [hashtable]$Parameters = @{},
        [string]  $ScriptPath,
        [bool]    $PassThru,
        [bool]    $ForceAsync,
        [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
        [string]  $WindowStyle = 'Normal'
    )

    if ([string]::IsNullOrWhiteSpace($FunctionName)) { throw "Parâmetro FunctionName não pode ser vazio." }

    try {
        # Execução direta no processo atual
        if (-not $ForceAsync) {
            Write-InstallLog "Executando $FunctionName diretamente."
            if ($ScriptPath -and (Test-Path $ScriptPath)) { . $ScriptPath }
            if ($Parameters.Count -gt 0) {
                return & $FunctionName @Parameters
            } else {
                return & $FunctionName
            }
        }

        #  Execução em novo processo filho 
        Write-InstallLog "Iniciando $FunctionName em novo processo..."

        $hostExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

        # Verificar se existe script compilado disponível
        $compiledPath = $null
        try {
            if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath -and (Test-Path $global:ScriptContext.CompiledScriptPath)) {
                $compiledPath = $global:ScriptContext.CompiledScriptPath
            }
        } catch {}

        # Raiz do projeto: sobe dois níveis a partir de Core/Process/
        $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

        $commandParts = @()

        # 1. Setup de contexto
        $commandParts += '$global:ScriptContext = if ($global:ScriptContext) { $global:ScriptContext } else { @{} }'
        $commandParts += '$global:ScriptContext.SkipEntryPoint = $true'

        # 2. Importar script extra opcional
        if ($ScriptPath -and (Test-Path $ScriptPath)) {
            $sp = $ScriptPath -replace "'", "''"
            $commandParts += ". '$sp'"
        }

        # 3. Importar definições de função
        if ($compiledPath) {
            $cp = $compiledPath -replace "'", "''"
            $commandParts += ". '$cp'"
        } elseif ($projectRoot -and (Test-Path $projectRoot)) {
            $rp = $projectRoot -replace "'", "''"
            # Core (dependências base primeiro)
            $commandParts += "Get-ChildItem '$rp\Core' -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object { . `$_.FullName }"
            # Features
            $commandParts += "Get-ChildItem '$rp\Features' -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object { . `$_.FullName }"
            # DialogInitializers
            $commandParts += "Get-ChildItem '$rp\DialogInitializers' -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . `$_.FullName }"
        }

        # 4. Montar chamada da função com parâmetros
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
                                if ($_ -is [string]) { $e = $_ -replace "'", "''"; "'$e'" }
                                elseif ($_ -is [bool]) { if ($_) { '$true' } else { '$false' } }
                                else { "$_" }
                            }) -join ","
                        "-$k @($arrayString)"
                    } elseif ($v -is [string]) {
                        $escaped = $v -replace "'", "''"
                        "-$k '$escaped'"
                    } else { "-$k $v" }
                }) -join " "
            $functionCall += " $paramString"
        }
        $commandParts += $functionCall

        $fullCommand = $commandParts -join "; "

        # 5. Iniciar processo filho
        $process = Start-Process `
            -FilePath     $hostExe `
            -ArgumentList "-WindowStyle $WindowStyle -NoProfile -ExecutionPolicy Bypass -Command `"$fullCommand`"" `
            -PassThru `
            -ErrorAction  Stop

        return $process
    } catch {
        Write-InstallLog "Erro em Invoke-PowerShellFunction ($FunctionName): $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        throw
    }
}

