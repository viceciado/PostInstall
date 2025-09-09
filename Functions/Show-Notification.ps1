function global:Show-Notification {
    <#
    .SYNOPSIS
    Exibe uma notificação toast do Windows usando a API nativa
    
    .DESCRIPTION
    Cria e exibe uma notificação toast do Windows 10/11 usando a API Windows.UI.Notifications.
    A notificação aparece na área de notificações do sistema e desaparece automaticamente após 1 minuto.
    
    .PARAMETER Title
    Título da notificação toast
    
    .PARAMETER Message
    Texto principal da notificação toast. Aceita entrada via pipeline.
    
    .PARAMETER ExpirationMinutes
    Tempo em minutos para a notificação expirar (padrão: 1 minuto)
    
    .PARAMETER AppId
    Identificador da aplicação para a notificação (padrão: "PowerShell")
    
    .EXAMPLE
    Show-Notification -Title "Instalação Concluída" -Message "Todos os programas foram instalados com sucesso!"
    
    .EXAMPLE
    "Sistema atualizado" | Show-Notification -Title "Atualização"
    
    .EXAMPLE
    Show-Notification -Title "Aviso" -Message "Reinicialização necessária" -ExpirationMinutes 5
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [int]$ExpirationMinutes = 1,
        
        [Parameter(Mandatory = $false)]
        [string]$AppId = "Configuração do Windows"
    )
    
    try {
        # Carregar a API de notificações do Windows
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        
        # Obter template de notificação com título e texto
        $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        
        # Converter para XML manipulável
        $RawXml = [xml] $Template.GetXml()
        
        # Configurar título (primeiro elemento de texto)
        ($RawXml.toast.visual.binding.text | Where-Object {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($Title)) > $null
        
        # Configurar texto principal (segundo elemento de texto)
        ($RawXml.toast.visual.binding.text | Where-Object {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($Message)) > $null
        
        # Criar documento XML serializado
        $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $SerializedXml.LoadXml($RawXml.OuterXml)
        
        # Criar notificação toast
        $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
        $Toast.Tag = $AppId
        $Toast.Group = $AppId
        $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($ExpirationMinutes)
        
        # Criar notificador e exibir
        $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
        $Notifier.Show($Toast)
        
    } catch {        
        # Fallback: tentar usar Show-MessageDialog se disponível
        if (Get-Command Show-MessageDialog -ErrorAction SilentlyContinue) {
            Write-InstallLog "Usando Show-MessageDialog como fallback" 
            Show-MessageDialog -Message $Message -Title $Title
        } else {
            # Último recurso: Write-Host
            Write-Host "NOTIFICAÇÃO: $Title - $Message" -ForegroundColor Yellow
        }
    }
}