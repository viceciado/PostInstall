function Invoke-ElevatedProcess {
    <#
    .SYNOPSIS
        Executa processos externos ou funÃ§Ãµes PowerShell, opcionalmente em processo separado.
    .DESCRIPTION
        Assume que o processo atual jÃ¡ possui privilÃ©gios administrativos.
        Delega para Invoke-PowerShellFunction (ParameterSet 'Function') ou
        Invoke-ExternalProcess (ParameterSet 'Process').
    #>
    [CmdletBinding(DefaultParameterSetName = 'Process')]
    param(
        [Parameter(Mandatory = $true,  ParameterSetName = 'Process')]
        [string]$FilePath,

        [Parameter(Mandatory = $false, ParameterSetName = 'Process')]
        [string]$ArgumentList,

        [Parameter(Mandatory = $true,  ParameterSetName = 'Function')]
        [string]$FunctionName,

        [Parameter(Mandatory = $false, ParameterSetName = 'Function')]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false, ParameterSetName = 'Function')]
        [string]$ScriptPath,

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
                return Invoke-PowerShellFunction `
                    -FunctionName $FunctionName `
                    -Parameters   $Parameters `
                    -ScriptPath   $ScriptPath `
                    -ForceAsync   ([bool]$ForceAsync) `
                    -WindowStyle  $WindowStyle `
                    -PassThru     ([bool]$PassThru)
            }
            'Process' {
                return Invoke-ExternalProcess `
                    -FilePath          $FilePath `
                    -ArgumentList      $ArgumentList `
                    -WorkingDirectory  $WorkingDirectory `
                    -Wait              ([bool]$Wait) `
                    -PassThru          ([bool]$PassThru) `
                    -ForceAsync        ([bool]$ForceAsync) `
                    -WindowStyle       $WindowStyle
            }
        }
    }
    catch {
        Write-InstallLog "Erro em Invoke-ElevatedProcess: $($_.Exception.Message)" -Status "ERRO" -ErrorAction SilentlyContinue
        throw $_
    }
}

