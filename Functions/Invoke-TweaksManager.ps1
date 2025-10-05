function global:Get-TweakByName {
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )
    try {
        $allTweaks = Get-AvailableItems -ItemType "Tweaks"
        return $allTweaks | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    }
    catch {
        Write-InstallLog "Erro ao obter tweak '$Name': $($_.Exception.Message)" -Status "ERRO"
        return $null
    }
}

function global:ConvertTo-RegistryType {
    param([string]$Type)
    $t = if ($Type) { $Type.ToUpperInvariant() } else { '' }
    switch ($t) {
        'REG_DWORD' { return @{ Up='DWORD'; Ps='DWord' } }
        'DWORD'     { return @{ Up='DWORD'; Ps='DWord' } }
        'REG_QWORD' { return @{ Up='QWORD'; Ps='QWord' } }
        'QWORD'     { return @{ Up='QWORD'; Ps='QWord' } }
        'REG_SZ'    { return @{ Up='STRING'; Ps='String' } }
        'STRING'    { return @{ Up='STRING'; Ps='String' } }
        'REG_EXPAND_SZ' { return @{ Up='EXPANDSTRING'; Ps='ExpandString' } }
        'EXPANDSTRING'  { return @{ Up='EXPANDSTRING'; Ps='ExpandString' } }
        'REG_BINARY' { return @{ Up='BINARY'; Ps='Binary' } }
        'BINARY'     { return @{ Up='BINARY'; Ps='Binary' } }
        'REG_MULTI_SZ' { return @{ Up='MULTISTRING'; Ps='MultiString' } }
        'MULTISTRING'  { return @{ Up='MULTISTRING'; Ps='MultiString' } }
        default { return @{ Up=$t; Ps=$Type } }
    }
}

function global:Apply-RegistryEntry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Type,
        [Parameter(Mandatory=$false)]$Value
    )
    try {
        $norm = ConvertTo-RegistryType -Type $Type
        $typeUpper = $norm.Up
        $psPropertyType = $norm.Ps
        if ($typeUpper -eq 'DELETEKEY') {
            if (Test-Path -Path $Path) {
                Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
                Write-InstallLog "Chave removida: $Path"
            } else {
                Write-InstallLog "Chave não encontrada para remover: $Path" -Status "AVISO"
            }
            return $true
        }

        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $existing = if ($Name) { Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue } else { $null }

        # Converter valor conforme o tipo
        $convertedValue = $Value
        switch ($typeUpper) {
            'DWORD' { $convertedValue = [int]$Value }
            'QWORD' { $convertedValue = [long]$Value }
            'STRING' { $convertedValue = [string]$Value }
            'EXPANDSTRING' { $convertedValue = [string]$Value }
            'BINARY' {
                if ($Value -is [string]) { $convertedValue = ($Value -split ',') | ForEach-Object { [byte]$_ } }
            }
            'MULTISTRING' { if ($Value -isnot [array]) { $convertedValue = @([string]$Value) } }
            default { $convertedValue = $Value }
        }

        if ($null -ne $existing) {
            if ($Name) {
                Set-ItemProperty -Path $Path -Name $Name -Value $convertedValue -ErrorAction Stop
            }
        } else {
            if ($Name) {
                New-ItemProperty -Path $Path -Name $Name -PropertyType $psPropertyType -Value $convertedValue -Force -ErrorAction Stop | Out-Null
            }
        }
        Write-InstallLog "Registro aplicado: $Path :: $Name = $convertedValue ($typeUpper/$psPropertyType)"
        return $true
    }
    catch {
        Write-InstallLog "Falha ao aplicar registro ($Path::$Name): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

function global:Undo-RegistryEntry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$false)][string]$Name,
        [Parameter(Mandatory=$false)]$OriginalValue,
        [Parameter(Mandatory=$false)][string]$Type
    )
    try {
        $norm = ConvertTo-RegistryType -Type $Type
        $typeUpper = $norm.Up

        # Tratar DeleteKey antes de qualquer verificação de existência
        if ($typeUpper -eq 'DELETEKEY') {
            if (($OriginalValue -as [string]) -eq '<RestoreKey>') {
                if (-not (Test-Path -Path $Path)) {
                    New-Item -Path $Path -Force | Out-Null
                    Write-InstallLog "Chave restaurada (recriada): $Path"
                } else {
                    Write-InstallLog "Chave já existe; nada a restaurar: $Path" -Status "AVISO"
                }
                return $true
            } else {
                # Nada a desfazer quando o objetivo era apenas remover a chave
                Write-InstallLog "Nada a desfazer para DeleteKey: $Path" -Status "AVISO"
                return $true
            }
        }

        if (-not (Test-Path -Path $Path)) {
            Write-InstallLog "Chave não existe para restaurar: $Path" -Status "AVISO"
            return $false
        }

        if ($Name) {
            if ($null -ne $OriginalValue) {
                # Se o marcador indicar remoção da entrada, remover a propriedade
                if (($OriginalValue -as [string]) -eq '<RemoveEntry>') {
                    $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                    if ($null -ne $existing) {
                        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
                        Write-InstallLog "Entrada de registro removida: $Path :: $Name"
                    } else {
                        Write-InstallLog "Entrada não existe para remover: $Path :: $Name" -Status "AVISO"
                    }
                    return $true
                }

                # Converter conforme tipo quando possível
                $convertedValue = $OriginalValue
                switch ($typeUpper) {
                    'DWORD' { $convertedValue = [int]$OriginalValue }
                    'QWORD' { $convertedValue = [long]$OriginalValue }
                    'MULTISTRING' { if ($OriginalValue -isnot [array]) { $convertedValue = @([string]$OriginalValue) } }
                    default { $convertedValue = $OriginalValue }
                }
                Set-ItemProperty -Path $Path -Name $Name -Value $convertedValue -ErrorAction Stop
                Write-InstallLog "Registro restaurado: $Path :: $Name = $convertedValue"
                return $true
            } else {
                Write-InstallLog "Valor original ausente para desfazer: $Path::$Name" -Status "AVISO"
                return $false
            }
        }
        return $false
    }
    catch {
        Write-InstallLog "Falha ao desfazer registro ($Path::$Name): $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

function global:Restart-Explorer {
    try {
        Write-InstallLog "Reiniciando o Explorer para aplicar alterações..."
        $explorers = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($explorers) { Stop-Process -Id ($explorers.Id) -Force -ErrorAction SilentlyContinue }
        # Start-Process explorer.exe
        # Write-InstallLog "Explorer reiniciado."
    }
    catch {
        Write-InstallLog "Falha ao reiniciar o Explorer: $($_.Exception.Message)" -Status "AVISO"
    }
}

function global:Set-Tweak {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [switch]$SkipPowerActions
    )
    try {
        $tweak = Get-TweakByName -Name $Name
        if ($null -eq $tweak) { Write-InstallLog "Tweak não encontrado: $Name" -Status "ERRO"; return $false }

        # Determinar scripts a executar (suporta Command ou InvokeScript)
        $scripts = @()
        if ($tweak.PSObject.Properties.Name -contains 'Command' -and $tweak.Command) { $scripts += $tweak.Command }
        if ($tweak.PSObject.Properties.Name -contains 'InvokeScript' -and $tweak.InvokeScript) { $scripts += $tweak.InvokeScript }

        # Aplicar entradas de registro
        $regAppliedAll = $true
        if ($tweak.Registry) {
            foreach ($entry in $tweak.Registry) {
                # Suporte a DeleteKey como propriedade booleana
                if (($entry.PSObject.Properties.Name -contains 'DeleteKey') -and $entry.DeleteKey) {
                    try {
                        if (Test-Path -Path $entry.Path) {
                            Remove-Item -Path $entry.Path -Force -Recurse -ErrorAction SilentlyContinue
                            Write-InstallLog "Chave removida: $($entry.Path)"
                        } else {
                            Write-InstallLog "Chave não encontrada para remover: $($entry.Path)" -Status "AVISO"
                        }
                    }
                    catch {
                        Write-InstallLog "Falha ao remover chave '$($entry.Path)': $($_.Exception.Message)" -Status "ERRO"
                        $regAppliedAll = $false
                    }
                    continue
                }

                $ok = Apply-RegistryEntry -Path $entry.Path -Name $entry.Name -Type $entry.Type -Value $entry.Value
                if (-not $ok) { $regAppliedAll = $false }
            }
        }

        # Executar scripts
        $scriptAppliedAll = $true
        foreach ($line in $scripts) {
            if ($SkipPowerActions -and ($line -match '(?i)Stop-Computer|Restart-Computer|\bshutdown(\.exe)?\b')) {
                Write-InstallLog "Ação de energia ignorada em '$Name': $line" -Status "AVISO"
                continue
            }
            try {
                Invoke-Expression $line
                Write-InstallLog "Script executado para '$Name': $line"
            }
            catch {
                Write-InstallLog "Erro ao executar script para '$Name': $($_.Exception.Message)" -Status "ERRO"
                $scriptAppliedAll = $false
            }
        }

        $success = $regAppliedAll -and $scriptAppliedAll
        
        # Só armazenar no AppliedTweaks se o tweak for reversível (IsBoolean: true)
        if ($success -and $tweak.IsBoolean -eq $true) {
            if ($null -eq $global:ScriptContext.AppliedTweaks) { $global:ScriptContext.AppliedTweaks = @{} }
            $global:ScriptContext.AppliedTweaks[$Name] = (Get-Date)
        }
        
        return $success
    }
    catch {
        Write-InstallLog "Falha ao aplicar tweak '$Name': $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

function global:Undo-Tweak {
    param(
        [Parameter(Mandatory=$true)][string]$Name
    )
    try {
        $tweak = Get-TweakByName -Name $Name
        if ($null -eq $tweak) { Write-InstallLog "Tweak não encontrado (desfazer): $Name" -Status "ERRO"; return $false }

        # Desfazer via registro quando houver OriginalValue
        $regUndoAll = $true
        if ($tweak.Registry) {
            foreach ($entry in $tweak.Registry) {
                if (($entry.PSObject.Properties.Name -contains 'DeleteKey') -and $entry.DeleteKey) {
                    # Desfazer remoção de chave: recriar quando OriginalValue == <RestoreKey>
                    $ok = Undo-RegistryEntry -Path $entry.Path -OriginalValue $entry.OriginalValue -Type 'DeleteKey'
                }
                else {
                    $ok = Undo-RegistryEntry -Path $entry.Path -Name $entry.Name -OriginalValue $entry.OriginalValue -Type $entry.Type
                }
                if (-not $ok) { $regUndoAll = $false }
            }
        }

        # Desfazer via scripts (UndoCommand/UndoScript)
        $undoScripts = @()
        if ($tweak.PSObject.Properties.Name -contains 'UndoCommand' -and $tweak.UndoCommand) { $undoScripts += $tweak.UndoCommand }
        if ($tweak.PSObject.Properties.Name -contains 'UndoScript' -and $tweak.UndoScript) { $undoScripts += $tweak.UndoScript }

        $undoScriptAll = $true
        foreach ($line in $undoScripts) {
            try {
                Invoke-Expression $line
                Write-InstallLog "Undo script executado para '$Name': $line"
            }
            catch {
                Write-InstallLog "Erro ao desfazer script para '$Name': $($_.Exception.Message)" -Status "ERRO"
                $undoScriptAll = $false
            }
        }

        if ($regUndoAll -and $undoScriptAll) { return $true } else { return $false }
    }
    catch {
        Write-InstallLog "Falha ao desfazer tweak '$Name': $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
}

function global:Invoke-TweaksManager {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][array]$Tweaks,
        [Parameter(Mandatory=$false)][array]$Names,
        [Parameter(Mandatory=$true)][ValidateSet('Apply','Undo')][string]$Mode,
        [switch]$SkipPowerActions
    )

    # Inicializar armazenamento
    if ($null -eq $global:ScriptContext.AppliedTweaks) { $global:ScriptContext.AppliedTweaks = @{} }

    # Resolver nomes
    $targetNames = @()
    if ($Tweaks -and $Tweaks.Count -gt 0) {
        $targetNames += ($Tweaks | ForEach-Object { if ($_.Tag) { $_.Tag.Name } elseif ($_.Name) { $_.Name } else { $_ } })
    }
    if ($Names -and $Names.Count -gt 0) { $targetNames += $Names }
    $targetNames = $targetNames | Where-Object { $_ } | Select-Object -Unique

    if ($targetNames.Count -eq 0) {
        Write-InstallLog "Nenhum tweak selecionado para $Mode" -Status "AVISO"
        return
    }

    $successCount = 0
    foreach ($name in $targetNames) {
        if ($Mode -eq 'Apply') {
            $result = Invoke-ElevatedProcess -FunctionName 'Set-Tweak' -Parameters @{ Name = $name; SkipPowerActions = [bool]$SkipPowerActions } -PassThru
            if ($result -match 'True') {
                $successCount++
            }
        } else {
            $result = Invoke-ElevatedProcess -FunctionName 'Undo-Tweak' -Parameters @{ Name = $name } -PassThru
            if ($result -match 'True') {
                $successCount++
                if ($global:ScriptContext.AppliedTweaks.ContainsKey($name)) { $global:ScriptContext.AppliedTweaks.Remove($name) | Out-Null }
            }
        }
    }

    if ($Mode -eq 'Apply') {
        Write-InstallLog "Tweaks aplicados com sucesso: $successCount de $($targetNames.Count)"
    } else {
        Write-InstallLog "Tweaks desfeitos com sucesso: $successCount de $($targetNames.Count)"
    }

    # Avaliar e realizar refresh do Explorer quando requerido
    try {
        $requiresRefresh = $false
        foreach ($n in $targetNames) {
            $tw = Get-TweakByName -Name $n
            if ($tw -and $tw.RefreshRequired) { $requiresRefresh = $true; break }
        }
        if ($requiresRefresh) { Restart-Explorer }
    }
    catch {
        Write-InstallLog "Falha ao avaliar/realizar refresh do Explorer: $($_.Exception.Message)" -Status "AVISO"
    }
}