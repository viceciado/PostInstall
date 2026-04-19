function Get-TweaksDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuração do diÃ¡logo TweaksDialog.
    #>
    return {
        param($tweaksDialogWindow)

        $FilterButtonsPanel              = $tweaksDialogWindow.FindName("FilterButtonsPanel")
        $filterButtonStyle               = $tweaksDialogWindow.Resources["FilterButtonStyle"]
        $TweaksStackPanel                = $tweaksDialogWindow.FindName("TweaksStackPanel")
        $RecommendedTweaksButton         = $tweaksDialogWindow.FindName("RecommendedTweaksButton")
        $script:RestoreDefaultsButton    = $tweaksDialogWindow.FindName("RestoreDefaultsButton")
        $script:ApplySelectedTweaksButton = $tweaksDialogWindow.FindName("ApplySelectedTweaksButton")
        $SystemPropPerfButton            = $tweaksDialogWindow.FindName("SystemPropPerfButton")
        $InstalledUpdatesButton          = $tweaksDialogWindow.FindName("InstalledUpdatesButton")
        $RarRegButton                    = $tweaksDialogWindow.FindName("RarRegButton")

        $script:originalApplyButtonBackground = if ($script:ApplySelectedTweaksButton -is [System.Windows.Controls.Button]) {
            $script:ApplySelectedTweaksButton.Background
        } else { $null }

        #  ScriptBlock de atualização do estado dos botÃµes 
        $script:updateApplyButtonState = {
            try {
                $checkedCount = ($script:checkboxesCollection.Values | Where-Object { $_.IsChecked -eq $true }).Count
                $hasAnyChecked = $checkedCount -gt 0

                if ($script:ApplySelectedTweaksButton -is [System.Windows.Controls.Button]) {
                    $script:ApplySelectedTweaksButton.IsEnabled = $hasAnyChecked
                    if ($hasAnyChecked) {
                        $script:ApplySelectedTweaksButton.Content    = "Aplicar $checkedCount tweaks"
                        $script:ApplySelectedTweaksButton.Background = $global:PSConst.Colors.Accent
                    }
                    else {
                        $script:ApplySelectedTweaksButton.Content    = "Aplicar"
                        $script:ApplySelectedTweaksButton.Background = $global:PSConst.Colors.Surface
                    }
                }

                $appliedCount = if ($global:ScriptContext.AppliedTweaks) { $global:ScriptContext.AppliedTweaks.Count } else { 0 }
                if ($appliedCount -gt 0) {
                    $script:RestoreDefaultsButton.IsEnabled  = $true
                    $script:RestoreDefaultsButton.Background = $global:PSConst.Colors.Accent
                    $script:RestoreDefaultsButton.Content    = "Desfazer $appliedCount alterações"
                }
                else {
                    $script:RestoreDefaultsButton.IsEnabled  = $false
                    $script:RestoreDefaultsButton.Background = $global:PSConst.Colors.Surface
                    $script:RestoreDefaultsButton.Content    = "Restaurar padrÃµes"
                }
            }
            catch {
                Write-InstallLog "Erro ao atualizar estado do botão Aplicar: $($_.Exception.Message)" -Status "AVISO"
            }
        }

        $script:checkboxesCollection = @{}

        #  Carregar tweaks e categorias 
        $allTweaks         = Get-AvailableItems -ItemType "Tweaks"
        $availableTweaks   = $allTweaks | Where-Object { $_.Category -notcontains "Finalize" }
        $tweaksCategories  = Get-AvailableItems -ItemType "TweaksCategories"
        if (-not $tweaksCategories) { $tweaksCategories = @() }
        $filteredCategories = $tweaksCategories | Where-Object { $_.Name -ne "Finalize" }

        #  Botão "Todos" 
        $allButton = New-Object System.Windows.Controls.Button
        $allButton.Style = $filterButtonStyle
        $allButton.FocusVisualStyle = $null
        $allButton.BorderThickness = 0
        $allButton.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $iconTextAll = New-Object System.Windows.Controls.TextBlock
        $iconTextAll.Text = [char]0xF0E2
        $iconTextAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
        $iconTextAll.FontSize = 16
        $allButton.Content = $iconTextAll
        $allButton.ToolTip = "Mostrar todos os tweaks"
        $allButton.Tag = "All"
        $FilterButtonsPanel.Children.Add($allButton)
        $allButton.Add_Click({
            $script:checkboxesCollection.Values | ForEach-Object { $_.Visibility = "Visible" }
        })

        # Separador
        $sep1 = New-Object System.Windows.Controls.Border
        $sep1.Width = 1; $sep1.Height = 20
        $sep1.Background = [System.Windows.Media.Brushes]::Gray
        $sep1.Margin = New-Object System.Windows.Thickness(5, 0, 5, 0)
        $sep1.VerticalAlignment = "Center"
        $FilterButtonsPanel.Children.Add($sep1)

        #  BotÃµes de categoria 
        foreach ($category in $filteredCategories) {
            $button = New-Object System.Windows.Controls.Button
            $button.Style = $filterButtonStyle
            $button.FocusVisualStyle = $null
            $button.BorderThickness = 0
            $button.BorderBrush = [System.Windows.Media.Brushes]::Transparent

            $iconText = New-Object System.Windows.Controls.TextBlock
            $iconValue = ""
            if (-not [string]::IsNullOrWhiteSpace($category.Icon)) {
                if ($category.Icon -match '&#x([0-9A-Fa-f]+);')  { $iconValue = [char]([Convert]::ToInt32($matches[1], 16)) }
                elseif ($category.Icon -match '&#([0-9]+);')      { $iconValue = [char]([int]$matches[1]) }
                else                                               { $iconValue = [string]$category.Icon }
            }
            $iconText.Text = $iconValue
            $iconText.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
            $iconText.FontSize = 16

            $colorBrush = [System.Windows.Media.Brushes]::White
            try {
                if (-not [string]::IsNullOrWhiteSpace($category.Color)) {
                    $bc = New-Object System.Windows.Media.BrushConverter
                    $conv = $bc.ConvertFromString($category.Color)
                    if ($conv) { $colorBrush = $conv }
                }
            } catch {}

            $button.Content    = $iconText
            $button.Background = $colorBrush
            $button.ToolTip    = "$($category.Name): $($category.Description)"
            $button.Tag        = $category.Name
            $FilterButtonsPanel.Children.Add($button)

            $button.Add_Click({
                $clickedCategory = $_.Source.Tag
                foreach ($cb in $script:checkboxesCollection.Values) {
                    $tweak = $cb.Tag
                    $cb.Visibility = if ($tweak -and $tweak.Category -contains $clickedCategory) { "Visible" } else { "Collapsed" }
                }
            })
        }

        # 2Âº separador
        $sep2 = New-Object System.Windows.Controls.Border
        $sep2.Width = 1; $sep2.Height = 20
        $sep2.Background = [System.Windows.Media.Brushes]::Gray
        $sep2.Margin = New-Object System.Windows.Thickness(5, 0, 5, 0)
        $sep2.VerticalAlignment = "Center"
        $FilterButtonsPanel.Children.Add($sep2)

        #  Botão "Marcar tudo" 
        $checkAllButton = New-Object System.Windows.Controls.Button
        $checkAllButton.Style = $filterButtonStyle
        $checkAllButton.FocusVisualStyle = $null
        $checkAllButton.BorderThickness = 0
        $checkAllButton.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $iconTextCheckAll = New-Object System.Windows.Controls.TextBlock
        $iconTextCheckAll.Text = [char]0xE9D5
        $iconTextCheckAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
        $iconTextCheckAll.FontSize = 16
        $checkAllButton.Content = $iconTextCheckAll
        $checkAllButton.ToolTip = "Marcar tudo"
        $FilterButtonsPanel.Children.Add($checkAllButton)
        $checkAllButton.Add_Click({
            $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $true }
            & $script:updateApplyButtonState
        })

        #  Botão "Limpar seleção" 
        $clearAllButton = New-Object System.Windows.Controls.Button
        $clearAllButton.Style = $filterButtonStyle
        $clearAllButton.FocusVisualStyle = $null
        $clearAllButton.BorderThickness = 0
        $clearAllButton.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $iconTextClearAll = New-Object System.Windows.Controls.TextBlock
        $iconTextClearAll.Text = [char]0xED62
        $iconTextClearAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
        $iconTextClearAll.FontSize = 16
        $clearAllButton.Content = $iconTextClearAll
        $clearAllButton.ToolTip = "Limpar seleção"
        $FilterButtonsPanel.Children.Add($clearAllButton)
        $clearAllButton.Add_Click({
            $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $false }
            & $script:updateApplyButtonState
        })

        #  Lista de checkboxes 
        if ($availableTweaks.Count -gt 0) {
            if ($global:ScriptContext.System.isWin11 -eq $false) {
                $availableTweaks = $availableTweaks | Where-Object { $_.Win11Only -eq $false }
            }
            foreach ($tweak in $availableTweaks) {
                $checkBox = New-Object System.Windows.Controls.CheckBox
                $checkBox.Content = $tweak.Name
                if ($tweak.Description) { $checkBox.ToolTip = $tweak.Description }
                $checkBox.Tag = $tweak
                $TweaksStackPanel.Children.Add($checkBox)
                $script:checkboxesCollection[$tweak.Name] = $checkBox
                $checkBox.Add_Checked(  { & $script:updateApplyButtonState })
                $checkBox.Add_Unchecked({ & $script:updateApplyButtonState })
            }
        }
        else {
            Write-InstallLog "Nenhum tweak encontrado no arquivo JSON" -Status "AVISO"
        }

        #  Restaurar padrÃµes 
        $script:RestoreDefaultsButton.Add_Click({
            try {
                if (-not $global:ScriptContext.AppliedTweaks -or $global:ScriptContext.AppliedTweaks.Count -eq 0) {
                    Show-MessageDialog -Title "Restaurar padrÃµes" -Message "Não hÃ¡ tweaks aplicados para desfazer." -MessageType "Info" -Buttons "OK"
                    return
                }
                $names = $global:ScriptContext.AppliedTweaks.Keys
                $list  = $names -join "`n"
                $confirm = Show-MessageDialog -Title "Restaurar padrÃµes" -Message "Desfazer os $($names.Count) tweaks aplicados abaixo?`n`n$list" -MessageType "Question" -Buttons "YesNo"
                if ($confirm -ne "Yes") { return }

                Invoke-TweaksManager -Names $names -Mode "Undo"
                $script:checkboxesCollection.Values | ForEach-Object {
                    if ($names -contains $_.Tag.Name) { $_.IsChecked = $false }
                }
                & $script:updateApplyButtonState
            }
            catch {
                Write-InstallLog "Erro ao desfazer tweaks: $($_.Exception.Message)" -Status "ERRO"
            }
        })

        #  Marcação de recomendados 
        $RecommendedTweaksButton.Add_Click({
            $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $false }
            $script:checkboxesCollection.Values | ForEach-Object {
                if (($_.Tag -and $_.Tag.IsRecommended -eq $true) -or
                    ($_.Tag -and $_.Tag.Category -and $_.Tag.Category -contains "Recommended")) {
                    $_.IsChecked = $true
                }
            }
            & $script:updateApplyButtonState
        })

        #  Aplicar selecionados 
        $script:ApplySelectedTweaksButton.Add_Click({
            $selectedTweaks = $script:checkboxesCollection.Values | Where-Object { $_.IsChecked -eq $true }
            $selectedCount  = $selectedTweaks.Count
            $selectedNames  = $selectedTweaks | ForEach-Object { $_.Tag.Name } | Out-String
            $applyDialog = Show-MessageDialog -Title "Aplicar Tweaks" -Message "Deseja aplicar os $selectedCount tweaks selecionados?`n`n$selectedNames" -MessageType "Question" -Buttons "YesNo"
            if ($applyDialog -eq "Yes") {
                Invoke-TweaksManager -Tweaks $selectedTweaks -Mode "Apply" -SkipPowerActions
                $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $false }
                & $script:updateApplyButtonState
            }
        })

        & $script:updateApplyButtonState

        $SystemPropPerfButton.Add_Click({ Start-Process "SystemPropertiesPerformance" })
        $InstalledUpdatesButton.Add_Click({ Start-Process "shell:AppUpdatesFolder" })

        #  Registro do WinRAR 
        if ($RarRegButton) {
            $RarRegButton.Add_Click({
                $WinrarPaths = @("$env:ProgramFiles\WinRAR", "$env:ProgramFiles(x86)\WinRAR")
                $isInstalled = $false
                foreach ($Path in $WinrarPaths) {
                    if (-not (Test-Path $Path)) { continue }
                    $isInstalled = $true
                    if (Test-Path "$Path\rarreg.key") {
                        Show-MessageDialog -Title "Ativação do WinRAR" -Message "O arquivo rarreg.key jÃ¡ existe na pasta do WinRAR."
                        return
                    }
                    $dlg = New-Object System.Windows.Forms.OpenFileDialog
                    $dlg.CheckFileExists = $true
                    $dlg.AutoUpgradeEnabled = $true
                    $dlg.Filter = "RarREG.key (*.key)|*.key"
                    $dlg.Title = "Selecione o arquivo de ativação do WinRAR"
                    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

                    $result = Invoke-ElevatedProcess -FunctionName "Copy-Item" -Parameters @{ Path = $dlg.FileName; Destination = $Path } -PassThru
                    if ($result -eq $true) {
                        Show-Notification -Title "WinRAR ativado" -Message "Arquivo rarreg.key copiado para a pasta do WinRAR."
                        Write-InstallLog "Arquivo rarreg.key copiado para $Path"
                    }
                    else {
                        Show-MessageDialog -Title "Erro" -Message "Ocorreu um erro ao copiar o arquivo." -MessageType "Error"
                        Write-InstallLog "Erro ao copiar rarreg.key para $Path" -Status "ERRO"
                    }
                }
                if (-not $isInstalled) {
                    Show-MessageDialog -Title "WinRAR não encontrado" -Message "O WinRAR não foi encontrado no sistema. Tente novamente após a instalação." -MessageType "Warning"
                }
            })
        }
    }
}

