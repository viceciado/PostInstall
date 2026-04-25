function Set-WindowsTheme {
    <#
    .SYNOPSIS
    Alterna entre tema claro e escuro do Windows
    
    .DESCRIPTION
    Função para alternar o tema do Windows entre claro e escuro,
    atualizando as configurações do registro e forçando refresh do sistema.
    
    .PARAMETER Theme
    Tema a ser aplicado: "Claro" ou "Escuro"
    
    .EXAMPLE
    Set-WindowsTheme -Theme "Escuro"
    
    .EXAMPLE
    Set-WindowsTheme -Theme "Claro"
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Claro", "Escuro")]
        [string]$Theme
    )
    
    $success = $true
    # Parte 1: Atualiza o tema do sistema
    $personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $appsUseLightThemeValue = if ($Theme -eq "Claro") { 1 } else { 0 }
    $systemUsesLightThemeValue = if ($Theme -eq "Claro") { 1 } else { 0 }

    try {
        Set-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme" -Value $appsUseLightThemeValue -Force
        Set-ItemProperty -Path $personalizePath -Name "SystemUsesLightTheme" -Value $systemUsesLightThemeValue -Force

        if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        IntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out IntPtr lpdwResult);
}
"@
        }

        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $SMTO_ABORTIFHUNG = 0x2
        $timeout = 100

        $null = [Win32]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [IntPtr]::Zero, "ImmersiveColorSet", $SMTO_ABORTIFHUNG, $timeout, [ref]([IntPtr]::Zero))
    }
    catch {
        Write-InstallLog "Erro em Set-WindowsTheme: $($_.Exception.Message)" -Status "ERRO"
        $success = $false
    }

    # Parte 2: Atualiza o wallpaper
    $wallpapersPath = "$env:windir\Web\Wallpaper\Windows"

    if ((Get-ChildItem -Path $wallpapersPath).Count -gt 0) {
        $wallpaperIndex = if (($global:ScriptContext.System.isWin11 -eq $true) -and ($Theme -eq "Escuro")) { 1 } else { 0 }
        $wallpaperFile = Get-ChildItem -Path $wallpapersPath | Sort-Object Name | Select-Object -Skip $wallpaperIndex -First 1
        
        if ($wallpaperFile) { $wallpaperFilePath = $wallpaperFile.FullName }
        $wallpaperFilePath = Join-Path $wallpapersPath $wallpaperFile.Name
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop\' -Name Wallpaper -Value $wallpaperFilePath

        if (-not ([System.Management.Automation.PSTypeName]'Wallpaper').Type) {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@ -Language CSharp
        }
        [void][Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperFilePath, 0x01 -bor 0x02)
    }
    return $success
}

function Get-CurrentWindowsTheme {
    <#
    .SYNOPSIS
    Obtém o tema atual do Windows
    
    .DESCRIPTION
    Verifica o registro do Windows para determinar se o tema atual é claro ou escuro.
    
    .OUTPUTS
    String - "Claro", "Escuro" ou "Unknown"
    
    .EXAMPLE
    $currentTheme = Get-CurrentWindowsTheme
    #>
    
    try {
        $CurrentTheme = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
        if ($CurrentTheme -and $CurrentTheme.AppsUseLightTheme -eq 1) {
            return "Claro"
        }
        else {
            return "Escuro"
        }
    }
    catch {
        Write-InstallLog "Erro em Get-CurrentWindowsTheme: $($_.Exception.Message)" -Status "ERRO"
        return "Unknown"
    }
}

function Update-ButtonUI {
    <#
    .SYNOPSIS
    Atualiza os botões da interface
    
    .DESCRIPTION
    Atualiza as propriedades de um determinado botão mediante parâmetros recebidos.
    
    .PARAMETER Button
    Referência ao botão que será atualizado
    
    .PARAMETER Icon
    Ícone a ser definido no botão
    
    .PARAMETER ToolTip
    Tooltip a ser definido no botão
    
    .EXAMPLE
    Update-ButtonUI -Button $applyThemeButton
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.Button]$Button,

        [Parameter(Mandatory = $false)]
        [string]$Icon,
        [string]$ToolTip,
        [string]$Foreground,
        [string]$Background
    )

    $buttonName = $Button.Name
    
    if ($buttonName -eq "ApplyThemeButton") {
        try {
            $currentTheme = Get-CurrentWindowsTheme
            
            if ($currentTheme -eq "Claro") {
                $Button.Content = $global:PSConst.Icons.Moon
                $Button.ToolTip = "Aplicar tema escuro"
            }
            else {
                $Button.Content = $global:PSConst.Icons.Sun
                $Button.ToolTip = "Aplicar tema claro"
            }
            
            return $currentTheme
        }
        catch {
            Write-InstallLog "Erro em Update-ButtonUI (tema): $($_.Exception.Message)" -Status "ERRO"
            return "Unknown"
        }
    }

    if ($buttonName -eq "AvoidSleepButton") {
        if ($global:ScriptContext.System.AvoidSleep -eq $true) {
            $Button.Content = $global:PSConst.Icons.AvoidSleepOn
            # E781 lâmpada acesa
            # EB50 lâmpada com check
            # EA80 
            # E7B3 olho com pupila
            # E052 olho padrão
            # E82F lâmpada 2 apagada

            $Button.Foreground = "Yellow"
            $Button.ToolTip = "A suspensão de energia está desativada"
            return $false
        }
        else {
            $Button.Content = $global:PSConst.Icons.AvoidSleepOff
            $Button.Foreground = "White"
            $Button.ToolTip = "Clique para manter o computador ligado"
            return $true
        }
    }
}
