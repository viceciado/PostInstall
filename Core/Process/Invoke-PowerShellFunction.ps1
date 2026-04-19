function Invoke-PowerShellFunction {
    <#
    .SYNOPSIS
        Executa uma funÃ§Ã£o PowerShell diretamente ou em um novo processo filho.
    .NOTES
        Quando ForceAsync=$true, um processo filho pwsh/powershell.exe Ã© criado.
        Em modo dev (sem CompiledScriptPath), importa todos os arquivos de funÃ§Ã£o
        dos sub-diretÃ³rios Core/, Features/ e DialogInitializers/ relativos Ã  raiz do projeto.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]  $FunctionName,
        [hashtable]$Parameters   = @{},
        [string]  $ScriptPath,
        [bool]    $PassThru,
        [bool]    $ForceAsync,
        [ValidateSet('Normal', 'Hidden', 'Minimized', 'Maximized')]
        [string]  $WindowStyle   = 'Normal'
    )

    if ([string]::IsNullOrWhiteSpace($FunctionName)) { throw "ParÃ¢metro FunctionName nÃ£o pode ser vazio." }

    try {
        # ExecuÃ§Ã£o direta no processo atual
        if (-not $ForceAsync) {
            Write-InstallLog "Executando $FunctionName diretamente."
            if ($ScriptPath -and (Test-Path $ScriptPath)) { . $ScriptPath }
            if ($Parameters.Count -gt 0) {
                return & $FunctionName @Parameters
            }
            else {
                return & $FunctionName
            }
        }

        # â”€â”€ ExecuÃ§Ã£o em novo processo filho â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Write-InstallLog "Iniciando $FunctionName em novo processo..."

        $hostExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell.exe" }

        # Verificar se existe script compilado disponÃ­vel
        $compiledPath = $null
        try {
            if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath -and (Test-Path $global:ScriptContext.CompiledScriptPath)) {
                $compiledPath = $global:ScriptContext.CompiledScriptPath
            }
        }
        catch {}

        # Raiz do projeto: sobe dois nÃ­veis a partir de Core/Process/
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

        # 3. Importar definiÃ§Ãµes de funÃ§Ã£o
        if ($compiledPath) {
            $cp = $compiledPath -replace "'", "''"
            $commandParts += ". '$cp'"
        }
        elseif ($projectRoot -and (Test-Path $projectRoot)) {
            $rp = $projectRoot -replace "'", "''"
            # Core (dependÃªncias base primeiro)
            $commandParts += "Get-ChildItem '$rp\Core' -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object { . `$_.FullName }"
            # Features
            $commandParts += "Get-ChildItem '$rp\Features' -Recurse -Filter '*.ps1' | Sort-Object FullName | ForEach-Object { . `$_.FullName }"
            # DialogInitializers
            $commandParts += "Get-ChildItem '$rp\DialogInitializers' -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . `$_.FullName }"
        }

        # 4. Montar chamada da funÃ§Ã£o com parÃ¢metros
        $functionCall = $FunctionName
        if ($Parameters.Count -gt 0) {
            $paramString = ($Parameters.GetEnumerator() | ForEach-Object {
                $k = $_.Key
                $v = $_.Value
                if ($v -is [bool]) {
                    $boolLiteral = if ($v) { '$true' } else { '$false' }
                    "-$k $boolLiteral"
                }
                elseif ($v -is [array]) {
                    $arrayString = ($v | ForEach-Object {
                        if ($_ -is [string])    { $e = $_ -replace "'", "''"; "'$e'" }
                        elseif ($_ -is [bool])  { if ($_) { '$true' } else { '$false' } }
                        else                    { "$_" }
                    }) -join ","
                    "-$k @($arrayString)"
                }
                elseif ($v -is [string]) {
                    $escaped = $v -replace "'", "''"
                    "-$k '$escaped'"
                }
                else { "-$k $v" }
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
    }
    catch {
        Write-InstallLog "Erro em Invoke-PowerShellFunction ($FunctionName): $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        throw
    }
}

