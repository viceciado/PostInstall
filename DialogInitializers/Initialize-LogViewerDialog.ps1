function Get-LogViewerConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuraÃ§Ã£o do diÃ¡logo LogViewer.
    #>
    return {
        param($logViewerWindow)

        $unifiedLogTextBox = $logViewerWindow.FindName("UnifiedLogTextBox")

        try {
            $logContent = New-Object System.Collections.Generic.List[string]

            $primaryLogPath = if ($global:PSConst) {
                $global:PSConst.LogPaths.Primary
            } else {
                "$env:SystemRoot\Setup\Scripts\Install.log"
            }
            $currentLogPath = if ($global:LogPath) {
                $global:LogPath
            } elseif ($global:PSConst) {
                $global:PSConst.LogPaths.Fallback
            } else {
                "$env:APPDATA\Install.log"
            }

            if (Test-Path $primaryLogPath) {
                $logContent.Add("InÃ­cio do log principal [$primaryLogPath]")
                $primaryLogLines = Get-Content -Path $primaryLogPath -ErrorAction SilentlyContinue
                if ($primaryLogLines) { $logContent.AddRange([string[]]$primaryLogLines) }
                else                  { $logContent.Add("O arquivo de log estÃ¡ vazio!") }
                $logContent.Add("Fim do log principal")
                $logContent.Add("")
            }

            if ((Test-Path $currentLogPath) -and ($currentLogPath -ne $primaryLogPath)) {
                $logContent.Add("InÃ­cio do log da sessÃ£o [$currentLogPath]")
                $currentLogLines = Get-Content -Path $currentLogPath -ErrorAction SilentlyContinue
                if ($currentLogLines) { $logContent.AddRange([string[]]$currentLogLines) }
                else                  { $logContent.Add("O arquivo de log estÃ¡ vazio!") }
                $logContent.Add("Fim do log da sessÃ£o")
            }

            $unifiedLogTextBox.Text = $logContent -join "`n"
            $unifiedLogTextBox.ScrollToEnd()
        }
        catch {
            $errorMessage = "Erro crÃ­tico ao carregar logs: $($_.Exception.Message)"
            $unifiedLogTextBox.Text = $errorMessage
            Write-InstallLog $errorMessage -Status "ERRO"
        }
    }
}

