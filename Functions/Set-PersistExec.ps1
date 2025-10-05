function global:Set-PersistExec {
    <#
    .SYNOPSIS
    Retoma a execução do script após reinicios inesperados
    
    .DESCRIPTION
    Ao ser chamada pela primeira vez, cria uma tarefa agendada para executar o script
    sempre que o sistema for iniciado. Ao Finalizar a instalação, remove a tarefa.
    
    .EXAMPLE
    Set-PersistExec -ScriptPath "C:\Scripts\MyScript.ps1"
    
    .EXAMPLE
    Set-PersistExec -Stop
    #>

    param (
        [string]$ScriptPath,
        [switch]$Stop
    )

    # Determinar o caminho do script de forma robusta
    if (-not $ScriptPath) {
        $ScriptPath = if ($PSCommandPath) { 
            $PSCommandPath 
        } elseif ($MyInvocation.MyCommand.Path) { 
            $MyInvocation.MyCommand.Path 
        } else { 
            [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName 
        }
    }

    $existingTask = Get-ScheduledTask -TaskName "PostInstall" -ErrorAction SilentlyContinue

    # Se for solicitado para parar, remover a tarefa
    if ($Stop) {
        $existingTask = Get-ScheduledTask -TaskName "PostInstall" -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName "PostInstall" -Confirm:$false
        }
        return
    }
    
    if ($null -eq $existingTask) {
        try {
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $principal = New-ScheduledTaskPrincipal -UserID $env:USERNAME -LogonType Interactive -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
            Register-ScheduledTask -TaskName "PostInstall" -InputObject $task | Out-Null
            return $true
        }
        catch {
            Write-InstallLog "Erro ao criar tarefa: $($_.Exception.Message)"
            return $false
        }
    } else {
        return $false
    }
}