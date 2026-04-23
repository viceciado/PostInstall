function Invoke-ApplicationShutdown {
    <#
    .SYNOPSIS
        Encerra a aplicação WPF de forma limpa, fechando todas as janelas abertas.

    .DESCRIPTION
        Fecha todas as janelas registradas em Application.Current.Windows via Dispatcher
        (thread-safe: funciona tanto da thread STA quanto de threads de background) e
        chama Application.Shutdown() para liberar o loop de mensagens WPF.

        Slot reservado para B20 (Runspaces): antes de fechar janelas, cancelar todos os
        Runspace workers ativos registrados em $global:ScriptContext.ActiveRunspaces.

    .PARAMETER Reason
        Motivo do encerramento, gravado no log.
    #>
    [CmdletBinding()]
    param(
        [string]$Reason = "Encerramento normal"
    )

    Write-InstallLog "Encerrando aplicação: $Reason"

    # ── B20: Cancelar Runspaces ativos ──────────────────────────────────────
    # Quando B20 for implementado, iterar $global:ScriptContext.ActiveRunspaces,
    # chamar .CancellationTokenSource.Cancel() em cada worker e aguardar com timeout.
    # Exemplo de estrutura esperada:
    #   foreach ($worker in $global:ScriptContext.ActiveRunspaces) {
    #       try { $worker.CancellationTokenSource.Cancel() } catch {}
    #   }
    # ────────────────────────────────────────────────────────────────────────

    $app = [System.Windows.Application]::Current
    if ($app -and $app.Dispatcher -and -not $app.Dispatcher.HasShutdownStarted) {
        $app.Dispatcher.Invoke([Action]{
            foreach ($win in @([System.Windows.Application]::Current.Windows)) {
                try { $win.Close() } catch {}
            }
            [System.Windows.Application]::Current.Shutdown()
        })
    }
}