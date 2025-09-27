function global:Invoke-XamlDialog {
    <#
    .SYNOPSIS
    Configura e exibe qualquer diálogo XAML com configuração específica
    
    .DESCRIPTION
    Função genérica para abrir diálogos XAML com configurações específicas.
    Carrega automaticamente o XAML pelo nome da janela e aplica configurações específicas.
    
    .PARAMETER WindowName
    Nome da janela XAML a ser carregada (ex: 'ActivationDialog', 'AboutDialog')
    
    .PARAMETER ConfigureDialog
    ScriptBlock que será executado para configurar eventos específicos do diálogo
    
    .PARAMETER ShowModal
    Se verdadeiro, exibe o diálogo como modal. Padrão: $true
    
    .EXAMPLE
    Invoke-XamlDialog -WindowName 'ActivationDialog'
    
    .EXAMPLE
    Invoke-XamlDialog -WindowName 'AboutDialog' -ConfigureDialog {
        param($dialog)
        $button = $dialog.FindName("OkButton")
        $button.Add_Click({ $dialog.Close() })
    }
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowName,
        
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$ConfigureDialog,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowModal = $true
    )
    
    try {
        # Carregar o conteúdo XAML pelo nome da janela
        $xamlContent = Get-XamlByWindowName -WindowName $WindowName
        if (-not $xamlContent) {
            throw "Janela '$WindowName' não encontrada. Janelas disponíveis: $(Get-AvailableWindows -join ', ')"
        }
        
        # Se não foi fornecida configuração específica, usar configuração padrão baseada no tipo de janela
        if (-not $ConfigureDialog) {
            $ConfigureDialog = Get-DefaultDialogConfiguration -WindowName $WindowName
        }
        
        # Resolver janela pai automaticamente, se disponível
        $owner = $null
        if ($global:ScriptContext.MainWindow -is [System.Windows.Window]) {
            $owner = $global:ScriptContext.MainWindow
        }
        
        # Usar a função genérica para abrir o diálogo
        Show-XamlDialog -XamlContent $xamlContent -Owner $owner -ConfigureDialog $ConfigureDialog -ShowModal $ShowModal
    }
    catch {
        Write-InstallLog "Erro ao abrir diálogo '$WindowName': $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}

function global:Get-DefaultDialogConfiguration {
    <#
    .SYNOPSIS
    Retorna a configuração padrão para diálogos conhecidos
    
    .PARAMETER WindowName
    Nome da janela para obter configuração padrão
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowName
    )
    
    switch ($WindowName) {
        'AboutDialog' {
            return {
                param($aboutDialogWindow)
                
                # Configurar informações do sistema
                $systemInfoTextBlock = $aboutDialogWindow.FindName("InfoTextBlock")
                $titleText = $aboutDialogWindow.FindName("TitleText")

                if ($titleText) {
                    $titleText.Text = "Informações sobre o sistema"
                }

                if ($systemInfoTextBlock) {
                    # Usar a variável global correta onde as informações do sistema são armazenadas
                    if ($global:ScriptContext.SystemInfo) {
                        $systemInfoTextBlock.Text = $global:ScriptContext.SystemInfo
                    }
                    else {
                        # Fallback: tentar coletar informações do sistema se não estiverem disponíveis
                        try {
                            $systemInfo = Get-SystemInfo
                            $systemInfoTextBlock.Text = $systemInfo
                        }
                        catch {
                            $systemInfoTextBlock.Text = "Erro ao carregar informações do sistema: $($_.Exception.Message)"
                        }
                    }
                }
            }
        }
        
        'TweaksDialog' {
            return {
                param($tweaksDialogWindow)
                
                $FilterButtonsPanel = $tweaksDialogWindow.FindName("FilterButtonsPanel")
                $filterButtonStyle = $tweaksDialogWindow.Resources["FilterButtonStyle"]
                $TweaksStackPanel = $tweaksDialogWindow.FindName("TweaksStackPanel")
                $RecommendedTweaksButton = $tweaksDialogWindow.FindName("RecommendedTweaksButton")
                $script:RestoreDefaultsButton = $tweaksDialogWindow.FindName("RestoreDefaultsButton")
                $script:ApplySelectedTweaksButton = $tweaksDialogWindow.FindName("ApplySelectedTweaksButton")
                $SystemPropPerfButton = $tweaksDialogWindow.FindName("SystemPropPerfButton")
                $InstalledUpdatesButton = $tweaksDialogWindow.FindName("InstalledUpdatesButton")
                $RarRegButton = $tweaksDialogWindow.FindName("RarRegButton")

                if ($script:ApplySelectedTweaksButton -and ($script:ApplySelectedTweaksButton -is [System.Windows.Controls.Button])) {
                    $script:originalApplyButtonBackground = $script:ApplySelectedTweaksButton.Background
                }
                else {
                    $script:originalApplyButtonBackground = $null
                }

                $script:updateApplyButtonState = {
                    try {
                        # Calcular quantos checkboxes estão marcados
                        $checkedCount = ($script:checkboxesCollection.Values | Where-Object { $_.IsChecked -eq $true }).Count
                        $hasAnyChecked = $checkedCount -gt 0

                        if ($script:ApplySelectedTweaksButton -and ($script:ApplySelectedTweaksButton -is [System.Windows.Controls.Button])) {
                            # Atualizar estado do botão diretamente (mesmo padrão do findOemKey)
                            $script:ApplySelectedTweaksButton.IsEnabled = $hasAnyChecked
                            
                            # Atualizar texto do botão com contador
                            if ($hasAnyChecked) {
                                $script:ApplySelectedTweaksButton.Content = "Aplicar $checkedCount tweaks"
                                $script:ApplySelectedTweaksButton.Background = "#993233"
                            }
                            else {
                                $script:ApplySelectedTweaksButton.Content = "Aplicar"
                                $script:ApplySelectedTweaksButton.Background = "#2D2D30"
                            }
                        }

                        # Habilitar/Desabilitar o botão "Restaurar padrões" com base nos tweaks aplicados
                        $appliedCount = if ($null -ne $global:ScriptContext.AppliedTweaks) { $global:ScriptContext.AppliedTweaks.Count } else { 0 }
                        if ($appliedCount -gt 0) {
                            $script:RestoreDefaultsButton.IsEnabled = $true
                            $script:RestoreDefaultsButton.Background = "#993233"
                            $script:RestoreDefaultsButton.Content = "Desfazer $($appliedCount) alterações"
                        }
                        else {
                            $script:RestoreDefaultsButton.IsEnabled = $false
                            $script:RestoreDefaultsButton.Background = "#2D2D30"
                            $script:RestoreDefaultsButton.Content = "Restaurar padrões"
                        }
                    }
                    catch {
                        Write-InstallLog "Erro ao atualizar estado do botão Aplicar: $($_.Exception.Message)" -Status "AVISO"
                    }
                }
                
                # Inicializar a coleção de checkboxes
                $script:checkboxesCollection = @{}
                
                # Carregar Tweaks e Categorias a partir do JSON (sem depender de $configData)
                $allTweaks = Get-AvailableItems -ItemType "Tweaks"
                # Filtrar tweaks para excluir aqueles que pertencem APENAS à categoria 'Finalização'
                $availableTweaks = $allTweaks | Where-Object { ($_.Category -notcontains "Finalização") }

                # Carregar categorias via Get-AvailableItems, evitando caminho direto
                $tweaksCategories = Get-AvailableItems -ItemType "TweaksCategories"
                if (-not $tweaksCategories) { $tweaksCategories = @() }
                $filteredCategories = $tweaksCategories | Where-Object { $_.Name -ne "Finalização" }
                
                # Adicionar o botão "Todos"
                $allButton = New-Object System.Windows.Controls.Button
                $allButton.Style = $filterButtonStyle
                $iconTextAll = New-Object System.Windows.Controls.TextBlock
                $iconTextAll.Text = [char]0xF0E2 # Ícone genérico para "Todos" (da fonte Segoe MDL2 Assets)
                $iconTextAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
                $iconTextAll.FontSize = 16
                $allButton.Content = $iconTextAll
                $allButton.ToolTip = "Mostrar todos os tweaks"
                $allButton.Tag = "All"
                $FilterButtonsPanel.Children.Add($allButton)
                
                # Handler do botão "Todos"
                $allButton.Add_Click({
                        $script:checkboxesCollection.Values | ForEach-Object { $_.Visibility = "Visible" }
                    })

                # Adicionar um separador visual
                $separator = New-Object System.Windows.Controls.Border
                $separator.Width = 1
                $separator.Height = 20
                $separator.Background = [System.Windows.Media.Brushes]::Gray
                $separator.Margin = New-Object System.Windows.Thickness(5, 0, 5, 0)
                $separator.VerticalAlignment = "Center"
                $FilterButtonsPanel.Children.Add($separator)

                # Adicionar os botões para cada categoria do JSON
                foreach ($category in $filteredCategories) {
                    $button = New-Object System.Windows.Controls.Button
                    $button.Style = $filterButtonStyle
        
                    # Criar o TextBlock para o ícone (conversão inline da entidade)
                    $iconText = New-Object System.Windows.Controls.TextBlock
                    $iconValue = ""
                    if (-not [string]::IsNullOrWhiteSpace($category.Icon)) {
                        if ($category.Icon -match '&#x([0-9A-Fa-f]+);') { $iconValue = [char]([Convert]::ToInt32($matches[1], 16)) }
                        elseif ($category.Icon -match '&#([0-9]+);') { $iconValue = [char]([int]$matches[1]) }
                        else { $iconValue = [string]$category.Icon }
                    }
                    $iconText.Text = $iconValue
                    $iconText.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
                    $iconText.FontSize = 16
        
                    # Aplicar a cor (conversão inline)
                    $colorBrush = [System.Windows.Media.Brushes]::White
                    try {
                        if (-not [string]::IsNullOrWhiteSpace($category.Color)) {
                            $bc = New-Object System.Windows.Media.BrushConverter
                            $conv = $bc.ConvertFromString($category.Color)
                            if ($conv) { $colorBrush = $conv }
                        }
                    }
                    catch {}
                    
                    # Definir o ícone como conteúdo do botão
                    $button.Content = $iconText
                    $button.Background = $colorBrush
                    $button.ToolTip = "$($category.Name): $($category.Description)"
                    $button.Tag = $category.Name # Usar a propriedade Tag para armazenar o nome da categoria
        
                    # Adicionar o botão ao painel
                    $FilterButtonsPanel.Children.Add($button)
        
                    # Adicionar o manipulador de evento para filtrar
                    $button.Add_Click({
                            $clickedCategory = $_.Source.Tag
                            foreach ($cb in $script:checkboxesCollection.Values) {
                                $tweak = $cb.Tag
                                if ($tweak -and $tweak.Category -contains $clickedCategory) {
                                    $cb.Visibility = "Visible"
                                }
                                else {
                                    $cb.Visibility = "Collapsed"
                                }
                            }
                        })
                }

                # Adicionar um segundo separador visual
                $separator2 = New-Object System.Windows.Controls.Border
                $separator2.Width = 1
                $separator2.Height = 20
                $separator2.Background = [System.Windows.Media.Brushes]::Gray
                $separator2.Margin = New-Object System.Windows.Thickness(5, 0, 5, 0)
                $separator2.VerticalAlignment = "Center"
                $FilterButtonsPanel.Children.Add($separator2)

                # Adicionar o botão "Marcar tudo"
                $checkAllButton = New-Object System.Windows.Controls.Button
                $checkAllButton.Style = $filterButtonStyle
                $iconTextCheckAll = New-Object System.Windows.Controls.TextBlock
                $iconTextCheckAll.Text = [char]0xE9D5
                $iconTextCheckAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
                $iconTextCheckAll.FontSize = 16
                $checkAllButton.Content = $iconTextCheckAll
                $checkAllButton.ToolTip = "Marcar tudo"
                $checkAllButton.Tag = "CheckAll"
                $FilterButtonsPanel.Children.Add($checkAllButton)
                
                # Handler do botão "Marcar tudo"
                $checkAllButton.Add_Click({
                        $script:checkboxesCollection.Values | ForEach-Object {
                            $_.IsChecked = $true
                        }
                        & $script:updateApplyButtonState
                    })

                # Adicionar o botão "Limpar tudo"
                $clearAllButton = New-Object System.Windows.Controls.Button
                $clearAllButton.Style = $filterButtonStyle
                $iconTextClearAll = New-Object System.Windows.Controls.TextBlock
                $iconTextClearAll.Text = [char]0xED62
                $iconTextClearAll.FontFamily = [System.Windows.Media.FontFamily]("Segoe MDL2 Assets")
                $iconTextClearAll.FontSize = 16
                $clearAllButton.Content = $iconTextClearAll
                $clearAllButton.ToolTip = "Limpar seleção"
                $clearAllButton.Tag = "ClearAll"
                $FilterButtonsPanel.Children.Add($clearAllButton)
                
                # Handler do botão "Limpar tudo"
                $clearAllButton.Add_Click({
                        $script:checkboxesCollection.Values | ForEach-Object {
                            $_.IsChecked = $false
                        }
                        & $script:updateApplyButtonState
                    })

                if ($availableTweaks.Count -gt 0) {
                    if ($global:ScriptContext.isWin11 -eq $false) {
                        $availableTweaks = $availableTweaks | Where-Object { $_.Win11Only -eq $false }
                    }
                    foreach ($tweak in $availableTweaks) {
                        $checkBox = New-Object System.Windows.Controls.CheckBox
                        $checkBox.Content = "$($tweak.Name)"
                        if ($tweak.Description) {
                            $checkBox.ToolTip = "$($tweak.Description)"
                        }
                        $checkBox.Tag = $tweak
                                      
                        $TweaksStackPanel.Children.Add($checkBox)
                        $script:checkboxesCollection[$tweak.Name] = $checkBox

                        # Atualizar estado do botão Aplicar quando o usuário marcar/desmarcar
                        $checkBox.Add_Checked({ & $script:updateApplyButtonState })
                        $checkBox.Add_Unchecked({ & $script:updateApplyButtonState })
                    }
                }
                else {
                    # Nenhum tweak encontrado
                    Write-InstallLog "Nenhum tweak encontrado no arquivo JSON" -Status "AVISO"
                }

                $script:RestoreDefaultsButton.Add_Click({
                        try {
                            if ($null -eq $global:ScriptContext.AppliedTweaks -or $global:ScriptContext.AppliedTweaks.Count -eq 0) {
                                Show-MessageDialog -Title "Restaurar padrões" -Message "Não há tweaks aplicados para desfazer." -MessageType "Info" -Buttons "OK"
                                return
                            }
                            $names = $global:ScriptContext.AppliedTweaks.Keys
                            $list = ($names -join "`n")
                            $confirm = Show-MessageDialog -Title "Restaurar padrões" -Message "Desfazer os $($names.Count) tweaks aplicados abaixo?`n`n$list" -MessageType "Question" -Buttons "YesNo"
                            if ($confirm -ne "Yes") { return }

                            Invoke-TweaksManager -Names $names -Mode "Undo"

                            # Desmarcar itens correspondentes
                            $script:checkboxesCollection.Values | ForEach-Object { if ($names -contains $_.Tag.Name) { $_.IsChecked = $false } }
                            & $script:updateApplyButtonState
                        }
                        catch {
                            Write-InstallLog "Erro ao desfazer tweaks: $($_.Exception.Message)" -Status "ERRO"
                        }
                    })
                $RecommendedTweaksButton.Add_Click({

                        $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $false }
                        $recommendedCount = 0
                        $markedCount = 0
                        
                        $script:checkboxesCollection.Values | ForEach-Object {
                            $isRecommended = ($_.Tag -and $_.Tag.IsRecommended -eq $true) -or 
                            ($_.Tag -and $_.Tag.Category -and $_.Tag.Category -contains "Recomendados")
                            
                            if ($isRecommended) {
                                $recommendedCount++
                                $_.IsChecked = $true
                                $markedCount++
                            }
                        }
                        & $script:updateApplyButtonState
                    })

                $script:ApplySelectedTweaksButton.Add_Click({
                        $selectedTweaks = $script:checkboxesCollection.Values | Where-Object { $_.IsChecked -eq $true }
                        $selectedCount = $selectedTweaks.Count
                        $selectedNames = $selectedTweaks | ForEach-Object { $_.Tag.Name } | Out-String
                        
                        $applyDialog = Show-MessageDialog -Title "Aplicar Tweaks" -Message "Deseja aplicar os $selectedCount tweaks selecionados?`n`n$selectedNames" -MessageType "Question" -Buttons "YesNo"
                        if ($applyDialog -eq "Yes") {
                            Invoke-TweaksManager -Tweaks $selectedTweaks -Mode "Apply" -SkipPowerActions
                            $script:checkboxesCollection.Values | ForEach-Object { $_.IsChecked = $false }
                            & $script:updateApplyButtonState
                        }
                    })

                # Estado inicial do botão Aplicar
                & $script:updateApplyButtonState
                $SystemPropPerfButton.Add_Click({
                        Start-Process "SystemPropertiesPerformance"
                    })

                $InstalledUpdatesButton.Add_Click({
                        Start-Process "shell:AppUpdatesFolder"
                    })

                $RarRegButton.Add_Click({
                        $WinrarInstallLocations = @("$env:ProgramFiles\WinRAR", "$env:ProgramFiles(x86)\WinRAR")
                        $isWinRarInstalled = $false

                        foreach ($Path in $WinrarInstallLocations) {
                            if (Test-Path -Path $Path) {
                                if (Test-Path -Path "$Path\rarreg.key") {
                                    Show-MessageDialog -Title "Ativação do WinRAR" -Message "O arquivo rarreg.key já existe na pasta do WinRAR."
                                    return
                                }
                                else {
                                    $RarRegKeyDialog = New-Object System.Windows.Forms.OpenFileDialog
                                    $RarRegKeyDialog.CheckFileExists = $true
                                    $RarRegKeyDialog.AutoUpgradeEnabled = $true
                                    $RarRegKeyDialog.Filter = "RarREG.key (*.key)|*.key"
                                    $RarRegKeyDialog.Title = "Selecione o arquivo de ativação do WinRAR"
                                    if ($RarRegKeyDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                                        $RarRegKeyFilePath = $RarRegKeyDialog.FileName
                                
                                    }
                                    else { return }
    
                                    $Parameters = @{
                                        Path        = $RarRegKeyFilePath
                                        Destination = $Path
                                    }
    
                                    $RarRegKeyCopyResult = Invoke-ElevatedProcess -FunctionName "Copy-Item" -Parameters $Parameters -PassThru
                                    if ($RarRegKeyCopyResult -eq $sucess) {
                                        Show-Notification -Title "WinRAR ativado" -Message "Arquivo rarreg.key copiado para a pasta do WinRAR."
                                        Write-InstallLog "Arquivo rarreg.key copiado para a pasta do WinRAR"
                                    }
                                    else {
                                        Show-MessageDialog -Title "Erro" -Message "Ocorreu um erro ao copiar o arquivo." -MessageType "Error"
                                        Write-InstallLog "Erro ao copiar arquivo rarreg.key para a pasta do WinRAR" -Status "ERRO"
                                    }
    
                                    $isWinRarInstalled = $true
                                }

                            }
                        }

                        # Verifica a flag após o loop
                        if (-not $isWinRarInstalled) {
                            Show-MessageDialog -Title "WinRAR não encontrado" -Message "O WinRAR não foi encontrado no sistema. Tente novamente após a instalação" -MessageType Warning
                        }
                    })
            }
        }

        'AppInstallDialog' {
            return {
                param($appInstallDialogWindow)
                
                # Popular a lista de programas do JSON
                $programsStackPanel = $appInstallDialogWindow.FindName("ProgramsStackPanelDialog")
                $script:customProgramIDsTextBox = $appInstallDialogWindow.FindName("CustomProgramIDsTextBox")
                
                # Declarar checkboxesCollection em escopo mais amplo
                $script:checkboxesCollection = @{}
                

                # Carregar programas do JSON
                $availablePrograms = Get-AvailableItems -ItemType "Programs"
                
                if ($availablePrograms.Count -gt 0) {
                    
                    # Criar checkboxes para cada programa
                    foreach ($program in $availablePrograms) {
                        $checkBox = New-Object System.Windows.Controls.CheckBox
                        $checkBox.Content = "$($program.Name)"
                        if ($program.Description) {
                            $checkBox.ToolTip = "$($program.Description)"
                        }
                        $checkBox.Tag = $program.ProgramId
                        
                        # Pré-selecionar programas recomendados
                        if ($program.Recommended -eq $true) {
                            $checkBox.IsChecked = $true
                        }
                        
                        $programsStackPanel.Children.Add($checkBox)
                        $script:checkboxesCollection[$program.ProgramId] = $checkBox
                    }
                }
                else {
                    Write-InstallLog "Nenhum programa encontrado no arquivo JSON" -Status "AVISO"
                    # Criar StackPanel para organizar ícone e mensagem
                    $errorContainer = New-Object System.Windows.Controls.StackPanel
                    $errorContainer.Orientation = "Vertical"
                    $errorContainer.HorizontalAlignment = "Center"
                    $errorContainer.Margin = "0,20,0,0"
                    
                    # Ícone de erro
                    $errorIcon = New-Object System.Windows.Controls.TextBlock
                    $errorIcon.Text = [char]0xE783  # Ícone de erro do Segoe MDL2 Assets
                    $errorIcon.FontFamily = "Segoe MDL2 Assets"
                    $errorIcon.FontSize = 32
                    $errorIcon.Foreground = "Orange"
                    $errorIcon.HorizontalAlignment = "Center"
                    $errorIcon.Margin = "0,0,0,10"
                    
                    # Mensagem explicativa
                    $errorLabel = New-Object System.Windows.Controls.TextBlock
                    $errorLabel.Text = "Falha ao ler a lista de programas padrão`nRealize a instalação manualmente."
                    $errorLabel.Foreground = "Orange"
                    $errorLabel.FontSize = 14
                    $errorLabel.TextAlignment = "Center"
                    $errorLabel.HorizontalAlignment = "Center"
                    $errorLabel.TextWrapping = "Wrap"
                    
                    # Adicionar elementos ao container
                    $errorContainer.Children.Add($errorIcon)
                    $errorContainer.Children.Add($errorLabel)
                    $programsStackPanel.Children.Add($errorContainer)
                }
                
                # Botão Instalar Selecionados
                $installSelectedButton = $appInstallDialogWindow.FindName("InstallSelectedButtonDialog")
                if ($installSelectedButton) {
                    $installSelectedButton.Add_Click({
                            $selectedProgramIDs = @()
     
                            # Captura as checkboxes marcadas
                            foreach ($programIDKey in $script:checkboxesCollection.Keys) {
                                $checkbox = $script:checkboxesCollection[$programIDKey]
                                if ($checkbox.IsChecked -eq $true) {
                                    $selectedProgramIDs += $checkbox.Tag
                                }
                            }

                            # Captura IDs de programas personalizados
                            $customText = $script:customProgramIDsTextBox.Text
                            $customProgramIDs = $customText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                            if ($customProgramIDs) {
                                $selectedProgramIDs += $customProgramIDs
                            }
                            
                            # Remove duplicatas e strings vazias
                            $selectedProgramIDs = $selectedProgramIDs | Where-Object { $_ -ne "" } | Sort-Object | Get-Unique
                            Write-InstallLog "$($selectedProgramIDs.Count) programas marcados para instalação: $($selectedProgramIDs -join ', ')"

                            $knownBrowserIDs = @("Google.Chrome", "Mozilla.Firefox", "Microsoft.Edge", "Opera.Opera")
                            $hasBrowser = $false
                            foreach ($programID in $selectedProgramIDs) {
                                if ($knownBrowserIDs -contains $programID) {
                                    $hasBrowser = $true
                                    break
                                }
                            }
                            if ($hasBrowser -and ($global:ScriptContext.isWin11 -eq $true)) {
                                $MSEdgeRedirInstall = Show-MessageDialog -Title "Instalação de outros navegadores" -Message "Você marcou a instalação de um ou mais navegadores.`nDeseja também instalar o MSEdgeRedirect para substituir o navegador padrão do sistema? (recomendado)" -MessageType "Question" -Buttons "YesNo"
                                if ($MSEdgeRedirInstall -eq "Yes") {
                                    Show-Notification -Title "Instalação de programas" -Message "Configure o MSEdgeRedirect após a instalação."
                                    $selectedProgramIDs += "rcmaehl.MSEdgeRedirect"
                                }
                            }
                            
                            if ($selectedProgramIDs.Count -gt 0) {
                                $params = @{ ProgramIDs = $selectedProgramIDs }
                                Show-Notification -Title "Instalação de programas" -Message "$($selectedProgramIDs.Count) programas escolhidos para instalação. Você pode continuar usando o script enquanto isso."
                                Invoke-ElevatedProcess -FunctionName "Install-Programs" -Parameters $params -ForceAsync
                            }
                            else {
                                Show-MessageDialog -Title "Nenhum programa selecionado" -Message "Por favor, selecione pelo menos um programa para instalar."
                            }
                        })
                }

                # Botão atualizar tudo usando Winget
                $UpdateAllProgramsButton = $appInstallDialogWindow.FindName("UpdateAllProgramsButton")
                if ($UpdateAllProgramsButton) {
                    $UpdateAllProgramsButton.Add_Click({
                            $isWingetAvailable = Test-WinGet -winget
                            if ($isWingetAvailable -eq "not-installed") {
                                $noWingetInstalled = Show-MessageDialog -Title "Winget não encontrado" -Message "O Winget não foi encontrado no sistema. Deseja instalá-lo agora? Após a instalação, será necessário tentar a atualização novamente." -MessageType "Question" -Buttons "YesNo"
                                if ($noWingetInstalled -eq "Yes") {
                                    Invoke-ElevatedProcess -FunctionName "Install-WingetWrapper" -ForceAsync
                                    Show-Notification -Title "Winget" -Message "Instalação do Winget iniciada. Tente atualizar os programas novamente após alguns minutos."
                                }
                            }
                            else {
                                Invoke-ElevatedProcess -FunctionName "Update-AllPrograms" -ForceAsync
                            }
                        })
                }
            }
        }
        
        'ActivationDialog' {
            return {
                param($activationDialogWindow)
            
                # Obter referências aos controles do diálogo de ativação
                $oemKeyTextBox = $activationDialogWindow.FindName("OemKeyTextBox")
                $copyOemKeyButton = $activationDialogWindow.FindName("CopyOemKeyButton")
                $findOemKeyButton = $activationDialogWindow.FindName("FindOemKeyButton")
                $activateOemButton = $activationDialogWindow.FindName("ActivateOemButton")
                $activateWindowsMasButton = $activationDialogWindow.FindName("ActivateWindowsMasButton")

                # Verificar se já existe uma chave OEM global e configurar interface
                if (-not [String]::IsNullOrWhiteSpace($global:OemKey)) {
                    $oemKeyTextBox.Text = $global:OemKey
                    $oemKeyTextBox.FontFamily = "Cascadia Mono"
                    $copyOemKeyButton.Visibility = "Visible"
                    $findOemKeyButton.IsEnabled = $false
                    $findOemKeyButton.Background = "#555555"
                    $activateOemButton.Background = "#4CAF50"
                    $activateOemButton.IsEnabled = $true
                }
            
                # Lógica para o botão "Localizar Chave OEM"
                $findOemKeyButton.Add_Click({
                        $productKey = $null
                        try {                    
                            $productKey = (Get-WmiObject -query 'select OA3xOriginalProductKey from SoftwareLicensingService').OA3xOriginalProductKey
                            
                            # Obter referências dos controles no escopo correto
                            $textBox = $dialog.FindName("OemKeyTextBox")
                            $findBtn = $dialog.FindName("FindOemKeyButton")
                            $activateBtn = $dialog.FindName("ActivateOemButton")
                            $copyBtn = $dialog.FindName("CopyOemKeyButton")
                            
                            if (-not [string]::IsNullOrWhiteSpace($productKey)) {
                                $textBox.FontFamily = "Cascadia Mono"
                                $textBox.Text = $productKey
                                $global:OemKey = $productKey
                                Write-InstallLog "Chave OEM encontrada: $productKey"
                                Write-InstallLog "Clique em Ativar para usar a chave encontrada"
                                Show-Notification -Title "Chave OEM encontrada`n$productKey" -Message "Clique em Ativar para usar a chave encontrada."
                                
                                # Atualizar interface
                                $activateBtn.Background = "#4CAF50" # Verde
                                $activateBtn.IsEnabled = $true
                                $copyBtn.Visibility = "Visible"
                            }
                            else {
                                $textBox.Text = "Chave OEM não encontrada. Use o ativador MAS"
                                Write-InstallLog "Nenhuma chave OEM encontrada no BIOS"
                                $activateBtn.IsEnabled = $false
                            }
                            $findBtn.IsEnabled = $false
                            $findBtn.Background = "#555555"
                        }
                        catch {
                            $errorMsg = "Falha ao buscar chave OEM: $($_.Exception.Message)"
                            $textBox = $dialog.FindName("OemKeyTextBox")
                            if ($textBox) {
                                $textBox.Text = "Erro ao buscar chave OEM"
                            }
                            Write-InstallLog  $errorMsg -Status "ERRO"
                            $activateBtn = $dialog.FindName("ActivateOemButton")
                            if ($activateBtn) {
                                $activateBtn.IsEnabled = $false
                            }
                        }
                    })

                # Lógica para o botão de copiar chave OEM
                $copyOemKeyButton.Add_Click({
                        try {
                            $textBox = $dialog.FindName("OemKeyTextBox")
                            if ($textBox) {
                                $textToCopy = $textBox.Text
                                if (-not [string]::IsNullOrWhiteSpace($textToCopy) -and $textToCopy -ne "Clique no botão abaixo para buscar pela chave OEM") {
                                    Set-Clipboard -Value $textToCopy
                                    Write-InstallLog "Chave OEM copiada para a área de transferência"
                                }
                                else {
                                    Write-InstallLog "Nenhuma chave OEM válida para copiar" -Status "AVISO"
                                }
                            }
                        }
                        catch {
                            Write-InstallLog "Erro ao copiar chave OEM: $($_.Exception.Message)" -Status "ERRO"
                        }
                    })

                # Lógica para o botão "Ativar com OEM"
                $activateOemButton.Add_Click({
                        $thisButton = $dialog.FindName("ActivateOemButton")
                        $textBox = $dialog.FindName("OemKeyTextBox")
                        $thisButton.IsEnabled = $false

                        $productKey = $textBox.Text
                        # Verifica se a chave no campo de texto é válida para tentar a ativação
                        if ($productKey -eq "Clique no botão abaixo para buscar pela chave OEM" -or $productKey -eq "Não encontrada" -or $productKey -eq "Erro ao buscar" -or [string]::IsNullOrWhiteSpace($productKey)) {
                            Write-InstallLog "Nenhuma chave OEM válida para ativar encontrada ou inserida"
                            return
                        }

                        try {
                            Write-InstallLog "Tentando ativar o sistema usando a chave OEM encontrada..."
                            $SLSvc = Get-WmiObject -Class SoftwareLicensingService -ErrorAction Stop
                            $null = $SLSvc.InstallProductKey($productKey)
                            $null = $SLSvc.RefreshLicenseStatus()
                            Start-Sleep -Seconds 3
                            $licenseInfo = Get-CimInstance -Query 'SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID = "55c92734-d682-4d71-983e-d6ec3f16059f" AND PartialProductKey IS NOT NULL' | Select-Object -First 1

                            # LicenseStatus 1 indica que o produto está licenciado (ativado)
                            if ($licenseInfo -and $licenseInfo.LicenseStatus -eq 1) {
                                Write-InstallLog "Ativação bem sucedida" -Status "SUCESSO"
                                $thisButton.IsEnabled = $false
                                $thisButton.Content = "Windows ativado!"
                                $thisButton.Background = "#555555"
                            }
                            else {
                                # Falha na ativação (LicenseStatus não é 1 após tentar instalar a chave)
                                $currentStatus = if ($licenseInfo) { $licenseInfo.LicenseStatus } else { "Não determinado" }
                                $productKey | Set-Clipboard
                                $UpdateActivationMsg = "Falha ao ativar o Windows usando a chave OEM. Status atual da licença: $currentStatus. A chave foi copiada para a área de transferência. Tente ativar manualmente."
                                Write-InstallLog  $UpdateActivationMsg -Status "ERRO"
                                $thisButton.IsEnabled = $false
                                $thisButton.Content = "Erro!"
                                $thisButton.Background = "#CC6666" # Cor vermelha para erro
                                Show-MessageDialog -Message $UpdateActivationMsg -Title "Ativação do sistema" -MessageType "Error" -Buttons "OK"
                            }
                        }
                        catch {
                            $errorMessage = $_.Exception.Message
                            if ($_.Exception.InnerException) {
                                $errorMessage += " Detalhes: $($_.Exception.InnerException.Message)"
                            }
                            Write-InstallLog "Erro durante a ativação OEM: $errorMessage" -Status "ERRO"
                            $thisButton.IsEnabled = $false
                            $thisButton.Content = "Erro!"
                            $thisButton.Background = "#CC6666" # Cor vermelha para erro
                            Show-MessageDialog -Message "Erro durante a ativação OEM: $errorMessage" -Title "Ativação do sistema" -MessageType "Error" -Buttons "OK"
                        }
                    })
            
                # Lógica para o botão "Abrir ativador MAS"
                $activateWindowsMasButton.Add_Click({
                        Write-InstallLog "Abrindo ativador MAS..."
                        try {
                            Show-Notification -Title "Abrindo ativador MAS" -Message "Aguarde enquanto o script é baixado."
                            $jobNameMAS = "MAS_Activation_Job"

                            # Remove qualquer job anterior com o mesmo nome para evitar conflitos
                            Get-Job -Name $jobNameMAS -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

                            $scriptBlockMAS = {
                                try {
                                    Invoke-Expression (Invoke-RestMethod -Uri https://get.activated.win)
                                }
                                catch {
                                    $errorMessage = "Erro dentro do job MAS ao executar o ativador: $($_.Exception.Message)"
                                    Write-InstallLog  $errorMessage -Status "ERRO"
                                }
                            }

                            # Inicia o job em segundo plano.
                            Start-Job -Name $jobNameMAS -ScriptBlock $scriptBlockMAS | Out-Null
                        }
                        catch {
                            # Captura erros ao iniciar o Job ou configurar o ambiente
                            $errorMessage = "Erro ao tentar iniciar o ativador MAS: $($_.Exception.Message)"
                            Write-InstallLog  $errorMessage -Status "ERRO"
                            Show-MessageDialog -Message "$errorMessage.`nVerifique a conexão com a internet." -Title "Ativação do Sistema" -MessageType "Error" -Buttons "OK"
                        }
                    })
            }
        }
        'LogViewer' {
            return {
                param($logViewerWindow)
                
                $unifiedLogTextBox = $logViewerWindow.FindName("UnifiedLogTextBox")
                
                try {
                    $logContent = New-Object System.Collections.Generic.List[string]
                    
                    $primaryLogPath = "$env:SystemRoot\Setup\Scripts\Install.log"
                    $currentLogPath_Value = if ($global:LogPath) { $global:LogPath } else { "$env:APPDATA\Install.log" }
                    
                    if (Test-Path $primaryLogPath) {
                        $logContent.Add("Início do log principal [$primaryLogPath]")
                        $primaryLogLines = Get-Content -Path $primaryLogPath -ErrorAction SilentlyContinue
                        if ($primaryLogLines) {
                            $logContent.AddRange([string[]]$primaryLogLines)
                        }
                        else {
                            $logContent.Add("O arquivo de log está vazio!")
                        }
                        $logContent.Add("Fim do log principal")
                        $logContent.Add("")
                    }
                    
                    if ((Test-Path $currentLogPath_Value) -and ($currentLogPath_Value -ne $primaryLogPath)) {
                        $logContent.Add("Início do log da sessão [$currentLogPath_Value]")
                        $currentLogLines = Get-Content -Path $currentLogPath_Value -ErrorAction SilentlyContinue
                        if ($currentLogLines) {
                            $logContent.AddRange([string[]]$currentLogLines)
                        }
                        else {
                            $logContent.Add("O arquivo de log está vazio!")
                        }
                        $logContent.Add("Fim do log da sessão")
                    }
                    
                    $unifiedLogTextBox.Text = $logContent -join "`n"
                    $unifiedLogTextBox.ScrollToEnd()
                }
                catch {
                    $errorMessage = "Erro crítico ao carregar logs: $($_.Exception.Message)"
                    $unifiedLogTextBox.Text = $errorMessage
                    Write-InstallLog  $errorMessage -Status "ERRO"
                }
            }
        }

        'FinalizeDialog' {
            return {
                param($finalizeDialogWindow)

                $FinalizeTweaksStackPanel = $finalizeDialogWindow.FindName("FinalizeTweaksStackPanel")

                # Inicializar a coleção de checkboxes
                $script:checkboxesCollection = @{}
                
                if ($FinalizeTweaksStackPanel) {
                    try {
                        $finalizeTweaks = Get-AvailableItems -ItemType "Tweaks" | Where-Object { $_.Category -contains "Finalização" }
                        if ($finalizeTweaks.Count -gt 0) {
                            
                            # Criar checkboxes para cada tweak
                            foreach ($tweak in $finalizeTweaks) {
                                try {
                                    $checkBox = New-Object System.Windows.Controls.CheckBox
                                    $checkBox.Content = $($tweak.Name)
                                    $checkBox.Tag = $tweak

                                    if ($tweak.Description) {
                                        $checkBox.ToolTip = "$(($tweak.Description))"
                                    }
                                    
                                    # Pré-selecionar tweaks recomendados
                                    if ($tweak.IsRecommended -eq $true) {
                                        $checkBox.IsChecked = $true
                                    }
                                    
                                    $FinalizeTweaksStackPanel.Children.Add($checkBox)
                                    $script:checkboxesCollection[$tweak.Name] = $checkBox
                                }
                                catch {
                                    Write-InstallLog "Erro ao criar checkbox para $($tweak.Name): $($_.Exception.Message)" -Status "ERRO"
                                }
                            }
                        }
                        else {
                            Show-MessageDialog -Title "Nenhum tweak disponível" -Message "Nenhum tweak foi encontrado no arquivo AvailableTweaks.json. Por favor, verifique se o arquivo está corretamente configurado." -MessageType "Info" -Buttons "OK"
                        }
                    }
                    catch {
                        Write-InstallLog "Erro ao popular tweaks: $($_.Exception.Message)" -Status "ERRO"
                    } 
                }
                
                
                $OSNumberTextBox = $finalizeDialogWindow.FindName("OsNumberTextBox")
                $ClientNameTextBox = $finalizeDialogWindow.FindName("ClientNameTextBox")
                $TechnicianTextBox = $finalizeDialogWindow.FindName("TechnicianTextBox")
                $finalizeOkButton = $finalizeDialogWindow.FindName("FinalizeOkButton")

                # Pré-popular os campos a partir do ScriptContext
                if ($null -ne $global:ScriptContext.OsNumber) { $OSNumberTextBox.Text = [string]$global:ScriptContext.OsNumber }
                if ($null -ne $global:ScriptContext.ClientName) { $ClientNameTextBox.Text = [string]$global:ScriptContext.ClientName }
                if ($null -ne $global:ScriptContext.TechnicianName) { $TechnicianTextBox.Text = [string]$global:ScriptContext.TechnicianName }

                $finalizeOkButton.Add_Click({
                        param($sender, $e)
                        # Aplicar tweaks de finalização selecionados (se houver)
                        if ($script:checkboxesCollection -and $script:checkboxesCollection.Count -gt 0) {
                                $finalizeSelected = $script:checkboxesCollection.Values | Where-Object { $_.IsChecked -eq $true }
                                if ($finalizeSelected.Count -gt 0) {
                                    $namesPreview = ($finalizeSelected | ForEach-Object { $_.Tag.Name }) -join "`n"
                                    $confirmFinalize = Show-MessageDialog -Title "Finalização" -Message "Executar ações selecionadas e encerrar?`n`n$namesPreview" -MessageType "Question" -Buttons "YesNo"
                                    if ($confirmFinalize -eq "Yes") {
                                        # Log detalhado dos tweaks selecionados
                                        $selectedNames = ($finalizeSelected | ForEach-Object { $_.Tag.Name }) -join ", "
                                        Write-InstallLog "Aplicando $($finalizeSelected.Count) tweaks de finalização: $selectedNames"
                                        Show-Notification -Title "Finalizando instalação" -Message "Aplicando configurações finais. Aguarde."
                                        Invoke-TweaksManager -Tweaks $finalizeSelected -Mode "Apply"
                                    }
                                    else {
                                        return
                                    }
                                }
                            }

                        # Reobter janela e controles para evitar problemas de captura de variáveis
                        $wnd = [System.Windows.Window]::GetWindow($sender)
                        if (-not $wnd) { $wnd = $finalizeDialogWindow }

                        $osBox = if ($wnd) { $wnd.FindName("OsNumberTextBox") } else { $null }
                        if (-not $osBox) { $osBox = $OSNumberTextBox }
                        $clientBox = if ($wnd) { $wnd.FindName("ClientNameTextBox") } else { $null }
                        if (-not $clientBox) { $clientBox = $ClientNameTextBox }
                        $techBox = if ($wnd) { $wnd.FindName("TechnicianTextBox") } else { $null }
                        if (-not $techBox) { $techBox = $TechnicianTextBox }

                        # Capturar valores dos campos com segurança
                        $osValue = if ($osBox) { $osBox.Text } else { $null }
                        $clientValue = if ($clientBox) { $clientBox.Text } else { $null }
                        $technicianValue = if ($techBox) { $techBox.Text } else { $null }

                        $global:ScriptContext.OsNumber = $osValue
                        $global:ScriptContext.ClientName = $clientValue
                        $global:ScriptContext.TechnicianName = $technicianValue

                        $registeredOrganization = "MasterNet Informática | (88) 99284-1517"

                        $logEntry = "$($global:ScriptContext.OsNumber), Cliente: $($global:ScriptContext.ClientName), Técnico responsável: $($global:ScriptContext.TechnicianName)"
                        $placeholder = "Informações não fornecidas"

                        $allEmpty = ([string]::IsNullOrWhiteSpace($global:ScriptContext.OsNumber) -and 
                            [string]::IsNullOrWhiteSpace($global:ScriptContext.ClientName) -and 
                            [string]::IsNullOrWhiteSpace($global:ScriptContext.TechnicianName))

                        if ($allEmpty) {
                            Write-InstallLog $placeholder
                        }
                        else {
                            $logContent = Get-Content -Path $global:LogPath -Raw -ErrorAction SilentlyContinue
                            if ($logContent -match [regex]::Escape($placeholder)) {
                                $newLogContent = $logContent -replace [regex]::Escape($placeholder), $logEntry
                                $newLogContent | Tee-Object -FilePath $global:LogPath
                                Write-InstallLog "Informações adicionadas ao log"
                                Write-InstallLog  $logEntry
                            }
                            else {
                                Write-InstallLog "O log não possuía o placeholder específico para as informações da OS. Registrando abaixo"
                                Write-InstallLog $logEntry
                            }

                            try {
                                $ownerString = "OS ($($global:ScriptContext.OsNumber)) - $($global:ScriptContext.ClientName)"

                                $params = @{
                                    Path        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
                                    Name        = "RegisteredOwner"
                                    Value       = $ownerString
                                    ErrorAction = "Stop"
                                }
                                $null = Invoke-ElevatedProcess -FunctionName "Set-ItemProperty" -Parameters $params -PassThru
                            }
                            catch {
                                Show-MessageDialog -Title "Informações do serviço" -Message "Erro ao salvar as informações do serviço no registro" -MessageType "Error"
                            }
                        }

                        # Sempre aplicar RegisteredOrganization, independentemente de campos vazios
                        try {
                            $OrgParams = @{
                                Path        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
                                Name        = "RegisteredOrganization"
                                Value       = $registeredOrganization
                                ErrorAction = "Stop"
                            }
                            $null = Invoke-ElevatedProcess -FunctionName "Set-ItemProperty" -Parameters $OrgParams -PassThru
                        }
                        catch {
                            Show-MessageDialog -Title "Informações do serviço" -Message "Erro ao salvar as informações do serviço no registro" -MessageType "Error"
                        }

                        $wnd.Close()
                        $xamlWindow.Close()
                    })  
            }
        }
    }
}