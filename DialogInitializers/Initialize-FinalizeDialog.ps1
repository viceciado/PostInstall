function Get-FinalizeDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuração do diÃ¡logo FinalizeDialog.
    #>
    return {
        param($finalizeDialogWindow)

        $FinalizeTweaksStackPanel = $finalizeDialogWindow.FindName("FinalizeTweaksStackPanel")
        $script:checkboxesCollection = @{}

        #  Carregar tweaks da categoria "Finalize" 
        if ($FinalizeTweaksStackPanel) {
            try {
                $finalizeTweaks = Get-AvailableItems -ItemType "Tweaks" | Where-Object { $_.Category -contains "Finalize" }
                if ($finalizeTweaks.Count -gt 0) {
                    foreach ($tweak in $finalizeTweaks) {
                        try {
                            $checkBox = New-Object System.Windows.Controls.CheckBox
                            $checkBox.Content = $tweak.Name
                            if ($tweak.Description) { $checkBox.ToolTip = $tweak.Description }
                            $checkBox.Tag = $tweak
                            if ($tweak.IsRecommended -eq $true) { $checkBox.IsChecked = $true }
                            $FinalizeTweaksStackPanel.Children.Add($checkBox)
                            $script:checkboxesCollection[$tweak.Name] = $checkBox
                        }
                        catch {
                            Write-InstallLog "Erro ao criar checkbox para $($tweak.Name): $($_.Exception.Message)" -Status "ERRO"
                        }
                    }
                }
                else {
                    Show-MessageDialog -Title "Nenhum tweak disponÃ­vel" -Message "Nenhum tweak foi encontrado no arquivo AvailableTweaks.json. Por favor, verifique se o arquivo estÃ¡ corretamente configurado." -MessageType "Info" -Buttons "OK"
                }
            }
            catch {
                Write-InstallLog "Erro ao popular tweaks: $($_.Exception.Message)" -Status "ERRO"
            }
        }

        #  Campos de metadados 
        $OSNumberTextBox    = $finalizeDialogWindow.FindName("OsNumberTextBox")
        $ClientNameTextBox  = $finalizeDialogWindow.FindName("ClientNameTextBox")
        $TechnicianTextBox  = $finalizeDialogWindow.FindName("TechnicianTextBox")
        $finalizeOkButton   = $finalizeDialogWindow.FindName("FinalizeOkButton")

        if ($null -ne $global:ScriptContext.Config.OsNumber)       { $OSNumberTextBox.Text   = [string]$global:ScriptContext.Config.OsNumber }
        if ($null -ne $global:ScriptContext.Config.ClientName)     { $ClientNameTextBox.Text = [string]$global:ScriptContext.Config.ClientName }
        if ($null -ne $global:ScriptContext.Config.TechnicianName) { $TechnicianTextBox.Text = [string]$global:ScriptContext.Config.TechnicianName }

        #  Botão OK: executa finalização 
        $finalizeOkButton.Add_Click({
            param($sender, $e)
            $wnd = [System.Windows.Window]::GetWindow($sender)
            if (-not $wnd) { $wnd = $finalizeDialogWindow }

            $statusText    = $wnd.FindName("FinalizeStatusText")
            $exitRadio     = $wnd.FindName("FinalizeOptionExitRadio")
            $shutdownRadio = $wnd.FindName("FinalizeOptionShutdownRadio")
            $restartRadio  = $wnd.FindName("FinalizeOptionRestartRadio")
            $osBox         = $wnd.FindName("OsNumberTextBox")
            $clientBox     = $wnd.FindName("ClientNameTextBox")
            $techBox       = $wnd.FindName("TechnicianTextBox")

            $osValue     = if ($osBox)     { $osBox.Text }     else { "" }
            $clientValue = if ($clientBox) { $clientBox.Text } else { "" }
            $techValue   = if ($techBox)   { $techBox.Text }   else { "" }

            $global:ScriptContext.Config.OsNumber       = $osValue
            $global:ScriptContext.Config.ClientName     = $clientValue
            $global:ScriptContext.Config.TechnicianName = $techValue
            Write-InstallLog "Iniciando finalização. OS: $osValue, Cliente: $clientValue, Técnico: $techValue"

            $ownerString  = if (-not [string]::IsNullOrWhiteSpace($osValue)) { "OS ($osValue) - $clientValue" } else { $clientValue }
            $orgString    = "MasterNet InformÃ¡tica | (88) 99284-1517"

            $selectedTweaksNames = @()
            if ($script:checkboxesCollection) {
                $selectedTweaksNames = $script:checkboxesCollection.Values |
                    Where-Object { $_.IsChecked } |
                    ForEach-Object { $_.Tag.Name }
            }

            $sender.IsEnabled = $false
            if ($statusText) {
                $statusText.Visibility = "Visible"
                $statusText.Text = "Finalizando... Aguarde."
            }

            #  Mostrar SplashScreen 
            $splash = $global:ScriptContext.UI.SplashScreenWindow
            if (-not $splash -or -not $splash.IsLoaded) {
                $xamlContent = Get-XamlByWindowName -WindowName 'SplashScreen'
                if ($xamlContent) {
                    $splash = New-XamlDialog -XamlContent $xamlContent
                    $global:ScriptContext.UI.SplashScreenWindow = $splash
                    $splash.Show()
                }
            }
            else {
                $splash.Visibility = 'Visible'
                $splash.Activate()
            }

            if ($splash) {
                $splashStatus = $splash.FindName("SplashStatusText")
                if ($splashStatus) { $splashStatus.Text = "Aplicando configurações finais. Aguarde..." }
            }

            $wnd.Visibility = 'Hidden'
            if ($global:ScriptContext.UI.MainWindow) { $global:ScriptContext.UI.MainWindow.Visibility = 'Hidden' }

            $params = @{
                Owner        = $ownerString
                Organization = $orgString
                TweakNames   = $selectedTweaksNames
            }

            try {
                $proc = Invoke-ElevatedProcess -FunctionName "Invoke-FinalizeTasks" -Parameters $params -ForceAsync -WindowStyle "Hidden"

                $waitFrame = New-Object System.Windows.Threading.DispatcherFrame
                $timer = New-Object System.Windows.Threading.DispatcherTimer
                $timer.Interval = [TimeSpan]::FromMilliseconds(500)

                $timerAction = {
                    $processRunning = $false
                    try {
                        if ($proc -and -not $proc.HasExited) {
                            $processRunning = $true
                            $proc.Refresh()
                        }
                    }
                    catch { $processRunning = $false }

                    if (-not $processRunning) {
                        $timer.Stop()
                        Start-Sleep -Milliseconds 500

                        if ($waitFrame) { $waitFrame.Continue = $false }

                        if ($shutdownRadio.IsChecked) {
                            Write-InstallLog "Desligando o computador..."
                            Start-Process "shutdown.exe" -ArgumentList "/s /t 60" -NoNewWindow
                            if ($splash) { $splash.Close() }
                        }
                        elseif ($restartRadio.IsChecked) {
                            Write-InstallLog "Reiniciando o computador..."
                            Start-Process "shutdown.exe" -ArgumentList "/r /t 60" -NoNewWindow
                            if ($splash) { $splash.Close() }
                        }
                        else {
                            Write-InstallLog "Encerrando script..."
                            Set-PersistExec -Stop
                            $wnd.Close()
                            if ($splash) { $splash.Close() }
                            if ($global:ScriptContext.UI.MainWindow) { $global:ScriptContext.UI.MainWindow.Close() }
                            if ([System.Windows.Application]::Current) {
                                [System.Windows.Application]::Current.Shutdown()
                            }
                        }
                    }
                }

                $timer.Add_Tick($timerAction)
                $timer.Start()
                try { if ($waitFrame) { [System.Windows.Threading.Dispatcher]::PushFrame($waitFrame) } }
                catch {}
            }
            catch {
                Show-MessageDialog -Title "Erro" -Message "Falha ao iniciar processo de finalização: $($_.Exception.Message)" -MessageType "Error"
                $sender.IsEnabled = $true
                if ($statusText) { $statusText.Text = "Erro na finalização." }
            }
        })
    }
}

