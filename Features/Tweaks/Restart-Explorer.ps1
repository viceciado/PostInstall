function Restart-Explorer {
    <#
    .SYNOPSIS
        Encerra o processo Explorer para forçar a aplicação de mudanças de registro.
        O Windows reinicia o Explorer automaticamente após o encerramento.
    #>
    try {
        Write-InstallLog "Reiniciando o Explorer para aplicar alterações..."
        $explorers = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($explorers) {
            Stop-Process -Id ($explorers.Id) -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-InstallLog "Aviso em Restart-Explorer: $($_.Exception.Message)" -Status "AVISO"
    }
}

