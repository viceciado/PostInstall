function Initialize-MainWindow {
    <#
    .SYNOPSIS
        Registra todos os event handlers da MainWindow.

    .DESCRIPTION
        Recebe a instância da MainWindow (xamlWindow) já carregada e registra nela
        todos os handlers de clique, comportamento e navegação.
        Mantém o Main.ps1 focado apenas no bootstrap do ciclo de vida da aplicação.

    .PARAMETER xamlWindow
        Instância da MainWindow carregada via XamlReader.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$xamlWindow
    )

    #  Arrastar janela sem barra de título 
    $dialogBorder = $xamlWindow.FindName("DialogBorder")
    $closeButton = $xamlWindow.FindName("CloseButton")

    if ($dialogBorder) {
        $dialogBorder.Add_MouseDown({
                param($wpfSender, $wpfArgs)
                if ($wpfArgs.LeftButton -eq 'Pressed') { $xamlWindow.DragMove() }
            })
    }

    #  Evitar suspensão 
    $avoidSleepButton = $xamlWindow.FindName("AvoidSleepButton")
    if ($avoidSleepButton) {
        Update-ButtonUI -Button $avoidSleepButton

        $avoidSleepButton.Add_Click({
                if ($global:ScriptContext.System.AvoidSleep -eq $true) { Set-AvoidSleep }
                else { Set-AvoidSleep -AvoidSleep $true }
                Update-ButtonUI -Button ([System.Windows.Controls.Button]$args[0])
            })
    }

    #  Instalar programas 
    $appInstallButton = $xamlWindow.FindName("SelectAndInstallProgramsButton")
    if ($appInstallButton) {
        $appInstallButton.Add_Click({ Invoke-XamlDialog -WindowName 'AppInstallDialog' })
    }

    #  Instalar Office (montar/desmontar imagem) 
    $script:officeMountedImagePath = $null
    $script:originalOfficeButtonContent = $null
    $script:originalOfficeButtonColor = $null

    $InstallOfficeButton = $xamlWindow.FindName("InstallOfficeButton")
    if ($InstallOfficeButton) {
        $script:originalOfficeButtonContent = $InstallOfficeButton.Content
        $script:originalOfficeButtonColor = $InstallOfficeButton.Background

        $InstallOfficeButton.Add_Click({
                $btn = [System.Windows.Controls.Button]$args[0]

                #  Modo desmontagem 
                if ($script:officeMountedImagePath) {
                    $result = Show-MessageDialog -Message "Tem certeza que deseja desmontar a imagem de instalação?" -Title "Instalação do Office" -MessageType "Question" -Buttons "YesNo"
                    if ($result -eq "Yes") {
                        try {
                            Dismount-DiskImage -ImagePath $script:officeMountedImagePath -Confirm:$false -ErrorAction Stop
                            Write-InstallLog "Imagem desmontada: $script:officeMountedImagePath"
                            $btn.Content = $script:originalOfficeButtonContent
                            $btn.Background = $script:originalOfficeButtonColor
                            $script:officeMountedImagePath = $null
                            Show-Notification -Title "Instalação do Office" -Message "Imagem desmontada com sucesso."
                        } catch {
                            $msg = "Erro ao desmontar a imagem: $($_.Exception.Message)"
                            Write-InstallLog $msg -Status "ERRO"
                            Show-MessageDialog -Message $msg -Title "Erro" -MessageType "Error"
                        }
                    }
                    return
                }

                #  Modo montagem 
                $btn.Content = "Aguarde..."
                $btn.IsEnabled = $false
                $btn.Background = "Gray"

                $dlg = New-Object System.Windows.Forms.OpenFileDialog
                $dlg.InitialDirectory = [System.Environment]::GetFolderPath('Desktop')
                $dlg.Filter = "Arquivos de imagem (*.img)|*.img|Todos os arquivos (*.*)|*.*"
                $dlg.Title = "Localize a imagem de instalação do Office"
                $dlg.CheckFileExists = $true
                $dlg.CheckPathExists = $true

                if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                    Write-InstallLog "Instalação do Office cancelada pelo usuário"
                    $btn.Content = $script:originalOfficeButtonContent
                    $btn.IsEnabled = $true
                    $btn.Background = $script:originalOfficeButtonColor
                    return
                }

                $selectedImagePath = $dlg.FileName
                Write-InstallLog "Arquivo selecionado: $selectedImagePath"

                try {
                    $mountResult = Mount-DiskImage -ImagePath $selectedImagePath -PassThru -ErrorAction Stop
                } catch {
                    $msg = "Erro ao montar a imagem: $($_.Exception.Message)"
                    Write-InstallLog $msg -Status "ERRO"
                    Show-MessageDialog -Message $msg -Title "Erro" -MessageType "Error"
                    $btn.Content = $script:originalOfficeButtonContent
                    $btn.IsEnabled = $true
                    $btn.Background = $script:originalOfficeButtonColor
                    return
                }

                if (-not $mountResult) {
                    $msg = "Erro ao montar a imagem. Verifique se o arquivo é válido e tente novamente."
                    Write-InstallLog $msg -Status "ERRO"
                    Show-MessageDialog -Message $msg -Title "Erro" -MessageType "Error"
                    $btn.Content = $script:originalOfficeButtonContent
                    $btn.IsEnabled = $true
                    $btn.Background = $script:originalOfficeButtonColor
                    return
                }

                $driveLetter = ($mountResult | Get-Volume).DriveLetter
                if (-not $driveLetter) {
                    $msg = "Erro ao obter a letra da unidade. Verifique se a imagem foi montada corretamente."
                    Write-InstallLog $msg -Status "ERRO"
                    Show-MessageDialog -Message $msg -Title "Erro" -MessageType "Error"
                    Dismount-DiskImage -ImagePath $selectedImagePath -Confirm:$false -ErrorAction SilentlyContinue
                    $btn.Content = $script:originalOfficeButtonContent
                    $btn.IsEnabled = $true
                    $btn.Background = $script:originalOfficeButtonColor
                    return
                }

                $script:officeMountedImagePath = $selectedImagePath
                $btn.Content = "Desmontar imagem"
                $btn.IsEnabled = $true
                $btn.Background = $global:PSConst.Colors.Success
                $btn.ToolTip = "Clique aqui quando a instalação do Office tiver sido concluída"

                Write-InstallLog "Imagem montada na unidade ${driveLetter}:"
                Show-MessageDialog -Message "Execute o arquivo de instalação a partir da próxima tela.`n`nQuando a instalação terminar, clique para desmontar a imagem." -Title "Instalação do Office"

                if (Test-Path -Path "$($driveLetter):\setup.exe") {
                    Start-Process -FilePath "explorer.exe" -ArgumentList ("/select,$($driveLetter):\setup.exe")
                } else {
                    Start-Process "${driveLetter}:\"
                }
            })
    }

    #  Tema do Windows 
    $applyThemeButton = $xamlWindow.FindName("ApplyThemeButton")
    if ($applyThemeButton) {
        Update-ButtonUI -Button $applyThemeButton

        $applyThemeButton.Add_Click({
                try {
                    $currentTheme = Get-CurrentWindowsTheme
                    $newTheme = if ($currentTheme -eq "Claro") { "Escuro" } else { "Claro" }
                    if (Set-WindowsTheme -Theme $newTheme) {
                        Update-ButtonUI -Button ([System.Windows.Controls.Button]$args[0])
                        Write-InstallLog "Tema $($newTheme.ToLower()) aplicado"
                    } else {
                        Write-InstallLog "Falha ao aplicar o tema $($newTheme.ToLower())" -Status "ERRO"
                    }
                } catch {
                    Write-InstallLog "Erro ao aplicar tema: $($_.Exception.Message)" -Status "ERRO"
                }
            })
    }

    #  Tweaks 
    $TweaksButton = $xamlWindow.FindName("TweaksButton")
    if ($TweaksButton) {
        $TweaksButton.Add_Click({ Invoke-XamlDialog -WindowName 'TweaksDialog' })
    }

    #  Limpeza de permissões 
    $FixPermissionsButton = $xamlWindow.FindName("FixPermissionsButton")
    if ($FixPermissionsButton) {
        $FixPermissionsButton.Add_Click({
                $selectedFolders = @()

                if ($global:ScriptContext.Config.PersistedSelectedFolders.Count -gt 0) {
                    $usePersistedChoice = Show-MessageDialog -Message "Você já selecionou $($global:ScriptContext.Config.PersistedSelectedFolders.Count) pastas anteriormente.`n`nDeseja continuar com a seleção anterior?" -Title "Limpeza de permissões" -MessageType "Question" -Buttons "YesNoCancel"
                    if ($usePersistedChoice -eq "Yes") {
                        $selectedFolders = $global:ScriptContext.Config.PersistedSelectedFolders
                    } elseif ($usePersistedChoice -eq "No") {
                        $global:ScriptContext.Config.PersistedSelectedFolders = @()
                    } else { return }
                }

                if ($selectedFolders.Count -eq 0) {
                    do {
                        $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                        $folderBrowserDialog.Description = "Selecione a pasta para ajustar as permissões`n`nAVISO: A limpeza é recursiva."
                        $folderBrowserDialog.ShowNewFolderButton = $false

                        if ($folderBrowserDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                            $selectedPath = $folderBrowserDialog.SelectedPath
                            if ($selectedFolders -notcontains $selectedPath) { $selectedFolders += $selectedPath }
                            $selectedFolders = Remove-RedundantSubfolders -FolderList $selectedFolders

                            $message = "Pasta(s) selecionada(s):`n$($selectedFolders -join "`n")`n`nDeseja selecionar mais pastas?"
                            $addMore = Show-MessageDialog -Title "Limpeza de permissões" -Message $message -MessageType "Question" -Buttons "YesNo"
                            if ($addMore -ne "Yes") { break }
                        } else { break }
                    } while ($true)
                }

                if ($selectedFolders.Count -gt 0) {
                    $global:ScriptContext.Config.PersistedSelectedFolders = $selectedFolders
                    Write-InstallLog "Pastas selecionadas para a limpeza de permissões:"
                    foreach ($folder in $selectedFolders) { Write-InstallLog $folder }

                    $cleanNowOrLater = Show-MessageDialog -Message "Deseja limpar as permissões agora?`n`nCaso contrário, o script criará uma tarefa agendada que executará a limpeza de permissões de forma automática e silenciosa no próximo boot do sistema." -Title "Limpeza de permissões" -MessageType "Question" -Buttons "YesNoCancel"

                    if ($cleanNowOrLater -eq "Yes") {
                        Invoke-XamlDialog -WindowName "PermissionsDialog" -ConfigureDialog {
                            param($dialog)
                            $foldersStackPanel = $dialog.FindName("FoldersStackPanel")
                            $clearPersistedButton = $dialog.FindName("ClearPersistedButton")

                            $cleanPermissions = {
                                param($folderPath, $button)
                                try {
                                    $button.IsEnabled = $false
                                    Invoke-ElevatedProcess -FilePath "icacls.exe" -ArgumentList "$folderPath /q /c /t /reset"
                                    $button.Content = "Executado"
                                    $button.Background = $global:PSConst.Colors.Success
                                    Write-InstallLog "Limpeza de permissões concluída para $folderPath"
                                    Show-Notification -Title "Limpeza de permissões em:" -Message $folderPath
                                } catch {
                                    $button.Content = "Erro!"
                                    $button.Background = $global:PSConst.Colors.Error
                                    Write-InstallLog "Erro ao limpar permissões de $folderPath`: $_" -Status "ERRO"
                                }
                            }

                            foreach ($folder in $selectedFolders) {
                                $grid = New-Object System.Windows.Controls.Grid
                                $grid.Margin = "0,5,0,5"
                                $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = "*"
                                $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = "Auto"
                                $grid.ColumnDefinitions.Add($col1); $grid.ColumnDefinitions.Add($col2)

                                $tb = New-Object System.Windows.Controls.TextBlock
                                $tb.Text = $folder; $tb.VerticalAlignment = "Center"
                                $tb.Margin = "5,0,10,0"; $tb.TextWrapping = "Wrap"
                                [System.Windows.Controls.Grid]::SetColumn($tb, 0)

                                $btn = New-Object System.Windows.Controls.Button
                                $btn.Content = "Limpar"
                                $btn.Style = $dialog.Resources["ActionButtonStyle"]
                                $btn.Background = $global:PSConst.Colors.Accent
                                [System.Windows.Controls.Grid]::SetColumn($btn, 1)
                                $btn.Add_Click({ $cleanPermissions.Invoke($folder, $btn) }.GetNewClosure())

                                $grid.Children.Add($tb); $grid.Children.Add($btn)
                                $foldersStackPanel.Children.Add($grid)
                            }

                            if ($clearPersistedButton) {
                                $clearPersistedButton.Add_Click({
                                        $confirm = Show-MessageDialog -Message "Tem certeza de que deseja limpar a seleção de pastas salva?`n`nIsso fará com que você precise selecionar as pastas novamente na próxima vez." -Title "Confirmar Limpeza" -MessageType "Question" -Buttons "YesNo"
                                        if ($confirm -eq "Yes") {
                                            $global:ScriptContext.Config.PersistedSelectedFolders = @()
                                            $dialog.DialogResult = $false
                                            $dialog.Close()
                                        }
                                    })
                            }
                        }
                    } elseif ($cleanNowOrLater -eq "No") {
                        $created = Register-PermissionsReset -selectedFolders $selectedFolders
                        if ($created -eq $true) {
                            Show-Notification -Title "Limpeza de permissões" -Message "A tarefa foi criada com sucesso"
                            $global:ScriptContext.Config.PersistedSelectedFolders = @()
                        } else {
                            $openLog = Show-MessageDialog -Message "Erro ao criar a tarefa.`n`nDeseja consultar o log para ver o problema?" -Title "Erro" -MessageType "Error" -Buttons "YesNo"
                            if ($openLog -eq "Yes") { Invoke-XamlDialog -WindowName 'LogViewer' }
                        }
                    }
                    # else: cancelado â€” não faz nada
                }
            })
    }

    #  Ativar Windows 
    $activateButton = $xamlWindow.FindName("ActivateButton")
    if ($activateButton) {
        $activateButton.Add_Click({ Invoke-XamlDialog -WindowName 'ActivationDialog' })
    }

    #  Windows Update 
    $WUpdateButton = $xamlWindow.FindName("WUpdateButton")
    if ($WUpdateButton) {
        $WUpdateButton.Add_Click({
                Write-InstallLog "Abrindo Windows Update"
                Start-Process "ms-settings:windowsupdate-action"
            })
    }

    #  Importar drivers 
    $importDriversButton = $xamlWindow.FindName("ImportDriversButton")
    if ($importDriversButton) {
        $importDriversButton.Add_Click({
                $btn = [System.Windows.Controls.Button]$args[0]
                $originalContent = $btn.Content
                $btn.IsEnabled = $false
                $btn.Content = "Aguarde..."

                Show-MessageDialog -Title "Importação de drivers" -Message "Essa função deve ser usada somente em cenários específicos. Sempre dê preferência para instalar os drivers da máquina pelo site do fabricante ou pelo Windows Update."

                $folderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
                $folderDlg.Description = "Selecione a pasta contendo os drivers para importação"
                $folderDlg.ShowNewFolderButton = $false

                if ($folderDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $selectedPath = $folderDlg.SelectedPath
                    $infFiles = Get-ChildItem -Path $selectedPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue

                    if ($infFiles.Count -eq 0) {
                        Write-InstallLog "A pasta selecionada '$selectedPath' não contém arquivos .inf." -Status "AVISO"
                        Show-MessageDialog -Message "A pasta selecionada não contém nenhum arquivo .inf válido. Por favor, selecione uma pasta que contenha drivers." -Title "Importação de drivers" -MessageType "Error"
                        $btn.Content = $originalContent
                        $btn.IsEnabled = $true
                        return
                    }

                    Write-InstallLog "Pasta selecionada: $selectedPath contendo $($infFiles.Count) drivers"
                    $confirm = Show-MessageDialog -Message "Quantidade de drivers encontrados na pasta: $($infFiles.Count)`n`nProsseguir com a instalação?" -Title "Importação de drivers" -MessageType "Question" -Buttons "YesNo"
                    if ($confirm -eq "Yes") {
                        $btn.Content = "Importação iniciada!"
                        $btn.IsEnabled = $true
                        try {
                            Invoke-ElevatedProcess -FilePath "pnputil.exe" -ArgumentList "/add-driver ""$selectedPath\*.inf"" /subdirs /install" -PassThru
                        } catch {
                            $msg = "Erro ao executar pnputil: $($_.Exception.Message)"
                            Write-InstallLog $msg -Status "ERRO"
                            $btn.Content = "Erro!"
                            Show-MessageDialog -Message $msg -Title "Importação de drivers" -MessageType "Error"
                        }
                    } else {
                        $btn.Content = $originalContent
                        $btn.IsEnabled = $true
                    }
                } else {
                    $btn.Content = $originalContent
                    $btn.IsEnabled = $true
                }
            })
    }

    #  Gerenciador de dispositivos 
    $deviceManagerButton = $xamlWindow.FindName("DeviceManagerButton")
    if ($deviceManagerButton) {
        $deviceManagerButton.Add_Click({
                Write-InstallLog "Abrindo Gerenciador de Dispositivos"
                Start-Process "devmgmt.msc"
            })
    }

    #  Versão do script / link GitHub 
    $scriptVersionButton = $xamlWindow.FindName("ScriptVersionButton")
    if ($scriptVersionButton) {
        if ($global:ScriptContext.ScriptVersion) {
            $scriptVersionButton.Content = $global:ScriptContext.ScriptVersion
        }
        $scriptVersionButton.Add_Click({ Start-Process "https://github.com/viceciado/PostInstall/" })
    }

    #  Sobre 
    $aboutButton = $xamlWindow.FindName("AboutButton")
    if ($aboutButton) {
        $aboutButton.Add_Click({ Invoke-XamlDialog -WindowName 'AboutDialog' })
    }

    #  Visualizar log 
    $viewLogButton = $xamlWindow.FindName("ViewLogButton")
    if ($viewLogButton) {
        $viewLogButton.Add_Click({ Invoke-XamlDialog -WindowName 'LogViewer' })
    }

    #  Finalizar instalação 
    $finalizeButton = $xamlWindow.FindName("FinalizeInstallButton")
    if ($finalizeButton) {
        $finalizeButton.Add_Click({ Invoke-XamlDialog -WindowName 'FinalizeDialog' })
    }

    #  Rodapé: atalho para log 
    $footerStatusButton = $xamlWindow.FindName("FooterStatusButton")
    if ($footerStatusButton) {
        $footerStatusButton.Add_Click({ Invoke-XamlDialog -WindowName 'LogViewer' })
    }

    #  Fechar janela 
    if ($closeButton) {
        $closeButton.Add_Click({
                $answer = Show-MessageDialog -Message "Deseja realmente fechar o script agora?`n`nIsso só fecha a janela, mas não encerra a configuração.`nSe você reiniciar o computador, essa janela aparecerá novamente.`n`nA forma correta de finalizar o script é por meio do botão Finalizar instalação na tela principal." -Title "Encerrar o Post-Install" -MessageType "Warning" -Buttons "YesNo"
                if ($answer -eq "Yes") { $xamlWindow.Close() }
            })
    }
}

