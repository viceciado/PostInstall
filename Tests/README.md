# Suite de Testes — PostInstall

## Visão Geral

A suite de testes do PostInstall valida a funcionalidade e qualidade do projeto em **quatro camadas**:

| Camada | Objetivo | Alcance | Dependências | Tempo |
|--------|----------|---------|--------------|-------|
| **Smoke — LoadAll** | Verifica que todos os arquivos carregam sem erro de sintaxe | 34 funções + imports | Pester v5 | ~1s |
| **Unit — Core** | Valida funções puras com mock de dependências externas | Registry, UI, Tweaks | Pester v5 + Mock | ~2s |
| **Integration — Registry** | Testa operações reais em sandbox de registro (HKCU) | Set/Restore de valores reais | Pester v5 + HKCU access | ~1s |
| **Smoke — Builder** | Confirma que o script compilado tem sintaxe válida e funções obrigatórias | PostInstall-Compiled.ps1 | PowerShell 5.1 | ~2s |

**Total**: ~126 testes, execução completa em ~6–8 segundos.

---

## Pré-Requisitos

### Obrigatório
- **PowerShell 5.1+** (ou PowerShell 7+; projeto é compatível com ambos)
- **Pester v5.0.0+** — instale via:
  ```powershell
  Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
  ```
  **Nota**: Se você tem Pester v3, desinstale-e ou use `-Force` para permitir downgrade.

### Recomendado
- **VS Code com PowerShell Extension** — para syntax highlighting dos `.ps1` de teste
- **Git** — para committar testes e artefatos de construção com `.gitignore` apropriado
- **UTF-8 BOM em todos os `.ps1`** — veja [Encoding de Arquivos](#-encoding-de-arquivos) abaixo

### Opcional
- **EditorConfig** — para auto-aplicar UTF-8 BOM e indentação (veja `.editorconfig` na raiz do projeto)
- **VS Code Settings** — `files.encoding: utf8bom` em `.vscode/settings.json` para salvar automaticamente com BOM

---

## Como Executar — Passo a Passo

### **Opção 1: Suite Completa (Recomendado)**

```powershell
cd d:\Documentos\Projetos\Scripts\PostInstall
.\Tests\Run-Tests.ps1
```

Isso executa:
- Smoke — LoadAll (34 testes)
- Unit — Core.Registry, Core.UI, Features.Tweaks (~66 testes)
- Integration — Registry (~12 testes)
- Smoke — Builder (13 testes)

**Saída esperada**: `Tests Passed: 126, Failed: 0, Skipped: 0`

---

### **Opção 2: Por Categoria (Desenvolvimento)**

#### Apenas Smoke
```powershell
.\Tests\Run-Tests.ps1 -Tag Smoke
```
Executa `LoadAll.Tests.ps1` + `Builder.Tests.ps1` (~48 testes).

#### Apenas Unit
```powershell
.\Tests\Run-Tests.ps1 -Tag Unit
```
Executa `Core.Registry.Tests.ps1` + `Core.UI.Tests.ps1` + `Features.Tweaks.Tests.ps1` (~66 testes).

#### Apenas Integration
```powershell
.\Tests\Run-Tests.ps1 -Tag Integration
```
Executa `Registry.Integration.Tests.ps1` (~12 testes). Modifica HKCU registry (usa sandbox `HKCU:\SOFTWARE\_PostInstall_Tests\`).

#### Arquivo Específico
```powershell
Import-Module Pester -MinimumVersion 5.0.0
Invoke-Pester -Path .\Tests\Unit\Core.Registry.Tests.ps1 -Output Detailed
```

---

### Opção 3: Com Verbosidade Detalhada

```powershell
.\Tests\Run-Tests.ps1 -Verbosity Detailed
```

Mostra cada teste individual conforme passa/falha, útil para debugar falhas.

---

## Estrutura da Suite

```
Tests/
├── README.md                              ← Você está aqui
├── Run-Tests.ps1                          ← Runner central (ponto de entrada)
├── Fixtures/
│   ├── SampleTweaks.json                  ← 3 tweaks para testes (TestTweak-*)
│   └── SamplePrograms.json                ← 2 programas para testes (TestApp-*)
├── Smoke/
│   ├── LoadAll.Tests.ps1                  ← Valida dot-source de todos os arquivos
│   └── Builder.Tests.ps1                  ← Compila Builder.ps1 e valida output
├── Unit/
│   ├── Core.Registry.Tests.ps1            ← ConvertTo-RegistryType, Set-RegistryEntry, Restore-RegistryEntry
│   ├── Core.UI.Tests.ps1                  ← Get-VariableNameFromFile, Get-AvailableItems
│   └── Features.Tweaks.Tests.ps1          ← Get-TweakByName, Set-Tweak, Restore-Tweak
├── Integration/
│   └── Registry.Integration.Tests.ps1     ← Testes reais em HKCU sandbox
└── Tools/
    └── (futuro) Assert-TextEncoding.ps1   ← Validação de UTF-8 BOM
```

---

## Detalhes das Camadas

### **Smoke — LoadAll**

**Arquivo**: `Smoke/LoadAll.Tests.ps1`  
**Tag**: `Smoke`  
**Testes**: 34

O que valida:
- Cada arquivo-fonte (`.ps1`) pode ser dot-sourced sem erro de sintaxe
- Todas as ~33 funções globais esperadas são definidas após load
- Nenhuma exceção silenciosa nas declarações de função

Por que é importante: Identifica erros de sintaxe ou referências quebradas rapidamente, antes de investir tempo em testes mais profundos.

Exemplo de falha:
```
[-] Carrega sem erro: Function X
    FunctionNotFoundException: A função 'Get-SomeHelper' não foi encontrada.
```
Significa que a função dependente não foi definida ou dot-sourced na ordem errada.

---

### **Unit Tests**

**Arquivos**: `Unit/Core.*.Tests.ps1` + `Unit/Features.*.Tests.ps1`  
**Tag**: `Unit`  
**Testes**: ~66

#### **Core.Registry.Tests.ps1** (29 testes)
Valida funções de manipulação de registro do Windows:

- **ConvertTo-RegistryType** (10 testes)
  - Conversão correta de tipos: DWORD, STRING, QWORD, MULTISTRING, DELETEKEY
  - Casos especiais: valores vazios, tipos inválidos
- **Set-RegistryEntry** (11 testes)
  - Criação de chaves e propriedades
  - Atualização de valores existentes
  - Remoção de chaves inteiras (DELETEKEY)
  - Tratamento de erro quando caminho inválido
- **Restore-RegistryEntry** (8 testes)
  - Restauração de valor original
  - Marcadores especiais: `<RemoveEntry>`, `<RestoreKey>`
  - Recriação de chaves removidas

**Recursos mockados**: `Write-InstallLog`, `Test-Path`, `New-Item`, `Set-ItemProperty`, `Remove-Item`

---

#### **Core.UI.Tests.ps1** (19 testes)
Valida funções de UI e leitura de dados:

- **Get-VariableNameFromFile** (7 testes)
  - Extração de nomes de variáveis a partir de XAML
  - Casos: MainWindow, dialogs especiais, XAML mal-formado
- **Get-AvailableItems** (12 testes)
  - Leitura de `AvailableTweaks.json` e `AvailablePrograms.json`
  - Filtragem por `ItemType` (Programs, Tweaks, TweaksCategories)
  - Comportamento em modo compilado vs não-compilado
  - Tratamento de JSON inválido

**Recursos mockados**: `$global:ScriptContext.IsCompiled`, `@()` arrays de fixture

---

#### **Features.Tweaks.Tests.ps1** (18 testes)
Valida aplicação e restauração de tweaks do Windows:

- **Get-TweakByName** (4 testes)
  - Busca por nome exato
  - Retorno de `$null` para tweaks inexistentes
  - Garantia de um único resultado (Select-Object -First 1)
- **Set-Tweak** (9 testes)
  - Aplicação de tweak com Registry
  - Execução de scripts (InvokeScript)
  - Gravação em `$global:ScriptContext.AppliedTweaks` quando IsBoolean=true
  - Tratamento de tweak inexistente (retorna $false e loga ERRO)
- **Restore-Tweak** (5 testes)
  - Restauração de registro original
  - Execução de UndoScript
  - Comportamento com tweaks inexistentes

**Recursos mockados**: `Get-AvailableItems`, `Set-RegistryEntry`, `Restore-RegistryEntry`, `Write-InstallLog`, `Invoke-Expression`

---

### **Integration Tests**

**Arquivo**: `Integration/Registry.Integration.Tests.ps1`  
**Tag**: `Integration`  
**Testes**: 12

**Diferença vs Unit**: Testes de integração usam HKCU registry **real** (não mockado), em sandbox `HKCU:\SOFTWARE\_PostInstall_Tests\`.

**O que valida**:
- Set-RegistryEntry cria chaves e grava valores (DWORD, STRING, QWORD, MULTISTRING)
- Restore-RegistryEntry recupera valores originais or remove entradas
- Semantica especial de DELETEKEY (remove chave inteira)
- Idempotencia (segunda execução não falha)

**Cleanup automático**: AfterAll remove `HKCU:\SOFTWARE\_PostInstall_Tests\` por completo, mesmo se testes falharem.

**Permissões requeridas**: Apenas acesso ao HKCU (user registry), sem admin necessário.

---

### **Smoke — Builder**

**Arquivo**: `Smoke/Builder.Tests.ps1`  
**Tag**: `Smoke`  
**Testes**: 13

**O que valida**:
- Executa `Builder.ps1` em processo filho isolado
- Verifica que script compilado (`_TestBuild.ps1`) é criado sem erro
- Tamanho do compilado > 100KB (sanidade)
- Sintaxe PowerShell válida (via `[System.Management.Automation.Language.Parser]::ParseFile`)
- Presença de funções obrigatórias: Write-InstallLog, Set-RegistryEntry, Get-AvailableItems, Set-Tweak, etc.
- Bloco ENTRYPOINT está presente no compilado

**Saída esperada**: Arquivo `_TestBuild.ps1` é criado, testado e removido automaticamente.

**Por que é importante**: Garante que o build é reprodutível e o artefato final não tem erros que quebrariam o script compilado em produção.

---

## Encoding de Arquivos

### Problema: UTF-8 sem BOM em PowerShell 5.1

PowerShell 5.1 sem BOM (Byte Order Mark) interpreta UTF-8 como **ANSI/Windows-1252**:
- Em-dashes (`–`, U+2014) viram caracteres inválidos → quebram parser
- Acentos em português viram caracteres inválidos → quebram strings

Exemplo:
```powershell
# Arquivo salvo como UTF-8 SEM BOM
$msg = "Resultado — Sucesso"   # em-dash quebrado
# PS 5.1 lê como "Resultado â€" Sucesso" → erro de parse
```

Solução: Salve TODOS os `.ps1` com UTF-8 BOM (Byte Order Mark `EF BB BF`).

### Como Verificar BOM

```powershell
$bytes = [System.IO.File]::ReadAllBytes("seu-arquivo.ps1")
$bytes[0..2]  # Deve mostrar: 239 187 191 (EF BB BF em decimal)
```

### Como Salvar com BOM (Manual)

VS Code: 
1. Abra Paleta de Comandos (`Ctrl+Shift+P`)
2. `Change File Encoding` → `UTF-8 with BOM`

**PowerShell**:
```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$content = [System.IO.File]::ReadAllText("seu-arquivo.ps1")
[System.IO.File]::WriteAllText("seu-arquivo.ps1", $content, $utf8Bom)
```

Em Batch (todos os `.ps1` no projeto):
```powershell
$utf8Bom = New-Object System.Text.UTF8Encoding $true
Get-ChildItem -Path . -Recurse -Filter '*.ps1' | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($_.FullName, $content, $utf8Bom)
}
```

EditorConfig (automático em editores suportados):
```ini
[*.ps1]
charset = utf-8-bom
```

---

## Convenções e Best Practices

### **Estrutura de um Teste**

```powershell
Describe 'Get-TweakByName' -Tag 'Unit' {
    BeforeAll {
        # Setup: importar mocks e fixtures ANTES de qualquer teste
        Mock Get-AvailableItems { return $script:SampleTweaks }
        Mock Write-InstallLog {}
    }

    Context 'Tweak existente' {
        It 'Encontra tweak pelo nome exato' {
            $result = Get-TweakByName -Name 'TestTweak-Registry'
            $result.Name | Should -Be 'TestTweak-Registry'
        }
    }

    Context 'Tweak inexistente' {
        It 'Retorna $null para nome inválido' {
            $result = Get-TweakByName -Name 'NonExistent'
            $result | Should -BeNull
        }
    }

    AfterAll {
        # Cleanup se necessário
    }
}
```

### **Regras de Mock em Pester v5**

**CRÍTICO**: Violar essas regras causa "Mock data are not setup for this scope" ou `Should -Invoke does not take pipeline input`.

1. Nunca chame `Import-Module Pester -Force` dentro de BeforeAll
   - Destrói estruturas internas de mock
   - Errado:
     ```powershell
     BeforeAll {
         Import-Module Pester -Force  # CauSA FALHA
         Mock Get-Item {}
     }
     ```
   - Certo: Pester já está carregado global antes do teste

2. Cada `Context` precisa seu próprio `BeforeAll` com Mocks
   - Pester v5 tem escopo isolado por bloco
   - Errado:
     ```powershell
     Describe 'X' {
         BeforeAll { Mock A {} }  # A está disponível globalmente
         Context 'A' { It 'x' { A } }
         Context 'B' { It 'x' { A } }  # A pode NÃO estar aqui
     }
     ```
   - Certo:
     ```powershell
     Context 'A' {
         BeforeAll { Mock A {} }
         It 'x' { A }
     }
     Context 'B' {
         BeforeAll { Mock A {} }  # Reproduz o mock localmente
         It 'x' { A }
     }
     ```

3. `Should -Invoke` não aceita pipeline input
   - Não chame a função inline
   - Errado:
     ```powershell
     It 'test' {
         Set-Tweak -Name 'X' | Should -Invoke Write-InstallLog
     }
     ```
   - Certo:
     ```powershell
     It 'test' {
         $null = Set-Tweak -Name 'X'  # Descarta output antes
         Should -Invoke Write-InstallLog -CommandName Write-InstallLog -Times 1 -Exactly
     }
     ```

4. Use `-CommandName` explicitamente em `Should -Invoke`
   ```powershell
   Should -Invoke -CommandName Write-InstallLog -ParameterFilter { $Status -eq 'ERRO' } -Times 1 -Exactly
   ```

---

## Troubleshooting

### Erro: "Mock data are not setup for this scope"

Causa: Provável violação de regra de mock (veja Convenções de Mock acima).

Solução:
1. Verifique se há `Import-Module Pester` dentro de `BeforeAll` → remova
2. Verifique se Mocks estão no `Context` correto com seu próprio `BeforeAll`
3. Rode `Invoke-Pester -Path seu-arquivo.Tests.ps1 -Output Detailed` para mais contexto

---

### Erro: "Should -Invoke does not take pipeline input or ActualValue"

Causa: Output da função é passado para `Should -Invoke` via pipeline.

Solução:
```powershell
# Antes
It 'test' {
    Set-Tweak -Name 'X'
    Should -Invoke Write-InstallLog
}

# Depois
It 'test' {
    $null = Set-Tweak -Name 'X'  # Descarta output
    Should -Invoke Write-InstallLog -CommandName Write-InstallLog
}
```

---

### Erro: Parse errors com em-dashes ou acentos (PS 5.1)

Causa: Arquivo salvo como UTF-8 sem BOM (veja Encoding de Arquivos).

Solução:
1. Abra arquivo em VS Code → Paleta de Comandos → "Change File Encoding" → "UTF-8 with BOM"
2. Ou use script PowerShell para re-salvar:
   ```powershell
   $utf8Bom = New-Object System.Text.UTF8Encoding $true
   $f = "seu-arquivo.ps1"
   [System.IO.File]::WriteAllText($f, [System.IO.File]::ReadAllText($f), $utf8Bom)
   ```

---

### Erro: "Pester v3 conflict" ou "Module not found"

Causa: Pester v3 instalado ou versão incompatível.

Solução:
```powershell
# Desinstale Pester v3 (se presente)
Get-Module Pester -ListAvailable
Uninstall-Module -Name Pester -AllVersions

# Instale Pester v5
Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
```

---

### Erro: Integration test falha com "Access Denied" no HKCU

Causa: Permissões insuficientes na registry.

Solução: Não é necessário admin, mas verifique:
```powershell
# Confirme que pode acessar HKCU
Test-Path HKCU:\
# Deve retornar $true
```

---

### Erro: Builder test falha com syntax error no artefato compilado

Causa: Código-fonte contém sintaxe PS7-only (ex.: `?.` null-conditional operator).

Solução: Substitua por patterns PS 5.1:
```powershell
# PS7+ only
if ($obj?.Property) { ... }

# PS5.1 compatible
if ($obj -and $obj.Property) { ... }
```

---

## Cobertura Atual

| Módulo | Função | Teste | Status |
|--------|--------|-------|--------|
| **Core.Logging** | `Write-InstallLog` | Unit (Mock) | OK |
| **Core.Registry** | `ConvertTo-RegistryType` | Unit (10 testes) | OK |
| | `Set-RegistryEntry` | Unit (11) + Integration (7) | OK |
| | `Restore-RegistryEntry` | Unit (8) + Integration (5) | OK |
| **Core.UI** | `Get-VariableNameFromFile` | Unit (7) | OK |
| | `Get-AvailableItems` | Unit (12) | OK |
| **Features.Tweaks** | `Get-TweakByName` | Unit (4) | OK |
| | `Set-Tweak` | Unit (9) | OK |
| | `Restore-Tweak` | Unit (5) | OK |
| **Build** | `Builder.ps1` | Smoke (13) | OK |
| **Load** | Smoke — todos os arquivos | Smoke (34) | OK |

**Total**: **126 testes** cobrindo ~33 funções críticas.

**Excluído**: UI/WPF (DialogInitializers) — não é testável sem headless display.

---

## Referências

- [Pester v5 Documentation](https://pester.dev/docs/quick-start)
- [PowerShell 5.1 Compatibility Issues](../../ANALYSIS.md)
- [Builder.ps1 — Processo de Compilação](../Builder.ps1)
- [Repository Compatibility Notes](/memories/repo/powershell-compat-notes.md)

---

## FAQ

P: Posso rodar testes em PowerShell 7?
R: Sim, a suite é compatível. Use `pwsh.exe` ou `pwsh` se instalado. PS 5.1 é recomendado para testar a verdadeira compatibilidade do produto.

P: Quanto tempo leva rodar todos os testes?
R: ~6–8 segundos (Smoke: ~2s + Unit: ~2s + Integration: ~1s + Builder: ~2s).

P: Posso adicionar novos testes?
R: Sim! Siga a estrutura acima e certifique-se de:
1. Usado a tag certa (`Smoke`, `Unit`, ou `Integration`)
2. Respeite as regras de Mock (Convenções de Mock)
3. Salve o arquivo em UTF-8 BOM
4. Rode `Run-Tests.ps1` para validar que passa

P: Posso rodar um teste isolado sem rodar a suite completa?
R: Sim, use Pester diretamente:
```powershell
Invoke-Pester -Path .\Tests\Unit\Core.Registry.Tests.ps1 -Container (New-PesterContainer -Path .\Tests\Unit\Core.Registry.Tests.ps1 -Data @{ SkipTag = 'Integration' })
```

P: O que fazer se um teste fica flaky (passa às vezes, falha outras)?
2. Uso de `Write-Host` ou output não-capturado vazando entre testes
3. Estado global vazio antes de cada teste (ex.: `$global:ScriptContext`)
