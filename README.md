# Claude Instance Manager (CIM)

**Idiomas / Languages:**
- [Português (pt-BR)](#português-pt-br)
- [English (en-US)](#english-en-us)

---

## Português (pt-BR)

### 1. Descrição do Sistema

O **Claude Instance Manager (CIM)** é um aplicativo utilitário nativo para Microsoft Windows. O CIM gerencia múltiplas instâncias simultâneas e isoladas do aplicativo **Claude Desktop** (pacote MSIX `Claude_pzs8sxrjxfjjc`).

O aplicativo utiliza a interface gráfica Windows Presentation Foundation (WPF) sobre o motor PowerShell e o compilador nativo do .NET Framework. O CIM não requer a instalação de dependências externas, runtimes adicionais ou privilégios de administrador.

#### 1.1. Problemas Resolvidos pelo Sistema

1. **Bloqueio de Instância Única (`SingleInstanceLock`):** Por padrão, o Claude Desktop permite apenas uma instância ativa por sessão de usuário do Windows. O CIM cria diretórios de dados isolados (`--user-data-dir`) para permitir a execução simultânea de múltiplas contas (por exemplo, contas corporativas e contas pessoais).
2. **Duplicação de Espaço em Disco (~8,8 GB por instância):** O pacote do Claude Desktop armazena binários pesados e imagens de máquina virtual (`rootfs.vhdx`) no diretório de dados do usuário. O CIM cria vínculos físicos NTFS (`Hardlinks` via `Kernel32.dll!CreateHardLink`) para todos os arquivos somente-leitura e isola exclusivamente o disco de sessão (`sessiondata.vhdx`) e os arquivos de configuração. Essa arquitetura reduz o consumo adicional de disco de ~8,8 GB para menos de 100 MB por instância secundária.
3. **Conflito de Bloqueio da Máquina Virtual Hyper-V (`EBUSY`):** Quando duas instâncias compartilham o arquivo `sessiondata.vhdx`, o serviço Hyper-V bloqueia a inicialização da segunda instância. O CIM exclui o arquivo `sessiondata.vhdx` da árvore de hardlinks para garantir que cada instância opere sua própria máquina virtual sem conflito.
4. **Erro de Escrita Atômica (`EMLINK` / `nlink > 1`):** O Claude Desktop rejeita arquivos de configuração (`claude_desktop_config.json`, `config.json`, `bridge-state.json`) que possuam mais de um vínculo físico no sistema de arquivos NTFS. O CIM verifica a contagem de links físicos e desvincula automaticamente esses arquivos antes de qualquer leitura ou gravação.
5. **Redirecionamento Incorreto do Protocolo `claude://` (OAuth Login):** Durante a autenticação no navegador web, o sistema operacional envia o callback `claude://` sempre para a instância primária. O CIM intercepta o protocolo `claude://` através da chave dinâmica `ProgID` (`Shlwapi.dll!AssocQueryString`) e direciona o token de autenticação para a instância selecionada pelo usuário.
6. **Reinicialização Forçada por Atualização Automática:** O atualizador padrão encerra todas as instâncias abertas para aplicar novas versões. O CIM configura o perfil local (`Claude-3p\configLibrary`) para permitir o download da atualização em segundo plano sem reiniciar o aplicativo automaticamente, mantendo o modo de operação `1p` ativo para evitar o bloqueio da tela corporativa Gateway (`3p`).
7. **Transferência Portátil de Projetos entre Computadores (`.cimpack`):** O histórico completo de uma sessão do Claude Code é distribuído entre a pasta da instância local e o diretório global `%USERPROFILE%\.claude\projects\`. O CIM empacota todos os artefatos da sessão, subagentes, memórias (`MEMORY.md`), histórico de edições de arquivos, código-fonte opcional e transcrições legíveis em HTML/Markdown em um único arquivo `.cimpack`. Na importação em outro computador, o CIM permite remapear o caminho do diretório do repositório local e reescreve automaticamente as referências internas.
8. **Motor de Alto Desempenho Pré-Compilado (`CIMNative.v4.dll`):** O CIM compila uma biblioteca nativa em C# que lê metadados de centenas de arquivos de sessão em milissegundos (ignorando blocos extensos de schemas MCP), consulta linhas de comando de processos diretamente via memória PEB do Windows (`NtQueryInformationProcess`) sem sobrecarga de consultas WMI e valida carimbos de sincronização (`.cim-sync-stamp`) antes de percorrer árvores de hardlinks.

---

### 2. Especificações Técnicas e Arquitetura de Diretórios

| Componente | Caminho no Sistema | Função Técnica |
| :--- | :--- | :--- |
| **Instância Primária (MSIX)** | `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc` | Armazena os dados da conta primária e os ativos base para criação de hardlinks. |
| **Instâncias Secundárias** | `%LOCALAPPDATA%\Claude-Instances\<InstanceID>` | Armazena os diretórios isolados de cada instância adicional. |
| **Estado do Gerenciador** | `%LOCALAPPDATA%\Claude-Instances\cim-state.json` | Armazena metadados das instâncias, idioma selecionado (`pt-BR` ou `en-US`) e regras do roteador `claude://`. |
| **Ícones Gerados** | `%LOCALAPPDATA%\Claude-Instances\icons\` | Armazena arquivos `.ico` multi-resolução (256px, 48px, 32px, 16px) com identificadores visuais personalizados. |
| **Backups do Sistema** | `%LOCALAPPDATA%\Claude-Instances\Backups\` | Armazena arquivos compactados `.zip` contendo sessões e configurações. |
| **Transcrições Globais CLI** | `%USERPROFILE%\.claude\projects\` | Armazena o histórico JSONL global compartilhado pelo motor do Claude Code. |

#### 2.1. Regras de Isolamento de Arquivos

* **Diretórios Compartilhados via Hardlink NTFS (Somente-Leitura):**
  * `claude-code`
  * `claude-code-vm`
  * `claude-ssh-remote`
  * `terminal-shell-integration`
  * `Claude Extensions`
  * `vm_bundles\claudevm.bundle` (exceto `sessiondata.vhdx` e `sessiondata.img`)
* **Arquivos e Diretórios Isolados por Instância (Nunca Vinculados):**
  * `claude_desktop_config.json`
  * `config.json`
  * `bridge-state.json`
  * `Preferences` e `Local State`
  * `Network`, `Session Storage`, `Local Storage` e `IndexedDB`
  * `claude-code-sessions` e `local-agent-mode-sessions`
  * `side-session-notes`
  * `vm_bundles\claudevm.bundle\sessiondata.vhdx`

---

### 3. Requisitos do Sistema

* **Sistema Operacional:** Windows 10 (versão 1809 ou superior) ou Windows 11 (x64).
* **Sistema de Arquivos:** Volume formatado em NTFS (necessário para suporte a hardlinks).
* **Aplicativo Base:** Claude Desktop instalado (pacote MSIX ou instalador padrão).
* **Ambiente de Execução:** Windows PowerShell 5.1 e .NET Framework 4.x (nativos do Windows).

---

### 4. Instalação e Execução

#### Método A: Executável Autônomo (`Claude-Instance-Manager.exe`)

1. Acesse a página **Releases** deste repositório no GitHub.
2. Baixe o arquivo `Claude-Instance-Manager.exe`.
3. Execute o arquivo `Claude-Instance-Manager.exe`.
   * *Nota:* Quando executado fora da pasta do código-fonte, o binário extrai automaticamente os módulos internos para `%LOCALAPPDATA%\Claude-Instances\Manager\` e inicia a interface gráfica sem exibir janelas de terminal.

#### Método B: Execução a partir do Código-Fonte

1. Clone este repositório em um diretório local:
   ```powershell
   git clone https://github.com/azhizarat/Claude-Instance-Manager.git
   cd Claude-Instance-Manager
   ```
2. Execute o arquivo `Launch-CIM.vbs` com duplo clique, ou execute pelo PowerShell:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Claude-Instance-Manager.ps1
   ```
3. Para compilar o executável `Claude-Instance-Manager.exe` localmente, execute:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
   ```

---

### 5. Procedimentos de Operação

#### 5.1. Alternar o Idioma da Interface (`pt-BR` / `en-US`)
1. Localize o seletor de idioma no canto superior direito da janela principal.
2. Selecione **Português (BR)** ou **English (US)**.
3. A interface atualiza todos os textos imediatamente e salva a preferência em `cim-state.json`.

#### 5.2. Criar uma Nova Instância Isolada
1. Selecione a aba **Instâncias e Contas**.
2. No painel lateral direito, preencha o campo **ID da Pasta** (use apenas letras, números, hífens ou sublinhados).
3. Preencha o campo **Nome de Exibição** e o campo **Descrição / Conta**.
4. Defina a **Sigla do Badge** (1 a 3 caracteres) e selecione uma **Cor Hex do Badge**.
5. Clique em **Salvar Instância e Gerar Atalhos**.
   * *Resultado:* O CIM cria o diretório da instância, vincula os binários via hardlinks NTFS, gera o arquivo `.ico` personalizado e cria os atalhos na Área de Trabalho e no Menu Iniciar.

#### 5.3. Autenticar ou Trocar a Conta de uma Instância
1. Na aba **Instâncias e Contas**, localize o cartão da instância desejada.
2. Clique no botão **Login / Trocar Conta**.
3. Na caixa de diálogo exibida:
   * Clique em **Sim** para remover apenas os cookies de autenticação atuais (mantendo sessões, projetos e configurações MCP intactos).
   * Clique em **Não** para manter a sessão web atual e apenas abrir a instância.
4. O CIM ativa automaticamente o roteador `claude://` apontando para essa instância durante 15 minutos e inicia a janela do Claude Desktop.
5. Conclua o login no navegador web. O redirecionamento `claude://` entregará o token diretamente para a instância selecionada.
6. Caso você tenha autenticado uma conta diferente da anterior na mesma instância, clique em **Vincular Sessões à Conta** no cartão da instância para mover as sessões locais existentes para o novo par `AccountUUID` / `OrgUUID`.

#### 5.4. Copiar ou Mover Projetos e Sessões entre Contas (Mesma Máquina)
1. Selecione a aba **Projetos, Sessões e Pacotes (.cimpack)**.
2. Na coluna **1. Instância de Origem**, selecione a instância que contém os projetos desejados.
3. Na coluna **2. Instância de Destino**, selecione a instância que receberá os projetos.
4. Utilize o campo de filtro para localizar o projeto pelo nome da pasta ou pelo título da sessão (a filtragem opera em memória em tempo real).
5. Selecione uma ou mais sessões na lista da esquerda.
6. Marque a opção **Incluir sub-sessões filhas** para transferir automaticamente sessões derivadas.
7. Clique em **Copiar / Clonar ->** para manter os arquivos na origem e criar uma cópia no destino, ou clique em **Mover Selecionados ->** para transferir definitivamente.

#### 5.5. Exportar e Importar Pacotes Portáteis entre Computadores (`.cimpack`) e Visualizar Histórico HTML/Markdown
1. Para visualizar o histórico completo de uma conversa no navegador web:
   * Selecione uma sessão na lista da esquerda na aba **Projetos, Sessões e Pacotes (.cimpack)**.
   * Clique em **Ver Conversa (HTML / MD)**. O CIM converte o arquivo `.jsonl` da sessão em um documento HTML interativo e em um arquivo Markdown, abrindo o visualizador no navegador padrão.
2. Para exportar projetos ou conversas para outro computador:
   * Selecione uma ou mais sessões na lista da esquerda.
   * Marque a caixa **Incluir arquivos de código da pasta** caso deseje incluir os arquivos do repositório dentro do pacote (pastas de cache como `.git`, `node_modules`, `bin` e `obj` são filtradas automaticamente).
   * Clique em **Exportar Pacote (.cimpack)** e escolha o local para salvar o arquivo.
3. Para importar um arquivo `.cimpack` em outro computador ou instância:
   * Selecione a **Instância de Destino** na coluna da direita.
   * Clique em **Importar Pacote (.cimpack)** e selecione o arquivo `.cimpack`.
   * Para cada projeto contido no pacote, o CIM exibe o caminho original da pasta e pergunta se você deseja selecionar o diretório equivalente no computador atual.
   * Caso selecione um novo diretório local, o CIM reescreve automaticamente as propriedades `cwd` na sessão e no histórico `.jsonl`, instala os arquivos em `%USERPROFILE%\.claude\projects\<caminho-codificado>` e autoriza a nova pasta com `bypassPermissions`.

#### 5.6. Configurar o Roteador de Protocolo `claude://`
1. Selecione a aba **Roteador claude:// e Sincronização**.
2. Escolha o modo de operação:
   * **Exibir janela seletora para escolher a instância de destino (Recomendado):** Abre uma janela flutuante sempre que um link `claude://` é acionado fora do fluxo automático de login.
   * **Enviar automaticamente para a instância fixa selecionada:** Redireciona todos os links `claude://` para uma instância predeterminada.
3. Clique em **Ativar / Salvar Roteador claude://**.
4. Para remover a interceptação e restaurar o comportamento original do Windows, clique em **Restaurar Padrão do Windows**.

#### 5.6. Controlar Atualizações Automáticas e Modo Dispatch
1. Selecione a aba **Atualizações, Proteções e Backups**.
2. Selecione a opção **Baixar atualizações em segundo plano, sem reiniciar automaticamente (Recomendado)**.
3. Clique em **Aplicar Política de Atualização e Forçar Modo 1p**.
4. Para ativar ou desativar o botão **Dispatch** (`sessions-bridge`) em uma instância específica, acesse a aba **Instâncias e Contas** e clique no botão **Dispatch: ON/OFF** no cartão da instância.

---

### 6. Verificação e Testes Automatizados

Para executar a suíte de verificação automatizada do projeto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\tests\CIM.Tests.ps1
```

A suíte valida a resolução de caminhos da instalação MSIX, o desacoplamento automático de hardlinks em arquivos JSON (`Ensure-UniqueConfigFile`), a geração de ícones multi-resolução, a leitura de sessões, a consulta `AssocQueryString` do protocolo `claude://`, a política de atualização `1p` e a integridade da interface XAML (`-CheckOnly`).

---
---

## English (en-US)

### 1. System Description

**Claude Instance Manager (CIM)** is a native utility application for Microsoft Windows. CIM manages multiple simultaneous and isolated instances of the **Claude Desktop** application (MSIX package `Claude_pzs8sxrjxfjjc`).

The application uses Windows Presentation Foundation (WPF) powered by the Windows PowerShell engine and the native .NET Framework compiler. CIM requires no external dependencies, no third-party runtimes, and no administrator privileges.

#### 1.1. Technical Problems Solved by CIM

1. **Single-Instance Lock (`SingleInstanceLock`):** By default, Claude Desktop restricts execution to a single process group per Windows user session. CIM provisions isolated user data directories (`--user-data-dir`) so multiple accounts (such as corporate and personal accounts) run concurrently.
2. **Disk Space Duplication (~8.8 GB per instance):** Claude Desktop stores large binaries and virtual machine images (`rootfs.vhdx`) inside the user data directory. CIM creates NTFS hardlinks (`Kernel32.dll!CreateHardLink`) for all read-only assets while isolating the session disk (`sessiondata.vhdx`) and configuration files. This architecture reduces the disk footprint of each additional instance from ~8.8 GB to less than 100 MB.
3. **Hyper-V Virtual Machine Lock Conflict (`EBUSY`):** Sharing `sessiondata.vhdx` across instances causes Hyper-V file locking errors when two instances start simultaneously. CIM excludes `sessiondata.vhdx` from hardlinking so each instance initializes its own independent virtual machine disk.
4. **Atomic Write Failure (`EMLINK` / `nlink > 1`):** Claude Desktop refuses to write to configuration files (`claude_desktop_config.json`, `config.json`, `bridge-state.json`) when their NTFS link count exceeds 1. CIM inspects the link count and detaches hardlinked configuration files into standalone files prior to modification.
5. **Misrouted `claude://` Deep Links (OAuth Login):** Browser OAuth callbacks (`claude://`) are routed by Windows to the primary MSIX instance by default. CIM intercepts the `claude://` protocol via the dynamic AppX `ProgID` (`Shlwapi.dll!AssocQueryString`) and dispatches the callback URI directly to the target instance.
6. **Forced Auto-Update Restarts:** The default updater terminates all running instances to apply updates. CIM configures the local managed profile (`Claude-3p\configLibrary`) to allow background update downloads without automatic restarts, while enforcing `deploymentMode: "1p"` to prevent accidental corporate Gateway (`3p`) lockouts.
7. **Cross-Machine Portable Project Transfer (`.cimpack`):** Claude Code distributes session state across the instance directory and `%USERPROFILE%\.claude\projects\`. CIM bundles session metadata, CLI JSONL transcripts, subagent logs, project memories (`MEMORY.md`), file-history snapshots, readable HTML/Markdown transcripts, and optional workspace source files into a single `.cimpack` archive. Upon import on another machine, CIM prompts for local folder remapping and rewrites internal path references automatically.
8. **Precompiled High-Performance Native Engine (`CIMNative.v4.dll`):** CIM compiles a native C# acceleration assembly that scans hundreds of session metadata files in milliseconds (skipping embedded MCP schema payloads), reads process command lines directly from Windows PEB memory (`NtQueryInformationProcess`) without WMI overhead, and checks synchronization stamps (`.cim-sync-stamp`) before walking NTFS hardlink trees.

---

### 2. Technical Specifications and Directory Architecture

| Component | System Path | Technical Function |
| :--- | :--- | :--- |
| **Primary Instance (MSIX)** | `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc` | Stores primary account data and serves as the source for read-only NTFS hardlinks. |
| **Secondary Instances** | `%LOCALAPPDATA%\Claude-Instances\<InstanceID>` | Stores isolated user data directories for each secondary instance. |
| **Manager State File** | `%LOCALAPPDATA%\Claude-Instances\cim-state.json` | Stores instance metadata, UI language (`pt-BR` or `en-US`), and `claude://` routing state. |
| **Generated Icons** | `%LOCALAPPDATA%\Claude-Instances\icons\` | Stores multi-resolution `.ico` files (256px, 48px, 32px, 16px) with custom badges. |
| **System Backups** | `%LOCALAPPDATA%\Claude-Instances\Backups\` | Stores `.zip` archives of sessions, side notes, and instance configurations. |
| **Global CLI Transcripts** | `%USERPROFILE%\.claude\projects\` | Stores global JSONL conversation transcripts shared by the Claude Code engine. |

---

### 3. System Requirements

* **Operating System:** Windows 10 (version 1809 or later) or Windows 11 (x64).
* **File System:** NTFS-formatted volume (required for NTFS hardlinks).
* **Base Application:** Claude Desktop installed on the system.
* **Runtime Environment:** Windows PowerShell 5.1 and .NET Framework 4.x (pre-installed on Windows).

---

### 4. Installation and Execution

#### Method A: Standalone Executable (`Claude-Instance-Manager.exe`)

1. Open the **Releases** page of this GitHub repository.
2. Download `Claude-Instance-Manager.exe`.
3. Run `Claude-Instance-Manager.exe`.
   * *Note:* When executed outside the repository directory, the executable automatically extracts its embedded modules to `%LOCALAPPDATA%\Claude-Instances\Manager\` and launches the WPF interface without a console window.

#### Method B: Run from Source

1. Clone this repository to a local directory:
   ```powershell
   git clone https://github.com/azhizarat/Claude-Instance-Manager.git
   cd Claude-Instance-Manager
   ```
2. Double-click `Launch-CIM.vbs`, or run the script from PowerShell:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Claude-Instance-Manager.ps1
   ```
3. To compile `Claude-Instance-Manager.exe` locally, run:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
   ```

---

### 5. Operating Procedures

#### 5.1. Switch User Interface Language (`pt-BR` / `en-US`)
1. Locate the language selector drop-down list in the top-right corner of the main window.
2. Select **Português (BR)** or **English (US)**.
3. The application updates all labels immediately and saves the preference to `cim-state.json`.

#### 5.2. Create a New Isolated Instance
1. Select the **Instances and Accounts** tab.
2. In the right-hand panel, enter a **Folder ID** (use alphanumeric characters, hyphens, or underscores).
3. Enter a **Display Name** and an **Account / Description** label.
4. Enter the **Badge Text** (1 to 3 characters) and select a **Badge Hex Color**.
5. Click **Save Instance and Generate Shortcuts**.
   * *Result:* CIM creates the instance directory, links read-only binaries via NTFS hardlinks, generates the custom `.ico` file, and creates Desktop and Start Menu shortcuts.

#### 5.3. Authenticate or Switch Account in an Instance
1. In the **Instances and Accounts** tab, locate the target instance card.
2. Click **Login / Switch Account**.
3. In the confirmation dialog:
   * Click **Yes** to clear existing authentication cookies while preserving all sessions, projects, and MCP configurations.
   * Click **No** to keep existing cookies and open the instance window.
4. CIM arms the `claude://` protocol router for that instance for 15 minutes and starts the instance.
5. Complete the OAuth login in your web browser. The `claude://` callback routes directly to the target instance.
6. If you authenticated a new account on an existing instance, click **Bind Sessions to Account** on the instance card to migrate local sessions to the new `AccountUUID` / `OrgUUID` pair.

#### 5.4. Copy or Move Projects and Sessions Across Accounts (Same Machine)
1. Select the **Projects, Sessions, and Packages (.cimpack)** tab.
2. Select the **Source Instance** in the left column and the **Target Instance** in the right column.
3. Select one or more sessions from the source list.
4. Enable **Include child sub-sessions** to include linked sub-sessions automatically.
5. Click **Copy / Clone ->** to duplicate the sessions into the target instance, or click **Move Selected ->** to move them.

#### 5.5. Export and Import Cross-Machine Portable Packages (`.cimpack`) and View HTML/Markdown Transcripts
1. To view a complete conversation transcript in a web browser:
   * Select a session in the left list on the **Projects, Sessions, and Packages (.cimpack)** tab.
   * Click **View Transcript (HTML / MD)**. CIM converts the session `.jsonl` transcript into a standalone Dark Mode HTML page and a Markdown file, and opens the HTML file in the default browser.
2. To export projects or conversations for another computer:
   * Select one or more sessions in the source list.
   * Enable **Include project workspace/code files** if you want to bundle the repository files inside the package (cache folders such as `.git`, `node_modules`, `bin`, and `obj` are excluded automatically).
   * Click **Export Package (.cimpack)** and select the destination file path.
3. To import a `.cimpack` file on another computer or instance:
   * Select the **Target Instance** in the right column.
   * Click **Import Package (.cimpack)** and select the `.cimpack` file.
   * For each project in the package, CIM displays the original directory path and asks whether you want to map it to a different local directory on the current computer.
   * CIM rewrites all internal `cwd` path references, installs the transcripts and memories under `%USERPROFILE%\.claude\projects\<encoded-path>`, and grants `bypassPermissions` on the mapped folder.

#### 5.6. Configure the `claude://` Protocol Router
1. Select the **claude:// Router and Config Sync** tab.
2. Select the routing mode:
   * **Display instance selector popup when claude:// is clicked (Recommended):** Opens a topmost selector window whenever a `claude://` link is invoked.
   * **Always route directly to the pinned instance:** Sends all `claude://` links to the specified instance.
3. Click **Enable / Save claude:// Router**.
4. To restore the default Windows protocol handler, click **Restore Windows Default**.

#### 5.6. Configure Auto-Update Policy and Dispatch Mode
1. Select the **Updates, Protections, and Backups** tab.
2. Select **Download updates in background, do NOT auto-restart (Recommended)**.
3. Click **Apply Update Policy and Enforce 1p Mode**.
4. To enable or disable the **Dispatch** button (`sessions-bridge`) for a specific instance, open the **Instances and Accounts** tab and click **Dispatch: ON/OFF** on the instance card.

---

### 6. Automated Verification

Run the automated test suite from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\tests\CIM.Tests.ps1
```
