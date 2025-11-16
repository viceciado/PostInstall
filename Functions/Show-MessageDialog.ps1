function global:Show-MessageDialog {
    <#
    .SYNOPSIS
    Exibe um diálogo de mensagem personalizado no estilo da aplicação
    
    .DESCRIPTION
    Substitui System.Windows.Forms.MessageBox com um diálogo XAML personalizado
    que segue o padrão visual da aplicação. Funciona independentemente da MainWindow.
    
    .PARAMETER Message
    Texto da mensagem a ser exibida
    
    .PARAMETER Title
    Título da janela do diálogo
    
    .PARAMETER MessageType
    Tipo da mensagem que determina o ícone: Info, Warning, Error, Question
    
    .PARAMETER Buttons
    Tipo de botões: OK, OKCancel, YesNo, YesNoCancel
    
    .PARAMETER Owner
    Janela pai (opcional, usa $global:XamlMainWindow se disponível)
    
    .EXAMPLE
    Show-MessageDialog -Message "Operação concluída com sucesso!" -Title "Sucesso" -MessageType "Info"
    
    .EXAMPLE
    $result = Show-MessageDialog -Message "Deseja continuar?" -Title "Confirmação" -MessageType "Question" -Buttons "YesNo"
    if ($result -eq "Yes") { Write-Host "Usuário confirmou" }
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Question", "Connection")]
        [string]$MessageType = "Info",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel", "RetryCancel")]
        [string]$Buttons = "OK",
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner
    )
    
    try {
        # Carregar XAML do MessageDialog
        $xamlContent = Get-XamlByWindowName -WindowName 'MessageDialog'
        if (-not $xamlContent) {
            throw "MessageDialog XAML não encontrado"
        }
        
        # Resolver owner automaticamente se não especificado
        # Verifica se MainWindow está disponível e é uma janela válida
        if (-not $Owner -and $global:XamlMainWindow -and $global:XamlMainWindow -is [System.Windows.Window] -and $global:XamlMainWindow.IsLoaded) {
            $Owner = $global:XamlMainWindow
        }
        
        # Criar diálogo
        $dialog = New-XamlDialog -XamlContent $xamlContent -Owner $Owner
        
        # Configurar propriedades para janela independente quando não há Owner
        if (-not $Owner) {
            $dialog.WindowStartupLocation = "CenterScreen"
            $dialog.Topmost = $true
            $dialog.ShowInTaskbar = $true
        } else {
            $dialog.WindowStartupLocation = "CenterOwner"
            $dialog.ShowInTaskbar = $false
        }
        
        # Configurar funcionalidade de arrastar
        $dialogBorder = $dialog.FindName("DialogBorder")
        if ($dialogBorder) {
            $dialogBorder.Add_MouseDown({
                param($sender, $e)
                if ($e.LeftButton -eq 'Pressed') {
                    $dialog.DragMove()
                }
            })
        }
        
        # Obter referências aos controles
        $titleText = $dialog.FindName("TitleText")
        $messageText = $dialog.FindName("MessageText")
        $iconText = $dialog.FindName("IconText")
        $button1 = $dialog.FindName("Button1")
        $button2 = $dialog.FindName("Button2")
        $button3 = $dialog.FindName("Button3")
        $closeButton = $dialog.FindName("CloseButton")
        
        # Configurar título e mensagem
        if ($titleText) { $titleText.Text = $Title }
        if (-not [string]::IsNullOrWhiteSpace($Title)) { $dialog.Title = $Title }
        if ($messageText) { $messageText.Text = $Message }
        
        # Configurar ícone baseado no tipo de mensagem
        if ($iconText) {
            switch ($MessageType) {
                "Info" {
                    $iconText.Text = [char]0xE946  # Info icon (Segoe MDL2 Assets)
                    $iconText.Foreground = "#007ACC"
                }
                "Warning" {
                    $iconText.Text = [char]0xE7BA  # Warning icon (Segoe MDL2 Assets)
                    $iconText.Foreground = "#FF8C00"
                }
                "Error" {
                    $iconText.Text = [char]0xE783  # Error icon (Segoe MDL2 Assets)
                    $iconText.Foreground = "#E81123"
                }
                "Question" {
                    $iconText.Text = [char]0xE9CE  # Help icon (Segoe MDL2 Assets)
                    $iconText.Foreground = "#0078D4"
                }
                "Connection" {
                    $iconText.Text = [char]0xEB55  # Connection icon (Segoe MDL2 Assets)
                    $iconText.Foreground = "#FF8C00"
                }
            }
        }
        
        # Variável para armazenar o resultado (usando script scope para garantir acesso)
        $script:dialogResult = $null
        
        # Configurar botões baseado no tipo
        switch ($Buttons) {
            "OK" {
                if ($button1) {
                    $button1.Content = "OK"
                    $button1.Visibility = "Visible"
                    $button1.Add_Click({
                        $script:dialogResult = "OK"
                        $dialog.Close()
                    })
                }
                if ($button2) { $button2.Visibility = "Collapsed" }
                if ($button3) { $button3.Visibility = "Collapsed" }
            }
            "OKCancel" {
                if ($button1) {
                    $button1.Content = "OK"
                    $button1.Visibility = "Visible"
                    $button1.Add_Click({
                        $script:dialogResult = "OK"
                        $dialog.Close()
                    })
                }
                if ($button2) {
                    $button2.Content = "Cancelar"
                    $button2.Visibility = "Visible"
                    $button2.Add_Click({
                        $script:dialogResult = "Cancel"
                        $dialog.Close()
                    })
                }
                if ($button3) { $button3.Visibility = "Collapsed" }
            }
            "RetryCancel" {
                if ($button1) {
                    $button1.Content = "Tentar novamente"
                    $button1.Visibility = "Visible"
                    $button1.Add_Click({
                        $script:dialogResult = "Retry"
                        $dialog.Close()
                    })
                }
                if ($button2) {
                    $button2.Content = "Sair"
                    $button2.Visibility = "Visible"
                    $button2.Add_Click({
                        $script:dialogResult = "Cancel"
                        $dialog.Close()
                    })
                }
                if ($button3) { $button3.Visibility = "Collapsed" }
            }
            "YesNo" {
                if ($button1) {
                    $button1.Content = "Sim"
                    $button1.Visibility = "Visible"
                    $button1.Add_Click({
                        $script:dialogResult = "Yes"
                        $dialog.Close()
                    })
                }
                if ($button2) {
                    $button2.Content = "Não"
                    $button2.Visibility = "Visible"
                    $button2.Add_Click({
                        $script:dialogResult = "No"
                        $dialog.Close()
                    })
                }
                if ($button3) { $button3.Visibility = "Collapsed" }
            }
            "YesNoCancel" {
                if ($button1) {
                    $button1.Content = "Sim"
                    $button1.Visibility = "Visible"
                    $button1.Add_Click({
                        $script:dialogResult = "Yes"
                        $dialog.Close()
                    })
                }
                if ($button2) {
                    $button2.Content = "Não"
                    $button2.Visibility = "Visible"
                    $button2.Add_Click({
                        $script:dialogResult = "No"
                        $dialog.Close()
                    })
                }
                if ($button3) {
                    $button3.Content = "Cancelar"
                    $button3.Visibility = "Visible"
                    $button3.Add_Click({
                        $script:dialogResult = "Cancel"
                        $dialog.Close()
                    })
                }
            }
        }
        
        # Configurar botão de fechar (X)
        if ($closeButton) {
            $closeButton.Add_Click({
                $script:dialogResult = "Cancel"
                $dialog.Close()
            })
        }
        
        # Configurar tecla ESC para fechar
        $dialog.Add_KeyDown({
            param($sender, $e)
            if ($e.Key -eq "Escape") {
                $script:dialogResult = "Cancel"
                $dialog.Close()
            }
        })
        
        # Exibir diálogo modal
        $dialog.ShowDialog() | Out-Null
        
        # Garantir que temos um resultado válido
        if (-not $script:dialogResult) {
            Write-InstallLog "Diálogo fechado sem resultado definido, assumindo Cancel" -Status "AVISO"
            $script:dialogResult = "Cancel"
        }
        
        # Retornar resultado
        return $script:dialogResult
    }
    catch {
        Write-InstallLog "Erro ao exibir MessageDialog: $($_.Exception.Message)" -Status "ERRO"
        
        # Fallback para MessageBox nativo em caso de erro
        Write-Warning "Usando MessageBox nativo como fallback"
        
        # Configurar tipo de botão para MessageBox nativo
        $nativeButtons = switch ($Buttons) {
            "OK" { [System.Windows.Forms.MessageBoxButtons]::OK }
            "OKCancel" { [System.Windows.Forms.MessageBoxButtons]::OKCancel }
            "RetryCancel" { [System.Windows.Forms.MessageBoxButtons]::RetryCancel }
            "YesNo" { [System.Windows.Forms.MessageBoxButtons]::YesNo }
            "YesNoCancel" { [System.Windows.Forms.MessageBoxButtons]::YesNoCancel }
            default { [System.Windows.Forms.MessageBoxButtons]::OK }
        }
        
        # Configurar ícone para MessageBox nativo
        $nativeIcon = switch ($MessageType) {
            "Info" { [System.Windows.Forms.MessageBoxIcon]::Information }
            "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
            "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
            "Question" { [System.Windows.Forms.MessageBoxIcon]::Question }
            "Connection" { [System.Windows.Forms.MessageBoxIcon]::Question }
            default { [System.Windows.Forms.MessageBoxIcon]::Information }
        }
        
        # Carregar assembly se necessário
        Add-Type -AssemblyName System.Windows.Forms
        
        $nativeResult = [System.Windows.Forms.MessageBox]::Show($Message, $Title, $nativeButtons, $nativeIcon)
        
        # Converter resultado do MessageBox nativo para nosso formato
        $convertedResult = switch ($nativeResult) {
            "OK" { "OK" }
            "Cancel" { "Cancel" }
            "Retry" { "Retry" }
            "Yes" { "Yes" }
            "No" { "No" }
            default { "Cancel" }
        }
        
        return $convertedResult
    }
}