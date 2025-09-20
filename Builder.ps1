<#
.SYNOPSIS
Script compilador para o projeto PostInstall

.DESCRIPTION
Este script compila todo o projeto PostInstall em um único arquivo .ps1 executável,
incluindo todas as funções, arquivos XAML e dados JSON necessários.

.PARAMETER Debug
Mantém arquivos temporários para debugging

.PARAMETER Run
Executa o arquivo compilado após a criação

.PARAMETER OutputName
Nome do arquivo de saída (padrão: PostInstall-Compiled.ps1)

.PARAMETER IncludeVersion
Inclui timestamp na versão do script compilado

.EXAMPLE
.\Build-PostInstall.ps1
Compila o projeto com configurações padrão

.EXAMPLE
.\Build-PostInstall.ps1 -Debug -OutputName "MyPostInstall.ps1"
Compila com modo debug e nome personalizado

.EXAMPLE
.\Build-PostInstall.ps1 -Run
Compila e executa imediatamente
#>

param (
    [switch]$Debug,
    [switch]$Run,
    [string]$OutputName = "PostInstall.ps1",
    [switch]$IncludeVersion = $true,
    [string]$Arguments
)

# Verificar se já existe arquivo compilado e remover se necessário
if (Test-Path ".\$OutputName") {
    if ((Get-Item ".\$OutputName" -ErrorAction SilentlyContinue).IsReadOnly) {
        Remove-Item ".\$OutputName" -Force
    }
    else {
        Remove-Item ".\$OutputName" -Force -ErrorAction SilentlyContinue
    }
}

$OFS = "`r`n"
$workingdir = $PSScriptRoot

Push-Location
Set-Location $workingdir

# Função para atualizar progresso
function Update-Progress {
    param (
        [Parameter(Mandatory, position=0)]
        [string]$StatusMessage,

        [Parameter(Mandatory, position=1)]
        [ValidateRange(0,100)]
        [int]$Percent,

        [Parameter(position=2)]
        [string]$Activity = "Compilando PostInstall"
    )

    Write-Progress -Activity $Activity -Status $StatusMessage -PercentComplete $Percent
}

# Cabeçalho do arquivo compilado
$header = @"
################################################################################################################
###                                            Script PostInstall                                            ###
###                                                @viceciado                                                ###
###                                                                                                          ###
### AVISO: Este arquivo foi gerado automaticamente. NÃO modifique este arquivo diretamente, pois ele será    ###
###        sobrescrito na próxima compilação.                                                                ###
###                                                                                                          ###
###      Para modificações, edite os arquivos fonte na pasta do projeto e execute Build-PostInstall.ps1      ###
###                                                                                                          ###
###                                    Build compilada em: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")                               ###
################################################################################################################
"@

Update-Progress "Inicializando compilação..." 0

# Validar estrutura do projeto
$requiredFolders = @("Functions", "Windows", "Data")
$missingFolders = @()

foreach ($folder in $requiredFolders) {
    if (-not (Test-Path $folder)) {
        $missingFolders += $folder
    }
}

if ($missingFolders.Count -gt 0) {
    Write-Error "Pastas obrigatórias não encontradas: $($missingFolders -join ', ')"
    Write-Error "Certifique-se de executar este script na pasta raiz do projeto PostInstall."
    Pop-Location
    exit 1
}

# Verificar se Main.ps1 existe
if (-not (Test-Path "Main.ps1")) {
    Write-Error "Arquivo Main.ps1 não encontrado na pasta atual."
    Write-Error "Certifique-se de executar este script na pasta raiz do projeto PostInstall."
    Pop-Location
    exit 1
}

Update-Progress "Validação concluída. Iniciando compilação..." 5

# Criar lista para o conteúdo do script
$script_content = [System.Collections.Generic.List[string]]::new()

Update-Progress "Adicionando cabeçalho..." 10
$script_content.Add($header)
$script_content.Add("")

# Adicionar assemblies necessários
Update-Progress "Adicionando assemblies..." 15
$assemblies = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Management
"@
$script_content.Add($assemblies)
$script_content.Add("")

# Adicionar contexto global
Update-Progress "Configurando contexto global..." 20
$globalContext = @"
`$global:ScriptContext = @{
    ScriptVersion     = "$(if ($IncludeVersion) { Get-Date -Format "dd-MM-yyyy" } else { "compiled" })"
    XamlWindows       = @{}
    SystemInfo        = `$null
    OemKey            = `$null
    IsAdministrator   = `$false
    MainWindow        = `$null
    AvailablePrograms = @()
    AvailableTweaks   = @()
    AvoidSleep        = `$false
    isWin11           = `$null
}
"@
$script_content.Add($globalContext)

# Carregar e adicionar todas as funções
Update-Progress "Compilando funções..." 30
$functionsPath = Join-Path $workingdir "Functions"
$functionFiles = Get-ChildItem -Path $functionsPath -Filter "*.ps1" -File | Sort-Object Name

if ($functionFiles.Count -eq 0) {
    Write-Warning "Nenhuma função encontrada na pasta Functions"
}
else {
    foreach ($file in $functionFiles) {
        try {
            $functionContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            
            # Corrigir referências de caminho para o arquivo compilado
            $functionContent = $functionContent -replace '\$scriptRoot = Split-Path -Parent \$PSScriptRoot', '$scriptRoot = $PSScriptRoot'
            
            # Remover trechos que contenham <##>
            $functionContent = $functionContent -replace '.*<##>.*\r?\n?', ''
            
            # Remover blocos de documentação PowerShell (<# #>)
            # $functionContent = $functionContent -replace '(?s)\s*<#.*?#>\s*', ''
            
            # Adicionar comentário identificando a função
            $script_content.Add($functionContent)
            
            Write-Host "[COMPILADO] Função: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Erro ao compilar função $($file.Name): $($_.Exception.Message)"
        }
    }
}

# Carregar e adicionar dados JSON
Update-Progress "Compilando dados JSON..." 50
$dataPath = Join-Path $workingdir "Data"
$jsonFiles = Get-ChildItem -Path $dataPath -Filter "*.json" -File

if ($jsonFiles.Count -gt 0) {
    
    foreach ($file in $jsonFiles) {
        try {
            $jsonContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            $variableName = "compiled" + $file.BaseName.Replace("Available", "")
            
            # Validar JSON
            $null = $jsonContent | ConvertFrom-Json -ErrorAction Stop
            
            # $script_content.Add("`n# Dados: $($file.Name)")
            $script_content.Add("`$$variableName = @'")
            $script_content.Add($jsonContent)
            $script_content.Add("'@ | ConvertFrom-Json")
            
            Write-Host "[COMPILADO] Dados: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Erro ao compilar dados $($file.Name): $($_.Exception.Message)"
        }
    }
}

# Carregar e adicionar arquivos XAML
Update-Progress "Compilando interfaces XAML..." 70
$windowsPath = Join-Path $workingdir "Windows"
$xamlFiles = Get-ChildItem -Path $windowsPath -Filter "*.xaml" -File

if ($xamlFiles.Count -gt 0) {
    
    foreach ($file in $xamlFiles) {
        try {
            $xamlContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            
            # Gerar nome da variável usando a mesma lógica do projeto original
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $variableName = $baseName.Substring(0,1).ToLower() + $baseName.Substring(1) + 'Xaml'
            
            # $script_content.Add("`n# Interface: $($file.Name)")
            $script_content.Add("`$$variableName = @'")
            $script_content.Add($xamlContent)
            $script_content.Add("'@")
            
            # Adicionar ao mapeamento global
            $windowBaseName = $file.BaseName
            $script_content.Add("`$global:ScriptContext.XamlWindows['$windowBaseName'] = '$variableName'")
            
            Write-Host "[COMPILADO] Interface: $($file.Name) -> `$$variableName" -ForegroundColor Green
        }
        catch {
            Write-Warning "Erro ao compilar interface $($file.Name): $($_.Exception.Message)"
        }
    }
}

# Adicionar código principal do Main.ps1 (excluindo partes já compiladas)
Update-Progress "Integrando código principal..." 90
try {
    $mainContent = Get-Content "Main.ps1" -Raw -Encoding UTF8 -ErrorAction Stop
    
    # Encontrar início do código principal (após carregamento de XAML)
    $startPattern = 'try {'
    $lines = $mainContent -split "`r?`n"
    $startIndex = -1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'INICIALIZAÇÃO DAS JANELAS PRINCIPAIS' -or $lines[$i] -match 'INICIALIZACAO DAS JANELAS PRINCIPAIS') {
            # Encontrar o 'try {' anterior
            for ($j = $i; $j -ge 0; $j--) {
                if ($lines[$j] -match '^\s*try\s*\{\s*$') {
                    $startIndex = $j
                    break
                }
            }
            break
        }
    }
    
    if ($startIndex -ge 0) {
        # Pegar apenas a parte do código após o carregamento dinâmico
        $processedLines = $lines[$startIndex..($lines.Count-1)]
        $processedContent = $processedLines -join "`r`n"
        Write-Host "[INFO] Código principal extraído a partir da linha $startIndex" -ForegroundColor Cyan
    } else {
        # Fallback: usar todo o conteúdo e remover seções conhecidas
        $processedContent = $mainContent
        Write-Host "[INFO] Usando conteúdo completo como fallback" -ForegroundColor Yellow
    }
    
    # Remover trechos que contenham <##>
    $processedContent = $processedContent -replace '.*<##>.*\r?\n?', ''
    
    # Remover blocos de documentação PowerShell (<# #>)
    $processedContent = $processedContent -replace '(?s)\s*<#.*?#>\s*', ''
    
    # Limpar linhas vazias excessivas
    $processedContent = $processedContent -replace '\n\s*\n\s*\n', "`n`n"
    
    $script_content.Add("`n# === CODIGO PRINCIPAL ===")
    $script_content.Add($processedContent)
    
    Write-Host "[COMPILADO] Código principal integrado" -ForegroundColor Green
}
catch {
    Write-Error "Erro ao processar Main.ps1: $($_.Exception.Message)"
    Pop-Location
    exit 1
}

# Escrever arquivo compilado
Update-Progress "Finalizando compilação..." 95
try {
    # Salvar com UTF-8 BOM usando .NET
    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    $content = $script_content -join "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $workingdir $OutputName), $content, $utf8WithBom)
    Write-Progress -Activity "Compilando PostInstall" -Completed
    
    $fileSize = [math]::Round((Get-Item $OutputName).Length / 1KB, 2)
    Write-Host "`n[SUCESSO] Compilação concluída!" -ForegroundColor Green
    Write-Host "Arquivo gerado: $OutputName ($fileSize KB)" -ForegroundColor Cyan
    Write-Host "Funções compiladas: $($functionFiles.Count)" -ForegroundColor Cyan
    Write-Host "Interfaces compiladas: $($xamlFiles.Count)" -ForegroundColor Cyan
    Write-Host "Dados compilados: $($jsonFiles.Count)" -ForegroundColor Cyan
}
catch {
    Write-Error "Erro ao escrever arquivo compilado: $($_.Exception.Message)"
    Pop-Location
    exit 1
}

# Validar sintaxe do arquivo compilado
Update-Progress -Activity "Validando" -StatusMessage "Verificando sintaxe do arquivo compilado" -Percent 0
try {
    $null = Get-Command -Syntax ".\$OutputName" -ErrorAction Stop
    Write-Host "[VALIDAÇÃO] Sintaxe do arquivo compilado está correta" -ForegroundColor Green
}
catch {
    Write-Warning "Aviso de sintaxe no arquivo compilado: $($_.Exception.Message)"
    if (-not $Debug) {
        Write-Host "Execute com -Debug para manter arquivos temporários e investigar" -ForegroundColor Yellow
    }
}
Write-Progress -Activity "Validando" -Completed

# Limpeza de arquivos temporários (se não estiver em modo debug)
if (-not $Debug) {
    # Remover arquivos temporários se existirem
    Get-ChildItem -Path "." -Filter "*.tmp" -File | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "." -Filter "*_temp.ps1" -File | Remove-Item -Force -ErrorAction SilentlyContinue
}
else {
    Write-Host "[DEBUG] Modo debug ativo - arquivos temporários mantidos" -ForegroundColor Yellow
}

# Executar arquivo compilado se solicitado
if ($Run) {
    Write-Host "`n[EXECUÇÃO] Iniciando arquivo compilado..." -ForegroundColor Magenta
    
    $script = "& '$workingdir\$OutputName' $Arguments"
    $powershellcmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { $powershellcmd }

    try {
        Start-Process $processCmd -ArgumentList "$powershellcmd -NoProfile -ExecutionPolicy Bypass -Command $script"
        Write-Host "[SUCESSO] Arquivo compilado executado em nova janela" -ForegroundColor Green
    }
    catch {
        Write-Warning "Erro ao executar arquivo compilado: $($_.Exception.Message)"
        Write-Host "Tente executar manualmente: .\$OutputName" -ForegroundColor Yellow
    }
}

Pop-Location

Write-Host "`n=== COMPILAÇÃO CONCLUÍDA ==="
Write-Host "Para executar: .\$OutputName" -ForegroundColor White
Write-Host "Para recompilar: .\Build-PostInstall.ps1" -ForegroundColor White
if ($Debug) {
    Write-Host "Modo debug ativo - verifique arquivos temporários para troubleshooting" -ForegroundColor Yellow
}