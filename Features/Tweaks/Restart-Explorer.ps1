function Restart-Explorer {
    <#
    .SYNOPSIS
        Encerra o processo Explorer para forÃ§ar a aplicaÃ§Ã£o de mudanÃ§as de registro.
        O Windows reinicia o Explorer automaticamente apÃ³s o encerramento.
    #>
    try {
        Write-InstallLog "Reiniciando o Explorer para aplicar alteraÃ§Ãµes..."
        $explorers = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($explorers) {
            Stop-Process -Id ($explorers.Id) -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-InstallLog "Aviso em Restart-Explorer: $($_.Exception.Message)" -Status "AVISO"
    }
}

