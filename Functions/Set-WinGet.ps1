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
        [ValidateSet("Programs", "Tweaks")]
        [string]$ItemType
    )
    
    try {
        # Definir caminho padrão se não especificado
        if (-not $JsonPath) {
            $scriptRoot = Split-Path -Parent $PSScriptRoot
            if ($ItemType -eq "Programs") {
                $JsonPath = Join-Path $scriptRoot "Data\AvailablePrograms.json"
            } else {
                $JsonPath = Join-Path $scriptRoot "Data\AvailableTweaks.json"
            }
        }
        
        # Verificar se o arquivo existe
        if (-not (Test-Path $JsonPath)) {
            Write-InstallLog "Arquivo de $ItemType não encontrado: $JsonPath" -Status "ERRO"
            return @()
        }
        
        # Carregar e converter o JSON
        $jsonContent = Get-Content -Path $JsonPath -Raw -Encoding UTF8
        $jsonData = $jsonContent | ConvertFrom-Json
        
        # Validar estrutura do JSON baseada no tipo
        $itemsArray = $null
        if ($ItemType -eq "Programs") {
            if (-not $jsonData.programs) {
                Write-InstallLog "Estrutura inválida no arquivo JSON: propriedade 'programs' não encontrada" -Status "ERRO"
                return @()
            }
            $itemsArray = $jsonData.programs
        } else {
            if (-not $jsonData.Tweaks) {
                Write-InstallLog "Estrutura inválida no arquivo JSON: propriedade 'Tweaks' não encontrada" -Status "ERRO"
                return @()
            }
            $itemsArray = $jsonData.Tweaks
        }
        
        # Processar cada item baseado no tipo
        $validItems = @()
        foreach ($item in $itemsArray) {
            if ($ItemType -eq "Programs") {
                # Validar programa
                if ($item.name -and $item.programId) {
                    $validItems += [PSCustomObject]@{
                        Name = $item.name
                        ProgramId = $item.programId
                        Category = if ($item.category) { $item.category } else { "Geral" }
                        Description = if ($item.description) { $item.description } else { "" }
                        Recommended = if ($item.recommended -ne $null) { $item.recommended } else { $false }
                    }
                } else {
                    Write-InstallLog "Programa inválido ignorado: faltam propriedades obrigatórias (name, programId)" -Status "AVISO"
                }
            } else {
                # Validar tweak
                if ($item.Name) {
                    $validItems += [PSCustomObject]@{
                        Name = $item.Name
                        Description = if ($item.Description) { $item.Description } else { "" }
                        Category = if ($item.Category) { $item.Category } else { @("Geral") }
                        Win11Only = if ($item.Win11Only -ne $null) { $item.Win11Only } else { $false }
                        IsBoolean = if ($item.IsBoolean -ne $null) { $item.IsBoolean } else { $false }
                        RefreshRequired = if ($item.RefreshRequired -ne $null) { $item.RefreshRequired } else { $false }
                        Command = if ($item.Command) { $item.Command } else { @() }
                        UndoCommand = if ($item.UndoCommand) { $item.UndoCommand } else { @() }
                        Registry = if ($item.Registry) { $item.Registry } else { @() }
                    }
                } else {
                    Write-InstallLog "Tweak inválido ignorado: falta propriedade obrigatória (Name)" -Status "AVISO"
                }
            }
        }
        
        Write-InstallLog "Carregados $($validItems.Count) $ItemType do arquivo JSON"
        return $validItems
        
    } catch {
        Write-InstallLog "Erro ao carregar $ItemType do JSON: $($_.Exception.Message)" -Status "ERRO"
        return @()
    }
}

# Função de compatibilidade para manter o código existente funcionando
function global:Get-AvailablePrograms {
    <#
    .SYNOPSIS
    Carrega a lista de programas disponíveis do arquivo JSON (função de compatibilidade)
    
    .DESCRIPTION
    Esta é uma função de compatibilidade que chama Get-AvailableItems com ItemType="Programs"
    
    .PARAMETER JsonPath
    Caminho para o arquivo JSON. Se não especificado, usa o caminho padrão
    
    .EXAMPLE
    $programs = Get-AvailablePrograms
    foreach ($program in $programs) {
        Write-Host "$($program.Name) - $($program.ProgramId)"
    }
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$JsonPath
    )
    
    return Get-AvailableItems -ItemType "Programs" -JsonPath $JsonPath
}

# Nova função para carregar tweaks
function global:Get-AvailableTweaks {
    <#
    .SYNOPSIS
    Carrega a lista de tweaks disponíveis do arquivo JSON
    
    .DESCRIPTION
    Lê o arquivo AvailableTweaks.json e retorna uma lista de tweaks
    disponíveis para aplicação no sistema
    
    .PARAMETER JsonPath
    Caminho para o arquivo JSON. Se não especificado, usa o caminho padrão
    
    .EXAMPLE
    $tweaks = Get-AvailableTweaks
    foreach ($tweak in $tweaks) {
        Write-Host "$($tweak.Name) - $($tweak.Description)"
    }
    #>
    
    param(
        [Parameter(Mandatory = $false)]
        [string]$JsonPath
    )
    
    return Get-AvailableItems -ItemType "Tweaks" -JsonPath $JsonPath
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

function global:Invoke-Winget {
    <#
    .SYNOPSIS
        Invokes the winget.exe with the provided arguments and returns the exit code.
    .PARAMETER wingetId
        The Id of the Program that Winget should Install/Uninstall.
    .PARAMETER scope
        Determines the installation mode. Can be "user" or "machine".
    .PARAMETER credential
        The PSCredential Object of the user that should be used to run winget.
    #>
    param (
        [string]$wingetId,
        [string]$scope = "",
        [PScredential]$credential = $null
    )

    # Garante que o caminho do Winget esteja disponível globalmente
    # Se não estiver, tenta localizá-lo novamente (cenário de instalação recém-concluída)
    if (-not $script:WinGetExePath) {
        Write-InstallLog "Caminho do Winget não definido. Tentando localizá-lo..."
        try {
            $wingetCmd = Get-Command winget -ErrorAction Stop
            $script:WinGetExePath = $wingetCmd.Source
            Write-InstallLog "Caminho do Winget encontrado: '$($script:WinGetExePath)'"
        }
        catch {
            Write-InstallLog "Não foi possível encontrar o executável 'winget' no PATH para instalação de '$wingetId'. Erro: $($_.Exception.Message)" -Status "ERRO"
            return -1 # Código de erro para indicar que Winget não foi encontrado
        }
    }

    $commonArguments = "--id `"$wingetId`" --silent" # Aspas para IDs com espaços, se houver
    $arguments = "install $commonArguments --accept-source-agreements --accept-package-agreements"
    if ($scope) {
        $arguments += " --scope $scope"
    }

    Write-InstallLog "Executando Winget com argumentos: '$arguments'"

    # Captura a saída do processo para o log
    $tempOutputFile = [System.IO.Path]::GetTempFileName()
    $tempErrorFile = [System.IO.Path]::GetTempFileName() + ".err"

    try {
        $process = Start-Process -FilePath $script:WinGetExePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $tempOutputFile -RedirectStandardError $tempErrorFile -ErrorAction Stop

        # Ler e logar a saída padrão
        $outputContent = @()
        if (Test-Path $tempOutputFile) {
            $outputContent = Get-Content -Path $tempOutputFile
            $outputContent | ForEach-Object { Write-InstallLog "Winget OUT: $_" }
        }
        # Ler e logar a saída de erro
        if (Test-Path $tempErrorFile) {
            Get-Content -Path $tempErrorFile | ForEach-Object { Write-InstallLog "Winget ERR: $_" }
        }
        
        # Verificar códigos de erro específicos relacionados à origem msstore e tentar novamente com --source winget
        if ($process.ExitCode -ne 0) {
            $exitCodeHex = "0x{0:X8}" -f [uint32]$process.ExitCode
            Write-InstallLog "Winget falhou com código de saída: $($process.ExitCode) ($exitCodeHex)"
            
            # Códigos de erro que indicam problemas com a origem msstore:
            # 0x8A15003B (-1978335173) = APPINSTALLER_CLI_ERROR_RESTAPI_INTERNAL_ERROR (Rest API internal error)
            # 0x8A150044 (-1978335164) = APPINSTALLER_CLI_ERROR_RESTAPI_ENDPOINT_NOT_FOUND (Rest source endpoint not found)
            # 0x8A15000F (-1978335217) = APPINSTALLER_CLI_ERROR_SOURCE_DATA_MISSING (Data required by the source is missing)
            # 0x8A15000B (-1978335221) = APPINSTALLER_CLI_ERROR_SOURCES_INVALID (The configured source information is corrupt)
            $msstoreErrorCodes = @(-1978335173, -1978335164, -1978335217, -1978335221)
            
            if ($msstoreErrorCodes -contains $process.ExitCode) {
                # Verificar se há múltiplas fontes disponíveis na saída
                $multipleSourcesDetected = $false
                if ($outputContent) {
                    $multipleSourcesDetected = ($outputContent | Where-Object { 
                        $_ -like "*winget*" -and ($_ -like "*Source*" -or $_ -like "*Origem*") 
                    }) -ne $null
                }
                
                if ($multipleSourcesDetected) {
                    Write-InstallLog "Detectado erro de origem msstore (código: $($process.ExitCode)). Tentando novamente com --source winget..." -Status "AVISO"
                    
                    # Tentar novamente com --source winget
                    $argumentsWithSource = "$arguments --source winget"
                    Write-InstallLog "Executando Winget com fonte específica: '$($script:WinGetExePath)' com argumentos: '$argumentsWithSource'"
                    
                    # Limpar arquivos temporários anteriores
                    if (Test-Path $tempOutputFile) { Remove-Item $tempOutputFile -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $tempErrorFile) { Remove-Item $tempErrorFile -Force -ErrorAction SilentlyContinue }
                    
                    # Recriar arquivos temporários
                    $tempOutputFile = [System.IO.Path]::GetTempFileName()
                    $tempErrorFile = [System.IO.Path]::GetTempFileName() + ".err"
                    
                    $processRetry = Start-Process -FilePath $script:WinGetExePath -ArgumentList $argumentsWithSource -Wait -PassThru -NoNewWindow `
                        -RedirectStandardOutput $tempOutputFile -RedirectStandardError $tempErrorFile -ErrorAction Stop
                    
                    # Ler e logar a saída da segunda tentativa
                    if (Test-Path $tempOutputFile) {
                        Get-Content -Path $tempOutputFile | ForEach-Object { Write-InstallLog "Winget OUT (retry): $_" }
                    }
                    if (Test-Path $tempErrorFile) {
                        Get-Content -Path $tempErrorFile | ForEach-Object { Write-InstallLog "Winget ERR (retry): $_" }
                    }
                    
                    $retryExitCodeHex = "0x{0:X8}" -f [uint32]$processRetry.ExitCode
                    Write-InstallLog "Tentativa com --source winget concluída com código: $($processRetry.ExitCode) ($retryExitCodeHex)"
                    return $processRetry.ExitCode
                }
                else {
                    Write-InstallLog "Erro de origem msstore detectado, mas não há fontes alternativas disponíveis." -Status "AVISO"
                }
            }
        }
        
        return $process.ExitCode
    }
    catch {
        Write-InstallLog "Erro ao executar Winget para '$wingetId': $($_.Exception.Message)" -Status "ERRO"
        return -1 # Código de erro genérico
    }
    finally {
        if (Test-Path $tempOutputFile) { Remove-Item $tempOutputFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempErrorFile) { Remove-Item $tempErrorFile -Force -ErrorAction SilentlyContinue }
    }
}

Function global:Invoke-Install {
    <#
    .SYNOPSIS
        Contains the Install Logic and return code handling from winget.
    .PARAMETER Program
        The Winget ID of the Program that should be installed.
    #>
    param (
        [string]$Program
    )

    Write-InstallLog "Iniciando instalação de '$Program'..."

    # 1. Tentar instalação no escopo 'machine' (sistema)
    $status = Invoke-Winget -wingetId $Program -scope "machine"
    if ($status -eq 0) {
        Write-InstallLog "'$Program' instalado com sucesso no escopo 'machine'." -Status "SUCESSO"
        return $true
    }
    elseif ($status -eq -1978335189) {
        # Winget exit code for "No applicable update found" or "already installed"
        Write-InstallLog "'$Program' já instalado ou nenhuma atualização aplicável encontrada." -Status "SUCESSO"
        return $true
    }
    else {
        Write-InstallLog "Instalação de '$Program' no escopo 'machine' falhou (código: $status). Tentando escopo 'user'..." -Status "AVISO"
    }

    # 2. Tentar instalação no escopo 'user' (usuário atual)
    $status = Invoke-Winget -wingetId $Program -scope "user"
    if ($status -eq 0) {
        Write-InstallLog "'$Program' instalado com sucesso no escopo 'user'." -Status "SUCESSO"
        return $true
    }
    elseif ($status -eq -1978335189) {
        Write-InstallLog "'$Program' já instalado (usuário) ou nenhuma atualização aplicável encontrada." -Status "SUCESSO"
        return $true
    }
    else {
        Write-InstallLog "Instalação de '$Program' no escopo 'user' falhou (código: $status). Não será tentado com credenciais interativas." -Status "AVISO"
        # Não faremos a parte de Get-Credential aqui, pois o script é invocado externamente
        # e a interação com o usuário pode não ser desejável ou possível em um contexto de automação.
        # Se for um cenário de unattend, um prompt de credencial pararia o processo.
    }
    
    Write-InstallLog "Falha ao instalar '$Program'." -Status "ERRO"
    return $false
}

function global:Install-WingetWrapper {
    <#
    .SYNOPSIS
        Wrapper function to ensure Winget is installed and its path is set globally.
    #>
    
    $isWingetInstalledStatus = Test-WinGet -winget

    if ($isWingetInstalledStatus -eq "installed") {
        Write-InstallLog "Winget já está instalado e atualizado"
        # O caminho já deve ter sido populado por Test-WinGet
        return $true
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
            return $true
        }
        else {
            Write-InstallLog "Winget não está operacional mesmo após a tentativa de instalação/atualização." -Status "ERRO"
            return $false
        }
    }
    else {
        Write-InstallLog "Falha ao instalar/atualizar o Winget" -Status "ERRO"
        return $false
    }
}

# Função principal para instalar programas via Winget
function global:Install-Programs {
    <#
    .SYNOPSIS
        Instala programas via Winget.
    .PARAMETER ProgramIDs
        Array de IDs dos programas a serem instalados.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ProgramIDs
    )

    Write-InstallLog "Iniciando instalação dos programas."
    Write-InstallLog "Programas solicitados: $($ProgramIDs -join ', ')"
    $overallSuccess = $true
    $browserInstalled = $false

    try {
        # 1. Garantir que o Winget esteja instalado e pronto
        Write-InstallLog "Verificando e preparando o Winget..."
        $wingetReady = Install-WingetWrapper
    
        if (-not $wingetReady) {
            Write-InstallLog "O Winget não está pronto para uso. Não é possível instalar programas." -Status "ERRO"
            $overallSuccess = $false # Marcar falha geral
        }
        else {
            # 2. Instalar os programas solicitados via Winget
            if ($ProgramIDs -and $ProgramIDs.Count -gt 0) {
                $knownBrowsers = @("Google.Chrome", "Brave.Brave", "Mozilla.Firefox", "Opera.Opera")
                $totalPrograms = $ProgramIDs.Count
                $currentProgram = 0
            
                foreach ($programId in $ProgramIDs) {
                    $currentProgram++
                    $percentComplete = [math]::Round(($currentProgram / $totalPrograms) * 100)
                    Write-Progress -Activity "Instalando programas" -Status "Instalando $programId ($currentProgram de $totalPrograms)" -PercentComplete $percentComplete
                
                    Write-InstallLog "Tentando instalar '$programId'..."
                    $installSuccess = Invoke-Install -Program $programId # Nova função para instalação

                    if ($installSuccess) {
                        Write-InstallLog "'$programId' instalado com sucesso." -Status "SUCESSO"

                        # Verificar se o programa instalado é um navegador conhecido
                        if ($knownBrowsers -contains $programId) {
                            $browserInstalled = $true # Marcar que um navegador foi instalado
                        }
                    }
                    else {
                        Write-InstallLog "Instalação de '$programId' falhou" -Status "ERRO"
                        $overallSuccess = $false # Marcar falha geral se uma instalação falhar
                    }
                }
            
                # Finalizar a barra de progresso
                Write-Progress -Activity "Instalando programas" -Status "Instalação concluída" -PercentComplete 100 -Completed
            
                # 3. Lógica para MSEdgeRedirect (se um navegador foi instalado e a versão do Windows é compatível)
                if ($browserInstalled -and ($global:ScriptContext.isWin11 -eq $true)) {
                    $msEdgeRedirectId = "rcmaehl.MSEdgeRedirect"
                    Write-InstallLog "Navegadores foram instalados. Instalando também o MSEdgeRedirect..."
                
                    # Chamando Invoke-Install para o MSEdgeRedirect
                    $msEdgeRedirectSuccess = Invoke-Install -Program $msEdgeRedirectId
                
                    if ($msEdgeRedirectSuccess) {
                        Start-Process "ms-settings:defaultapps"
                        # a janela de seleção de navegador, mas muitas vezes não funciona em contextos de automação.
                    }
                    else {
                        Write-InstallLog "Falha ao instalar MSEdgeRedirect" -Status "ERRO"
                        $overallSuccess = $false # Marcar falha se MSEdgeRedirect falhar
                    }
                }
            
            }
        }
    }
    catch {
        Write-InstallLog "Erro inesperado no fluxo principal do script de instalação: $($_.Exception.Message)" -Status "ERRO"
        $overallSuccess = $false # Garantir código de falha em exceção não tratada
    }
}