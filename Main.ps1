Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Management

$global:ScriptContext = @{
    ScriptVersion     = "pre-build"
    XamlWindows       = @{}
    SystemInfo        = $null
    OemKey            = $null
    IsAdministrator   = $false
    MainWindow        = $null
    AvailablePrograms = @()
    AvailableTweaks   = @()
    AvoidSleep        = $false
    isWin11           = $null
    OsNumber          = $null
    ClientName        = $null
    TechnicianName    = $null
}

# === SISTEMA DE CARREGAMENTO DINÂMICO DE FUNÇÕES ===

# Função para carregamento dinâmico de arquivos de função
function Import-FunctionFile {
    <#
    .SYNOPSIS
    Carrega um arquivo de função PowerShell usando dot-sourcing
    
    .DESCRIPTION
    Carrega dinamicamente arquivos .ps1 da pasta Functions usando dot-sourcing,
    com tratamento de erro e logs informativos
    
    .PARAMETER FunctionFileName
    Nome do arquivo de função a ser carregado
    
    .PARAMETER FunctionsPath
    Caminho base para a pasta Functions
    
    .EXAMPLE
    Import-FunctionFile -FunctionFileName "Write-InstallLog.ps1" -FunctionsPath $PSScriptRoot
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$FunctionFileName,
        
        [Parameter(Mandatory = $true)]
        [string]$FunctionsPath
    )
    
    $functionFilePath = Join-Path -Path $FunctionsPath -ChildPath "Functions" | Join-Path -ChildPath $FunctionFileName
    
    if (Test-Path -Path $functionFilePath) {
        try {
            . $functionFilePath
            Write-Host "[SUCESSO] Função carregada: $FunctionFileName" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[ERRO] Falha ao carregar '$FunctionFileName': $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "[AVISO] Arquivo de função não encontrado: $functionFilePath" -ForegroundColor Yellow
        return $false
    }
}

# Descobrir e carregar todas as funções automaticamente
try {
    $functionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions"
    
    if (Test-Path -Path $functionsPath) {
         $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -File
         
         Write-Host "[INFO] Descobrindo funções na pasta: $functionsPath" -ForegroundColor Cyan
         Write-Host "[INFO] Encontrados $($functionFiles.Count) arquivo(s) de função" -ForegroundColor Cyan
         
         $loadedFunctions = @()
         $failedFunctions = @()
         
         foreach ($file in $functionFiles) {
             $success = Import-FunctionFile -FunctionFileName $file.Name -FunctionsPath $PSScriptRoot
             
             if ($success) {
                 $loadedFunctions += $file.BaseName
             }
             else {
                 $failedFunctions += $file.BaseName
             }
         }
         
         Write-Host "[SUCESSO] Sistema de carregamento dinâmico de funções inicializado" -ForegroundColor Green
         Write-Host "[INFO] Funções carregadas: $($loadedFunctions -join ', ')" -ForegroundColor Cyan
         
         if ($failedFunctions.Count -gt 0) {
             Write-Host "[AVISO] Funções com falha: $($failedFunctions -join ', ')" -ForegroundColor Yellow
         }

         Write-InstallLog "Sistema de funções carregado com sucesso" -Status "SUCESSO"
     }
     else {
         Write-Host "[AVISO] Pasta Functions não encontrada: $functionsPath" -ForegroundColor Yellow
     }
 }
 catch {
     Write-Host "[ERRO] Falha crítica no carregamento de funções: $($_.Exception.Message)" -ForegroundColor Red
     exit 1
 }

# Função para listar funções carregadas
function Get-LoadedFunctions {
    <#
    .SYNOPSIS
    Lista todas as funções disponíveis no sistema
    
    .DESCRIPTION
    Retorna uma lista de todas as funções que foram descobertas e carregadas automaticamente
    da pasta Functions
    
    .EXAMPLE
    Get-LoadedFunctions
    #>
    
    $functionsPath = Join-Path -Path $PSScriptRoot -ChildPath "Functions"
    
    if (Test-Path -Path $functionsPath) {
        $functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -File
        return $functionFiles | ForEach-Object { $_.BaseName } | Sort-Object
    }
    else {
        Write-Warning "Pasta Functions não encontrada"
        return @()
    }
}

# === INICIALIZAÇÃO DO SCRIPT ===

try {
    # Obter caminho base do script
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $windowsPath = Join-Path $scriptPath "Windows"
    
    # Descobrir automaticamente todos os arquivos XAML na pasta Windows
    $xamlFiles = Get-ChildItem -Path $windowsPath -Filter "*.xaml" -File
    
    if ($xamlFiles.Count -eq 0) {
        throw "Nenhum arquivo XAML encontrado na pasta Windows"
    }
    
    Write-InstallLog "Descobertos $($xamlFiles.Count) arquivos XAML na pasta Windows" 
    
    # Carregar cada arquivo XAML dinamicamente
    foreach ($file in $xamlFiles) {
        $fileName = $file.Name
        $variableName = Get-VariableNameFromFile -FileName $fileName
        
        try {
            $content = Get-XamlContent -XamlFileName $fileName -WindowsPath $windowsPath
            Set-Variable -Name $variableName -Value $content -Scope Script
            Write-InstallLog "Variável '$variableName' definida para '$fileName'" -Status "SUCESSO"
        }
        catch {
            Write-InstallLog "Falha ao carregar '$fileName': $($_.Exception.Message)" -Status "ERRO"
            # Continuar com outros arquivos mesmo se um falhar
        }
    }
    
    # Listar todas as variáveis XAML carregadas
    $loadedVariables = $xamlFiles | ForEach-Object { Get-VariableNameFromFile -FileName $_.Name }
    Write-InstallLog "Variáveis XAML disponíveis: $($loadedVariables -join ', ')" 
    Write-InstallLog "Sistema de carregamento dinâmico de XAML inicializado com sucesso" -Status "SUCESSO"
    
    # Criar hashtable global para facilitar acesso às janelas
    foreach ($file in $xamlFiles) {
        $variableName = Get-VariableNameFromFile -FileName $file.Name
        $global:ScriptContext.XamlWindows[$file.BaseName] = $variableName
    }
    
    Write-InstallLog "Mapeamento de janelas criado: $($global:ScriptContext.XamlWindows.Keys -join ', ')" 
}
catch {
    Write-InstallLog "Falha crítica no carregamento de XAML: $($_.Exception.Message)" -Status "ERRO"
    Show-MessageDialog -Message "Erro ao carregar arquivos de interface. Verifique se os arquivos XAML estão presentes na pasta Windows.`n`nDetalhes: $($_.Exception.Message)" -Title "Erro Crítico" -MessageType "Error" 
    exit 1
}

try {
    # === INICIALIZAÇÃO DAS JANELAS PRINCIPAIS ===
    try {
        Test-WindowsVersion
        
        [xml]$splashScreenXamlParsed = $splashScreenXaml
        [xml]$mainWindowXamlParsed = $mainWindowXaml
    
        $SplashScreen = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $splashScreenXamlParsed))
        $xamlWindow = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $mainWindowXamlParsed))
    
        # Tornar a MainWindow acessível globalmente como Owner para diálogos
        $global:ScriptContext.MainWindow = $xamlWindow
    
        # Hooks básicos da MainWindow
        $dialogBorder = $xamlWindow.FindName("DialogBorder")
        $scriptVersionTextBlock = $xamlWindow.FindName("ScriptVersionText")
        $closeButton = $xamlWindow.FindName("CloseButton")
    
        if ($dialogBorder) {
            $dialogBorder.Add_MouseDown({
                    param($sender, $e)
                    if ($e.LeftButton -eq 'Pressed') { $xamlWindow.DragMove() }
                })
        }
    
        if ($global:ScriptContext.ScriptVersion) { $scriptVersionTextBlock.Text = $($global:ScriptContext.ScriptVersion) }
    
        # Ações da MainWindow
        $avoidSleepButton = $xamlWindow.FindName("AvoidSleepButton")
        if ($avoidSleepButton) {
            $avoidSleepButton.Add_Click({ 
                    if ($global:ScriptContext.AvoidSleep -eq $true) {
                        Set-AvoidSleep
                    }
                    else {
                        Set-AvoidSleep -AvoidSleep $true
                    }
                    Update-ButtonUI -Button $avoidSleepButton
                })
        }

        $appInstallButton = $xamlWindow.FindName("SelectAndInstallProgramsButton")
        if ($appInstallButton) {
            $appInstallButton.Add_Click({ Invoke-XamlDialog -WindowName 'AppInstallDialog' })
        }

        # Variáveis para controle do estado do botão Office
        $script:officeMountedImagePath = $null
        $script:originalOfficeButtonContent = $null
        $script:originalOfficeButtonColor = $null

        $InstallOfficeButton = $xamlWindow.FindName("InstallOfficeButton")
        if ($InstallOfficeButton) {
            # Armazenar valores originais do botão
            $script:originalOfficeButtonContent = $InstallOfficeButton.Content
            $script:originalOfficeButtonColor = $InstallOfficeButton.Background
            
            $InstallOfficeButton.Add_Click({ 
                    # Verificar se já existe uma imagem montada
                    if ($script:officeMountedImagePath) {
                        # Modo desmontagem
                        $result = Show-MessageDialog -Message "Tem certeza que deseja desmontar a imagem de instalação?" -Title "Instalação do Office" -MessageType "Question" -Buttons "YesNo"
                        if ($result -eq "Yes") {
                            try {
                                Dismount-DiskImage -ImagePath $script:officeMountedImagePath -Confirm:$false -ErrorAction Stop
                                Write-InstallLog "Imagem desmontada: $script:officeMountedImagePath"
                            
                                # Restaurar estado original do botão
                                $InstallOfficeButton.Content = $script:originalOfficeButtonContent
                                $InstallOfficeButton.Background = $script:originalOfficeButtonColor
                                $script:officeMountedImagePath = $null
                                Show-Notification -Title "Instalação do Office" -Message "Imagem desmontada com sucesso."
                            }
                            catch {
                                $dismountErrorMsg = "Erro ao desmontar a imagem: $($_.Exception.Message)"
                                Write-InstallLog  $dismountErrorMsg -Status "ERRO"
                                Show-MessageDialog -Message $dismountErrorMsg -Title "Erro" -MessageType "Error" 
                            }
                        }
                        return
                    }
                
                    # Modo montagem
                    $InstallOfficeButton.Content = "Aguarde..."
                    $InstallOfficeButton.IsEnabled = $false
                    $InstallOfficeButton.Background = "Gray"

                    $OfficeImgPickDialog = New-Object System.Windows.Forms.OpenFileDialog                
                    $OfficeImgPickDialog.InitialDirectory = [System.Environment]::GetFolderPath('Desktop')
                    $OfficeImgPickDialog.Filter = "Arquivos de imagem (*.img)|*.img|Todos os arquivos (*.*)|*.*"
                    $OfficeImgPickDialog.Title = "Localize a imagem de instalação do Office"
                    $OfficeImgPickDialog.CheckFileExists = $true
                    $OfficeImgPickDialog.CheckPathExists = $true
                
                    $dialogResult = $OfficeImgPickDialog.ShowDialog()
                
                    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                        $selectedImagePath = $OfficeImgPickDialog.FileName
                        Write-InstallLog "Arquivo selecionado: $selectedImagePath"
                    }
                    else {
                        Write-InstallLog "Instalação do Office cancelada pelo usuário"
                        # Restaurar o estado do botão
                        $InstallOfficeButton.Content = $script:originalOfficeButtonContent
                        $InstallOfficeButton.IsEnabled = $true
                        $InstallOfficeButton.Background = $script:originalOfficeButtonColor
                        return
                    }

                    $mountImgResult = $null
                    try {
                        $mountImgResult = Mount-DiskImage -ImagePath $selectedImagePath -PassThru -ErrorAction Stop
                    }
                    catch {
                        $mountErrorMsg = "Erro ao montar a imagem: $($_.Exception.Message)"
                        Write-InstallLog  $mountErrorMsg -Status "ERRO"
                        Show-MessageDialog -Message $mountErrorMsg -Title "Erro" -MessageType "Error" 
                        # Restaurar estado do botão em caso de erro
                        $InstallOfficeButton.Content = $script:originalOfficeButtonContent
                        $InstallOfficeButton.IsEnabled = $true
                        $InstallOfficeButton.Background = $script:originalOfficeButtonColor
                        return
                    }

                    if ($mountImgResult -eq $null) {
                        $ErrorMsg = "Erro ao montar a imagem. Verifique se o arquivo é válido e tente novamente."
                        Write-InstallLog  $ErrorMsg -Status "ERRO"
                        Show-MessageDialog -Message $ErrorMsg -Title "Erro" -MessageType "Error" 
                        # Restaurar estado do botão
                        $InstallOfficeButton.Content = $script:originalOfficeButtonContent
                        $InstallOfficeButton.IsEnabled = $true
                        $InstallOfficeButton.Background = $script:originalOfficeButtonColor
                        return
                    }

                    $mountImgLetter = ($mountImgResult | Get-Volume).DriveLetter
                    if (-not $mountImgLetter) {
                        $ErrorMsg = "Erro ao obter a letra da unidade. Verifique se a imagem foi montada corretamente."
                        Write-InstallLog  $ErrorMsg -Status "ERRO"
                        Show-MessageDialog -Message $ErrorMsg -Title "Erro" -MessageType "Error" 
                        Dismount-DiskImage -ImagePath $selectedImagePath -Confirm:$false -ErrorAction SilentlyContinue
                        # Restaurar estado do botão
                        $InstallOfficeButton.Content = $script:originalOfficeButtonContent
                        $InstallOfficeButton.IsEnabled = $true
                        $InstallOfficeButton.Background = $script:originalOfficeButtonColor
                        return
                    }

                    # Atualizar estado do botão para modo desmontagem
                    $script:officeMountedImagePath = $selectedImagePath
                    $InstallOfficeButton.Content = "Desmontar imagem"
                    $InstallOfficeButton.IsEnabled = $true
                    $InstallOfficeButton.Background = "#4CAF50"
                    $InstallOfficeButton.ToolTip = "Clique aqui quando a instalação do Office tiver sido concluída"

                    Write-InstallLog "Imagem montada na unidade ${mountImgLetter}:"
                    Show-MessageDialog -Message "Execute o arquivo de instalação a partir da próxima tela.`n`nQuando a instalação terminar, clique para desmontar a imagem." -Title "Instalação do Office"
                    if (Test-Path -Path "$($mountImgLetter):\setup.exe") {
                        Start-Process -FilePath "explorer.exe" -ArgumentList ("/select,$($mountImgLetter):\setup.exe")
                    } else {
                        Start-Process "${mountImgLetter}:\"
                    }
                })
        }

        $applyThemeButton = $xamlWindow.FindName("ApplyThemeButton")
        if ($applyThemeButton) {
            # Inicializa o UI do botão com o tema atual
            $currentTheme = Update-ButtonUI -Button $applyThemeButton
    
            $applyThemeButton.Add_Click({
                    try {
                        $currentTheme = Get-CurrentWindowsTheme
                    
                        # Alterna entre tema claro e escuro
                        $newTheme = if ($currentTheme -eq "Claro") { "Escuro" } else { "Claro" }
                    
                        # Aplicar o novo tema
                        $success = Set-WindowsTheme -Theme $newTheme
                    
                        if ($success) {
                            # Atualizar UI do botão
                            Update-ButtonUI -Button $applyThemeButton
                            Write-InstallLog "Tema $($newTheme.ToLower()) aplicado"
                        }
                        else {
                            Write-InstallLog "Falha ao aplicar o tema $($newTheme.ToLower())" -Status "ERRO"
                        }
                    
                    }
                    catch {
                        Write-InstallLog "Erro ao aplicar tema $($newTheme.ToLower()): $($_.Exception.Message)" -Status "ERRO"
                    }
                })
        }

        $TweaksButton = $xamlWindow.FindName("TweaksButton")
        if ($TweaksButton) {
            $TweaksButton.Add_Click({
                    # Show-MessageDialog -Title "Recurso em desenvolvimento" -Message "Essa tela possui recursos ainda em desenvolvimento. Agradecemos a compreensão."
                    Invoke-XamlDialog -WindowName 'TweaksDialog'
                })
        }

        $FixPermissionsButton = $xamlWindow.FindName("FixPermissionsButton")
        if ($FixPermissionsButton) {
            $FixPermissionsButton.Add_Click({
                    $selectedFolders = @()
                
                    # Verificar se já existem pastas persistidas
                    if (-not $global:ScriptContext.ContainsKey('PersistedSelectedFolders')) {
                        $global:ScriptContext.PersistedSelectedFolders = @()
                    }
                
                    # Se há pastas persistidas, perguntar se o usuário quer usar as mesmas ou selecionar novas
                    if ($global:ScriptContext.PersistedSelectedFolders.Count -gt 0) {
                        $usePersistedChoice = Show-MessageDialog -Message "Você já selecionou $($global:ScriptContext.PersistedSelectedFolders.Count) pastas anteriormente.`n`nDeseja continuar com a seleção anterior?" -Title "Limpeza de permissões" -MessageType "Question" -Buttons "YesNoCancel"
                    
                        if ($usePersistedChoice -eq "Yes") {
                            $selectedFolders = $global:ScriptContext.PersistedSelectedFolders
                        }
                        elseif ($usePersistedChoice -eq "No") {
                            $global:ScriptContext.PersistedSelectedFolders = @()
                        }
                        else {
                            # Usuário cancelou
                            return
                        }
                    }
                
                    # Se não há pastas selecionadas (primeira vez ou usuário escolheu selecionar novas), fazer seleção
                    if ($selectedFolders.Count -eq 0) {
                        do {
                            $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                            $folderBrowserDialog.Description = "Selecione a pasta para ajustar as permissões`n`nAVISO: A limpeza é recursiva."
                            $folderBrowserDialog.ShowNewFolderButton = $false

                            $result = $folderBrowserDialog.ShowDialog()
                        
                            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                                $selectedPath = $folderBrowserDialog.SelectedPath
                            
                                # Verificar se a pasta já foi selecionada (ignorar duplicatas)
                                if ($selectedFolders -notcontains $selectedPath) {
                                    $selectedFolders += $selectedPath
                                }
                            
                                # Remover subpastas redundantes (manter apenas pastas-pai)
                                $selectedFolders = Remove-RedundantSubfolders -FolderList $selectedFolders
                            
                                # Mostrar status e perguntar se deseja adicionar mais pastas
                                $message = "Pasta(s) selecionada(s):`n$($selectedFolders -join "`n")`n`nDeseja selecionar mais pastas?"
                                $addMoreResult = Show-MessageDialog -Title "Limpeza de permissões" -Message $message -MessageType "Question" -Buttons "YesNo"
                            
                                # Se não quiser adicionar mais, sair do loop
                                if ($addMoreResult -ne "Yes") {
                                    break
                                }
                            }
                            else {
                                break
                            }
                        } while ($true)
                    }

                    if ($selectedFolders.Count -gt 0) {
                        # Persistir as pastas selecionadas
                        $global:ScriptContext.PersistedSelectedFolders = $selectedFolders
                    
                        Write-InstallLog "Pastas selecionadas para a limpeza de permissões:"
                        foreach ($folder in $selectedFolders) {
                            Write-InstallLog $folder
                        }

                        $cleanNowOrLater = Show-MessageDialog -Message "Deseja limpar as permissões agora?`n`nCaso contrário, o script criará uma tarefa agendada que executará a limpeza de permissões de forma automática e silenciosa no próximo boot do sistema." -Title "Limpeza de permissões" -MessageType "Question" -Buttons "YesNoCancel"
                    
                        if ($cleanNowOrLater -eq "Yes") {
                            Invoke-XamlDialog -WindowName "PermissionsDialog" -ConfigureDialog {
                                param($dialog)
                            
                                # Obter referências aos controles
                                $foldersStackPanel = $dialog.FindName("FoldersStackPanel")
                                $clearPersistedButton = $dialog.FindName("ClearPersistedButton")
                            
                                # Função para executar limpeza de permissões
                                $cleanPermissions = {
                                    param($folderPath, $button)
                                
                                    try {
                                        $button.IsEnabled = $false
                                        $icacArgs = """$folderPath"" /q /c /t /reset"
                                        Invoke-ElevatedProcess -FilePath "icacls.exe" -ArgumentList $icacArgs -PassThru
                                    
                                        $button.Content = "Executado"
                                        $button.Background = "#28A745" # Verde para sucesso
                                    
                                        Write-InstallLog "Limpeza de permissões concluída para $folderPath"
                                        Show-Notification -Title "Limpeza de permissões em:" -Message $folderPath
                                    
                                    }
                                    catch {
                                        $button.Content = "Erro!"
                                        $button.Background = "#DC3545" # Vermelho para erro
                                        Write-InstallLog "Erro ao limpar permissões de $folderPath`: $_" -Status "ERRO"
                                        Show-Notification -Title "Erro ao limpar permissões" -Message $folderPath
                                    }
                                }
                            
                                # Popular a lista com as pastas selecionadas
                                foreach ($folder in $selectedFolders) {
                                    # Criar container para cada pasta
                                    $folderContainer = New-Object System.Windows.Controls.Grid
                                    $folderContainer.Margin = "0,5,0,5"
                                
                                    # Definir colunas do grid
                                    $col1 = New-Object System.Windows.Controls.ColumnDefinition
                                    $col1.Width = "*"
                                    $col2 = New-Object System.Windows.Controls.ColumnDefinition
                                    $col2.Width = "Auto"
                                    $folderContainer.ColumnDefinitions.Add($col1)
                                    $folderContainer.ColumnDefinitions.Add($col2)
                                
                                    # TextBlock com o caminho da pasta
                                    $folderTextBlock = New-Object System.Windows.Controls.TextBlock
                                    $folderTextBlock.Text = $folder
                                    $folderTextBlock.VerticalAlignment = "Center"
                                    $folderTextBlock.Margin = "5,0,10,0"
                                    $folderTextBlock.TextWrapping = "Wrap"
                                    [System.Windows.Controls.Grid]::SetColumn($folderTextBlock, 0)
                                
                                    # Botão para limpar permissões
                                    $cleanButton = New-Object System.Windows.Controls.Button
                                    $cleanButton.Content = "Limpar"
                                    $cleanButton.Style = $dialog.Resources["ActionButtonStyle"]
                                    $cleanButton.Background = "#993233" # Azul para ação
                                    [System.Windows.Controls.Grid]::SetColumn($cleanButton, 1)
                                
                                    # Adicionar evento de clique
                                    $cleanButton.Add_Click({
                                            $cleanPermissions.Invoke($folder, $cleanButton)
                                        }.GetNewClosure())
                                
                                    # Adicionar controles ao container
                                    $folderContainer.Children.Add($folderTextBlock)
                                    $folderContainer.Children.Add($cleanButton)
                                
                                    # Adicionar container ao painel principal
                                    $foldersStackPanel.Children.Add($folderContainer)
                                }
                            
                                # Configurar botão para limpar seleção salva
                                if ($clearPersistedButton) {
                                    $clearPersistedButton.Add_Click({
                                            $confirmClear = Show-MessageDialog -Message "Tem certeza de que deseja limpar a seleção de pastas salva?`n`nIsso fará com que você precise selecionar as pastas novamente na próxima vez." -Title "Confirmar Limpeza" -MessageType "Question" -Buttons "YesNo"
                                    
                                            if ($confirmClear -eq "Yes") {
                                                $global:ScriptContext.PersistedSelectedFolders = @()
                                        
                                                # Fechar a janela após limpar
                                                $dialog.DialogResult = $false
                                                $dialog.Close()
                                            }
                                        })
                                }
                            }
                        }
                        if ($cleanNowOrLater -eq "No") {
                            $CreateTask = Register-PermissionsReset -selectedFolders $selectedFolders

                            if ($CreateTask -eq $true) {
                                Show-Notification -Title "Limpeza de permissões" -Message "A tarefa foi criada com sucesso"
                                $global:ScriptContext.PersistedSelectedFolders = @()
                            }
                            else {
                                $ShowLogOnError = Show-MessageDialog -Message "Erro ao criar a tarefa.`n`nDeseja consultar o log para ver o problema?" -Title "Erro" -MessageType "Error" -Buttons "YesNo"
                                if ($ShowLogOnError -eq "Yes") {
                                    Invoke-XamlDialog -WindowName 'LogViewer'
                                }
                            }
                        }
                        else {
                            return
                        }
                    }
                })
        }

        $activateButton = $xamlWindow.FindName("ActivateButton")
        if ($activateButton) {
            $activateButton.Add_Click({ Invoke-XamlDialog -WindowName 'ActivationDialog' })
        }
    
        $WUpdateButton = $xamlWindow.FindName("WUpdateButton")
        if ($WUpdateButton) {
            $WUpdateButton.Add_Click({
                    Write-InstallLog "Abrindo Windows Update"
                    Start-Process "ms-settings:windowsupdate-action"
                })
        }

        $importDriversButton = $xamlWindow.FindName("ImportDriversButton")
        if ($importDriversButton) {
            $importDriversButton.Add_Click({
                    $originalDriversButtonContent = $importDriversButton.Content
                    $importDriversButton.IsEnabled = $false
                    $importDriversButton.Content = "Aguarde..."

                    Show-MessageDialog -Title "Importação de drivers" -Message "Essa função deve ser usada somente em cenários específicos. Sempre dê preferência para instalar os drivers da máquina pelo site do fabricante ou pelo Windows Update."

                    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
                    $folderBrowserDialog.Description = "Selecione a pasta contendo os drivers para importação"
                    $folderBrowserDialog.ShowNewFolderButton = $false

                    if ($folderBrowserDialog.ShowDialog([System.Windows.Forms.NativeWindow]::new()) -eq [System.Windows.Forms.DialogResult]::OK) {
                        $selectedPath = $folderBrowserDialog.SelectedPath
                    
                        $infFiles = Get-ChildItem -Path $selectedPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
                        if ($infFiles.Count -eq 0) {
                            Write-InstallLog "A pasta selecionada '$selectedPath' não contém arquivos .inf." -Status "AVISO"
                            Show-MessageDialog -Message "A pasta selecionada não contém nenhum arquivo .inf válido. Por favor, selecione uma pasta que contenha drivers." -Title "Importação de drivers" -MessageType "Error" 
                            $importDriversButton.Content = $originalDriversButtonContent
                            $importDriversButton.IsEnabled = $true
                            return
                        }

                        Write-InstallLog "Pasta selecionada: $selectedPath contendo $($infFiles.Count) drivers"
                        $ConfirmImport = Show-MessageDialog -Message "Quantidade de drivers encontrados na pasta: $($infFiles.Count)`n`nProsseguir com a instalação?" -Title "Importação de drivers" -MessageType "Question" -Buttons "YesNo" 
                        if ($ConfirmImport -eq "Yes") {
                            $importDriversButton.Content = "Importação iniciada!"
                            $importDriversButton.IsEnabled = $true
    
                            try {
                                $argumentList = "/add-driver ""$selectedPath\*.inf"" /subdirs /install"
                                Invoke-ElevatedProcess -FilePath "pnputil.exe" -ArgumentList $argumentList -PassThru
                            }
                            catch {
                                $errorMessage = "Erro ao executar pnputil: $($_.Exception.Message)"
                                Write-InstallLog $errorMessage -Status "ERRO"
                                $importDriversButton.Content = "Erro!"
                                Show-MessageDialog -Message $errorMessage -Title "Importação de drivers" -MessageType "Error" 
                            }
                        }
                        else {
                            $importDriversButton.Content = $originalDriversButtonContent
                            $importDriversButton.IsEnabled = $true
                            return
                        }
                    }
                    else {
                        $importDriversButton.Content = $originalDriversButtonContent
                        $importDriversButton.IsEnabled = $true
                    }
                })
        }

        $deviceManagerButton = $xamlWindow.FindName("DeviceManagerButton")
        if ($deviceManagerButton) {
            $deviceManagerButton.Add_Click({
                    Write-InstallLog "Abrindo Gerenciador de Dispositivos"
                    Start-Process "devmgmt.msc"
                })
        }

        $aboutButton = $xamlWindow.FindName("AboutButton")
        if ($aboutButton) {
            $aboutButton.Add_Click({ Invoke-XamlDialog -WindowName 'AboutDialog' })
        }
    
        $viewLogButton = $xamlWindow.FindName("ViewLogButton")
        if ($viewLogButton) {
            $viewLogButton.Add_Click({ Invoke-XamlDialog -WindowName 'LogViewer' })
        }
    
        $finalizeButton = $xamlWindow.FindName("FinalizeInstallButton")
        if ($finalizeButton) {
            $finalizeButton.Add_Click({ 
                    Invoke-XamlDialog -WindowName 'FinalizeDialog' 
            
                })
        }
    
        $footerStatusButton = $xamlWindow.FindName("FooterStatusButton")
        if ($footerStatusButton) {
            $footerStatusButton.Add_Click({ Invoke-XamlDialog -WindowName 'LogViewer' })
        }
    
        if ($closeButton) {
            $closeButton.Add_Click({ $xamlWindow.Close() })
        }
    }
    catch {
        Write-InstallLog "Erro fatal ao carregar XAML principal: $($_.Exception.Message)" -Status "ERRO"
        exit 1
    }

    # === FLUXO DE INICIALIZAÇÃO COM SPLASH ===
    try {
        # Exibir splash enquanto coleta informações
        $SplashScreen.Show()
    
        # Verificar conectividade (opcionalmente interativo)
        $hasInternet = Test-InternetConnection -ShowDialog $true
        if (-not $hasInternet) { 
            # Fechar splash screen antes de encerrar
            $SplashScreen.Close()
            Write-InstallLog "Aplicação encerrada: sem conexão com a internet" 
            exit 0
        }
    
        # Coletar informações do sistema (modular com auto-elevação)
        if (-not $global:ScriptContext.SystemInfo) {
            $global:ScriptContext.SystemInfo = Get-SystemInfo -AutoElevate $true
        }
    
        $SplashScreen.Close()

        # Desativar a suspensão do computador
        Set-AvoidSleep -AvoidSleep $true -Silent $true
    
        # Exibir a MainWindow (bloqueante)
        $xamlWindow.ShowDialog() | Out-Null
    }
    catch {
        # Garantir que a splash screen seja fechada em caso de erro
        if ($SplashScreen -and $SplashScreen.IsVisible) {
            $SplashScreen.Close()
        }
        Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
        Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
        exit 1
    }
}
catch {
    Write-InstallLog "ERRO FATAL no script principal: $($_.Exception.Message) `n$($_.ScriptStackTrace)" -Status "ERRO CRÍTICO"
    Show-MessageDialog -Message "Ocorreu um erro crítico: $($_.Exception.Message)" -Title "Erro na Aplicação" -MessageType "Error" 
    exit
}
finally {
    # === ROTINAS DE LIMPEZA ===
    Write-InstallLog "Executando rotinas de limpeza..."

    # Finalizar todos os jobs em execução
    try {
        $runningJobs = Get-Job -State Running -ErrorAction SilentlyContinue
        if ($runningJobs) {
            Write-InstallLog "Finalizando $($runningJobs.Count) job(s) em execução..."
            foreach ($job in $runningJobs) {
                Write-InstallLog "Finalizando job: $($job.Name)" -Status "INFO"
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Limpar todos os jobs restantes (incluindo jobs concluídos)
        $allJobs = Get-Job -ErrorAction SilentlyContinue
        if ($allJobs) {
            Write-InstallLog "Removendo $($allJobs.Count) job(s) restante(s)..."
            Remove-Job -Job $allJobs -Force -ErrorAction SilentlyContinue
        }
        
        Write-InstallLog "Limpeza de jobs concluída com sucesso" -Status "SUCESSO"
    }
    catch {
        Write-InstallLog "Erro durante a limpeza de jobs: $($_.Exception.Message)" -Status "AVISO"
    }

    # Restaurar as configurações de suspensão
    if ($global:ScriptContext.AvoidSleep) {
        Set-AvoidSleep -Silent $true
    }

    # Limpar o contexto global do script
    if ($global:ScriptContext) {
        Remove-Variable -Name ScriptContext -Scope Global -Force -ErrorAction SilentlyContinue
        Write-InstallLog "Contexto global do script limpo com sucesso" -Status "SUCESSO"
    }
    
    Write-InstallLog "Rotinas de limpeza concluídas" -Status "SUCESSO"
}
