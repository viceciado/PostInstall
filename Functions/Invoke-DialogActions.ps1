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
                
                $TweaksStackPanel = $tweaksDialogWindow.FindName("TweaksStackPanel")

                # Inicializar a coleção de checkboxes
                $script:checkboxesCollection = @{}
                
                if ($TweaksStackPanel) {
                    try {
                        $availableTweaks = Get-AvailableItems -ItemType "Tweaks"
                        if ($availableTweaks.Count -gt 0) {
                            Write-InstallLog "Populando interface com $($availableTweaks.Count) tweaks"
                            
                            # Criar checkboxes para cada tweak
                            foreach ($tweak in $availableTweaks) {
                                try {
                                    $checkBox = New-Object System.Windows.Controls.CheckBox
                                    $checkBox.Content = "$($tweak.Name)"
                                    if ($tweak.Description) {
                                        $checkBox.ToolTip = "$($tweak.Description)"
                                    }
                                    $checkBox.Tag = $tweak.Name
                                    
                                    # Pré-selecionar tweaks recomendados
                                    if ($tweak.Recommended -eq $true) {
                                        $checkBox.IsChecked = $true
                                    }
                                    
                                    $TweaksStackPanel.Children.Add($checkBox)
                                    $script:checkboxesCollection[$tweak.Name] = $checkBox
                                }
                                catch {
                                    Write-InstallLog "Erro ao criar checkbox para $($tweak.Name): $($_.Exception.Message)" -Status "ERRO"
                                }
                            }
                        }
                        else {
                            <# Action when all if and elseif conditions are false #>
                        }
                    }
                    catch {
                        Write-InstallLog "Erro ao popular tweaks: $($_.Exception.Message)" -Status "ERRO"
                    }
                }

                # Botões
                $RecommendedTweaksButton = $tweaksDialogWindow.FindName("RecommendedTweaksButton")
                $RestoreDefaultsButton = $tweaksDialogWindow.FindName("RestoreDefaultsButton")
                $ApplySelectedTweaksButton = $tweaksDialogWindow.FindName("ApplySelectedTweaksButton")
                $SystemPropPerfButton = $tweaksDialogWindow.FindName("SystemPropPerfButton")
                $RarRegButton = $tweaksDialogWindow.FindName("RarRegButton")


                $SystemPropPerfButton.Add_Click({
                        Start-Process "SystemPropertiesPerformance"
                    })

                $RarRegButton.Add_Click({
                        $RarRegKeyDialog = New-Object System.Windows.Forms.OpenFileDialog
                        $RarRegKeyDialog.CheckFileExists = $true
                        $RarRegKeyDialog.AutoUpgradeEnabled = $true
                        $RarRegKeyDialog.Filter = "RarREG.key (*.key)|*.key"
                        $RarRegKeyDialog.Title = "Selecione o arquivo de ativação do WinRAR"
                        if ($RarRegKeyDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                            $RarRegKeyFilePath = $RarRegKeyDialog.FileName
                            
                            $WinrarInstallLocations = @("$env:ProgramFiles\WinRAR", "$env:ProgramFiles(x86)\WinRAR")
                            foreach ($Path in $WinrarInstallLocations) {
                                if (Test-Path -Path $Path) {
                                    Invoke-ElevatedProcess 
                                }
                                else {
                                }
                            }
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
                

                if ($programsStackPanel) {
                    try {
                        # Carregar programas do JSON
                        $availablePrograms = Get-AvailableItems -ItemType "Programs"
                        
                        if ($availablePrograms.Count -gt 0) {
                            Write-InstallLog "Populando interface com $($availablePrograms.Count) programas"
                            
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
                    }
                    catch {
                        Write-InstallLog "Erro ao popular lista de programas: $($_.Exception.Message)" -Status "ERRO"
                        # Criar StackPanel para organizar ícone e mensagem de erro crítico
                        $criticalErrorContainer = New-Object System.Windows.Controls.StackPanel
                        $criticalErrorContainer.Orientation = "Vertical"
                        $criticalErrorContainer.HorizontalAlignment = "Center"
                        $criticalErrorContainer.Margin = "0,20,0,0"
                        
                        # Ícone de erro crítico
                        $criticalErrorIcon = New-Object System.Windows.Controls.TextBlock
                        $criticalErrorIcon.Text = [char]0xE711  # Ícone de erro crítico do Segoe MDL2 Assets
                        $criticalErrorIcon.FontFamily = "Segoe MDL2 Assets"
                        $criticalErrorIcon.FontSize = 32
                        $criticalErrorIcon.Foreground = "Red"
                        $criticalErrorIcon.HorizontalAlignment = "Center"
                        $criticalErrorIcon.Margin = "0,0,0,10"
                        
                        # Mensagem de erro crítico
                        $criticalErrorLabel = New-Object System.Windows.Controls.TextBlock
                        $criticalErrorLabel.Text = "Erro ao carregar programas.`nVerifique os logs para mais detalhes."
                        $criticalErrorLabel.Foreground = "Red"
                        $criticalErrorLabel.FontSize = 14
                        $criticalErrorLabel.TextAlignment = "Center"
                        $criticalErrorLabel.HorizontalAlignment = "Center"
                        $criticalErrorLabel.TextWrapping = "Wrap"
                        
                        # Adicionar elementos ao container
                        $criticalErrorContainer.Children.Add($criticalErrorIcon)
                        $criticalErrorContainer.Children.Add($criticalErrorLabel)
                        $programsStackPanel.Children.Add($criticalErrorContainer)
                    }
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
                            Write-InstallLog "IDs inseridos manualmente: $($customProgramIDs -join ', ')"
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
                            Invoke-ElevatedProcess -FilePath "winget.exe" -ArgumentList "upgrade --all"
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
                
                $readOnlyButton = $logViewerWindow.FindName("ReadOnlyButton")
                if ($readOnlyButton) {
                    $readOnlyButton.Add_Click({
                            Show-MessageDialog -Title "Log Somente Leitura" -Message "Os logs são gerados automaticamente pelo script e refletem o histórico de execução. Para garantir a integridade e a precisão dos registros, a edição não é permitida." -MessageType "Info" -Buttons "OK"
                        })
                }
            }
        }
    }
}