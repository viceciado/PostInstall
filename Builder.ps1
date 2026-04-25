#region Documentation and Parameters
<#
.SYNOPSIS
Script compilador para o projeto PostInstall

.DESCRIPTION
Este script compila todo o projeto PostInstall em um único arquivo .ps1 executável,
incluindo todas as funções, arquivos XAML e dados JSON necessários.

.PARAMETER OutputName
Nome do arquivo de saída (padrão: PostInstall.ps1)

.PARAMETER IncludeVersion
Inclui timestamp na versão do script compilado

.EXAMPLE
.\Builder.ps1
Compila o projeto com configurações padrão

.EXAMPLE
.\Builder.ps1 -OutputName "MyPostInstall.ps1"
Compila com nome personalizado
#>

param (
    [string]$OutputName = "PostInstall.ps1",
    [switch]$IncludeVersion = $true
)
#endregion

#region Environment Setup
# Verificar se já existe arquivo compilado e remover se necessário
if (Test-Path ".\$OutputName") {
    if ((Get-Item ".\$OutputName" -ErrorAction SilentlyContinue).IsReadOnly) {
        Remove-Item ".\$OutputName" -Force
    } else {
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
        [Parameter(Mandatory, position = 0)]
        [string]$StatusMessage,

        [Parameter(Mandatory, position = 1)]
        [ValidateRange(0, 100)]
        [int]$Percent,

        [Parameter(position = 2)]
        [string]$Activity = "Compilando PostInstall"
    )

    Write-Progress -Activity $Activity -Status $StatusMessage -PercentComplete $Percent
}
#endregion

#region Project Validation
# Cabeçalho do arquivo compilado
$header = @"
################################################################################################################
###                                            Script PostInstall                                            ###
###                                                @viceciado                                                ###
###                                                                                                          ###
### AVISO: Este arquivo foi gerado automaticamente. NÃO modifique este arquivo diretamente, pois ele será    ###
###        sobrescrito na próxima compilação.                                                                ###
###                                                                                                          ###
###      Para modificações, edite os arquivos fonte na pasta do projeto e execute Builder.ps1                ###
###                                                                                                          ###
###                                    Build compilada em: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")                               ###
################################################################################################################
"@

Update-Progress "Inicializando compilação..." 0

# Validar estrutura do projeto
$requiredFolders = @("Core", "Features", "DialogInitializers", "Windows", "Data")
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

#endregion

#region Header and Runtime Context
Update-Progress "Validação concluída. Iniciando compilação..." 5

# Criar lista para o conteúdo do script
$script_content = [System.Collections.Generic.List[string]]::new()
$compilationErrors = [System.Collections.Generic.List[object]]::new()

function Add-CompilationError {
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $compilationErrors.Add([PSCustomObject]@{
            Stage = $Stage
            File = $File
            Message = $Message
        }) | Out-Null
}

function Fail-IfCompilationErrors {
    if ($compilationErrors.Count -gt 0) {
        Write-Error "Falha na compilação de blocos. Erros encontrados:"
        foreach ($err in $compilationErrors) {
            Write-Error "[$($err.Stage)] $($err.File): $($err.Message)"
        }
        Pop-Location
        exit 1
    }
}

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
if (-not `$global:ScriptContext) {
    `$global:ScriptContext = @{
        ScriptVersion          = "$(if ($IncludeVersion) { Get-Date -Format 'dd-MM-yyyy' } else { 'compiled' })"
        IsCompiled             = `$true
        SkipEntryPoint         = `$false
        CompiledScriptPath     = `$null
        AvailablePrograms      = @()
        AvailableTweaks        = @()
        AppliedTweaks          = @{}
        UI = @{
            XamlWindows        = @{}
            MainWindow         = `$null
            SplashScreenWindow = `$null
        }
        System = @{
            IsAdministrator    = `$false
            isWin11            = `$null
            AvoidSleep         = `$false
            Info               = `$null
        }
        Config = @{
            OemKey                   = `$null
            ClientName               = `$null
            TechnicianName           = `$null
            OsNumber                 = `$null
            PersistedSelectedFolders = @()
        }
    }
} else {
    # Não sobrescrever ScriptContext existente; garantir apenas chaves essenciais
    if (-not `$global:ScriptContext.ContainsKey('IsCompiled')) { `$global:ScriptContext.IsCompiled = `$true } else { `$global:ScriptContext.IsCompiled = `$true }
    if (-not `$global:ScriptContext.ContainsKey('CompiledScriptPath')) { `$global:ScriptContext.CompiledScriptPath = `$null }
    if (-not `$global:ScriptContext.ContainsKey('UI') -or `$null -eq `$global:ScriptContext.UI) { `$global:ScriptContext.UI = @{ XamlWindows = @{}; MainWindow = `$null; SplashScreenWindow = `$null } }
    elseif (-not `$global:ScriptContext.UI.ContainsKey('XamlWindows') -or `$null -eq `$global:ScriptContext.UI.XamlWindows) { `$global:ScriptContext.UI.XamlWindows = @{} }
    # Não alterar SkipEntryPoint aqui para preservar valor definido externamente
}
"@
$script_content.Add($globalContext)
$script_content.Add("")

# Inicializar CompiledScriptPath no próprio compilado (em runtime)
$script_content.Add(@"
if (-not `$global:ScriptContext.CompiledScriptPath) {
    try { `$global:ScriptContext.CompiledScriptPath = `$MyInvocation.MyCommand.Path } catch {}
}
"@)
#endregion

#region Compile Functions
# Carregar e adicionar todas as funções
Update-Progress "Compilando funções..." 30

# Coletar arquivos em ordem de dependência:
#   1. Core/ (utilitários base)
#   2. Features/ (funcionalidades de alto nível)
#   3. DialogInitializers/ (inicializadores de janelas)
#   4. Functions/ restante (dispatcher)
$functionFiles = @(
    if (Test-Path (Join-Path $workingdir 'Core')) { Get-ChildItem (Join-Path $workingdir 'Core')               -Recurse -Filter '*.ps1' -File | Sort-Object FullName }
    if (Test-Path (Join-Path $workingdir 'Features')) { Get-ChildItem (Join-Path $workingdir 'Features')           -Recurse -Filter '*.ps1' -File | Sort-Object FullName }
    if (Test-Path (Join-Path $workingdir 'DialogInitializers')) { Get-ChildItem (Join-Path $workingdir 'DialogInitializers') -Filter  '*.ps1' -File | Sort-Object Name }
    if (Test-Path (Join-Path $workingdir 'Functions')) { Get-ChildItem (Join-Path $workingdir 'Functions')          -Filter  '*.ps1' -File | Sort-Object Name }
)

if ($functionFiles.Count -eq 0) {
    Write-Warning "Nenhuma função encontrada"
} else {
    foreach ($file in $functionFiles) {
        try {
            $functionContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop

            # Validar sintaxe do arquivo de função antes de incorporar ao compilado
            $funcTokens = $null
            $funcParseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($functionContent, [ref]$funcTokens, [ref]$funcParseErrors)
            if ($funcParseErrors -and $funcParseErrors.Count -gt 0) {
                $messages = ($funcParseErrors | ForEach-Object {
                        "$($_.Message) (linha $($_.Extent.StartLineNumber), coluna $($_.Extent.StartColumnNumber))"
                    }) -join '; '
                Add-CompilationError -Stage "Functions" -File $file.Name -Message $messages
                continue
            }
            
            # Corrigir referências de caminho para o arquivo compilado
            $functionContent = $functionContent -replace '\$scriptRoot = Split-Path -Parent \$PSScriptRoot', '$scriptRoot = $PSScriptRoot'
            
            # Remover trechos que contenham <##>
            $functionContent = $functionContent -replace '.*<##>.*\r?\n?', ''
            
            # Remover blocos de documentação PowerShell (<# #>)
            # $functionContent = $functionContent -replace '(?s)\s*<#.*?#>\s*', ''
            
            # Adicionar comentário identificando a função
            $script_content.Add($functionContent)
            
            Write-Host "[COMPILADO] Função: $($file.Name)" -ForegroundColor Green
        } catch {
            $message = $_.Exception.Message
            Write-Warning "Erro ao compilar função $($file.Name): $message"
            Add-CompilationError -Stage "Functions" -File $file.Name -Message $message
        }
    }
}
#endregion

#region Compile JSON Data
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
        } catch {
            $message = $_.Exception.Message
            Write-Warning "Erro ao compilar dados $($file.Name): $message"
            Add-CompilationError -Stage "Data" -File $file.Name -Message $message
        }
    }
}
#endregion

#region Compile XAML
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
            $variableName = $baseName.Substring(0, 1).ToLower() + $baseName.Substring(1) + 'Xaml'
            
            # $script_content.Add("`n# Interface: $($file.Name)")
            $script_content.Add("`$$variableName = @'")
            $script_content.Add($xamlContent)
            $script_content.Add("'@")
            
            # Adicionar ao mapeamento global
            $windowBaseName = $file.BaseName
            $script_content.Add("if (-not `$global:ScriptContext) { `$global:ScriptContext = @{} }")
            $script_content.Add("if (-not `$global:ScriptContext.ContainsKey('UI') -or `$null -eq `$global:ScriptContext.UI) { `$global:ScriptContext.UI = @{} }")
            $script_content.Add("if (-not `$global:ScriptContext.UI.ContainsKey('XamlWindows') -or `$null -eq `$global:ScriptContext.UI.XamlWindows) { `$global:ScriptContext.UI.XamlWindows = @{} }")
            $script_content.Add("`$global:ScriptContext.UI.XamlWindows['$windowBaseName'] = '$variableName'")
            
            Write-Host "[COMPILADO] Interface: $($file.Name) -> `$$variableName" -ForegroundColor Green
        } catch {
            $message = $_.Exception.Message
            Write-Warning "Erro ao compilar interface $($file.Name): $message"
            Add-CompilationError -Stage "XAML" -File $file.Name -Message $message
        }
    }
}

Fail-IfCompilationErrors
#endregion

#region Integrate Main Entry Point
# Adicionar código principal do Main.ps1 (excluindo partes já compiladas)
Update-Progress "Integrando código principal..." 90
try {
    $mainContent = Get-Content "Main.ps1" -Raw -Encoding UTF8 -ErrorAction Stop

    # Encontrar início do código principal (após carregamento de XAML)
    $lines = $mainContent -split "`r?`n"
    $startIndex = -1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '#region ENTRYPOINT' -or $lines[$i] -match 'INICIALIZA[CÇ][AÃ]O DAS JANELAS PRINCIPAIS') {
            # Encontrar o 'try {' anterior ou usar a linha do marcador diretamente
            for ($j = $i; $j -ge 0; $j--) {
                if ($lines[$j] -match '^\s*try\s*\{\s*$') {
                    $startIndex = $j
                    break
                }
            }
            if ($startIndex -lt 0) { $startIndex = $i }
            break
        }
    }
    
    if ($startIndex -lt 0) {
        throw "Marcador de ENTRYPOINT não encontrado em Main.ps1. Estrutura obrigatória para compilação não atendida."
    }

    # Pegar apenas a parte do código após o carregamento dinâmico
    $processedLines = $lines[$startIndex..($lines.Count - 1)]
    $processedContent = $processedLines -join "`r`n"
    Write-Host "[INFO] Código principal extraído a partir da linha $startIndex" -ForegroundColor Cyan
    
    # Remover trechos que contenham <##>
    $processedContent = $processedContent -replace '.*<##>.*\r?\n?', ''
    
    # Remover blocos de documentação PowerShell (<# #>)
    $processedContent = $processedContent -replace '(?s)\s*<#.*?#>\s*', ''
    
    # Limpar linhas vazias excessivas
    $processedContent = $processedContent -replace '\n\s*\n\s*\n', "`n`n"
    
    $script_content.Add("`n# === ENTRADA PRINCIPAL ENCAPSULADA ===")
    $script_content.Add("function Start-PostInstallMain {")
    $script_content.Add($processedContent)
    $script_content.Add("}")
    $script_content.Add("")
    # Guard de entrada: só executa o Main se não estivermos importando como biblioteca
    $script_content.Add("if (-not `$global:ScriptContext.SkipEntryPoint) { Start-PostInstallMain }")
    Write-Host "[COMPILADO] Código principal integrado" -ForegroundColor Green
} catch {
    Write-Error "Erro ao processar Main.ps1: $($_.Exception.Message)"
    Pop-Location
    exit 1
}
#endregion

#region Write Artifact
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
} catch {
    Write-Error "Erro ao escrever arquivo compilado: $($_.Exception.Message)"
    Pop-Location
    exit 1
}
#endregion

#region Validate Artifact Syntax
# Validar sintaxe do arquivo compilado
Update-Progress -Activity "Validando" -StatusMessage "Verificando sintaxe do arquivo compilado" -Percent 0
try {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $workingdir $OutputName), [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        foreach ($parseError in $parseErrors) {
            Write-Host "[ERRO-SINTAXE] $($parseError.Message) (linha $($parseError.Extent.StartLineNumber), coluna $($parseError.Extent.StartColumnNumber))" -ForegroundColor Red
        }
        throw "Foram encontrados $($parseErrors.Count) erro(s) de sintaxe no arquivo compilado."
    }

    Write-Host "[VALIDAÇÃO] Sintaxe do arquivo compilado está correta" -ForegroundColor Green
} catch {
    Write-Error "Falha de sintaxe no arquivo compilado: $($_.Exception.Message)"
    Pop-Location
    exit 1
}
Write-Progress -Activity "Validando" -Completed
#endregion

#region Exit Summary
Pop-Location

Write-Host "`n=== COMPILAÇÃO CONCLUÍDA ==="
Write-Host "Para executar: .\$OutputName" -ForegroundColor White
Write-Host "Para recompilar: .\Builder.ps1" -ForegroundColor White
#endregion