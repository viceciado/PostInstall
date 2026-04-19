function Invoke-ExternalProcess {
    <#
    .SYNOPSIS
        Executa um processo externo (nÃ£o-PowerShell) com controle de janela e espera.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,
        [string]$ArgumentList,
        [string]$WorkingDirectory,
        [bool]  $Wait,
        [bool]  $PassThru,
        [bool]  $ForceAsync,
        [string]$WindowStyle = 'Normal'
    )

    if ([string]::IsNullOrWhiteSpace($FilePath)) { throw "ParÃ¢metro FilePath nÃ£o pode ser vazio." }

    try {
        $actualWait = if ($ForceAsync) { $false } else { $Wait }

        $processArgs = @{
            FilePath     = $FilePath
            ArgumentList = $ArgumentList
            Wait         = $actualWait
            PassThru     = $PassThru
            ErrorAction  = 'Stop'
            WindowStyle  = $WindowStyle
        }
        if ($WorkingDirectory) { $processArgs.WorkingDirectory = $WorkingDirectory }

        $process = Start-Process @processArgs
        if ($PassThru -or $ForceAsync) { return $process }
    }
    catch {
        Write-InstallLog "Erro em Invoke-ExternalProcess ($FilePath): $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        throw
    }
}

