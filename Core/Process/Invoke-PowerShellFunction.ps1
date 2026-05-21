function Invoke-PowerShellFunction {
    <#
    .SYNOPSIS
        Executa uma função PowerShell diretamente ou em um novo processo filho.
    .NOTES
        Quando ForceAsync=$true, um processo filho pwsh/powershell.exe é criado.
        C12: o caminho async exige runtime compilado e CompiledScriptPath válido.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]  $FunctionName,
        [hashtable]$Parameters = @{},
        [bool]    $ForceAsync,
        [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
        [string]  $WindowStyle = 'Normal'
    )

    if ([string]::IsNullOrWhiteSpace($FunctionName)) { throw "Parâmetro FunctionName não pode ser vazio." }

    try {
        # Execução direta no processo atual
        if (-not $ForceAsync) {
            Write-InstallLog "Executando $FunctionName diretamente."
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

        $commandParts = @()

        # 1. Setup de contexto
        $commandParts += '$global:ScriptContext = if ($global:ScriptContext) { $global:ScriptContext } else { @{} }'
        $commandParts += '$global:ScriptContext.SkipEntryPoint = $true'

        # 2. Importar definições de função
        if ($compiledPath) {
            $cp = $compiledPath -replace "'", "''"
            $commandParts += ". '$cp'"
        } else {
            throw "CompiledScriptPath não encontrado. Invoke-PowerShellFunction async requer runtime compilado." 
        }

        # 3. Montar chamada da função com parâmetros
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

        # 4. Iniciar processo filho
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

