PostInstall – Automação de pós-instalação no Windows

Visão geral
- Projeto PowerShell com UI em XAML para instalar programas (via Winget), aplicar ajustes do sistema (tweaks) e registrar logs de forma segura.
- O código é compilado em um único script executável (PostInstall.ps1) por meio do Builder.ps1.

Requisitos
- Windows 10/11
- PowerShell 5.1+ ou 7+
- Permissão para executar scripts (se necessário, use: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser)
- Winget opcional (se ausente, o projeto instala automaticamente e gerencia reinício da sessão quando necessário)

Como executar
1) Compilar: powershell -ExecutionPolicy Bypass -File .\Builder.ps1 -Run
   - Gera PostInstall.ps1, valida sintaxe e executa em nova janela.
2) Executar diretamente: .\PostInstall.ps1
   - A UI principal será aberta e você poderá escolher programas e ajustes.

Funcionamento
- UI: janelas XAML em Windows\*.xaml (Splash, MainWindow, diálogos de instalação, permissões e logs).
- Instalação de programas: usa Winget com ProgramIDs definidos em Data\AvailablePrograms.json.
  - Se Winget não estiver disponível, Install-WingetWrapper fará a instalação. Caso exija reinício, a nova sessão importa o compilado com SkipEntryPoint = $true, evitando reabrir a UI e iniciando a instalação diretamente.
- Tweaks: definidos em Data\AvailableTweaks.json e aplicados via funções em Functions.
- Logs: registrados por Functions\Write-InstallLog.ps1 (console e arquivo), úteis para auditoria.

Estrutura do projeto (resumo)
- Builder.ps1: compila e integra funções, dados e XAML no PostInstall.ps1.
- Main.ps1: ponto de entrada quando não compilado.
- Data\*.json: listas de programas e ajustes.
- Windows\*.xaml: interface (janelas e diálogos).
- Functions\*.ps1: funções de UI, instalação, winget, tweaks, logs, etc.

Desenvolvimento
- Adicionar janelas: crie Windows\NovaJanela.xaml; o builder mapeia automaticamente em ScriptContext.XamlWindows.
- Adicionar funções: inclua em Functions\*.ps1; o builder compila tudo. Use SkipEntryPoint para evitar reexecução quando o compilado é importado em sessões elevadas.

Solução de problemas
- Política de execução: use -ExecutionPolicy Bypass ou defina RemoteSigned.
- Winget ausente: o projeto instalará; se houver reinício, a nova janela não reabrirá a UI, iniciando a instalação.
- UI reabrindo em sessão elevada: garanta SkipEntryPoint = $true antes de importar PostInstall.ps1.

Comandos úteis
- Recompilar: powershell -File .\Builder.ps1 -Run
- Executar compilado: .\PostInstall.ps1