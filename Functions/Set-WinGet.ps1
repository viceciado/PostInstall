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

function global:Test-WinGet {
    Param(
        [System.Management.Automation.SwitchParameter]$winget
    )

    $status = "not-installed"

    if ($winget) {
        $wingetExists = $true
        try {
            $wingetVersionFull = winget --version
        }
        catch [System.Management.Automation.CommandNotFoundException], [System.Management.Automation.ApplicationFailedException] {
            Write-InstallLog "Winget não encontrado ou inacessível. ($($_.Exception.Message))" -Status "AVISO"
            $wingetExists = $false
        }
        catch {
            Write-InstallLog "Erro desconhecido ao verificar Winget: $($_.Exception.Message)" -Status "ERRO"
            $wingetExists = $false
        }

        if ($wingetExists) {
            # Extrair informações da versão
            if ($wingetVersionFull.Contains("-preview")) {
                $wingetVersion = $wingetVersionFull.Trim("-preview")
                $wingetPreview = $true
            }
            else {
                $wingetVersion = $wingetVersionFull
                $wingetPreview = $false
            }

            # Comparar com a última versão do GitHub
            try {
                $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/Winget-cli/releases/latest" -Method Get -ErrorAction Stop
                $wingetLatestVersion = [System.Version]::Parse(($response.tag_name).Trim('v'))
                $wingetCurrentVersion = [System.Version]::Parse($wingetVersion.Trim('v'))
                $wingetOutdated = $wingetCurrentVersion -lt $wingetLatestVersion
            }
            catch {
                Write-InstallLog "Não foi possível verificar a última versão do Winget no GitHub. Erro: $($_.Exception.Message)" -Status "AVISO"
                # Assume que não está desatualizado se não conseguir verificar, para não forçar atualização
                $wingetOutdated = $false
            }
            
            Write-InstallLog "Winget está instalado. Versão: $wingetVersionFull"
            if ($wingetPreview) {
                Write-InstallLog "  - É uma versão preview. Problemas inesperados podem ocorrer." -Status "AVISO"
            }
            if (-not $wingetOutdated) {
                Write-InstallLog "  - Winget está atualizado." -Status "SUCESSO"
                $status = "installed"
            }
            else {
                Write-InstallLog "  - Winget está desatualizado. (Versão mais recente: $wingetLatestVersion)" -Status "AVISO"
                $status = "outdated"
            }

            # Atualiza o caminho global do Winget, se ele estiver funcionando
            try {
                # Tenta encontrar o caminho completo do executável "winget" no PATH
                $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
                if ($wingetCmd) {
                    $script:WinGetExePath = $wingetCmd.Source
                    Write-InstallLog "Caminho do Winget localizado: '$($script:WinGetExePath)'"
                }
                else {
                    Write-InstallLog "Não foi possível resolver o caminho completo do Winget via Get-Command." -Status "AVISO"
                }
            }
            catch {
                Write-InstallLog "Erro ao tentar obter o caminho completo do Winget: $($_.Exception.Message)" -Status "AVISO"
            }

        }
        else {
            Write-InstallLog "Winget não está instalado ou funcional." -Status "AVISO"
            $status = "not-installed"
        }
    }
    return $status
}

function global:Get-WingetLatest {
    [CmdletBinding()]
    param()

    <#
    .SYNOPSIS
        Ensures Winget is installed and up-to-date.
    .DESCRIPTION
        This function first attempts to update WinGet using winget itself, then falls back to Microsoft Store installation,
        and finally to manual GitHub download if needed.
    #>
    $ProgressPreference = "SilentlyContinue"
    $InformationPreference = 'Continue' # Manter info para debug, se necessário

    Write-InstallLog "Iniciando processo para obter ou atualizar o Winget..."

    # 1. Tentar atualizar/instalar Winget usando o próprio Winget (se já estiver no PATH)
    try {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-InstallLog "Tentando atualizar Winget usando o próprio Winget..."
            $result = Start-Process -FilePath "`"$($wingetCmd.Source)`"" -ArgumentList "install -e --accept-source-agreements --accept-package-agreements Microsoft.AppInstaller" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\winget_update_out.log" -RedirectStandardError "$env:TEMP\winget_update_err.log"
            
            # Lê a saída para o log principal
            if (Test-Path "$env:TEMP\winget_update_out.log") {
                Get-Content "$env:TEMP\winget_update_out.log" | ForEach-Object { Write-InstallLog "Winget Update OUT: $_" }
                Remove-Item "$env:TEMP\winget_update_out.log" -ErrorAction SilentlyContinue
            }
            if (Test-Path "$env:TEMP\winget_update_err.log") {
                Get-Content "$env:TEMP\winget_update_err.log" | ForEach-Object { Write-InstallLog "Winget Update ERR: $_" }
                Remove-Item "$env:TEMP\winget_update_err.log" -ErrorAction SilentlyContinue
            }

            if ($result.ExitCode -eq 0 -or $result.ExitCode -eq -1978335189) {
                # -1978335189 = No applicable update found
                Write-InstallLog "Winget atualizado/verificado com sucesso via Winget." -Status "SUCESSO"
                return $true
            }
            else {
                Write-InstallLog "Atualização do Winget via Winget falhou com código de saída: $($result.ExitCode). Tentando fallback..." -Status "AVISO"
            }
        }
        else {
            Write-InstallLog "Winget não encontrado no PATH. Tentando instalação a partir da Microsoft Store."
        }
    }
    catch {
        Write-InstallLog "Erro ao tentar atualizar Winget via Winget: $($_.Exception.Message). Tentando fallback..." -Status "AVISO"
    }

    # 2. Fallback para Instalação pela Microsoft Store (via APIs do Windows Runtime)
    try {
        Write-InstallLog "Tentando instalar Winget pela Microsoft Store (APIs do Windows Runtime)..."

        # Tentar fechar quaisquer processos Winget em execução
        Get-Process -Name "DesktopAppInstaller", "winget" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-InstallLog "Encerrando processo de Winget em execução: $($_.ProcessName)"
            $_.Kill()
            Start-Sleep -Seconds 1
        }

        # Carregar assemblies do Windows Runtime mais confiavelmente
        $null = [System.Runtime.WindowsRuntime.WindowsRuntimeSystemExtensions]
        Add-Type -AssemblyName System.Runtime.WindowsRuntime

        # Carregar assemblies necessários do Windows SDK
        $null = @(
            [Windows.Management.Deployment.PackageManager, Windows.Management.Deployment, ContentType = WindowsRuntime]
            [Windows.Foundation.Uri, Windows.Foundation, ContentType = WindowsRuntime]
            [Windows.Management.Deployment.DeploymentOptions, Windows.Management.Deployment, ContentType = WindowsRuntime]
        )

        $packageManager = New-Object Windows.Management.Deployment.PackageManager
        $appxPackage = "https://aka.ms/getwinget"
        $uri = New-Object Windows.Foundation.Uri($appxPackage)
        $deploymentOperation = $packageManager.AddPackageAsync($uri, $null, "Add")

        # Adicionar verificação de timeout
        $timeout = 300 # 5 minutos
        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        while ($deploymentOperation.Status -eq 0) {
            # Status 0 = Started
            if ($timer.Elapsed.TotalSeconds -gt $timeout) {
                throw "A instalação da Microsoft Store atingiu o tempo limite ($timeout segundos)."
            }
            Start-Sleep -Milliseconds 100
        }

        if ($deploymentOperation.Status -eq 1) {
            # Status 1 = Completed
            Write-InstallLog "Winget instalado com sucesso da Microsoft Store." -Status "SUCESSO"
            return $true
        }
        else {
            Write-InstallLog "Instalação da Microsoft Store falhou com status: $($deploymentOperation.Status)." -Status "AVISO"
            throw "Instalação da Microsoft Store falhou. Tentando fallback."
        }
    }
    catch [System.Management.Automation.RuntimeException] {
        Write-InstallLog "Componentes do Windows Runtime não disponíveis ou falha na instalação da Store: $($_.Exception.Message). Tentando download manual..." -Status "AVISO"
    }
    catch {
        Write-InstallLog "Erro inesperado na instalação via Microsoft Store: $($_.Exception.Message). Tentando download manual..." -Status "AVISO"
    }

    # 3. Fallback para Download Manual do GitHub
    try {
        Write-InstallLog "Tentando download e instalação manual do Winget do GitHub..."
        
        # Tentar fechar quaisquer processos Winget em execução antes do download
        Get-Process -Name "DesktopAppInstaller", "winget" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-InstallLog "Encerrando processo de Winget em execução antes do download: $($_.ProcessName)"
            $_.Kill()
            Start-Sleep -Seconds 1
        }

        $apiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        Write-InstallLog "Consultando API do GitHub para a última versão do Winget: $apiUrl"
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        
        # Buscar o arquivo .msixbundle
        $msixBundleAsset = $release.assets | Where-Object { $_.name -like "Microsoft.DesktopAppInstaller_*.msixbundle" }
        if (-not $msixBundleAsset) {
            throw "Não foi possível encontrar o arquivo .msixbundle na última release do GitHub."
        }
        $msixBundleUrl = $msixBundleAsset.browser_download_url
        
        # Buscar o arquivo de dependências
        $depsAsset = $release.assets | Where-Object { $_.name -eq "DesktopAppInstaller_Dependencies.zip" }
        if (-not $depsAsset) {
            Write-InstallLog "Arquivo de dependências não encontrado na release. Tentando instalação sem dependências..." -Status "AVISO"
        }
        $depsUrl = $depsAsset.browser_download_url

        # Detectar arquitetura do sistema
        $procArch = $env:PROCESSOR_ARCHITECTURE
        switch -Wildcard ($procArch) {
            "AMD64"   { $arch = "x64" }
            "x86"     { $arch = "x86" }
            "*ARM64*" { $arch = "arm64" }
            "*ARM*"   { $arch = "arm" }
            default {
                $arch = "x64"
                Write-InstallLog "Arquitetura não reconhecida: $procArch. Usando x64 como padrão." -Status "AVISO"
            }
        }
        Write-InstallLog "Arquitetura detectada: $arch"

        # Download do arquivo principal
        $tempFile = Join-Path $env:TEMP $msixBundleAsset.name
        Write-InstallLog "Baixando Winget de: $msixBundleUrl para $tempFile"
        Invoke-WebRequest -Uri $msixBundleUrl -OutFile $tempFile -ErrorAction Stop

        # Download e instalação das dependências
        if ($depsUrl) {
            $depsZipPath = Join-Path $env:TEMP "DesktopAppInstaller_Dependencies.zip"
            $topDepsFolder = Join-Path $env:TEMP "Dependencies"
            $depsFolder = Join-Path $topDepsFolder $arch
            
            Write-InstallLog "Baixando dependências de: $depsUrl"
            Invoke-WebRequest -Uri $depsUrl -OutFile $depsZipPath -ErrorAction Stop
            
            # Remover pasta de dependências existente e extrair o zip
            if (Test-Path $topDepsFolder) { 
                Remove-Item -Path $topDepsFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Write-InstallLog "Extraindo dependências para $topDepsFolder"
            Expand-Archive -LiteralPath $depsZipPath -DestinationPath $topDepsFolder -Force
            
            # Instalar dependências se existirem para a arquitetura
            if (Test-Path $depsFolder) {
                Write-InstallLog "Instalando dependências da pasta: $depsFolder"
                
                # Verificar se existe arquivo JSON com ordem de instalação
                $jsonFile = Join-Path $depsFolder "DesktopAppInstaller_Dependencies.json"
                if (Test-Path $jsonFile) {
                    Write-InstallLog "Instalando dependências baseado em DesktopAppInstaller_Dependencies.json"
                    $jsonContent = Get-Content $jsonFile -Raw | ConvertFrom-Json
                    $dependencies = $jsonContent.Dependencies
                    
                    foreach ($dep in $dependencies) {
                        $matchingFiles = Get-ChildItem -Path $depsFolder -Filter *.appx -Recurse |
                            Where-Object { $_.Name -like "*$($dep.Name)*" -and $_.Name -like "*$($dep.Version)*" }
                        
                        foreach ($file in $matchingFiles) {
                            try {
                                Write-InstallLog "Instalando dependência: $($file.Name)"
                                Add-AppxPackage -Path $file.FullName -ErrorAction Stop
                                Write-InstallLog "Dependência $($file.Name) instalada com sucesso"
                            }
                            catch {
                                Write-InstallLog "Erro ao instalar dependência $($file.Name): $($_.Exception.Message)" -Status "AVISO"
                                # Continua com as outras dependências mesmo se uma falhar
                            }
                        }
                    }
                }
                else {
                    # Se não há JSON, instalar todos os .appx na pasta
                    Write-InstallLog "Instalando todas as dependências .appx encontradas"
                    foreach ($appxFile in Get-ChildItem $depsFolder -Filter *.appx -Recurse) {
                        try {
                            Write-InstallLog "Instalando dependência: $($appxFile.Name)"
                            Add-AppxPackage -Path $appxFile.FullName -ErrorAction Stop
                            Write-InstallLog "Dependência $($appxFile.Name) instalada com sucesso"
                        }
                        catch {
                            Write-InstallLog "Erro ao instalar dependência $($appxFile.Name): $($_.Exception.Message)" -Status "AVISO"
                            # Continua com as outras dependências mesmo se uma falhar
                        }
                    }
                }
            }
            else {
                Write-InstallLog "Nenhuma dependência encontrada para a arquitetura $arch em $depsFolder" -Status "AVISO"
            }
            
            # Limpeza dos arquivos temporários de dependências
            if (Test-Path $depsZipPath) {
                Remove-Item $depsZipPath -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path $topDepsFolder) {
                Remove-Item -Path $topDepsFolder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-InstallLog "Instalando Winget a partir de $tempFile..."
        try {
            Add-AppxPackage -Path $tempFile -ErrorAction Stop
            Write-InstallLog "Winget instalado com sucesso a partir do GitHub release." -Status "SUCESSO"
            
            # Verificar se o Winget está funcionando após a instalação
            Start-Sleep -Seconds 2
            $wingetTest = Get-Command winget -ErrorAction SilentlyContinue
            if ($wingetTest) {
                Write-InstallLog "Winget está disponível no PATH e pronto para uso." -Status "SUCESSO"
            }
            else {
                Write-InstallLog "Winget foi instalado mas pode não estar imediatamente disponível no PATH. Pode ser necessário reiniciar o terminal." -Status "AVISO"
            }
            
            return $true
        }
        catch {
            # Capturar erros específicos de instalação do MSIX
            $errorMessage = $_.Exception.Message
            if ($errorMessage -like "*0x80073CF3*") {
                Write-InstallLog "Erro de dependência detectado (0x80073CF3). Algumas dependências podem não ter sido instaladas corretamente." -Status "ERRO"
            }
            elseif ($errorMessage -like "*0x80073D01*") {
                Write-InstallLog "Erro de arquitetura ou versão incompatível (0x80073D01)." -Status "ERRO"
            }
            else {
                Write-InstallLog "Erro durante a instalação do Winget: $errorMessage" -Status "ERRO"
            }
            throw
        }
    }
    catch {
        Write-InstallLog "Falha final na instalação do Winget via GitHub: $($_.Exception.Message)" -Status "ERRO"
        return $false
    }
    finally {
        # Limpeza dos arquivos temporários
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function global:Install-WingetWrapper {
    <#
    .SYNOPSIS
        Wrapper function to ensure Winget is installed and its path is set globally.
        Returns hashtable with Success and RequiresRestart properties.
    #>
    
    $isWingetInstalledStatus = Test-WinGet -winget
    $wasNotInstalled = $isWingetInstalledStatus -eq "not-installed"

    if ($isWingetInstalledStatus -eq "installed") {
        Write-InstallLog "Winget já está instalado e atualizado"
        # O caminho já deve ter sido populado por Test-WinGet
        return @{ Success = $true; RequiresRestart = $false }
    }
    elseif ($isWingetInstalledStatus -eq "outdated") {
        Write-InstallLog "O Winget está desatualizado. Iniciando processo de atualização..."
    }
    else {
        Write-InstallLog "O Winget não está instalado. Iniciando processo de instalação..."
    }

    # Se Winget não está instalado ou está desatualizado, chamamos a função mais robusta para instalá-lo/atualizá-lo
    $wingetInstallSuccess = Get-WingetLatest
    
    if ($wingetInstallSuccess) {
        Write-InstallLog "Atualização concluída"
        Start-Sleep -Seconds 5 
        $finalWingetStatus = Test-WinGet -winget
        if ($finalWingetStatus -eq "installed" -or $finalWingetStatus -eq "outdated") {
            # Se o winget não estava instalado antes, uma reinicialização pode ser necessária
            return @{ Success = $true; RequiresRestart = $wasNotInstalled }
        }
        else {
            Write-InstallLog "Winget não está operacional mesmo após a tentativa de instalação/atualização." -Status "ERRO"
            return @{ Success = $false; RequiresRestart = $false }
        }
    }
    else {
        Write-InstallLog "Falha ao instalar/atualizar o Winget" -Status "ERRO"
        return @{ Success = $false; RequiresRestart = $false }
    }
}

function global:Install-Programs {
    <#
    .SYNOPSIS
    Versão otimizada para execução em janela PowerShell elevada
    
    .DESCRIPTION
    Esta versão é especificamente projetada para ser executada via Invoke-ElevatedProcess
    com melhor visibilidade e controle da janela
    
    .PARAMETER ProgramIDs
    Array de IDs dos programas a serem instalados
    
    .EXAMPLE
    Install-Programs -ProgramIDs @("Google.Chrome", "Mozilla.Firefox")
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProgramIDs
    )
    
    # Configurar janela do console
    $Host.UI.RawUI.WindowTitle = "PostInstall - Instalando $($ProgramIDs -join ', ')"
    
    # Configurar codificação UTF-8 para exibição correta
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    
    Clear-Host
    
    Write-Host "=== INSTALAÇÃO DE PROGRAMAS VIA WINGET ==="
    Write-Host "Programas solicitados para instalação: $($ProgramIDs -join ', ')" -ForegroundColor Yellow
    Write-Host "" # Linha em branco
    
    if (-not $ProgramIDs -or $ProgramIDs.Count -eq 0) {
        Write-Host "ERRO: Nenhum programa especificado para instalação" -ForegroundColor Red
        Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    # Verificar se winget está disponível
    Write-Host "Verificando disponibilidade do Winget..." -ForegroundColor White
    try {
        $wingetPath = (Get-Command winget -ErrorAction Stop).Source
        Write-Host "Winget encontrado! Prosseguindo para a instalação." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERRO] Winget não encontrado. Tentando instalar/atualizar..." -ForegroundColor Red
        
        # Preparar ambiente de funções sem dot-sourcing amplo: tentar importar o script compilado
        try {
            # Garantir que a função de instalação esteja disponível
            if (-not (Get-Command Install-WingetWrapper -ErrorAction SilentlyContinue)) {
                $compiledPath = $null
                if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath) {
                    $compiledPath = $global:ScriptContext.CompiledScriptPath
                } else {
                    $scriptRoot = Split-Path -Parent $PSScriptRoot
                    $candidate = Join-Path $scriptRoot "PostInstall.ps1"
                    if (Test-Path $candidate) { $compiledPath = $candidate }
                }
                
                if ($compiledPath) {
                    if (-not $global:ScriptContext) { $global:ScriptContext = @{} }
                    $global:ScriptContext.SkipEntryPoint = $true
                    . $compiledPath
                } else {
                    # Fallback mínimo: carregar apenas Set-WinGet e Write-InstallLog, se necessário
                    $functionsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Functions"
                    $winGetFile = Join-Path $functionsPath "Set-WinGet.ps1"
                    if (Test-Path $winGetFile) { . $winGetFile }
                    $logFile = Join-Path $functionsPath "Write-InstallLog.ps1"
                    if (Test-Path $logFile) { . $logFile }
                }
            }

            # Executar preparação/instalação do Winget e respeitar RequiresRestart
            $wingetResult = Install-WingetWrapper
            if (-not $wingetResult.Success) {
                Write-Host "[ERRO] Não foi possível preparar o Winget. Cancelando instalações." -ForegroundColor Red
                Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }

            if ($wingetResult.RequiresRestart) {
                Write-Host "Winget instalado com sucesso. Reiniciando processo para aplicar mudanças..." -ForegroundColor Yellow
                Write-Host "Aguarde alguns segundos..." -ForegroundColor Gray
                Start-Sleep -Seconds 3
                
                # Salvar os parâmetros em um arquivo temporário para o novo processo
                $tempParamsFile = [System.IO.Path]::GetTempFileName() + ".json"
                
                # Definir caminho do script compilado para reimportação no novo processo
                $compiledPath = $null
                if ($global:ScriptContext -and $global:ScriptContext.CompiledScriptPath) {
                    $compiledPath = $global:ScriptContext.CompiledScriptPath
                } else {
                    $scriptRoot = Split-Path -Parent $PSScriptRoot
                    $candidate = Join-Path $scriptRoot "PostInstall.ps1"
                    if (Test-Path $candidate) { $compiledPath = $candidate }
                }

                $paramsData = @{ 
                    ProgramIDs = $ProgramIDs 
                    CompiledScriptPath = $compiledPath 
                }
                $paramsData | ConvertTo-Json -Depth 3 | Out-File -FilePath $tempParamsFile -Encoding UTF8
                
                # Criar script temporário para executar a instalação sem dot-sourcing amplo
                $tempScriptFile = [System.IO.Path]::GetTempFileName() + ".ps1"
                $restartScript = @"
# Script de reinicialização para instalação de programas
`$paramsFile = '$tempParamsFile'
`$paramsData = Get-Content -Path `$paramsFile -Raw | ConvertFrom-Json

if (-not `$global:ScriptContext) { `$global:ScriptContext = @{} }
`$global:ScriptContext.SkipEntryPoint = `$true

if (`$paramsData.CompiledScriptPath) {
    . "`$(`$paramsData.CompiledScriptPath)"
} else {
    # Fallback: localizar PostInstall.ps1 ao lado do script atual
    `$scriptRoot = Split-Path -Parent `$PSScriptRoot
    `$candidate = Join-Path `$scriptRoot "PostInstall.ps1"
    if (Test-Path `$candidate) { . `$candidate }
}

Install-Programs -ProgramIDs `$paramsData.ProgramIDs

# Limpar arquivos temporários
Remove-Item -Path `$paramsFile -Force -ErrorAction SilentlyContinue
"@
                $restartScript | Out-File -FilePath $tempScriptFile -Encoding UTF8
                
                # Iniciar novo processo PowerShell com o script temporário
                $processArgs = @{ 
                    FilePath = "powershell.exe" 
                    ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScriptFile`"") 
                    Verb = "RunAs" 
                    PassThru = $false 
                }
                Start-Process @processArgs

                # Encerrar o processo atual
                Write-Host "Processo reiniciado. Esta janela será fechada." -ForegroundColor Green
                Start-Sleep -Seconds 2
                return
            } else {
                # Se não precisa reiniciar, obter caminho do winget e continuar
                try {
                    $wingetPath = (Get-Command winget -ErrorAction Stop).Source
                    Write-Host "Winget disponível sem reinício. Prosseguindo..." -ForegroundColor Green
                } catch {
                    Write-Host "[ERRO] Winget ainda indisponível após instalação." -ForegroundColor Red
                    Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    return
                }
            }
        }
        catch {
            Write-Host "Erro ao preparar Winget: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    
    Write-Host "" # Linha em branco
    Write-Host "Iniciando instalação de $($ProgramIDs.Count) programa(s)..."
    Write-Host "" # Linha em branco
    
    $completed = @()
    $failed = @()
    $totalPrograms = $ProgramIDs.Count
    
    for ($i = 0; $i -lt $totalPrograms; $i++) {
        $programId = $ProgramIDs[$i]
        $currentNumber = $i + 1
        
        Write-Host "[$currentNumber/$totalPrograms] Instalando: $programId" -ForegroundColor White
        Write-Host "" # Linha em branco
        
        $startTime = Get-Date
        $installSuccess = $false
        
        # Função inline para instalar programa
        try {
            # Tentar instalação no escopo machine
            Write-Host "  -> Tentando instalação no escopo 'machine'..." -ForegroundColor Gray
            $arguments = "install --id `"$programId`"--source winget  --scope machine --silent --accept-source-agreements --accept-package-agreements"
            
            # Executar winget usando Start-Process para melhor controle
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $wingetPath
            $psi.Arguments = $arguments
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            [void]$process.Start()
            $output = $process.StandardOutput.ReadToEnd()
            $error = $process.StandardError.ReadToEnd()
            $process.WaitForExit(300000)
            $exitCode = $process.ExitCode

            
            # DEBUG: Mostrar conteúdo bruto
            Write-Host "DEBUG OUTPUT: [$output]" -ForegroundColor Magenta
            Write-Host "DEBUG ERROR: [$error]" -ForegroundColor Magenta
            
            # Mostrar saída relevante do winget
            $allOutput = "$output`n$error"
            if ($allOutput.Trim()) {
                $allOutput -split "`n" | Where-Object { 
                    $line = $_.Trim()
                    $line -and $line -ne "True" -and $line -ne "False" -and $line -notmatch "^\s*$"
                } | ForEach-Object {
                    Write-Host "    $($_.Trim())" -ForegroundColor DarkGray
                }
            }
            
            $process.Dispose()
            
            # Verificar sucesso
            $installSuccess = ($exitCode -eq 0) -or ($exitCode -eq -1978335189)
            
            if (-not $installSuccess) {
                Write-Host "  -> Instalação 'machine' falhou (código: $exitCode)" -ForegroundColor Yellow
                
                # Tentar no escopo user
                Write-Host "  -> Tentando instalação no escopo 'user'..." -ForegroundColor Gray
                $arguments = "install --id `"$programId`"--soruce winget --scope user --silent --accept-source-agreements --accept-package-agreements"
                
                $psi.Arguments = $arguments
            $null = [System.Diagnostics.Process]::Start($psi)
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            [void]$process.Start()
            $output = $process.StandardOutput.ReadToEnd()
            $error = $process.StandardError.ReadToEnd()
            $process.WaitForExit(300000)
            $exitCode = $process.ExitCode
            $process.Dispose()
                
                # Mostrar saída relevante do winget
                $allOutput = "$output`n$error"
                if ($allOutput.Trim()) {
                    $allOutput -split "`n" | Where-Object { 
                        $line = $_.Trim()
                        $line -and $line -ne "True" -and $line -ne "False" -and $line -notmatch "^\s*$"
                    } | ForEach-Object {
                        Write-Host "    $($_.Trim())" -ForegroundColor DarkGray
                    }
                }
                
                $installSuccess = ($exitCode -eq 0) -or ($exitCode -eq -1978335189)
            }
        }
        catch {
            Write-Host "  [ERRO] Erro durante instalação: $($_.Exception.Message)" -ForegroundColor Red
            $installSuccess = $false
        }
        
        $duration = (Get-Date) - $startTime
        
        if ($installSuccess) {
            $completed += $programId
            Write-Host "  [OK] '$programId' instalado com sucesso em $([math]::Round($duration.TotalSeconds, 1))s" -ForegroundColor Green
        } else {
            $failed += $programId
            Write-Host "  [ERRO] Instalação de '$programId' falhou após $([math]::Round($duration.TotalSeconds, 1))s" -ForegroundColor Red
        }
        
        Write-Host "" # Linha em branco
    }
    
    # Relatório final
    Write-Host "Total de programas: $totalPrograms"
    Write-Host "Sucessos: $($completed.Count)" -ForegroundColor Green
    Write-Host "Falhas: $($failed.Count)" -ForegroundColor Red
    
    if ($completed.Count -gt 0) {
        Write-Host "" # Linha em branco
        Write-Host "Programas instalados:"
        $completed | ForEach-Object { Write-Host $_ }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host "" # Linha em branco
        Write-Host "Programas que falharam:" -ForegroundColor Red
        $failed | ForEach-Object { Write-Host "  [ERRO] $_" -ForegroundColor Red }
    }
    
    Write-Host "" # Linha em branco
    
    if ($failed.Count -gt 0) {
        Write-Host "Pressione qualquer tecla para fechar..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } else {
        Write-Host "Essa janela será fechada em 5 segundos..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}