function global:Get-AvailableItems {
    <#
    .SYNOPSIS
    Carrega a lista de itens disponíveis do arquivo JSON (programas ou tweaks)
    
    .DESCRIPTION
    Lê o arquivo JSON especificado e retorna uma lista de itens
    disponíveis (programas para instalação via Winget ou tweaks do sistema)
    
    .PARAMETER JsonPath
    Caminho para o arquivo JSON. Se não especificado, usa o caminho padrão baseado no tipo
    
    .PARAMETER ItemType
    Tipo de item a carregar: 'Programs' ou 'Tweaks'
    
    .EXAMPLE
    $programs = Get-AvailableItems -ItemType "Programs"
    foreach ($program in $programs) {
        Write-Host "$($program.Name) - $($program.ProgramId)"
    }
    
    .EXAMPLE
    $tweaks = Get-AvailableItems -ItemType "Tweaks"
    foreach ($tweak in $tweaks) {
        Write-Host "$($tweak.Name) - $($tweak.Description)"
    }
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$JsonPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Programs", "Tweaks", "TweaksCategories")]
        [string]$ItemType
    )
    
    try {
        # Se estiver compilado e nenhum caminho explícito foi informado, use os dados embutidos
        if (-not $JsonPath -and $global:ScriptContext -and $global:ScriptContext.IsCompiled) {
            switch ($ItemType) {
                "Programs" {
                    if ($script:compiledPrograms) {
                        if ($script:compiledPrograms.PSObject.Properties.Name -contains 'programs') {
                            return $script:compiledPrograms.programs
                        }
                        else {
                            return $script:compiledPrograms
                        }
                    }
                }
                "Tweaks" {
                    if ($script:compiledTweaks) {
                        if ($script:compiledTweaks.PSObject.Properties.Name -contains 'Tweaks') {
                            return $script:compiledTweaks.Tweaks
                        }
                        else {
                            return $script:compiledTweaks
                        }
                    }
                }
                "TweaksCategories" {
                    if ($script:compiledTweaks) {
                        if ($script:compiledTweaks.PSObject.Properties.Name -contains 'TweaksCategories') {
                            return $script:compiledTweaks.TweaksCategories
                        }
                        elseif ($script:compiledTweaks.PSObject.Properties.Name -contains 'Tweaks') {
                            $names = $script:compiledTweaks.Tweaks |
                                ForEach-Object { $_.Category } |
                                Where-Object { $_ } |
                                ForEach-Object { $_ } |
                                Select-Object -Unique |
                                Sort-Object
                            return ($names | ForEach-Object { [PSCustomObject]@{ Name = $_; Description = $null; Icon = $null; Color = $null; IsRecommended = $false } })
                        }
                    }
                }
            }
            # Se caiu aqui, segue fluxo para tentar arquivo (fallback)
        }

        # Modo não compilado ou com JsonPath explícito: resolver caminho do JSON
        if (-not $JsonPath) {
            # $PSScriptRoot aponta para a pasta onde este arquivo está.
            # Se estivermos em Functions, subir um nível para chegar na raiz do projeto.
            $scriptRoot = $PSScriptRoot
            if ((Split-Path -Leaf $scriptRoot) -eq "Functions") {
                $scriptRoot = Split-Path -Parent $scriptRoot
            }

            if ($ItemType -eq "Programs") {
                $JsonPath = Join-Path $scriptRoot "Data\AvailablePrograms.json"
            } else {
                $JsonPath = Join-Path $scriptRoot "Data\AvailableTweaks.json"
            }
        }

        # Leitura via arquivo (fallback ou quando explicitamente pedido)
        if (-not (Test-Path -LiteralPath $JsonPath)) {
            throw "Arquivo JSON não encontrado: $JsonPath"
        }

        $json = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

        switch ($ItemType) {
            "Programs" {
                if ($json.PSObject.Properties.Name -contains 'programs') {
                    return $json.programs
                }
                else {
                    return $json
                }
            }
            "Tweaks" {
                if ($json.PSObject.Properties.Name -contains 'Tweaks') {
                    return $json.Tweaks
                }
                else {
                    return $json
                }
            }
            "TweaksCategories" {
                if ($json.PSObject.Properties.Name -contains 'TweaksCategories') {
                    return $json.TweaksCategories
                }
                elseif ($json.PSObject.Properties.Name -contains 'Tweaks') {
                    $names = $json.Tweaks |
                        ForEach-Object { $_.Category } |
                        Where-Object { $_ } |
                        ForEach-Object { $_ } |
                        Select-Object -Unique |
                        Sort-Object
                    return ($names | ForEach-Object { [PSCustomObject]@{ Name = $_; Description = $null; Icon = $null; Color = $null; IsRecommended = $false } })
                }
                else {
                    return @()
                }
            }
        }
    }
    catch {
        Write-InstallLog "Erro ao carregar itens ($ItemType): $($_.Exception.Message)" -Status "ERRO"
        return @()
    }
}

function global:Get-AvailableWindows {
    <#
    .SYNOPSIS
    Lista todas as janelas XAML disponíveis no sistema
    
    .DESCRIPTION
    Retorna uma lista de todas as janelas XAML que foram descobertas e carregadas automaticamente
    
    .EXAMPLE
    Get-AvailableWindows
    #>
    
    if ($global:ScriptContext.XamlWindows) {
        return $global:ScriptContext.XamlWindows.Keys | Sort-Object
    }
    else {
        Write-Warning "Nenhuma janela XAML foi carregada ainda"
        return @()
    }
}