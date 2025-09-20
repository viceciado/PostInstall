function global:Set-AvoidSleep {
    param (
        [bool]$AvoidSleep = $false,
        [bool]$Silent = $false
    )

    if (-not ([System.Management.Automation.PSTypeName]'PowerUtil').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class PowerUtil {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
}
"@
    }

    if ($AvoidSleep -eq $true) {
        $flags = [PowerUtil]::ES_CONTINUOUS -bor [PowerUtil]::ES_SYSTEM_REQUIRED -bor [PowerUtil]::ES_DISPLAY_REQUIRED
        $result = [PowerUtil]::SetThreadExecutionState($flags)
        if ($result -eq 0) {
            Write-InstallLog "Falha ao configurar para evitar o modo de suspensão. Código de erro: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" -Status "ERRO"
        }
        else {
            Write-InstallLog "O computador está configurado para não entrar em suspensão."
            if ($Silent -eq $false) {
                Show-Notification -Title "Configuração de suspensão" -Message "O computador está configurado temporariamente para não entrar em suspensão."
            }
            $global:ScriptContext.AvoidSleep = $true
        }
    }
    else {
        $result = [PowerUtil]::SetThreadExecutionState([PowerUtil]::ES_CONTINUOUS)
        if ($result -eq 0) {
            Write-InstallLog "Falha ao restaurar as configurações de suspensão. Código de erro: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" -Status "ERRO"
        }
        else {
            Write-InstallLog "As configurações de suspensão foram restauradas."
            if ($Silent -eq $false) {
                Show-Notification -Title "Configuração de suspensão" -Message "As configurações de suspensão foram restauradas ao padrão."
            }
            $global:ScriptContext.AvoidSleep = $false
        }
    }
}