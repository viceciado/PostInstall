function global:Show-XamlDialog {
    <#
    .SYNOPSIS
    Abre um diálogo XAML de forma padronizada com funcionalidades comuns
    
    .DESCRIPTION
    Cria e exibe um diálogo XAML com funcionalidades padrão como arrastar janela,
    configurações básicas e permite executar configurações específicas através de um ScriptBlock
    
    .PARAMETER XamlContent
    O conteúdo XAML da janela a ser criada
    
    .PARAMETER Owner
    A janela pai que será proprietária do diálogo
    
    .PARAMETER ConfigureDialog
    ScriptBlock que será executado para configurar eventos específicos do diálogo
    O diálogo criado será passado como parâmetro $dialog para o ScriptBlock
    
    .PARAMETER ShowModal
    Se verdadeiro, exibe o diálogo como modal (ShowDialog). Se falso, apenas Show.
    Padrão: $true
    
    .EXAMPLE
    Show-XamlDialog -XamlContent $activationDialogXaml -Owner $xamlWindow -ConfigureDialog {
        param($dialog)
        # Configurações específicas do diálogo de ativação
        $button = $dialog.FindName("MyButton")
        $button.Add_Click({ Write-Host "Clicked!" })
    }
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlContent,
        
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner,
        
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$ConfigureDialog,
        
        [Parameter(Mandatory = $false)]
        [bool]$ShowModal = $true
    )
    
    try {
        # Criar nova instância do diálogo
        $dialog = New-XamlDialog -XamlContent $XamlContent -Owner $Owner
        
        # Configurar funcionalidade padrão de arrastar janela
        $dialogBorder = $dialog.FindName("DialogBorder")
        if ($dialogBorder) {
            $dialogBorder.Add_MouseDown({
                param($sender, $e)
                if ($e.LeftButton -eq 'Pressed') {
                    $wnd = [System.Windows.Window]::GetWindow($sender)
                    if ($wnd) { $wnd.DragMove() }
                }
            })
        }

        # Botão de fechar da barra de título (padronizado para todas as janelas)
        $closeButton = $dialog.FindName("CloseButton")
        if ($closeButton) {
            $closeButton.Add_Click({
                    param($senderParam, $eParam)
                    $wnd = [System.Windows.Window]::GetWindow($senderParam)
                    if ($wnd) { $wnd.Close() }
                })
        }
        
        # Fechar diálogo ao pressionar a tecla Esc
        $dialog.Add_KeyDown({
            param($sender, $e)
            if ($e.Key -eq 'Escape') {
                if ($sender -is [System.Windows.Window]) { $sender.Close() }
            }
        })
        
        # Executar configurações específicas do diálogo se fornecidas
        if ($ConfigureDialog) {
            & $ConfigureDialog $dialog
        }
        
        # Exibir o diálogo
        if ($ShowModal) {
            return $dialog.ShowDialog()
        } else {
            $dialog.Show()
            return $dialog
        }
    }
    catch {
        Write-InstallLog "Erro ao abrir diálogo XAML: $($_.Exception.Message)" -Status "ERRO"
        throw
    }
}