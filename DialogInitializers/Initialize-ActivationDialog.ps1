function Get-ActivationDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuração do diÃ¡logo ActivationDialog.
    #>
    return {
        param($activationDialogWindow)

        $oemKeyTextBox             = $activationDialogWindow.FindName("OemKeyTextBox")
        $copyOemKeyButton          = $activationDialogWindow.FindName("CopyOemKeyButton")
        $findOemKeyButton          = $activationDialogWindow.FindName("FindOemKeyButton")
        $activateOemButton         = $activationDialogWindow.FindName("ActivateOemButton")
        $activateWindowsMasButton  = $activationDialogWindow.FindName("ActivateWindowsMasButton")

        # Se jÃ¡ existe chave OEM carregada, pré-configurar interface
        if (-not [String]::IsNullOrWhiteSpace($global:ScriptContext.Config.OemKey)) {
            $oemKeyTextBox.Text = $global:ScriptContext.Config.OemKey
            $oemKeyTextBox.FontFamily = "Cascadia Mono"
            $copyOemKeyButton.Visibility = "Visible"
            $findOemKeyButton.IsEnabled = $false
            $findOemKeyButton.Background = $global:PSConst.Colors.Disabled
            $activateOemButton.Background = $global:PSConst.Colors.SuccessAlt
            $activateOemButton.IsEnabled = $true
        }

        #  Localizar chave OEM 
        $findOemKeyButton.Add_Click({
            $productKey = $null
            try {
                $productKey = (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey

                $textBox     = $activationDialogWindow.FindName("OemKeyTextBox")
                $findBtn     = $activationDialogWindow.FindName("FindOemKeyButton")
                $activateBtn = $activationDialogWindow.FindName("ActivateOemButton")
                $copyBtn     = $activationDialogWindow.FindName("CopyOemKeyButton")

                if (-not [string]::IsNullOrWhiteSpace($productKey)) {
                    $textBox.FontFamily = "Cascadia Mono"
                    $textBox.Text = $productKey
                    $global:ScriptContext.Config.OemKey = $productKey
                    Write-InstallLog "Chave OEM encontrada: $productKey"
                    Write-InstallLog "Clique em Ativar para usar a chave encontrada"
                    Show-Notification -Title "Chave OEM encontrada`n$productKey" -Message "Clique em Ativar para usar a chave encontrada."

                    $activateBtn.Background = $global:PSConst.Colors.SuccessAlt
                    $activateBtn.IsEnabled  = $true
                    $copyBtn.Visibility     = "Visible"
                }
                else {
                    $textBox.Text = "Chave OEM não encontrada. Use o ativador MAS"
                    Write-InstallLog "Nenhuma chave OEM encontrada no BIOS"
                    $activateBtn.IsEnabled = $false
                }
                $findBtn.IsEnabled  = $false
                $findBtn.Background = $global:PSConst.Colors.Disabled
            }
            catch {
                $errorMsg = "Falha ao buscar chave OEM: $($_.Exception.Message)"
                $textBox = $activationDialogWindow.FindName("OemKeyTextBox")
                if ($textBox) { $textBox.Text = "Erro ao buscar chave OEM" }
                Write-InstallLog $errorMsg -Status "ERRO"
                $activateBtn = $activationDialogWindow.FindName("ActivateOemButton")
                if ($activateBtn) { $activateBtn.IsEnabled = $false }
            }
        })

        #  Copiar chave OEM 
        $copyOemKeyButton.Add_Click({
            try {
                $textBox = $activationDialogWindow.FindName("OemKeyTextBox")
                if ($textBox) {
                    $textToCopy = $textBox.Text
                    if (-not [string]::IsNullOrWhiteSpace($textToCopy) -and
                        $textToCopy -ne "Clique no botão abaixo para buscar pela chave OEM") {
                        Set-Clipboard -Value $textToCopy
                        Write-InstallLog "Chave OEM copiada para a Ã¡rea de transferÃªncia"
                    }
                    else {
                        Write-InstallLog "Nenhuma chave OEM vÃ¡lida para copiar" -Status "AVISO"
                    }
                }
            }
            catch {
                Write-InstallLog "Erro ao copiar chave OEM: $($_.Exception.Message)" -Status "ERRO"
            }
        })

        #  Ativar com chave OEM 
        $activateOemButton.Add_Click({
            $thisButton = $activationDialogWindow.FindName("ActivateOemButton")
            $textBox    = $activationDialogWindow.FindName("OemKeyTextBox")
            $thisButton.IsEnabled = $false

            $productKey = $textBox.Text
            $invalidValues = @(
                "Clique no botão abaixo para buscar pela chave OEM",
                "Não encontrada",
                "Erro ao buscar"
            )
            if ($invalidValues -contains $productKey -or [string]::IsNullOrWhiteSpace($productKey)) {
                Write-InstallLog "Nenhuma chave OEM vÃ¡lida para ativar encontrada ou inserida"
                return
            }

            try {
                Write-InstallLog "Tentando ativar o sistema usando a chave OEM encontrada..."
                $SLSvc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
                $null = Invoke-CimMethod -InputObject $SLSvc -MethodName InstallProductKey -Arguments @{ ProductKey = $productKey } -ErrorAction Stop
                $null = Invoke-CimMethod -InputObject $SLSvc -MethodName RefreshLicenseStatus -ErrorAction Stop
                Start-Sleep -Seconds 3
                $licenseInfo = Get-CimInstance -Query 'SELECT LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID = "55c92734-d682-4d71-983e-d6ec3f16059f" AND PartialProductKey IS NOT NULL' | Select-Object -First 1

                $licensedStatus = $global:PSConst.WindowsLicense.Licensed
                if ($licenseInfo -and $licenseInfo.LicenseStatus -eq $licensedStatus) {
                    Write-InstallLog "Ativação bem sucedida" -Status "SUCESSO"
                    $thisButton.IsEnabled = $false
                    $thisButton.Content   = "Windows ativado!"
                    $thisButton.Background = $global:PSConst.Colors.Disabled
                }
                else {
                    $currentStatus = if ($licenseInfo) { $licenseInfo.LicenseStatus } else { "Não determinado" }
                    $productKey | Set-Clipboard
                    $msg = "Falha ao ativar o Windows usando a chave OEM. Status atual da licença: $currentStatus. A chave foi copiada para a Ã¡rea de transferÃªncia. Tente ativar manualmente."
                    Write-InstallLog $msg -Status "ERRO"
                    $thisButton.IsEnabled  = $false
                    $thisButton.Content    = "Erro!"
                    $thisButton.Background = $global:PSConst.Colors.Error
                    Show-MessageDialog -Message $msg -Title "Ativação do sistema" -MessageType "Error" -Buttons "OK"
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                if ($_.Exception.InnerException) { $errorMessage += " Detalhes: $($_.Exception.InnerException.Message)" }
                Write-InstallLog "Erro durante a ativação OEM: $errorMessage" -Status "ERRO"
                $thisButton.IsEnabled  = $false
                $thisButton.Content    = "Erro!"
                $thisButton.Background = $global:PSConst.Colors.Error
                Show-MessageDialog -Message "Erro durante a ativação OEM: $errorMessage" -Title "Ativação do sistema" -MessageType "Error" -Buttons "OK"
            }
        })

        #  Abrir ativador MAS 
        $activateWindowsMasButton.Add_Click({
            Write-InstallLog "Abrindo ativador MAS..."
            try {
                Show-Notification -Title "Abrindo ativador MAS" -Message "Aguarde enquanto o script é baixado."
                $jobNameMAS = "MAS_Activation_Job"
                Get-Job -Name $jobNameMAS -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

                $scriptBlockMAS = {
                    try { Invoke-Expression (Invoke-RestMethod -Uri https://get.activated.win) }
                    catch { Write-InstallLog "Erro dentro do job MAS: $($_.Exception.Message)" -Status "ERRO" }
                }
                Start-Job -Name $jobNameMAS -ScriptBlock $scriptBlockMAS | Out-Null
            }
            catch {
                $errorMessage = "Erro ao tentar iniciar o ativador MAS: $($_.Exception.Message)"
                Write-InstallLog $errorMessage -Status "ERRO"
                Show-MessageDialog -Message "$errorMessage.`nVerifique a conexão com a internet." -Title "Ativação do Sistema" -MessageType "Error" -Buttons "OK"
            }
        })
    }
}

