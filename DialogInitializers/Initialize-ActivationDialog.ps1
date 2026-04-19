function Get-ActivationDialogConfiguration {
    <#
    .SYNOPSIS
        Retorna o ScriptBlock de configuraÃ§Ã£o do diÃ¡logo ActivationDialog.
    #>
    return {
        param($activationDialogWindow)

        $oemKeyTextBox             = $activationDialogWindow.FindName("OemKeyTextBox")
        $copyOemKeyButton          = $activationDialogWindow.FindName("CopyOemKeyButton")
        $findOemKeyButton          = $activationDialogWindow.FindName("FindOemKeyButton")
        $activateOemButton         = $activationDialogWindow.FindName("ActivateOemButton")
        $activateWindowsMasButton  = $activationDialogWindow.FindName("ActivateWindowsMasButton")

        # Se jÃ¡ existe chave OEM carregada, prÃ©-configurar interface
        if (-not [String]::IsNullOrWhiteSpace($global:ScriptContext.Config.OemKey)) {
            $oemKeyTextBox.Text = $global:ScriptContext.Config.OemKey
            $oemKeyTextBox.FontFamily = "Cascadia Mono"
            $copyOemKeyButton.Visibility = "Visible"
            $findOemKeyButton.IsEnabled = $false
            $findOemKeyButton.Background = "#555555"
            $activateOemButton.Background = "#4CAF50"
            $activateOemButton.IsEnabled = $true
        }

        # â”€â”€ Localizar chave OEM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                    $activateBtn.Background = "#4CAF50"
                    $activateBtn.IsEnabled  = $true
                    $copyBtn.Visibility     = "Visible"
                }
                else {
                    $textBox.Text = "Chave OEM nÃ£o encontrada. Use o ativador MAS"
                    Write-InstallLog "Nenhuma chave OEM encontrada no BIOS"
                    $activateBtn.IsEnabled = $false
                }
                $findBtn.IsEnabled  = $false
                $findBtn.Background = "#555555"
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

        # â”€â”€ Copiar chave OEM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $copyOemKeyButton.Add_Click({
            try {
                $textBox = $activationDialogWindow.FindName("OemKeyTextBox")
                if ($textBox) {
                    $textToCopy = $textBox.Text
                    if (-not [string]::IsNullOrWhiteSpace($textToCopy) -and
                        $textToCopy -ne "Clique no botÃ£o abaixo para buscar pela chave OEM") {
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

        # â”€â”€ Ativar com chave OEM â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $activateOemButton.Add_Click({
            $thisButton = $activationDialogWindow.FindName("ActivateOemButton")
            $textBox    = $activationDialogWindow.FindName("OemKeyTextBox")
            $thisButton.IsEnabled = $false

            $productKey = $textBox.Text
            $invalidValues = @(
                "Clique no botÃ£o abaixo para buscar pela chave OEM",
                "NÃ£o encontrada",
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

                $licensedStatus = if ($global:PSConst) { $global:PSConst.WindowsLicense.Licensed } else { 1 }
                if ($licenseInfo -and $licenseInfo.LicenseStatus -eq $licensedStatus) {
                    Write-InstallLog "AtivaÃ§Ã£o bem sucedida" -Status "SUCESSO"
                    $thisButton.IsEnabled = $false
                    $thisButton.Content   = "Windows ativado!"
                    $thisButton.Background = "#555555"
                }
                else {
                    $currentStatus = if ($licenseInfo) { $licenseInfo.LicenseStatus } else { "NÃ£o determinado" }
                    $productKey | Set-Clipboard
                    $msg = "Falha ao ativar o Windows usando a chave OEM. Status atual da licenÃ§a: $currentStatus. A chave foi copiada para a Ã¡rea de transferÃªncia. Tente ativar manualmente."
                    Write-InstallLog $msg -Status "ERRO"
                    $thisButton.IsEnabled  = $false
                    $thisButton.Content    = "Erro!"
                    $thisButton.Background = "#CC6666"
                    Show-MessageDialog -Message $msg -Title "AtivaÃ§Ã£o do sistema" -MessageType "Error" -Buttons "OK"
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                if ($_.Exception.InnerException) { $errorMessage += " Detalhes: $($_.Exception.InnerException.Message)" }
                Write-InstallLog "Erro durante a ativaÃ§Ã£o OEM: $errorMessage" -Status "ERRO"
                $thisButton.IsEnabled  = $false
                $thisButton.Content    = "Erro!"
                $thisButton.Background = "#CC6666"
                Show-MessageDialog -Message "Erro durante a ativaÃ§Ã£o OEM: $errorMessage" -Title "AtivaÃ§Ã£o do sistema" -MessageType "Error" -Buttons "OK"
            }
        })

        # â”€â”€ Abrir ativador MAS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        $activateWindowsMasButton.Add_Click({
            Write-InstallLog "Abrindo ativador MAS..."
            try {
                Show-Notification -Title "Abrindo ativador MAS" -Message "Aguarde enquanto o script Ã© baixado."
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
                Show-MessageDialog -Message "$errorMessage.`nVerifique a conexÃ£o com a internet." -Title "AtivaÃ§Ã£o do Sistema" -MessageType "Error" -Buttons "OK"
            }
        })
    }
}

