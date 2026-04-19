function Get-AboutDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuraÃ§Ã£o do diÃ¡logo AboutDialog.
    #>
    return {
        param($aboutDialogWindow)

        $systemInfoPanel   = $aboutDialogWindow.FindName("SystemInfoPanel")
        $fallbackText      = $aboutDialogWindow.FindName("FallbackText")
        $machineSKUText    = $aboutDialogWindow.FindName("MachineSKUText")
        $manufacturerText  = $aboutDialogWindow.FindName("ManufacturerText")
        $modelText         = $aboutDialogWindow.FindName("ModelText")
        $serialText        = $aboutDialogWindow.FindName("SerialText")
        $copySerialButton  = $aboutDialogWindow.FindName("CopySerialButton")
        $processorText     = $aboutDialogWindow.FindName("ProcessorText")
        $osCaptionText     = $aboutDialogWindow.FindName("OSCaptionText")
        $osArchText        = $aboutDialogWindow.FindName("OSArchText")
        $osBuildText       = $aboutDialogWindow.FindName("OSBuildText")
        $memoryText        = $aboutDialogWindow.FindName("MemoryText")
        $bootTypeText      = $aboutDialogWindow.FindName("BootTypeText")
        $disksText         = $aboutDialogWindow.FindName("DisksText")
        $gpusText          = $aboutDialogWindow.FindName("GpusText")

        if ($global:ScriptContext.System.Info) {
            if ($fallbackText) { $fallbackText.Visibility = "Collapsed" }

            if ($machineSKUText)   { $machineSKUText.Text   = if ($global:ScriptContext.System.Info.Machine -and $global:ScriptContext.System.Info.Machine.ChassisSKUNumber) { $global:ScriptContext.System.Info.Machine.ChassisSKUNumber } else { "-" } }
            if ($manufacturerText) { $manufacturerText.Text = if ($global:ScriptContext.System.Info.Machine -and $global:ScriptContext.System.Info.Machine.Manufacturer)     { $global:ScriptContext.System.Info.Machine.Manufacturer }     else { "-" } }
            if ($modelText)        { $modelText.Text        = if ($global:ScriptContext.System.Info.Machine -and $global:ScriptContext.System.Info.Machine.Model)            { $global:ScriptContext.System.Info.Machine.Model }            else { "-" } }
            if ($serialText)       { $serialText.Text       = if ($global:ScriptContext.System.Info.SerialNumber)              { $global:ScriptContext.System.Info.SerialNumber }              else { "-" } }

            if ($copySerialButton) {
                if ($global:ScriptContext.System.Info.SerialNumber) {
                    $copySerialButton.Visibility = "Visible"
                    $copySerialButton.Add_Click({
                        [System.Windows.Clipboard]::SetText($global:ScriptContext.System.Info.SerialNumber)
                        Show-Notification -Title "NÃºmero de sÃ©rie copiado" -Message "VocÃª pode usar essa informaÃ§Ã£o para localizar os drivers da mÃ¡quina."
                    })
                }
                else {
                    $copySerialButton.Visibility = "Collapsed"
                }
            }

            if ($processorText) { $processorText.Text = if ($global:ScriptContext.System.Info.Processor -and $global:ScriptContext.System.Info.Processor.Name) { $global:ScriptContext.System.Info.Processor.Name } else { "-" } }
            if ($osCaptionText) { $osCaptionText.Text = if ($global:ScriptContext.System.Info.OS -and $global:ScriptContext.System.Info.OS.Caption)     { $global:ScriptContext.System.Info.OS.Caption }     else { "-" } }
            if ($osArchText)    { $osArchText.Text    = if ($global:ScriptContext.System.Info.OS -and $global:ScriptContext.System.Info.OS.Architecture) { $global:ScriptContext.System.Info.OS.Architecture } else { "-" } }
            if ($osBuildText)   { $osBuildText.Text   = if ($global:ScriptContext.System.Info.OS -and $global:ScriptContext.System.Info.OS.DisplayVersion) { $global:ScriptContext.System.Info.OS.DisplayVersion } else { "-" } }
            if ($memoryText)    { $memoryText.Text    = if ($global:ScriptContext.System.Info.TotalMemoryGB) { "{0} GB" -f $global:ScriptContext.System.Info.TotalMemoryGB } else { "-" } }
            if ($bootTypeText)  { $bootTypeText.Text  = if ($global:ScriptContext.System.Info.Boot -and $global:ScriptContext.System.Info.Boot.Description) { $global:ScriptContext.System.Info.Boot.Description } else { "-" } }

            if ($disksText) {
                $disksText.Text = if ($global:ScriptContext.System.Info.Disks -and $global:ScriptContext.System.Info.Disks.Count -gt 0) {
                    ($global:ScriptContext.System.Info.Disks | ForEach-Object { "Disco {0}: {1} ({2} GB)" -f $_.Index, $_.Model, $_.SizeGB }) -join "`n"
                } else { "-" }
            }

            if ($gpusText) {
                $gpusText.Text = if ($global:ScriptContext.System.Info.GPUs -and $global:ScriptContext.System.Info.GPUs.Count -gt 0) {
                    ($global:ScriptContext.System.Info.GPUs | ForEach-Object { "GPU: {0} - MemÃ³ria: {1} MB" -f $_.Name, $_.MemoryMB }) -join "`n"
                } else { "-" }
            }
        }
        else {
            if ($fallbackText) { $fallbackText.Visibility = "Visible" }
        }
    }
}

