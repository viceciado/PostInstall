function Get-AppInstallDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuraÃ§Ã£o do diÃ¡logo AppInstallDialog.
    #>
    return {
        param($appInstallDialogWindow)

        $programsStackPanel             = $appInstallDialogWindow.FindName("ProgramsStackPanelDialog")
        $script:customProgramIDsTextBox = $appInstallDialogWindow.FindName("CustomProgramIDsTextBox")
        $script:checkboxesCollection    = @{}

        $availablePrograms = Get-AvailableItems -ItemType "Programs"

        if ($availablePrograms.Count -gt 0) {
            foreach ($program in $availablePrograms) {
                $checkBox = New-Object System.Windows.Controls.CheckBox
                $checkBox.Content = $program.Name
                if ($program.Description) { $checkBox.ToolTip = $program.Description }
                $checkBox.Tag = $program.ProgramId
                if ($program.Recommended -eq $true) { $checkBox.IsChecked = $true }
                $programsStackPanel.Children.Add($checkBox)
                $script:checkboxesCollection[$program.ProgramId] = $checkBox
            }
        }
        else {
            Write-InstallLog "Nenhum programa encontrado no arquivo JSON" -Status "AVISO"

            $errorContainer = New-Object System.Windows.Controls.StackPanel
            $errorContainer.Orientation = "Vertical"
            $errorContainer.HorizontalAlignment = "Center"
            $errorContainer.Margin = "0,20,0,0"

            $errorIcon = New-Object System.Windows.Controls.TextBlock
            $errorIcon.Text = [char]0xE783
            $errorIcon.FontFamily = "Segoe MDL2 Assets"
            $errorIcon.FontSize = 32
            $errorIcon.Foreground = "Orange"
            $errorIcon.HorizontalAlignment = "Center"
            $errorIcon.Margin = "0,0,0,10"

            $errorLabel = New-Object System.Windows.Controls.TextBlock
            $errorLabel.Text = "Falha ao ler a lista de programas padrÃ£o`nRealize a instalaÃ§Ã£o manualmente."
            $errorLabel.Foreground = "Orange"
            $errorLabel.FontSize = 14
            $errorLabel.TextAlignment = "Center"
            $errorLabel.HorizontalAlignment = "Center"
            $errorLabel.TextWrapping = "Wrap"

            $errorContainer.Children.Add($errorIcon)
            $errorContainer.Children.Add($errorLabel)
            $programsStackPanel.Children.Add($errorContainer)
        }

        #  Instalar selecionados 
        $installSelectedButton = $appInstallDialogWindow.FindName("InstallSelectedButtonDialog")
        if ($installSelectedButton) {
            $installSelectedButton.Add_Click({
                $selectedProgramIDs = @()
                foreach ($key in $script:checkboxesCollection.Keys) {
                    $cb = $script:checkboxesCollection[$key]
                    if ($cb.IsChecked -eq $true) { $selectedProgramIDs += $cb.Tag }
                }

                $customText       = $script:customProgramIDsTextBox.Text
                $customProgramIDs = $customText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                if ($customProgramIDs) { $selectedProgramIDs += $customProgramIDs }

                $selectedProgramIDs = $selectedProgramIDs | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
                Write-InstallLog "$($selectedProgramIDs.Count) programas marcados para instalaÃ§Ã£o: $($selectedProgramIDs -join ', ')"

                # Detectar navegadores â†’ oferecer MSEdgeRedirect no Win11
                $knownBrowserIDs = $global:PSConst.KnownBrowserIDs
                $hasBrowser = $selectedProgramIDs | Where-Object { $knownBrowserIDs -contains $_ }
                if ($hasBrowser -and ($global:ScriptContext.System.isWin11 -eq $true)) {
                    $msEdge = Show-MessageDialog -Title "InstalaÃ§Ã£o de outros navegadores" -Message "VocÃª marcou a instalaÃ§Ã£o de um ou mais navegadores.`nDeseja tambÃ©m instalar o MSEdgeRedirect para substituir o navegador padrÃ£o do sistema? (recomendado)" -MessageType "Question" -Buttons "YesNo"
                    if ($msEdge -eq "Yes") {
                        Show-Notification -Title "InstalaÃ§Ã£o de programas" -Message "Configure o MSEdgeRedirect apÃ³s a instalaÃ§Ã£o."
                        $selectedProgramIDs += "rcmaehl.MSEdgeRedirect"
                    }
                }

                if ($selectedProgramIDs.Count -gt 0) {
                    Show-Notification -Title "InstalaÃ§Ã£o de programas" -Message "O processo continuarÃ¡ em uma nova janela..."
                    Invoke-ElevatedProcess -FunctionName "Initialize-And-Install-Programs" -Parameters @{ ProgramIDs = $selectedProgramIDs } -ForceAsync
                }
                else {
                    Show-MessageDialog -Title "Nenhum programa selecionado" -Message "Por favor, selecione pelo menos um programa para instalar."
                }
            })
        }

        #  Atualizar todos 
        $UpdateAllProgramsButton = $appInstallDialogWindow.FindName("UpdateAllProgramsButton")
        if ($UpdateAllProgramsButton) {
            $UpdateAllProgramsButton.Add_Click({
                Show-Notification -Title "AtualizaÃ§Ã£o Geral" -Message "O processo continuarÃ¡ em uma nova janela..."
                Invoke-ElevatedProcess -FunctionName "Initialize-And-Upgrade-All" -ForceAsync
            })
        }
    }
}

