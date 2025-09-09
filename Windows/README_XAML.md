# Sistema de Carregamento Dinâmico de XAML

Este sistema permite carregar arquivos XAML de forma **completamente automática**, descobrindo e carregando todas as janelas disponíveis na pasta `Windows/` sem necessidade de configuração manual.

## Como Funciona

O sistema utiliza **descoberta automática** através das seguintes funções:

### Funções Principais:
- `Get-XamlContent` - Carrega conteúdo XAML de arquivos
- `Get-VariableNameFromFile` - Gera nomes de variáveis automaticamente
- `Get-XamlByWindowName` - Acessa janelas por nome simplificado
- `Get-AvailableWindows` - Lista todas as janelas disponíveis
- `New-XamlDialog` - Cria novas instâncias de diálogos XAML dinamicamente

### Processo Automático:
1. **Descobre automaticamente** todos os arquivos `.xaml` na pasta `Windows/`
2. **Gera nomes de variáveis** seguindo convenções inteligentes
3. **Carrega e valida** cada arquivo XAML
4. **Cria mapeamentos globais** para fácil acesso
5. **Registra logs detalhados** de todo o processo
6. **Trata erros** individualmente sem interromper o carregamento

## Estrutura de Arquivos

```
PostInstall/
├── Main.ps1
└── Windows/
    ├── SplashScreen.xaml      # Tela de splash
    ├── MainWindow.xaml        # Janela principal
    ├── ActivationDialog.xaml  # Diálogo de ativação
    └── ExampleDialog.xaml     # Exemplo de nova janela
```

## Como Adicionar uma Nova Janela

### ✨ **EXTREMAMENTE SIMPLES!**

**Passo único:** Crie um arquivo `.xaml` na pasta `Windows/`

Isso é tudo! O sistema fará o resto automaticamente:

1. **Descoberta automática** - O arquivo será detectado na próxima execução
2. **Variável criada** - Nome gerado automaticamente seguindo convenções
3. **Mapeamento global** - Acesso facilitado através de funções utilitárias

### Convenções de Nomenclatura

| Arquivo XAML | Variável Gerada | Acesso Simplificado |
|--------------|-----------------|--------------------|
| `MainWindow.xaml` | `$mainWindowXaml` | `Get-XamlByWindowName 'MainWindow'` |
| `SplashScreen.xaml` | `$splashScreenXaml` | `Get-XamlByWindowName 'SplashScreen'` |
| `ActivationDialog.xaml` | `$activationDialogXaml` | `Get-XamlByWindowName 'ActivationDialog'` |
| `MinhaJanela.xaml` | `$minhaJanelaXaml` | `Get-XamlByWindowName 'MinhaJanela'` |

### Exemplos de Uso

```powershell
# Método tradicional (ainda funciona)
$minhaJanela = [Windows.Markup.XamlReader]::Parse($minhaJanelaXaml)

# Método simplificado (recomendado)
$xamlContent = Get-XamlByWindowName 'MinhaJanela'
$minhaJanela = [Windows.Markup.XamlReader]::Parse($xamlContent)

# Listar todas as janelas disponíveis
$janelasDisponiveis = Get-AvailableWindows
Write-Host "Janelas disponíveis: $($janelasDisponiveis -join ', ')"
```

## Vantagens do Sistema

### ✅ **Organização**
- Separação clara entre lógica (PowerShell) e interface (XAML)
- Estrutura de pastas organizada
- Código mais limpo e legível

### ✅ **Manutenibilidade**
- Arquivos XAML podem ser editados independentemente
- Mudanças na interface não afetam a lógica
- Fácil localização de problemas

### ✅ **Escalabilidade**
- Adicionar novas janelas é simples e rápido
- Sistema automático de carregamento
- Reutilização de código

### ✅ **Robustez**
- Validação automática de arquivos
- Tratamento de erros detalhado
- Logs informativos para debugging

### ✅ **Flexibilidade**
- Suporte a qualquer número de janelas
- Carregamento condicional possível
- Fácil desabilitação temporária

### ✅ **Estabilidade**
- Criação dinâmica de diálogos evita problemas de estado
- Cada instância é completamente independente
- Eliminação de erros de reutilização

## Resolução de Problemas de Estado

O sistema implementa criação dinâmica de diálogos para resolver problemas comuns do WPF:

### Problema Original
- Diálogos criados uma única vez no início
- Após fechamento, ficavam em estado inválido
- Tentativas de reabertura resultavam em erro

### Solução Implementada
- Função `New-XamlDialog` cria novas instâncias a cada abertura
- Cada diálogo é completamente independente
- Eventos configurados dinamicamente para cada instância
- Eliminação total de problemas de reutilização

### Benefícios da Abordagem
- **Confiabilidade**: Diálogos sempre funcionam, independente de quantas vezes foram abertos
- **Isolamento**: Cada instância é independente das anteriores
- **Flexibilidade**: Permite múltiplos diálogos simultâneos se necessário
- **Manutenção**: Código mais limpo e reutilizável

## Exemplo Prático

### Cenário: Adicionando uma nova janela de configurações

1. **Crie o arquivo** `ConfigDialog.xaml` na pasta `Windows/`
2. **Execute o script** - A janela será automaticamente descoberta
3. **Use a janela:**

```powershell
# O sistema automaticamente criará a variável $configDialogXaml
# E adicionará 'ConfigDialog' ao mapeamento global

# Verificar se a janela foi carregada
if ('ConfigDialog' -in (Get-AvailableWindows)) {
    $configXaml = Get-XamlByWindowName 'ConfigDialog'
    $configWindow = [Windows.Markup.XamlReader]::Parse($configXaml)
    $configWindow.ShowDialog()
}
```

### Janelas Atualmente Disponíveis

O sistema descobriu automaticamente as seguintes janelas:
- `AboutDialog` → `$aboutDialogXaml`
- `ActivationDialog` → `$activationDialogXaml`
- `AppInstallDialog` → `$appInstallDialogXaml`
- `FinalizeDialog` → `$finalizeDialogXaml`
- `LogViewer` → `$logViewerXaml`
- `MainWindow` → `$mainWindowXaml`
- `PermissionsDialog` → `$permissionsDialogXaml`
- `SplashScreen` → `$splashScreenXaml`

## Logs e Debugging

O sistema gera logs detalhados para facilitar o debugging:

- `[SUCESSO]` - Arquivo XAML carregado com sucesso
- `[INFO]` - Variável definida no escopo
- `[ERRO]` - Problemas no carregamento

Todos os logs são registrados através da função `Write-InstallLog` existente.

## Tratamento de Erros

O sistema possui tratamento robusto de erros:

1. **Validação de existência** do arquivo
2. **Captura de exceções** durante o carregamento
3. **Mensagens informativas** para o usuário
4. **Interrupção segura** em caso de falha crítica

---

*Este sistema foi projetado para facilitar a manutenção e expansão da interface do usuário, mantendo a organização e robustez do código.*