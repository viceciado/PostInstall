# PostInstall - Sistema de Configuração Pós-Instalação do Windows

## Visão Geral

Este projeto é um sistema modular de configuração pós-instalação do Windows desenvolvido em PowerShell com interface gráfica WPF/XAML. O sistema permite automatizar a instalação de programas, aplicação de tweaks do sistema e configurações diversas através de uma interface amigável.

## Arquitetura do Projeto

### Estrutura de Pastas

```
PostInstall/
├── Main.ps1                    # Orquestrador principal
├── Functions/                  # Funções auxiliares modulares
│   ├── Get-*.ps1              # Funções de obtenção de dados
│   ├── Set-*.ps1              # Funções de configuração
│   ├── Show-*.ps1             # Funções de interface
│   ├── Invoke-*.ps1           # Funções de execução
│   └── Write-InstallLog.ps1   # Sistema de logging
├── Windows/                    # Arquivos XAML das interfaces
│   ├── MainWindow.xaml        # Janela principal
│   ├── SplashScreen.xaml      # Tela de carregamento
│   └── *.xaml                 # Diálogos específicos
├── Data/                       # Dados de configuração
│   ├── AvailablePrograms.json # Lista de programas disponíveis
│   └── AvailableTweaks.json   # Lista de tweaks disponíveis
└── CompileReference.ps1        # Script de compilação (referência)
```

## Fluxo de Execução do Main.ps1

### 1. Inicialização do Sistema

#### 1.1 Carregamento de Assemblies
```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Management
```

#### 1.2 Contexto Global
O sistema utiliza uma hashtable global (`$global:ScriptContext`) para compartilhar estado entre componentes:
- `ScriptVersion`: Versão do script
- `XamlWindows`: Mapeamento de janelas XAML
- `SystemInfo`: Informações do sistema
- `MainWindow`: Referência à janela principal
- `AvailablePrograms/AvailableTweaks`: Dados carregados
- `AvoidSleep`: Estado de prevenção de suspensão

### 2. Sistema de Carregamento Dinâmico de Funções

#### 2.1 Descoberta Automática
- Escaneia a pasta `Functions/` por arquivos `.ps1`
- Carrega cada função usando dot-sourcing
- Registra sucessos e falhas no log
- Implementa tratamento robusto de erros

#### 2.2 Função `Import-FunctionFile`
- Valida existência do arquivo
- Executa dot-sourcing com tratamento de exceções
- Fornece feedback visual colorido
- Retorna status booleano de sucesso

### 3. Sistema de Carregamento Dinâmico de XAML

#### 3.1 Descoberta e Carregamento
- Escaneia pasta `Windows/` por arquivos `.xaml`
- Gera nomes de variáveis consistentes usando `Get-VariableNameFromFile`
- Carrega conteúdo usando `Get-XamlContent`
- Cria mapeamento global em `$global:ScriptContext.XamlWindows`

#### 3.2 Convenção de Nomenclatura
- `MainWindow.xaml` → `$mainWindowXaml`
- `SplashScreen.xaml` → `$splashScreenXaml`
- `ActivationDialog.xaml` → `$activationDialogXaml`

### 4. Inicialização das Interfaces

#### 4.1 Parsing XAML
- Converte strings XAML em objetos XML
- Usa `XamlReader` para criar objetos WPF
- Estabelece referência global à MainWindow

#### 4.2 Event Handlers
- Configura eventos de clique para todos os botões
- Implementa funcionalidades específicas:
  - Instalação de programas
  - Aplicação de tweaks
  - Montagem de imagens ISO (Office)
  - Correção de permissões
  - Ativação do Windows
  - Gerenciamento de temas

### 5. Fluxo de Inicialização com Splash

#### 5.1 Sequência de Startup
1. Exibe SplashScreen
2. Testa conectividade com internet
3. Coleta informações do sistema
4. Fecha SplashScreen
5. Ativa prevenção de suspensão
6. Exibe MainWindow (modal)

#### 5.2 Tratamento de Erros
- Captura exceções em cada etapa
- Garante fechamento do SplashScreen
- Exibe diálogos de erro informativos
- Registra erros no log do sistema

### 6. Rotinas de Limpeza (Finally)

- Restaura configurações de suspensão
- Remove contexto global
- Registra conclusão no log

## Funcionalidades Principais

### 1. Instalação de Programas
- **Fonte de Dados**: `Data/AvailablePrograms.json`
- **Integração**: WinGet para instalação automatizada
- **Categorização**: Programas organizados por categoria (Compressão, Navegador, etc.)
- **Recomendações**: Sistema de marcação de programas recomendados
- **Interface**: Diálogo dedicado com seleção múltipla

### 2. Sistema de Tweaks
- **Fonte de Dados**: `Data/AvailableTweaks.json`
- **Tipos de Modificação**:
  - Alterações de registro do Windows
  - Comandos PowerShell personalizados
  - Limpeza de arquivos temporários
  - Configurações específicas do Windows 11
- **Recursos Avançados**:
  - Sistema de undo para reversão
  - Tweaks condicionais por versão do Windows
  - Categorização por impacto e função

### 3. Gerenciamento de Temas
- **Funcionalidade**: Alternância entre tema claro/escuro do Windows
- **Aplicação**: Imediata através da API do sistema
- **Interface**: Botão com estado visual dinâmico
- **Persistência**: Configuração mantida pelo sistema operacional

### 4. Correção de Permissões
- **Seleção**: Interface para escolha múltipla de pastas
- **Persistência**: Sistema salva seleções para reutilização
- **Execução**: Opções de execução imediata ou agendada
- **Ferramenta**: Utiliza `icacls.exe` com privilégios elevados
- **Interface**: Progresso em tempo real com feedback visual

### 5. Instalação do Microsoft Office
- **Método**: Montagem de imagens ISO
- **Interface**: Seletor de arquivos integrado
- **Estados**: Botão com estados visuais (montar/desmontar)
- **Automação**: Abertura automática da unidade montada
- **Segurança**: Validação de arquivos e tratamento de erros

### 6. Ativação do Windows
- **Detecção**: Busca automática por chaves OEM no sistema
- **Interface**: Diálogo dedicado para processo de ativação
- **Validação**: Verificação de status de licença
- **Logging**: Registro detalhado do processo

### 7. Utilitários do Sistema
- **Importação de Drivers**: Interface para seleção e instalação via `pnputil.exe`
- **Windows Update**: Acesso direto às configurações do sistema
- **Gerenciador de Dispositivos**: Abertura rápida via `devmgmt.msc`
- **Prevenção de Suspensão**: Controle automático durante operações

## Pontos Fortes da Arquitetura

### 1. Modularidade Excepcional
- **Funções Independentes**: Cada função em arquivo separado facilita manutenção
- **Carregamento Dinâmico**: Sistema descobre e carrega automaticamente novos componentes
- **Separação Clara**: Interface (XAML), lógica (Functions) e dados (JSON) bem separados
- **Reutilização**: Componentes podem ser facilmente reutilizados

### 2. Robustez e Confiabilidade
- **Tratamento de Erros**: Múltiplas camadas de tratamento de exceções
- **Fallbacks Inteligentes**: Caminhos alternativos para logs e configurações
- **Validações Rigorosas**: Verificações de existência de arquivos e permissões
- **Recuperação Graceful**: Sistema continua funcionando mesmo com falhas parciais

### 3. Experiência do Usuário
- **Interface Moderna**: Design WPF com estilos customizados e consistentes
- **Feedback Visual**: Cores, estados dos botões e notificações indicam progresso
- **Logging Integrado**: Sistema de log com múltiplos níveis e cores
- **Responsividade**: Interface não trava durante operações longas

### 4. Flexibilidade e Extensibilidade
- **Configuração JSON**: Programas e tweaks definidos em arquivos de dados editáveis
- **Contexto Global**: Estado compartilhado facilita comunicação entre componentes
- **Sistema de Janelas**: Múltiplas interfaces especializadas para diferentes funções
- **Convenções Consistentes**: Padrões claros para nomenclatura e estrutura

## Pontos de Melhoria Identificados

### 1. Gerenciamento de Dependências

**Problema Atual**: Funções podem ter dependências implícitas entre si, sem controle de ordem de carregamento.

**Impacto**: Possíveis falhas se uma função depender de outra que ainda não foi carregada.

**Solução Sugerida**:
```powershell
# Implementar sistema de dependências explícitas
function Import-FunctionWithDependencies {
    param(
        [string]$FunctionName,
        [string[]]$Dependencies = @()
    )
    
    # Carregar dependências primeiro
    foreach ($dep in $Dependencies) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Import-FunctionFile -FunctionFileName "$dep.ps1"
        }
    }
    
    # Carregar função principal
    Import-FunctionFile -FunctionFileName "$FunctionName.ps1"
}
```

### 2. Configuração Centralizada

**Problema Atual**: Configurações espalhadas pelo código (caminhos, timeouts, cores, etc.).

**Impacto**: Dificuldade para modificar comportamentos sem editar código.

**Solução Sugerida**:
```json
// config.json
{
  "paths": {
    "logPrimary": "%SystemRoot%\Setup\Scripts\Install.log",
    "logFallback": "%APPDATA%\Install.log"
  },
  "ui": {
    "colors": {
      "primary": "#993233",
      "success": "#28A745",
      "error": "#DC3545"
    },
    "timeouts": {
      "splash": 3000,
      "notification": 5000
    }
  },
  "features": {
    "autoElevate": true,
    "preventSleep": true,
    "internetCheck": true
  }
}
```

### 3. Sistema de Plugins

**Problema Atual**: Adicionar novas funcionalidades requer modificação do código principal.

**Impacto**: Dificuldade para extensões de terceiros e manutenção de customizações.

**Solução Sugerida**:
```powershell
# Interface padrão para plugins
class IPlugin {
    [string] $Name
    [string] $Version
    [string[]] $Dependencies
    
    [void] Initialize() { throw "Not implemented" }
    [void] Execute() { throw "Not implemented" }
    [void] Cleanup() { throw "Not implemented" }
}

# Sistema de registro de plugins
function Register-Plugin {
    param([IPlugin]$Plugin)
    $global:ScriptContext.Plugins[$Plugin.Name] = $Plugin
}
```

### 4. Validação de Integridade

**Problema Atual**: Não há verificação de integridade dos arquivos carregados.

**Impacto**: Possível execução de código malicioso ou corrompido.

**Solução Sugerida**:
```powershell
function Test-FileIntegrity {
    param(
        [string]$FilePath,
        [string]$ExpectedHash = $null
    )
    
    # Verificar sintaxe PowerShell
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $FilePath -Raw), [ref]$null
        )
    }
    catch {
        throw "Sintaxe inválida em $FilePath: $($_.Exception.Message)"
    }
    
    # Verificar hash se fornecido
    if ($ExpectedHash) {
        $actualHash = Get-FileHash $FilePath -Algorithm SHA256
        if ($actualHash.Hash -ne $ExpectedHash) {
            throw "Hash inválido para $FilePath"
        }
    }
}
```

### 5. Performance e Otimização

**Problema Atual**: Carregamento sequencial pode ser lento com muitas funções.

**Impacto**: Tempo de inicialização aumenta proporcionalmente ao número de componentes.

**Solução Sugerida**:
```powershell
# Carregamento paralelo de funções independentes
function Import-FunctionsParallel {
    param([string[]]$FunctionFiles)
    
    $jobs = @()
    foreach ($file in $FunctionFiles) {
        $jobs += Start-Job -ScriptBlock {
            param($FilePath)
            . $FilePath
        } -ArgumentList $file
    }
    
    # Aguardar conclusão
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
}

# Cache de funções compiladas
function Get-CompiledFunction {
    param([string]$FunctionName)
    
    $cacheFile = "$env:TEMP\PostInstall_$FunctionName.cache"
    if (Test-Path $cacheFile) {
        return Import-Clixml $cacheFile
    }
    return $null
}
```

### 6. Internacionalização

**Problema Atual**: Strings hardcoded em português limitam uso internacional.

**Impacto**: Barreira para adoção em outros países/idiomas.

**Solução Sugerida**:
```powershell
# Sistema de recursos localizáveis
function Get-LocalizedString {
    param(
        [string]$Key,
        [string]$Culture = (Get-Culture).Name
    )
    
    $resourceFile = "Resources\$Culture.json"
    if (-not (Test-Path $resourceFile)) {
        $resourceFile = "Resources\en-US.json"  # Fallback
    }
    
    $resources = Get-Content $resourceFile | ConvertFrom-Json
    return $resources.$Key ?? $Key
}

# Uso: Get-LocalizedString "InstallationComplete"
```

### 7. Testes Automatizados

**Problema Atual**: Ausência de testes unitários e de integração.

**Impacto**: Dificuldade para detectar regressões e validar funcionalidades.

**Solução Sugerida**:
```powershell
# Framework de testes simples
function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [scriptblock]$ExpectedResult
    )
    
    try {
        $result = & $TestScript
        $expected = & $ExpectedResult
        
        if ($result -eq $expected) {
            Write-Host "✓ $TestName" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "✗ $TestName - Expected: $expected, Got: $result" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ $TestName - Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Exemplo de teste
Test-Function "Get-VariableNameFromFile" {
    Get-VariableNameFromFile "MainWindow.xaml"
} {
    "mainWindowXaml"
}
```

### 8. Documentação Automática

**Problema Atual**: Documentação limitada e manual das funções.

**Impacto**: Dificuldade para novos desenvolvedores entenderem e contribuírem.

**Solução Sugerida**:
```powershell
# Gerador de documentação automática
function Export-FunctionDocumentation {
    param([string]$OutputPath = "Documentation")
    
    $functions = Get-ChildItem "Functions\*.ps1"
    $docs = @()
    
    foreach ($file in $functions) {
        $content = Get-Content $file.FullName -Raw
        $help = Get-Help $file.BaseName -ErrorAction SilentlyContinue
        
        if ($help) {
            $docs += @{
                Name = $file.BaseName
                Synopsis = $help.Synopsis
                Description = $help.Description.Text
                Parameters = $help.Parameters.Parameter
                Examples = $help.Examples.Example
            }
        }
    }
    
    $docs | ConvertTo-Json -Depth 3 | Out-File "$OutputPath\functions.json"
}
```

## Considerações de Segurança

### 1. Execução com Privilégios
- **Elevação Automática**: Sistema detecta quando privilégios administrativos são necessários
- **Validação de Permissões**: Verificação antes de operações críticas
- **Isolamento**: Operações privilegiadas executadas em processos separados
- **Auditoria**: Log detalhado de todas as operações com privilégios elevados

### 2. Validação de Entrada
- **Sanitização**: Limpeza de caminhos de arquivo e parâmetros
- **Whitelist**: Validação contra lista de valores permitidos
- **Escape**: Tratamento adequado de caracteres especiais
- **Limites**: Verificação de tamanhos e ranges de valores

### 3. Proteção contra Injeção
- **Parametrização**: Uso de parâmetros em vez de concatenação de strings
- **Validação de Comandos**: Verificação de comandos antes da execução
- **Sandbox**: Execução de código não confiável em ambiente isolado
- **Assinatura Digital**: Verificação de assinaturas quando disponível

## Análise de Qualidade do Código

### Pontos Positivos

1. **Arquitetura Limpa**: Separação clara de responsabilidades
2. **Tratamento de Erros**: Abrangente e bem estruturado
3. **Logging Detalhado**: Sistema robusto de auditoria
4. **Modularidade**: Fácil manutenção e extensão
5. **Convenções Consistentes**: Padrões claros em todo o código
6. **Interface Profissional**: Design moderno e responsivo

### Áreas para Melhoria

1. **Documentação**: Expandir comentários e help das funções
2. **Testes**: Implementar cobertura de testes automatizados
3. **Performance**: Otimizar carregamento e operações pesadas
4. **Configurabilidade**: Centralizar configurações em arquivos externos
5. **Internacionalização**: Suporte a múltiplos idiomas
6. **Versionamento**: Sistema de controle de versões dos componentes

## Conclusão

O projeto PostInstall demonstra uma arquitetura exemplar para automação de configurações pós-instalação do Windows. A abordagem modular, combinada com o sistema de carregamento dinâmico, cria uma base sólida e extensível.

### Principais Forças
- **Modularidade excepcional** facilita manutenção e desenvolvimento
- **Robustez** através de tratamento abrangente de erros
- **Experiência do usuário** profissional e intuitiva
- **Flexibilidade** para customização e extensão

### Oportunidades de Evolução
- **Sistema de plugins** para extensibilidade de terceiros
- **Testes automatizados** para garantir qualidade
- **Configuração centralizada** para maior flexibilidade
- **Internacionalização** para alcance global

A implementação de um sistema de compilação permitirá distribuir o projeto como um único arquivo executável, mantendo todas as vantagens modulares durante o desenvolvimento. Este é um projeto maduro e bem estruturado, pronto para evolução e uso profissional.