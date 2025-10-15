<div align="center">

# PostInstall - Script de pós-instalação do Windows
Script utilitário para auxiliar no processo de pós-instalação e configuração de um ambiente Windows.

[![Version](https://img.shields.io/github/v/release/viceciado/PostInstall?style=for-the-badge&color=%23993233&label=Versão%20mais%20recente)](https://github.com/viceciado/PostInstall/releases/latest)

<img width="700" height="600" alt="home" src="https://github.com/user-attachments/assets/b3db8042-9ab1-471d-969e-d686d4abf5f0" />

</div>

## Visão geral

- Pensado primariamente para ser usado em conjunto com um arquivo de reposta *unattend.xml*.
- Pode ser executado de forma autônoma através do arquivo [**PostInstall.ps1**](https://github.com/viceciado/PostInstall/releases/latest) ou executando [**PI-Downloader.ps1**](https://github.com/viceciado/PostInstall/blob/main/PI-Downloader.ps1).

<div align="center">

### Cenários possíveis
</div>

|Instalação automatizada (unattend.xml)|Execução manual|
|-|-|
|<p>Copie para dentro do seu arquivo de resposta o conteúdo do arquivo [PI-Downloader.ps1](https://github.com/viceciado/PostInstall/blob/main/PI-Downloader.ps1) e configure a execução para acontecer após o primeiro login de um usuário no sistema. <p>Dessa forma, o PI-Downloader baixará a última versão disponível do repositório e executará o script com privilégios de administrador. |Você pode baixar e executar o [PI-Downloader.ps1](https://github.com/viceciado/PostInstall/blob/main/PI-Downloader.ps1) ou baixar o arquivo [PostInstall.ps1](https://github.com/viceciado/PostInstall/releases/latest) disponível na aba de Releases e executá-lo diretamente.|
|<p>Nesse cenário, nenhuma modificação extra é necessária, pois o arquivo de resposta já instrui o sistema a executar o script diretamente, sem a necessidade de alterar a política de execução de scripts, e com privilégios de administrador. <p>A execução é orquestrada pelo sistema. O script será inicializado automaticamente após o login. <p>Como o script foi executado pelo próprio sistema, a política de execução de scripts se mantém inalterada, evitando brechas de segurança.| Muito provavelmente será necessário alterar temporariamente a política de execução de scripts PowerShell para que o sistema permita a execução. <p> <br>Para isso, abra uma janela do PowerShell como administrador e execute `Set-ExecutionPolicy Bypass -Scope Process`, em seguida, execute o script baixado usando `./PostInstall.ps1`.

> [!NOTE]
> 
> - Evite alterar a política de execução de scripts desnecessariamente, pois isso pode representar uma potencial brecha de segurança no sistema. O parâmetro `-Scope Process` restringe a alteração da política à seção atual do PowerShell, preservando o comportamento padrão no restante do sistema.
> 
> - Apesar de possível, executar o script sem privilégios de administrador pode resultar em falhas em várias operações. Prefira sempre executar com os privilégios de administrador.

<div align="center">

### PostInstall ou PI-Downloader?
</div>

A resposta mais simples é: **tanto faz.**

|PostInstall.ps1|PI-Downloader.ps1|
|-|-|
|É o arquivo principal do projeto. Ele contém tudo o que o script precisa para funcionar, desde as janelas XAML até as funções auxiliares e as instruções contidas nos arquivos JSON. É esse arquivo que faz toda a mágica acontecer.|<p>Script auxiliar que facilita o download e a execução do **PostInstall** na máquina. <p>Se executado com permissões de administrador, baixa o arquivo `PostInstall.ps1` na pasta C:\Windows\Setup\Scripts e o executa com os parâmetros `-ExecutionPolicy Bypass -Scope Process` <p>Ao ser executado como usuário limitado, salva o arquivo `PostInstall.ps1` na pasta temporária.|



## Funções e recursos
O script consiste de funções acessíveis por meio de uma interface gráfica.

1. **Instalação de programas**
2. **Instalação do Office**
3. **Botão de alternar entre tema claro e tema escuro**
4. **Ajustes gerais**
5. **Limpar permissões**
6. **Ativação**
7. **Importar backup de drivers**

Além de dispor de janelas e botões auxiliares, tais como:
- Abrir o Windows Update
- Abrir o Gerenciador de Dispositivos
- Alternar o comportamento de hibernação do sistema temporariamente
- Visualizar o log da instalação
- Visualizar informações do sistema

<div align="center">

## Janelas principais

### Instalação de programas

<img width="500" height="652" alt="appinstall" src="https://github.com/user-attachments/assets/4adbffb3-5cde-4e66-9ed0-6b1f6045dd9e" />

</div>

- Utiliza o _winget_ para realizar a instalação dos programas marcados, além de permitir a seleção de outros programas além dos pré-especificados, por meio dos IDs correspondentes.

- Permite atualizar todos os programas do sistema por meio do _winget_.

> [!NOTE]
> 
> O script está configurado para buscar por uma instalação válida do _winget_ antes de prosseguir, e caso não o encontre, ele é capaz de baixar a última versão disponível por meio dos repositórios oficiais, muito embora, isso não seja necessário a partir do Windows 11 24h2, que já dispõe do _winget_ a partir da instalação.
> 
> A lista dos programas pré-determinados pode ser encontrada no arquivo [**`AvaiablePrograms.json`**](https://github.com/viceciado/PostInstall/blob/main/Data/AvailablePrograms.json)

---

<div align="center">

### Ajustes gerais

<img width="750" height="623" alt="tweaks" src="https://github.com/user-attachments/assets/709a7e9c-9f33-4fd2-b879-4807dd0e13fa" />

</div>

- Fornece ao usuário uma lista com diversos ajustes *(tweaks)* considerados úteis para serem aplicados em um ambiente de pós-instalação do Windows.
- Os ajustes podem ser listados por categoria.
- Na aba lateral, dispõe de ações rápidas relacionadas aos *tweaks*, além de dar acesso a outras funções como ajustar configurações de aparência e desempenho, exibir as atualizações instaladas via Windows Update e registrar o WinRAR[^rar].

[^rar]: O script não contém nenhuma chave de registro do WinRAR. Essa função permite ao usuário selecionar dentre os seus arquivos uma chave válida de registro do WinRAR `(rarreg.key)` e copia essa chave para a localização do WinRAR (caso ele esteja instalado no sistema).

> [!NOTE]
> 
> A disponibilidade de certos *tweaks* dependerá da versão do Windows rodando na máquina. Caso o script detecte que se trata do Windows 10, *tweaks* incompatíveis não serão exibidos.
> 
> É possível que alguns dos *tweaks* listados executem tarefas e rotinas que não possam ser desfeitas. Consulte o arquivo [**`AvaiableTweaks.json`**](https://github.com/viceciado/PostInstall/blob/main/Data/AvailableTweaks.json) para saber o que cada *tweak* faz.

---

<div align="center">

### Limpeza de permissões

<img width="499" height="471" alt="permission" src="https://github.com/user-attachments/assets/5243ee66-cac2-489a-9047-5dc6714edd51" />

Janela principal e notificação de limpeza
</div>

Permite ao usuário realizar a limpeza de permissões de pastas do sistema, considerando cenários de instalação do sistema em novos discos ou em discos com múltiplas partições NTFS, contendo arquivos registrados com [SIDs](https://learn.microsoft.com/pt-br/windows-server/identity/ad-ds/manage/understand-security-identifiers) diferentes.

O script permite escolher em quais pastas o usuário deseja realizar a limpeza de permissões usando o utilitário **`icacls`** com parâmetros de limpeza.

```
icacls "`$path" /reset /T /C /Q
```

Por se tratar de uma tarefa potencialmente demorada, o usuário pode executar a limpeza de permissões durante a execução do script ou criar uma tarefa agendada que executa a limpeza na próxima inicialização do sistema, em segundo plano e com privilégios de **`SYSTEM`**.

<div align="center">

<img width="482" height="222" alt="permission-now-later" src="https://github.com/user-attachments/assets/9df64ec8-a1d0-4283-ad73-c05c1f491f60" />

Janela que permite escolher o modo de operação.
</div>

|Execução imediata|Execução agendada|
|-----------------|-----------------|
|O script exibe a seleção de pastas escolhidas para a limpeza de permissões, e ao lado de cada uma delas, exibe o botão que chama o **`icacls`**.|A seleção de pastas é armazenada e um novo script **`.ps1`** é criado na pasta **AppData**. Em seguida, o script cria uma nova tarefa agendada para executar o novo script no próximo boot, antes mesmo do login, o que garante a execução com privilégios máximos.|
|<p>Ao clicar no botão **Limpar**, uma nova instância do powershell é iniciada, executando a operação e fechando ao concluir a limpeza. <p>Devido o uso do parâmetro **`/q`**, o **`icacls`** só exibirá mensagens de erro, suprimindo operações bem-sucedidas. Isso pode induzir o usuário a achar que a execução parou, mas basta aguardar o término da operação e a janela será fechada automaticamente.|Como a execução acontece em segundo plano, invisível ao usuário, o script funciona de forma autônoma, usando um `foreach` que itera sobre a seleção de pastas, uma de cada vez.|
|Atualmente, a implementação do script possui algumas limitações. A limpeza de permissões nas pastas selecionadas deve ser realizada manualmente, uma por vez, o que pode demorar. Apesar de possível, não é recomendado executar a limpeza de permissões em mais de uma pasta ao mesmo tempo, pois isso pode gerar um overhead de **`I/O`** nos discos. |Após o `foreach`, o próprio script de limpeza gerado apaga a tarefa agendada e a si mesmo.|

> [!NOTE]
> 
> Para evitar redundância na seleção de pastas, a cada nova pasta selecionada, uma função interna analisa a nova localização e a compara com as demais pastas escolhidas previamente. Caso o script detecte que possa haver repetição de uma mesma pasta durante a execução do **`icacls`**, ele remove da seleção a pasta-filho, mantendo somente a pasta-pai, evitando repetições na rotina de limpeza.

---

<div align="center">

### Ativação

<img width="400" height="382" alt="activation" src="https://github.com/user-attachments/assets/bb14a0c2-a654-42dc-8163-c5d9a2cf92e2" />

</div>

Dividida em duas seções principais.
#### Ativação OEM:
- Utiliza **`Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey`** para localizar uma Product Key OEM registrada no firmware da máquina.
- Se uma chave for localizada, ela é exibida no campo de texto, e o botão **Ativar** se torna disponível.
- Ao clicar no botão **Ativar**, o script tenta realizar a ativação do sistema de forma nativa internamente. Caso a ativação seja bem-sucedida, uma mensagem de sucesso é exibida.
- Se por algum motivo, a ativação usando a chave encontrada não funcionar, o usuário ainda pode copiar a chave OEM para realizar a ativação manualmente por meio da página de configurações do sistema.

#### Ativação complementar:
- O botão **Abrir ativador MAS** baixa e executa a última versão disponível do [**MAS**](https://github.com/massgravel/Microsoft-Activation-Scripts) diretamente do repositório oficial.

---

<div align="center">

### Finalização

<img width="500" height="577" alt="finalize" src="https://github.com/user-attachments/assets/0a5f6836-b9f1-4d49-8e41-c0f7449d494c" />

</div>

Essa é a janela reponsável por encerrar o fluxo do script. Ela permite ao usuário registrar informações referentes ao serviço em execução. Essas informações são registradas tanto em chaves de registro no sistema[^regowner] quanto no log de instalação[^log].

Nessa tela, o usuário também pode selecionar quais parâmetros de finalização ele deseja que o script execute antes de ser encerrado, seguindo a implementação semelhante à encontrada na tela de **Ajustes gerais**.

[^regowner]: As informações Número da OS e Cliente, quando fornecidas, são salvas na chave **`RegisteredOwner`**, localizada em `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion`
[^log]: O log de instalação registra todas as operações realizadas pelo script e pode ser encontrado em duas localizações, a depender do nível de privilégios 

<div align="center">

Ao clicar no botão **Finalizar:**

<img width="450" height="258" alt="finish-msg" src="https://github.com/user-attachments/assets/f45e2d72-1336-4248-8051-84399aa193f0" />

</div>

> [!NOTE]
> 
> Os parâmetros de finalização selecionados não podem ser desfeitos diretamente pelo script.
> 
> Atendendendo a necessidades específicas, o script **SEMPRE** registrará informações predeterminadas na chave **`RegisteredOrganization`**. Essas informações podem ser visualizadas facilmente por meio do **`winver`**.

> [!IMPORTANT]  
> Uma vez que o script **PostInstall** é executado com privilégios de administrador, ele cria uma tarefa agendada para ser executado novamente após uma reinicialização. Isso é pensado para evitar situações em que a configuração ainda não foi concluída, mas o sistema foi reinicializado de forma inesperada, o que poderia tornar a execução das tarefas do script incompletas.
> 
> Para garantir a conclusão do fluxo do script de forma definitiva, é importante encerrar por meio do botão **Finalizar**, que apaga a tarefa agendada e evita que o script seja executado novamente no próximo boot. Outra opção é apagar a tarefa manualmente por meio do **Agendador de Tarefas** do próprio sistema.

---

<div align="center">

### Logs de instalação

<img width="900" height="700" alt="logviewer" src="https://github.com/user-attachments/assets/2e928a78-6f0d-4452-8e0c-b9566bf3eaf1" />

</div>

Exibe o conteúdo dos logs de instalação gerados pelo script para fácil visualização. Dependendo das permissões de execução do script, o log pode ser criado em duas localizações:

Com permissões de administrador (caminho padrão):
```
$env:windir\Setup\Scripts\Install.log
```

Sem permissões de administrador (fallback):
```
$env:APPDATA\Install.log
```

Por padrão, a janela sempre vai tentar exibir o conteúdo do log principal, mas caso encontre um arquivo de log em `AppData`, ele também será exibido logo abaixo.

> [!NOTE]
> 
> Devido a limitações na implementação, o conteúdo dos logs exibido na janela não é atualizado em tempo real.

---

<div align="center">

### Outros componentes

<img width="213" height="161" alt="toggletheme" src="https://github.com/user-attachments/assets/825a6247-0d2b-461d-a05a-9bdc908613c8" />

Botão que alterna entre o tema claro e escuro do sistema.
</div>

> [!NOTE]
> 
> Se executado no Windows 10, ou caso o script não localize os arquivos de papel de parede padrão do sistema, somente o tema é alterado.
<div align="center">

<img width="378" height="151" alt="hiberoff" src="https://github.com/user-attachments/assets/f657b797-80dd-42f8-a941-4243b631e9e3" />

Notificações nativas usando a API do Windows.

<img width="500" height="586" alt="systeminfo" src="https://github.com/user-attachments/assets/28c714e9-5f79-4726-8c8b-b26fa594a838" />

Tela de exibição de informações do sistema. 

</div>

Se o script conseguir localizar um número serial registrado no firmware, ele é exibido nessa tela, o que pode facilitar ao usuário localizar informações adicionais do hardware por meio do site do fabricante, tais como drivers específicos, documentação etc.

<div align="center">

</div>

---
## Informações importantes

- O script foi pensado para ser usado em um ambiente específico de assistência técnica, voltado tanto para simplificar quanto para padronizar o processo de instalação e configuração de um sistema, considerando o contexto de uso de um usuário comum. O script visa atender necessidades específicas desse contexto, que podem ser divergentes das necessidades de outros usuários em outros contextos.

- Algumas funções do script dependem de arquivos externos. É o caso do botão **Instalar o Office**, que atualmente facilita o processo de montagem de uma imagem de instalação do Office e exibe a janela contendo os arquivos de instalação e nada mais. Uma implementação mais robusta e automatizada foi considerada, mas não se mostrou essencial no contexto de uso primário.

<div align="center">
   
<img width="166" height="138" alt="suspend" src="https://github.com/user-attachments/assets/93d6f8ee-9959-4051-bba3-a6e890ea9c18" />

</div>

- Por padrão, o script usa chamadas internas ao kernel do Windows para inibir a hibernação do sistema. Esse comportamento visa garantir a execução das tarefas e evitar que o computador entre em suspenção ou hibernação. O comportamento padrão é restaurado sempre que o script é encerrado, seja pela tela de **Finalização**, seja fechando a janela principal diretamente ou encerrando o processo do PowerShell. A função de inibição também pode ser controlada a qualquer momento diretamente pela interface do script, clicando no ícone de lâmpada bem ao topo da janela principal.


### Requisitos e dependências

- Windows 10 e 11
- PowerShell 5.1+

### Como executar

1. O script pode ser executado em modo não compilado _(pre-build)_ a partir do arquivo **`Main.ps1`**.

```
.\Main.ps1
```
2. Para compilar uma nova versão, execute o arquivo **`Builder.ps1`**

```
.\Builder.ps1
```

3. A versão compilada pode ser executada a partir do arquivo **`PostInstall.ps1`**

```
.\PostInstall.ps1
```

4. Caso queira baixar a última release disponível no repositório do GitHub, execute o arquivo **`PI-Downloader.ps1`**

```
.\PI-Downloader.ps1
```

## Agradecimentos

Os seguintes projetos serviram de base para a idealização do **PostInstall**:

- [Chris' winutil](https://github.com/ChrisTitusTech/winutil)
- [massgravel's Microsoft Activation Scripts](https://github.com/massgravel/Microsoft-Activation-Scripts)
- [ThioJoe's Windows-Sandbox-Tools](https://github.com/ThioJoe/Windows-Sandbox-Tools)
-  [Schneegans' unattend generator](https://schneegans.de/windows/unattend-generator/)
