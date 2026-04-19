function Get-LogViewerConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuração do diÃ¡logo LogViewer.
    #>
    return {
        param($logViewerWindow)

        $unifiedLogTextBox = $logViewerWindow.FindName("UnifiedLogTextBox")

        try {
            $logContent = New-Object System.Collections.Generic.List[string]

            $primaryLogPath = $global:PSConst.LogPaths.Primary
            $currentLogPath = if ($global:LogPath) {
                $global:LogPath
            } else {
                $global:PSConst.LogPaths.Fallback
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
                $logContent.Add("InÃ­cio do log da sessão [$currentLogPath]")
                $currentLogLines = Get-Content -Path $currentLogPath -ErrorAction SilentlyContinue
                if ($currentLogLines) { $logContent.AddRange([string[]]$currentLogLines) }
                else                  { $logContent.Add("O arquivo de log estÃ¡ vazio!") }
                $logContent.Add("Fim do log da sessão")
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

