param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$SrcDir = Join-Path $PSScriptRoot "src"
. (Join-Path $SrcDir "Core-Instances.ps1")
. (Join-Path $SrcDir "Core-Sessions.ps1")
. (Join-Path $SrcDir "Core-ProtocolRouter.ps1")
. (Join-Path $SrcDir "Core-SettingsBackup.ps1")

$script:I18N = @{
    "pt-BR" = @{
        Subtitle              = "Gerenciador Multi-Instância, Migração de Projetos, Roteador claude:// e Controle de Atualizações"
        BtnRefreshAll         = "Atualizar Tudo"
        TabInstances          = "Instâncias e Contas"
        TabSessions           = "Projetos e Sessões (Mover / Copiar)"
        TabProtocol           = "Roteador claude:// e Sincronização"
        TabSettings           = "Atualizações, Proteções e Backups"
        LblInstalledInstances = "Instâncias Instaladas"
        BtnSyncAllLinks       = "Reparar Hardlinks de Todas"
        FormTitleNew          = "Criar Nova Instância"
        FormTitleEdit         = "Editar Instância"
        LblInstId             = "ID da Pasta (ex: Empresa2, Pessoal):"
        LblInstDisplayName    = "Nome de Exibição (Atalho e Card):"
        LblInstLabel          = "Descrição / Conta:"
        LblInstBadgeText      = "Sigla do Badge (1-3 letras):"
        LblInstBadgeColor     = "Cor Hex do Badge:"
        LblQuickColors        = "Cores Rápidas:"
        ColorBlue             = "Azul #2563EB"
        ColorPurple           = "Roxo #7C3AED"
        ColorGreen            = "Verde #10B981"
        ColorAmber            = "Âmbar #F59E0B"
        ColorRose             = "Rosa #E11D48"
        BtnSaveInstance       = "Salvar Instância e Gerar Atalhos"
        BtnClearForm          = "Limpar Formulário (Nova Instância)"
        TxtLoginTip           = "Nota: O botão 'Login / Trocar Conta' direciona o roteador claude:// para a instância selecionada durante 15 minutos. Quando o navegador concluir a autenticação OAuth, o token será entregue diretamente à instância correta."
        PrimaryTag            = " (Primária MSIX)"
        IsolatedTag           = " (Instância Isolada)"
        StatusRunning         = "EM EXECUÇÃO"
        StatusStopped         = "PARADA"
        BtnOpen               = "Abrir"
        BtnStop               = "Fechar"
        BtnLogin              = "Login / Trocar Conta"
        BtnRemap              = "Vincular Sessões à Conta"
        BtnEdit               = "Editar / Atalhos"
        BtnFolder             = "Abrir Pasta"
        LblSrcInstance        = "1. Instância de Origem"
        LblFilter             = "Filtrar por Projeto ou Título:"
        BtnSelectAll          = "Selecionar Visíveis"
        BtnClearSel           = "Limpar Seleção"
        LblTransferHeader     = "Operação de Transferência"
        ChkIncludeSub         = "Incluir sub-sessões filhas"
        ChkAutoBackup         = "Criar backup antes de mover"
        BtnCopySessions       = "Copiar / Clonar ->"
        BtnMoveSessions       = "Mover Selecionados ->"
        TxtTransferNote       = "Autoriza automaticamente a pasta do repositório (bypassPermissions) e ativa o agrupamento por pasta no destino."
        LblDstInstance        = "2. Instância de Destino"
        LblDstSummary         = "Sessões na instância de destino"
        LblProtoTitle         = "Interceptador e Roteador do Protocolo claude://"
        LblProtoDesc          = "Quando o navegador executa a autenticação OAuth ou ativa um conector, o sistema operacional aciona uma URI claude://. Com o interceptador ativo, o CIM direciona o link para a instância desejada."
        LblProtoBehavior      = "Comportamento ao receber um link claude://:"
        RbProtoAsk            = "Exibir janela seletora para escolher a instância de destino (Recomendado)"
        RbProtoFixed          = "Enviar automaticamente para a instância fixa selecionada abaixo:"
        BtnEnableProto        = "Ativar / Salvar Roteador claude://"
        BtnDisableProto       = "Restaurar Padrão do Windows"
        LblManualUrlTitle     = "Disparar URI claude:// Manualmente"
        BtnPaste              = "Colar"
        LblSendTo             = "Enviar para:"
        BtnSendUrl            = "Enviar URI"
        LblSyncTitle          = "Sincronizador de MCPs, Permissões e Preferências"
        LblSyncDesc           = "Copia servidores MCP (mcpServers), permissões de diretórios e preferências entre instâncias sem alterar as credenciais de login."
        LblSyncSrc            = "Instância de Origem:"
        LblSyncDst            = "Instância de Destino:"
        ChkSyncMcp            = "Servidores MCP (mcpServers)"
        ChkSyncPerms          = "Permissões de Diretórios (bypassPermissions)"
        ChkSyncPrefs          = "Preferências Gerais (tema, atalhos, exibição)"
        BtnRunSync            = "Clonar Configurações Selecionadas"
        LblUpdateTitle        = "Controle de Atualização Automática e Proteção Gateway (1p)"
        LblUpdateDesc         = "Impede que o Claude Desktop encerre as instâncias automaticamente durante a execução de tarefas e mantém o modo 1p ativo."
        RbUpdateManual        = "Baixar atualizações em segundo plano, sem reiniciar automaticamente (Recomendado)"
        RbUpdateDisabled      = "Desativar atualizações automáticas completamente"
        RbUpdateDefault       = "Padrão do aplicativo (Baixar e reiniciar automaticamente)"
        BtnApplyUpdate        = "Aplicar Política de Atualização e Forçar Modo 1p"
        LblBackupTitle        = "Backup e Restauração de Sessões e Configurações"
        LblBackupDesc         = "Gera um arquivo .zip contendo todas as sessões (Code e Cowork), notas laterais, configurações MCP e estado das instâncias."
        BtnCreateBackup       = "Criar Backup Agora"
        LblAvailableBackups   = "Backups Disponíveis:"
        BtnRestoreBackup      = "Restaurar Selecionado"
        BtnOpenBackupDir      = "Abrir Pasta"
        ProtoActiveHeader     = "claude:// Roteador Ativo"
        ProtoDefaultHeader    = "claude:// Padrão"
        ProtoStatusActive     = "ATIVO — Links claude:// interceptados pelo CIM"
        ProtoStatusDefault    = "PADRÃO DO WINDOWS — Links claude:// enviados à instância primária"
        ProtoArmedPrefix      = "Alvo temporário de login armado para: "
        ProtoArmedNone        = "Alvo temporário de login: Nenhum"
        UpdateModeManual      = "Controle Manual de Reinício (Baixa atualização sem fechar instâncias)"
        UpdateModeDisabled    = "Atualizações Automáticas Desativadas"
        UpdateModeDefault     = "Padrão do Claude (Reinício Automático)"
        MsgReady              = "Pronto."
    }
    "en-US" = @{
        Subtitle              = "Multi-Instance Manager, Project Migration, claude:// Protocol Router, and Update Controller"
        BtnRefreshAll         = "Refresh All"
        TabInstances          = "Instances and Accounts"
        TabSessions           = "Projects and Sessions (Move / Copy)"
        TabProtocol           = "claude:// Router and Config Sync"
        TabSettings           = "Updates, Protections, and Backups"
        LblInstalledInstances = "Installed Instances"
        BtnSyncAllLinks       = "Repair All Hardlinks"
        FormTitleNew          = "Create New Instance"
        FormTitleEdit         = "Edit Instance"
        LblInstId             = "Folder ID (e.g., Work2, Personal):"
        LblInstDisplayName    = "Display Name (Shortcut and Card):"
        LblInstLabel          = "Account / Description:"
        LblInstBadgeText      = "Badge Text (1-3 chars):"
        LblInstBadgeColor     = "Badge Hex Color:"
        LblQuickColors        = "Quick Colors:"
        ColorBlue             = "Blue #2563EB"
        ColorPurple           = "Purple #7C3AED"
        ColorGreen            = "Green #10B981"
        ColorAmber            = "Amber #F59E0B"
        ColorRose             = "Rose #E11D48"
        BtnSaveInstance       = "Save Instance and Generate Shortcuts"
        BtnClearForm          = "Clear Form (New Instance)"
        TxtLoginTip           = "Note: Clicking 'Login / Switch Account' arms the claude:// router for the selected instance for 15 minutes. When the browser finishes OAuth authentication, the callback is routed directly to that instance."
        PrimaryTag            = " (Primary MSIX)"
        IsolatedTag           = " (Isolated Instance)"
        StatusRunning         = "RUNNING"
        StatusStopped         = "STOPPED"
        BtnOpen               = "Start"
        BtnStop               = "Stop"
        BtnLogin              = "Login / Switch Account"
        BtnRemap              = "Bind Sessions to Account"
        BtnEdit               = "Edit / Shortcuts"
        BtnFolder             = "Open Folder"
        LblSrcInstance        = "1. Source Instance"
        LblFilter             = "Filter by Project or Title:"
        BtnSelectAll          = "Select Visible"
        BtnClearSel           = "Clear Selection"
        LblTransferHeader     = "Transfer Operation"
        ChkIncludeSub         = "Include child sub-sessions"
        ChkAutoBackup         = "Create backup before moving"
        BtnCopySessions       = "Copy / Clone ->"
        BtnMoveSessions       = "Move Selected ->"
        TxtTransferNote       = "Automatically grants repository folder permission (bypassPermissions) and enables folder grouping in the target instance."
        LblDstInstance        = "2. Target Instance"
        LblDstSummary         = "Sessions in target instance"
        LblProtoTitle         = "claude:// Protocol Interceptor and Router"
        LblProtoDesc          = "When the browser completes OAuth login or connector authentication, Windows invokes a claude:// URI. When active, CIM routes the URI to the selected instance."
        LblProtoBehavior      = "Action when a claude:// URI is triggered:"
        RbProtoAsk            = "Display instance selector popup when claude:// is clicked (Recommended)"
        RbProtoFixed          = "Always route directly to the pinned instance selected below:"
        BtnEnableProto        = "Enable / Save claude:// Router"
        BtnDisableProto       = "Restore Windows Default"
        LblManualUrlTitle     = "Dispatch claude:// URI Manually"
        BtnPaste              = "Paste"
        LblSendTo             = "Send to:"
        BtnSendUrl            = "Dispatch URI"
        LblSyncTitle          = "MCP Servers, Permissions, and Preferences Synchronizer"
        LblSyncDesc           = "Copies MCP server definitions (mcpServers), authorized folder permissions, and preferences across instances without altering login credentials."
        LblSyncSrc            = "Source Instance:"
        LblSyncDst            = "Target Instance:"
        ChkSyncMcp            = "MCP Servers (mcpServers)"
        ChkSyncPerms          = "Project Folder Permissions (bypassPermissions)"
        ChkSyncPrefs          = "General Preferences (theme, shortcuts, display)"
        BtnRunSync            = "Clone Selected Settings"
        LblUpdateTitle        = "Auto-Update Controller and Anti-Gateway Protection (1p)"
        LblUpdateDesc         = "Prevents Claude Desktop from automatically closing running instances to install updates, and enforces 1p deployment mode."
        RbUpdateManual        = "Download updates in background, do NOT auto-restart (Recommended)"
        RbUpdateDisabled      = "Disable automatic updates completely"
        RbUpdateDefault       = "Application default (Download and restart automatically)"
        BtnApplyUpdate        = "Apply Update Policy and Enforce 1p Mode"
        LblBackupTitle        = "Session and Configuration Backup and Restore"
        LblBackupDesc         = "Creates a .zip archive containing all sessions (Code and Cowork), side notes, MCP configurations, and instance metadata."
        BtnCreateBackup       = "Create Backup Now"
        LblAvailableBackups   = "Available Backups:"
        BtnRestoreBackup      = "Restore Selected"
        BtnOpenBackupDir      = "Open Folder"
        ProtoActiveHeader     = "claude:// Router Active"
        ProtoDefaultHeader    = "claude:// Default"
        ProtoStatusActive     = "ACTIVE — claude:// URIs intercepted by CIM"
        ProtoStatusDefault    = "WINDOWS DEFAULT — claude:// URIs sent to primary instance"
        ProtoArmedPrefix      = "Temporary login target armed for: "
        ProtoArmedNone        = "Temporary login target: None"
        UpdateModeManual      = "Manual Restart Control (Downloads updates without closing instances)"
        UpdateModeDisabled    = "Automatic Updates Disabled"
        UpdateModeDefault     = "Claude Default (Automatic Restart)"
        MsgReady              = "Ready."
    }
}

$initState = Get-CIMState
$script:CurrentLang = if ($initState.language -and $script:I18N.ContainsKey($initState.language)) { [string]$initState.language } else { "pt-BR" }
$script:IsEditingExisting = $false

function T([string]$Key) {
    $dict = $script:I18N[$script:CurrentLang]
    if ($dict -and $dict.ContainsKey($Key)) { return $dict[$Key] }
    return $Key
}

[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Instance Manager (CIM)"
        Width="1140" Height="770" MinWidth="980" MinHeight="640"
        WindowStartupLocation="CenterScreen"
        Background="#0F0F12" Foreground="#F4F4F5"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#27272A"/>
            <Setter Property="Foreground" Value="#F4F4F5"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3F3F46"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#18181B"/>
            <Setter Property="Foreground" Value="#F4F4F5"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="CaretBrush" Value="#D97757"/>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#E4E4E7"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
        </Style>

        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="#E4E4E7"/>
            <Setter Property="Margin" Value="0,5,0,5"/>
        </Style>

        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#18181B"/>
            <Setter Property="Foreground" Value="#A1A1AA"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="Border" Background="#18181B" BorderBrush="#27272A" BorderThickness="1,1,1,0" CornerRadius="8,8,0,0" Padding="{TemplateBinding Padding}" Margin="0,0,6,0" Cursor="Hand">
                            <ContentPresenter ContentSource="Header"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#27272A"/>
                                <Setter TargetName="Border" Property="BorderBrush" Value="#D97757"/>
                                <Setter Property="Foreground" Value="#F4F4F5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16,12" Margin="0,0,0,14">
            <DockPanel LastChildFill="False">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
                    <Border Width="38" Height="38" CornerRadius="8" Background="#D97757" Margin="0,0,12,0">
                        <TextBlock Text="CIM" FontSize="14" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Claude Instance Manager" FontSize="18" FontWeight="Bold" Foreground="#F4F4F5"/>
                        <TextBlock x:Name="LblSubtitle" Text="" FontSize="12" Foreground="#A1A1AA"/>
                    </StackPanel>
                </StackPanel>

                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                    <ComboBox x:Name="CmbLanguage" Width="110" Height="30" Margin="0,0,10,0" VerticalContentAlignment="Center">
                        <ComboBoxItem Content="Português (BR)" Tag="pt-BR"/>
                        <ComboBoxItem Content="English (US)" Tag="en-US"/>
                    </ComboBox>
                    <Border x:Name="BadgeProtoHeader" Background="#27272A" CornerRadius="6" Padding="10,6" Margin="0,0,10,0">
                        <TextBlock x:Name="TxtProtoHeader" Text="claude://" FontSize="12" Foreground="#E4E4E7"/>
                    </Border>
                    <Button x:Name="BtnRefreshAll" Content="Refresh" Background="#D97757" BorderBrush="#D97757" Foreground="White"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- Main Tabs -->
        <TabControl Grid.Row="1" Background="#141418" BorderBrush="#27272A" BorderThickness="1" Padding="14">

            <!-- TAB 1: INSTANCES & ACCOUNTS -->
            <TabItem x:Name="TabInstances" Header="Instances">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="2.2*"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left: Instances ScrollViewer -->
                    <DockPanel Grid.Column="0" Margin="0,0,14,0">
                        <DockPanel DockPanel.Dock="Top" LastChildFill="False" Margin="0,0,0,10">
                            <TextBlock x:Name="LblInstalledInstances" Text="" FontSize="15" FontWeight="Bold" VerticalAlignment="Center" DockPanel.Dock="Left"/>
                            <Button x:Name="BtnSyncAllLinks" Content="" DockPanel.Dock="Right" Padding="10,5"/>
                        </DockPanel>
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="InstancesContainer" />
                        </ScrollViewer>
                    </DockPanel>

                    <!-- Right: Create / Edit Instance Form -->
                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <StackPanel>
                            <TextBlock x:Name="TxtFormTitle" Text="" FontSize="15" FontWeight="Bold" Margin="0,0,0,12"/>

                            <TextBlock x:Name="LblInstId" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                            <TextBox x:Name="InputInstId" Text=""/>

                            <TextBlock x:Name="LblInstDisplayName" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,10,0,4"/>
                            <TextBox x:Name="InputInstDisplayName" Text=""/>

                            <TextBlock x:Name="LblInstLabel" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,10,0,4"/>
                            <TextBox x:Name="InputInstLabel" Text=""/>

                            <Grid Margin="0,10,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0" Margin="0,0,6,0">
                                    <TextBlock x:Name="LblInstBadgeText" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBox x:Name="InputInstBadgeText" MaxLength="3" Text="N1"/>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Margin="6,0,0,0">
                                    <TextBlock x:Name="LblInstBadgeColor" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                                    <TextBox x:Name="InputInstBadgeColor" Text="#F59E0B"/>
                                </StackPanel>
                            </Grid>

                            <TextBlock x:Name="LblQuickColors" Text="" Foreground="#A1A1AA" FontSize="11" Margin="0,10,0,4"/>
                            <WrapPanel Margin="0,0,0,14">
                                <Button x:Name="BtnColorBlue" Content="" Background="#2563EB" Foreground="White" Padding="8,4" Margin="0,0,6,6"/>
                                <Button x:Name="BtnColorPurple" Content="" Background="#7C3AED" Foreground="White" Padding="8,4" Margin="0,0,6,6"/>
                                <Button x:Name="BtnColorGreen" Content="" Background="#10B981" Foreground="White" Padding="8,4" Margin="0,0,6,6"/>
                                <Button x:Name="BtnColorAmber" Content="" Background="#F59E0B" Foreground="White" Padding="8,4" Margin="0,0,6,6"/>
                                <Button x:Name="BtnColorRose" Content="" Background="#E11D48" Foreground="White" Padding="8,4" Margin="0,0,6,6"/>
                            </WrapPanel>

                            <Button x:Name="BtnSaveInstance" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="12,9" Margin="0,0,0,8"/>
                            <Button x:Name="BtnClearForm" Content="" Padding="10,6"/>

                            <Border Background="#09090B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,16,0,0">
                                <TextBlock x:Name="TxtLoginTip" TextWrapping="Wrap" FontSize="11" Foreground="#A1A1AA" Text=""/>
                            </Border>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 2: PROJECTS & CHATS MIGRATION -->
            <TabItem x:Name="TabSessions" Header="Sessions">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="220"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Source Column -->
                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="14">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblSrcInstance" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,6"/>
                                <ComboBox x:Name="CmbSourceInstance" Height="32" Margin="0,0,0,8"/>
                                <DockPanel>
                                    <TextBlock x:Name="LblFilter" Text="" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <TextBox x:Name="TxtSessionFilter" />
                                </DockPanel>
                                <WrapPanel Margin="0,8,0,0">
                                    <Button x:Name="BtnSelectAllSessions" Content="" Padding="8,4" Margin="0,0,6,0" FontSize="11"/>
                                    <Button x:Name="BtnClearSessionSelection" Content="" Padding="8,4" FontSize="11"/>
                                </WrapPanel>
                            </StackPanel>

                            <ListBox x:Name="LstSourceSessions" SelectionMode="Extended" Background="#09090B" Foreground="#F4F4F5" BorderBrush="#27272A" FontSize="12"/>
                        </DockPanel>
                    </Border>

                    <!-- Center Transfer Controls -->
                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0">
                        <Border Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="12">
                            <StackPanel>
                                <TextBlock x:Name="LblTransferHeader" Text="" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" Margin="0,0,0,10"/>
                                <CheckBox x:Name="ChkIncludeSubSessions" Content="" IsChecked="True" FontSize="11"/>
                                <CheckBox x:Name="ChkAutoBackupMove" Content="" IsChecked="True" FontSize="11" Margin="0,4,0,12"/>

                                <Button x:Name="BtnCopySessions" Content="" Background="#2563EB" BorderBrush="#2563EB" Foreground="White" Padding="10,9" Margin="0,0,0,10"/>
                                <Button x:Name="BtnMoveSessions" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="10,9"/>

                                <TextBlock x:Name="TxtTransferNote" TextWrapping="Wrap" Foreground="#A1A1AA" FontSize="11" Margin="0,12,0,0" Text=""/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <!-- Target Column -->
                    <Border Grid.Column="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="14">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblDstInstance" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,6"/>
                                <ComboBox x:Name="CmbTargetInstance" Height="32" Margin="0,0,0,8"/>
                                <TextBlock x:Name="TxtTargetSummary" Text="" Foreground="#A1A1AA" FontSize="12"/>
                            </StackPanel>
                            <ListBox x:Name="LstTargetSessions" Background="#09090B" Foreground="#A1A1AA" BorderBrush="#27272A" FontSize="12"/>
                        </DockPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 3: CLAUDE:// PROTOCOL ROUTER & CONFIG SYNC -->
            <TabItem x:Name="TabProtocol" Header="Protocol">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left: claude:// Protocol Interceptor -->
                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock x:Name="LblProtoTitle" Text="" FontSize="15" FontWeight="Bold" Margin="0,0,0,6"/>
                            <TextBlock x:Name="LblProtoDesc" TextWrapping="Wrap" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,12" Text=""/>

                            <Border Background="#09090B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,14">
                                <StackPanel>
                                    <TextBlock x:Name="TxtProtoDetailStatus" Text="" FontWeight="Bold" Foreground="#10B981" FontSize="13"/>
                                    <TextBlock x:Name="TxtProtoProgId" Text="ProgID: —" Foreground="#A1A1AA" FontSize="11" Margin="0,4,0,0"/>
                                    <TextBlock x:Name="TxtProtoArmed" Text="" Foreground="#F59E0B" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>

                            <TextBlock x:Name="LblProtoBehavior" Text="" FontWeight="SemiBold" Margin="0,0,0,6"/>
                            <RadioButton x:Name="RbProtoAsk" Content="" IsChecked="True"/>
                            <RadioButton x:Name="RbProtoFixed" Content=""/>

                            <ComboBox x:Name="CmbProtoFixedInstance" Height="30" Margin="22,4,0,14"/>

                            <WrapPanel Margin="0,0,0,18">
                                <Button x:Name="BtnEnableProto" Content="" Background="#10B981" BorderBrush="#10B981" Foreground="White" Padding="12,8" Margin="0,0,10,0"/>
                                <Button x:Name="BtnDisableProto" Content="" Padding="12,8"/>
                            </WrapPanel>

                            <Separator Background="#27272A" Margin="0,4,0,14"/>

                            <TextBlock x:Name="LblManualUrlTitle" Text="" FontWeight="Bold" FontSize="13" Margin="0,0,0,6"/>
                            <DockPanel Margin="0,0,0,8">
                                <Button x:Name="BtnPasteClipboardUrl" Content="" DockPanel.Dock="Right" Margin="8,0,0,0"/>
                                <TextBox x:Name="TxtManualClaudeUrl" Text="claude://"/>
                            </DockPanel>
                            <DockPanel>
                                <TextBlock x:Name="LblSendTo" Text="" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <ComboBox x:Name="CmbManualUrlInstance" Width="200" Height="30" Margin="0,0,8,0"/>
                                <Button x:Name="BtnSendManualUrl" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White"/>
                            </DockPanel>
                        </StackPanel>
                    </Border>

                    <!-- Right: Config & MCP Cloner -->
                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <StackPanel>
                            <TextBlock x:Name="LblSyncTitle" Text="" FontSize="15" FontWeight="Bold" Margin="0,0,0,6"/>
                            <TextBlock x:Name="LblSyncDesc" TextWrapping="Wrap" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,14" Text=""/>

                            <TextBlock x:Name="LblSyncSrc" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbSyncSrc" Height="30" Margin="0,0,0,12"/>

                            <TextBlock x:Name="LblSyncDst" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbSyncDst" Height="30" Margin="0,0,0,14"/>

                            <CheckBox x:Name="ChkSyncMcp" Content="" IsChecked="True"/>
                            <CheckBox x:Name="ChkSyncPerms" Content="" IsChecked="True"/>
                            <CheckBox x:Name="ChkSyncPrefs" Content="" IsChecked="True" Margin="0,4,0,16"/>

                            <Button x:Name="BtnRunConfigSync" Content="" Background="#2563EB" BorderBrush="#2563EB" Foreground="White" Padding="12,9"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 4: UPDATES, ANTI-GATEWAY & BACKUPS -->
            <TabItem x:Name="TabSettings" Header="Settings">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1*"/>
                        <ColumnDefinition Width="1.1*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left: Auto-Update & 1p Policy -->
                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock x:Name="LblUpdateTitle" Text="" FontSize="15" FontWeight="Bold" Margin="0,0,0,6"/>
                            <TextBlock x:Name="LblUpdateDesc" TextWrapping="Wrap" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,14" Text=""/>

                            <Border Background="#09090B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,14">
                                <StackPanel>
                                    <TextBlock x:Name="TxtCurrentUpdatePolicy" Text="" FontWeight="Bold" Foreground="#10B981" FontSize="13"/>
                                    <TextBlock x:Name="TxtCurrentDeploymentMode" Text="Deployment Mode: 1p" Foreground="#A1A1AA" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>

                            <RadioButton x:Name="RbUpdateManualRestart" Content="" IsChecked="True"/>
                            <RadioButton x:Name="RbUpdateDisabled" Content=""/>
                            <RadioButton x:Name="RbUpdateDefault" Content=""/>

                            <Button x:Name="BtnApplyUpdatePolicy" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="12,9" Margin="0,14,0,0"/>
                        </StackPanel>
                    </Border>

                    <!-- Right: Backups -->
                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblBackupTitle" Text="" FontSize="15" FontWeight="Bold" Margin="0,0,0,6"/>
                                <TextBlock x:Name="LblBackupDesc" TextWrapping="Wrap" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,10" Text=""/>
                                <DockPanel Margin="0,0,0,10">
                                    <Button x:Name="BtnCreateBackup" Content="" Background="#10B981" BorderBrush="#10B981" Foreground="White" DockPanel.Dock="Right" Margin="8,0,0,0"/>
                                    <TextBox x:Name="TxtBackupLabel" Text="manual"/>
                                </DockPanel>
                                <DockPanel LastChildFill="False" Margin="0,4,0,4">
                                    <TextBlock x:Name="LblAvailableBackups" Text="" FontWeight="SemiBold" VerticalAlignment="Center" DockPanel.Dock="Left"/>
                                    <Button x:Name="BtnOpenBackupsFolder" Content="" Padding="8,4" FontSize="11" DockPanel.Dock="Right"/>
                                    <Button x:Name="BtnRestoreBackup" Content="" Padding="8,4" FontSize="11" DockPanel.Dock="Right" Margin="0,0,6,0"/>
                                </DockPanel>
                            </StackPanel>
                            <ListBox x:Name="LstBackups" Background="#09090B" Foreground="#E4E4E7" BorderBrush="#27272A" FontSize="12"/>
                        </DockPanel>
                    </Border>
                </Grid>
            </TabItem>

        </TabControl>

        <!-- Status Bar -->
        <Border Grid.Row="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="0,12,0,0">
            <DockPanel LastChildFill="True">
                <TextBlock x:Name="TxtStatusBar" Text="" Foreground="#A1A1AA" FontSize="12"/>
            </DockPanel>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader($Xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

if ($CheckOnly) {
    Write-Output "CIM_GUI_OK"
    exit 0
}

# --- Bind Controls ---
$TxtStatusBar          = $Window.FindName("TxtStatusBar")
$BadgeProtoHeader      = $Window.FindName("BadgeProtoHeader")
$TxtProtoHeader        = $Window.FindName("TxtProtoHeader")
$BtnRefreshAll         = $Window.FindName("BtnRefreshAll")
$CmbLanguage           = $Window.FindName("CmbLanguage")

# Tab 1
$InstancesContainer    = $Window.FindName("InstancesContainer")
$BtnSyncAllLinks       = $Window.FindName("BtnSyncAllLinks")
$TxtFormTitle          = $Window.FindName("TxtFormTitle")
$InputInstId           = $Window.FindName("InputInstId")
$InputInstDisplayName  = $Window.FindName("InputInstDisplayName")
$InputInstLabel        = $Window.FindName("InputInstLabel")
$InputInstBadgeText    = $Window.FindName("InputInstBadgeText")
$InputInstBadgeColor   = $Window.FindName("InputInstBadgeColor")
$BtnColorBlue          = $Window.FindName("BtnColorBlue")
$BtnColorPurple        = $Window.FindName("BtnColorPurple")
$BtnColorGreen         = $Window.FindName("BtnColorGreen")
$BtnColorAmber         = $Window.FindName("BtnColorAmber")
$BtnColorRose          = $Window.FindName("BtnColorRose")
$BtnSaveInstance       = $Window.FindName("BtnSaveInstance")
$BtnClearForm          = $Window.FindName("BtnClearForm")

# Tab 2
$CmbSourceInstance     = $Window.FindName("CmbSourceInstance")
$CmbTargetInstance     = $Window.FindName("CmbTargetInstance")
$TxtSessionFilter      = $Window.FindName("TxtSessionFilter")
$BtnSelectAllSessions  = $Window.FindName("BtnSelectAllSessions")
$BtnClearSessionSelection = $Window.FindName("BtnClearSessionSelection")
$LstSourceSessions     = $Window.FindName("LstSourceSessions")
$LstTargetSessions     = $Window.FindName("LstTargetSessions")
$TxtTargetSummary      = $Window.FindName("TxtTargetSummary")
$ChkIncludeSubSessions = $Window.FindName("ChkIncludeSubSessions")
$ChkAutoBackupMove     = $Window.FindName("ChkAutoBackupMove")
$BtnCopySessions       = $Window.FindName("BtnCopySessions")
$BtnMoveSessions       = $Window.FindName("BtnMoveSessions")

# Tab 3
$TxtProtoDetailStatus  = $Window.FindName("TxtProtoDetailStatus")
$TxtProtoProgId        = $Window.FindName("TxtProtoProgId")
$TxtProtoArmed         = $Window.FindName("TxtProtoArmed")
$RbProtoAsk            = $Window.FindName("RbProtoAsk")
$RbProtoFixed          = $Window.FindName("RbProtoFixed")
$CmbProtoFixedInstance = $Window.FindName("CmbProtoFixedInstance")
$BtnEnableProto        = $Window.FindName("BtnEnableProto")
$BtnDisableProto       = $Window.FindName("BtnDisableProto")
$TxtManualClaudeUrl    = $Window.FindName("TxtManualClaudeUrl")
$BtnPasteClipboardUrl  = $Window.FindName("BtnPasteClipboardUrl")
$CmbManualUrlInstance  = $Window.FindName("CmbManualUrlInstance")
$BtnSendManualUrl      = $Window.FindName("BtnSendManualUrl")
$CmbSyncSrc            = $Window.FindName("CmbSyncSrc")
$CmbSyncDst            = $Window.FindName("CmbSyncDst")
$ChkSyncMcp            = $Window.FindName("ChkSyncMcp")
$ChkSyncPerms          = $Window.FindName("ChkSyncPerms")
$ChkSyncPrefs          = $Window.FindName("ChkSyncPrefs")
$BtnRunConfigSync      = $Window.FindName("BtnRunConfigSync")

# Tab 4
$TxtCurrentUpdatePolicy   = $Window.FindName("TxtCurrentUpdatePolicy")
$TxtCurrentDeploymentMode = $Window.FindName("TxtCurrentDeploymentMode")
$RbUpdateManualRestart    = $Window.FindName("RbUpdateManualRestart")
$RbUpdateDisabled         = $Window.FindName("RbUpdateDisabled")
$RbUpdateDefault          = $Window.FindName("RbUpdateDefault")
$BtnApplyUpdatePolicy     = $Window.FindName("BtnApplyUpdatePolicy")
$TxtBackupLabel           = $Window.FindName("TxtBackupLabel")
$BtnCreateBackup          = $Window.FindName("BtnCreateBackup")
$BtnRestoreBackup         = $Window.FindName("BtnRestoreBackup")
$BtnOpenBackupsFolder     = $Window.FindName("BtnOpenBackupsFolder")
$LstBackups               = $Window.FindName("LstBackups")

$BrushConv = New-Object System.Windows.Media.BrushConverter
$script:CachedInstances = @()
$script:CachedSourceSessions = @()

function Set-Status([string]$Message) {
    $TxtStatusBar.Text = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

function Apply-Localization {
    $Window.FindName("LblSubtitle").Text          = T "Subtitle"
    $BtnRefreshAll.Content                        = T "BtnRefreshAll"
    $Window.FindName("TabInstances").Header       = T "TabInstances"
    $Window.FindName("TabSessions").Header        = T "TabSessions"
    $Window.FindName("TabProtocol").Header        = T "TabProtocol"
    $Window.FindName("TabSettings").Header        = T "TabSettings"
    $Window.FindName("LblInstalledInstances").Text= T "LblInstalledInstances"
    $BtnSyncAllLinks.Content                      = T "BtnSyncAllLinks"
    $TxtFormTitle.Text                            = if ($script:IsEditingExisting) { T "FormTitleEdit" } else { T "FormTitleNew" }
    $Window.FindName("LblInstId").Text            = T "LblInstId"
    $Window.FindName("LblInstDisplayName").Text   = T "LblInstDisplayName"
    $Window.FindName("LblInstLabel").Text         = T "LblInstLabel"
    $Window.FindName("LblInstBadgeText").Text     = T "LblInstBadgeText"
    $Window.FindName("LblInstBadgeColor").Text    = T "LblInstBadgeColor"
    $Window.FindName("LblQuickColors").Text       = T "LblQuickColors"
    $BtnColorBlue.Content                         = T "ColorBlue"
    $BtnColorPurple.Content                       = T "ColorPurple"
    $BtnColorGreen.Content                        = T "ColorGreen"
    $BtnColorAmber.Content                        = T "ColorAmber"
    $BtnColorRose.Content                         = T "ColorRose"
    $BtnSaveInstance.Content                      = T "BtnSaveInstance"
    $BtnClearForm.Content                         = T "BtnClearForm"
    $Window.FindName("TxtLoginTip").Text          = T "TxtLoginTip"
    $Window.FindName("LblSrcInstance").Text       = T "LblSrcInstance"
    $Window.FindName("LblFilter").Text            = T "LblFilter"
    $BtnSelectAllSessions.Content                 = T "BtnSelectAll"
    $BtnClearSessionSelection.Content             = T "BtnClearSel"
    $Window.FindName("LblTransferHeader").Text    = T "LblTransferHeader"
    $ChkIncludeSubSessions.Content                = T "ChkIncludeSub"
    $ChkAutoBackupMove.Content                    = T "ChkAutoBackup"
    $BtnCopySessions.Content                      = T "BtnCopySessions"
    $BtnMoveSessions.Content                      = T "BtnMoveSessions"
    $Window.FindName("TxtTransferNote").Text      = T "TxtTransferNote"
    $Window.FindName("LblDstInstance").Text       = T "LblDstInstance"
    $Window.FindName("LblProtoTitle").Text        = T "LblProtoTitle"
    $Window.FindName("LblProtoDesc").Text         = T "LblProtoDesc"
    $Window.FindName("LblProtoBehavior").Text     = T "LblProtoBehavior"
    $RbProtoAsk.Content                           = T "RbProtoAsk"
    $RbProtoFixed.Content                         = T "RbProtoFixed"
    $BtnEnableProto.Content                       = T "BtnEnableProto"
    $BtnDisableProto.Content                      = T "BtnDisableProto"
    $Window.FindName("LblManualUrlTitle").Text    = T "LblManualUrlTitle"
    $BtnPasteClipboardUrl.Content                 = T "BtnPaste"
    $Window.FindName("LblSendTo").Text            = T "LblSendTo"
    $BtnSendManualUrl.Content                     = T "BtnSendUrl"
    $Window.FindName("LblSyncTitle").Text         = T "LblSyncTitle"
    $Window.FindName("LblSyncDesc").Text          = T "LblSyncDesc"
    $Window.FindName("LblSyncSrc").Text           = T "LblSyncSrc"
    $Window.FindName("LblSyncDst").Text           = T "LblSyncDst"
    $ChkSyncMcp.Content                           = T "ChkSyncMcp"
    $ChkSyncPerms.Content                         = T "ChkSyncPerms"
    $ChkSyncPrefs.Content                         = T "ChkSyncPrefs"
    $BtnRunConfigSync.Content                     = T "BtnRunSync"
    $Window.FindName("LblUpdateTitle").Text       = T "LblUpdateTitle"
    $Window.FindName("LblUpdateDesc").Text        = T "LblUpdateDesc"
    $RbUpdateManualRestart.Content                = T "RbUpdateManual"
    $RbUpdateDisabled.Content                     = T "RbUpdateDisabled"
    $RbUpdateDefault.Content                      = T "RbUpdateDefault"
    $BtnApplyUpdatePolicy.Content                 = T "BtnApplyUpdate"
    $Window.FindName("LblBackupTitle").Text       = T "LblBackupTitle"
    $Window.FindName("LblBackupDesc").Text        = T "LblBackupDesc"
    $BtnCreateBackup.Content                      = T "BtnCreateBackup"
    $Window.FindName("LblAvailableBackups").Text  = T "LblAvailableBackups"
    $BtnRestoreBackup.Content                     = T "BtnRestoreBackup"
    $BtnOpenBackupsFolder.Content                 = T "BtnOpenBackupDir"
}

function Refresh-ProtocolUI {
    $st = Get-ClaudeProtocolStatus
    $TxtProtoProgId.Text = "ProgID Windows: $($st.ProgId)"
    if (-not [string]::IsNullOrWhiteSpace($st.ArmedLoginInstanceId)) {
        $TxtProtoArmed.Text = "$(T 'ProtoArmedPrefix')$($st.ArmedLoginInstanceId)"
    } else {
        $TxtProtoArmed.Text = T "ProtoArmedNone"
    }

    if ($st.IsIntercepted) {
        $TxtProtoDetailStatus.Text = "$(T 'ProtoStatusActive') ($($st.Mode))"
        $TxtProtoDetailStatus.Foreground = $BrushConv.ConvertFromString("#10B981")
        $TxtProtoHeader.Text = "$(T 'ProtoActiveHeader') ($($st.Mode))"
        $BadgeProtoHeader.Background = $BrushConv.ConvertFromString("#065F46")
    } else {
        $TxtProtoDetailStatus.Text = T "ProtoStatusDefault"
        $TxtProtoDetailStatus.Foreground = $BrushConv.ConvertFromString("#A1A1AA")
        $TxtProtoHeader.Text = T "ProtoDefaultHeader"
        $BadgeProtoHeader.Background = $BrushConv.ConvertFromString("#27272A")
    }

    if ($st.Mode -eq "fixed") {
        $RbProtoFixed.IsChecked = $true
    } else {
        $RbProtoAsk.IsChecked = $true
    }
}

function Refresh-UpdateAndBackupUI {
    $pol = Get-ClaudeUpdatePolicy
    $TxtCurrentDeploymentMode.Text = "Deployment Mode: $($pol.DeploymentMode) (1p Enforced)"
    switch ($pol.Mode) {
        "ManualRestart" {
            $TxtCurrentUpdatePolicy.Text = T "UpdateModeManual"
            $RbUpdateManualRestart.IsChecked = $true
        }
        "Disabled" {
            $TxtCurrentUpdatePolicy.Text = T "UpdateModeDisabled"
            $RbUpdateDisabled.IsChecked = $true
        }
        default {
            $TxtCurrentUpdatePolicy.Text = T "UpdateModeDefault"
            $RbUpdateDefault.IsChecked = $true
        }
    }

    $LstBackups.Items.Clear()
    $backups = @(Get-ClaudeBackups)
    foreach ($b in $backups) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Content = $b.Label
        $item.Tag = $b.FullPath
        [void]$LstBackups.Items.Add($item)
    }
}

function Refresh-SessionLists {
    $srcItem = $CmbSourceInstance.SelectedItem
    $dstItem = $CmbTargetInstance.SelectedItem

    $LstSourceSessions.Items.Clear()
    if ($srcItem -and $srcItem.Tag) {
        $script:CachedSourceSessions = @(Get-ClaudeInstanceSessions -InstanceId ([string]$srcItem.Tag))
        $filter = $TxtSessionFilter.Text.Trim()
        foreach ($s in $script:CachedSourceSessions) {
            if ($filter -and ($s.DisplayLabel -notmatch [regex]::Escape($filter)) -and ($s.Cwd -notmatch [regex]::Escape($filter))) {
                continue
            }
            $li = New-Object System.Windows.Controls.ListBoxItem
            $li.Content = $s.DisplayLabel
            $li.ToolTip = "Path: $($s.Cwd)`nSessionId: $($s.SessionId)`nModel: $($s.Model)"
            $li.Tag = $s.SessionId
            [void]$LstSourceSessions.Items.Add($li)
        }
    }

    $LstTargetSessions.Items.Clear()
    if ($dstItem -and $dstItem.Tag) {
        $dstSessions = @(Get-ClaudeInstanceSessions -InstanceId ([string]$dstItem.Tag))
        $TxtTargetSummary.Text = "$(T 'LblDstSummary') ($($dstSessions.Count)):"
        foreach ($s in $dstSessions) {
            $li = New-Object System.Windows.Controls.ListBoxItem
            $li.Content = $s.DisplayLabel
            $li.Tag = $s.SessionId
            [void]$LstTargetSessions.Items.Add($li)
        }
    }
}

function Refresh-InstancesUI {
    $script:CachedInstances = @(Get-ClaudeInstances)
    $InstancesContainer.Children.Clear()

    $combos = @($CmbSourceInstance, $CmbTargetInstance, $CmbProtoFixedInstance, $CmbManualUrlInstance, $CmbSyncSrc, $CmbSyncDst)
    $prevSel = @{}
    foreach ($c in $combos) {
        if ($c.SelectedItem -and $c.SelectedItem.Tag) { $prevSel[$c.Name] = [string]$c.SelectedItem.Tag }
        $c.Items.Clear()
    }

    foreach ($inst in $script:CachedInstances) {
        foreach ($c in $combos) {
            $ci = New-Object System.Windows.Controls.ComboBoxItem
            $ci.Content = "[$($inst.BadgeText)] $($inst.DisplayName)"
            $ci.Tag = $inst.Id
            [void]$c.Items.Add($ci)
        }

        $card = New-Object System.Windows.Controls.Border
        $card.Background = $BrushConv.ConvertFromString("#18181B")
        $card.BorderBrush = $BrushConv.ConvertFromString($inst.BadgeColor)
        $card.BorderThickness = New-Object System.Windows.Thickness(4, 1, 1, 1)
        $card.CornerRadius = New-Object System.Windows.CornerRadius(10)
        $card.Padding = New-Object System.Windows.Thickness(14)
        $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)

        $stack = New-Object System.Windows.Controls.StackPanel

        $topDock = New-Object System.Windows.Controls.DockPanel
        $topDock.LastChildFill = $false

        $leftHeader = New-Object System.Windows.Controls.StackPanel
        $leftHeader.Orientation = "Horizontal"
        [System.Windows.Controls.DockPanel]::SetDock($leftHeader, "Left")

        $badgeBorder = New-Object System.Windows.Controls.Border
        $badgeBorder.Width = 34
        $badgeBorder.Height = 34
        $badgeBorder.CornerRadius = New-Object System.Windows.CornerRadius(17)
        $badgeBorder.Background = $BrushConv.ConvertFromString($inst.BadgeColor)
        $badgeBorder.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
        $badgeTxt = New-Object System.Windows.Controls.TextBlock
        $badgeTxt.Text = $inst.BadgeText
        $badgeTxt.Foreground = [System.Windows.Media.Brushes]::White
        $badgeTxt.FontWeight = "Bold"
        $badgeTxt.HorizontalAlignment = "Center"
        $badgeTxt.VerticalAlignment = "Center"
        $badgeBorder.Child = $badgeTxt
        [void]$leftHeader.Children.Add($badgeBorder)

        $titleStack = New-Object System.Windows.Controls.StackPanel
        $titleTxt = New-Object System.Windows.Controls.TextBlock
        $primTag = if ($inst.IsPrimary) { T "PrimaryTag" } else { T "IsolatedTag" }
        $titleTxt.Text = "$($inst.DisplayName)$primTag"
        $titleTxt.FontSize = 15
        $titleTxt.FontWeight = "Bold"
        $titleTxt.Foreground = $BrushConv.ConvertFromString("#F4F4F5")
        [void]$titleStack.Children.Add($titleTxt)

        $subTxt = New-Object System.Windows.Controls.TextBlock
        $subTxt.Text = "$($inst.AccountLabel)  |  ID: $($inst.Id)"
        $subTxt.FontSize = 11
        $subTxt.Foreground = $BrushConv.ConvertFromString("#A1A1AA")
        [void]$titleStack.Children.Add($subTxt)
        [void]$leftHeader.Children.Add($titleStack)
        [void]$topDock.Children.Add($leftHeader)

        $statusBorder = New-Object System.Windows.Controls.Border
        $statusBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $statusBorder.Padding = New-Object System.Windows.Thickness(10, 4, 10, 4)
        [System.Windows.Controls.DockPanel]::SetDock($statusBorder, "Right")
        $statusTxt = New-Object System.Windows.Controls.TextBlock
        $statusTxt.FontSize = 11
        $statusTxt.FontWeight = "SemiBold"
        if ($inst.IsRunning) {
            $statusBorder.Background = $BrushConv.ConvertFromString("#064E3B")
            $statusTxt.Foreground = $BrushConv.ConvertFromString("#34D399")
            $statusTxt.Text = "$(T 'StatusRunning') ($($inst.ProcessCount) proc | $($inst.RamMB) MB)"
        } else {
            $statusBorder.Background = $BrushConv.ConvertFromString("#27272A")
            $statusTxt.Foreground = $BrushConv.ConvertFromString("#A1A1AA")
            $statusTxt.Text = T "StatusStopped"
        }
        $statusBorder.Child = $statusTxt
        [void]$topDock.Children.Add($statusBorder)
        [void]$stack.Children.Add($topDock)

        $infoTxt = New-Object System.Windows.Controls.TextBlock
        $dispLabel = if ($inst.DispatchEnabled) { "ON" } else { "OFF" }
        $vmLabel = if ($inst.VmDiskPresent) { "OK" } else { "—" }
        $infoTxt.Text = "AccountUUID: $($inst.AccountUuid)   |   OrgUUID: $($inst.OrgUuid)`nSessions: $($inst.SessionCount)   |   Dispatch: $dispLabel   |   VM Disk: $vmLabel"
        $infoTxt.FontSize = 11
        $infoTxt.Foreground = $BrushConv.ConvertFromString("#A1A1AA")
        $infoTxt.Margin = New-Object System.Windows.Thickness(0, 8, 0, 10)
        [void]$stack.Children.Add($infoTxt)

        $btnWrap = New-Object System.Windows.Controls.WrapPanel

        if ($inst.IsRunning) {
            $btnStop = New-Object System.Windows.Controls.Button
            $btnStop.Content = T "BtnStop"
            $btnStop.Background = $BrushConv.ConvertFromString("#7F1D1D")
            $btnStop.BorderBrush = $BrushConv.ConvertFromString("#991B1B")
            $btnStop.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
            $btnStop.Tag = $inst.Id
            $btnStop.Add_Click({
                param($s, $e)
                $cnt = Stop-ClaudeInstance -InstanceId ([string]$s.Tag)
                Set-Status "Stopped instance '$($s.Tag)' ($cnt processes terminated)."
                Refresh-InstancesUI
            })
            [void]$btnWrap.Children.Add($btnStop)
        } else {
            $btnStart = New-Object System.Windows.Controls.Button
            $btnStart.Content = T "BtnOpen"
            $btnStart.Background = $BrushConv.ConvertFromString("#065F46")
            $btnStart.BorderBrush = $BrushConv.ConvertFromString("#059669")
            $btnStart.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
            $btnStart.Tag = $inst.Id
            $btnStart.Add_Click({
                param($s, $e)
                Start-ClaudeInstance -InstanceId ([string]$s.Tag)
                Set-Status "Started instance '$($s.Tag)'."
                Start-Sleep -Milliseconds 800
                Refresh-InstancesUI
            })
            [void]$btnWrap.Children.Add($btnStart)
        }

        $btnLogin = New-Object System.Windows.Controls.Button
        $btnLogin.Content = T "BtnLogin"
        $btnLogin.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $btnLogin.Tag = $inst.Id
        $btnLogin.Add_Click({
            param($s, $e)
            $id = [string]$s.Tag
            $promptMsg = if ($script:CurrentLang -eq "en-US") {
                "Do you want to clear existing web session cookies in '$id' before opening for login?`n`n- YES: Clears only auth cookies/tokens (keeps all sessions, projects, and MCPs) and arms the claude:// router for this instance.`n- NO: Only arms the claude:// router for this instance and launches the window."
            } else {
                "Deseja limpar os cookies de sessão atuais de '$id' antes de abrir para login?`n`n- SIM: Limpa apenas os cookies/tokens de autenticação (mantendo todos os seus projetos, sessões e MCPs) e arma o roteador claude:// para esta instância.`n- NÃO: Apenas arma o roteador claude:// para esta instância e abre a janela."
            }
            $res = [System.Windows.MessageBox]::Show(
                $promptMsg,
                "Login — $id",
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($res -eq [System.Windows.MessageBoxResult]::Cancel) { return }
            if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
                Clear-ClaudeInstanceAuth -InstanceId $id | Out-Null
            }
            Set-ClaudeLoginTarget -InstanceId $id -MinutesValid 15
            Start-ClaudeInstance -InstanceId $id
            Refresh-ProtocolUI
            Refresh-InstancesUI
            Set-Status "claude:// login target armed for '$id' (15 min)."
        })
        [void]$btnWrap.Children.Add($btnLogin)

        $btnRemap = New-Object System.Windows.Controls.Button
        $btnRemap.Content = T "BtnRemap"
        $btnRemap.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $btnRemap.Tag = $inst.Id
        $btnRemap.Add_Click({
            param($s, $e)
            $id = [string]$s.Tag
            $cnt = Repair-ClaudeInstanceSessionOwnership -InstanceId $id
            Refresh-InstancesUI
            Refresh-SessionLists
            Set-Status "Bound $cnt session(s) in '$id' to active account UUID."
        })
        [void]$btnWrap.Children.Add($btnRemap)

        $btnDisp = New-Object System.Windows.Controls.Button
        $btnDisp.Content = if ($inst.DispatchEnabled) { "Dispatch: ON" } else { "Dispatch: OFF" }
        $btnDisp.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $btnDisp.Tag = $inst
        $btnDisp.Add_Click({
            param($s, $e)
            $targetInst = $s.Tag
            $newState = -not $targetInst.DispatchEnabled
            Set-ClaudeInstanceDispatch -InstanceId $targetInst.Id -Enabled $newState | Out-Null
            Refresh-InstancesUI
            Set-Status "Dispatch set to $newState on '$($targetInst.DisplayName)'."
        })
        [void]$btnWrap.Children.Add($btnDisp)

        $btnEdit = New-Object System.Windows.Controls.Button
        $btnEdit.Content = T "BtnEdit"
        $btnEdit.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $btnEdit.Tag = $inst
        $btnEdit.Add_Click({
            param($s, $e)
            $targetInst = $s.Tag
            $script:IsEditingExisting = $true
            $TxtFormTitle.Text = "$(T 'FormTitleEdit'): $($targetInst.DisplayName)"
            $InputInstId.Text = $targetInst.Id
            $InputInstId.IsEnabled = $false
            $InputInstDisplayName.Text = $targetInst.DisplayName
            $InputInstLabel.Text = $targetInst.AccountLabel
            $InputInstBadgeText.Text = $targetInst.BadgeText
            $InputInstBadgeColor.Text = $targetInst.BadgeColor
            Set-Status "Editing '$($targetInst.Id)'."
        })
        [void]$btnWrap.Children.Add($btnEdit)

        $btnFolder = New-Object System.Windows.Controls.Button
        $btnFolder.Content = T "BtnFolder"
        $btnFolder.Margin = New-Object System.Windows.Thickness(0, 0, 6, 6)
        $btnFolder.Tag = $inst.DataDir
        $btnFolder.Add_Click({
            param($s, $e)
            $dir = [string]$s.Tag
            if (Test-Path $dir) { Start-Process "explorer.exe" -ArgumentList "`"$dir`"" }
        })
        [void]$btnWrap.Children.Add($btnFolder)

        [void]$stack.Children.Add($btnWrap)
        $card.Child = $stack
        [void]$InstancesContainer.Children.Add($card)
    }

    foreach ($c in $combos) {
        $wanted = $prevSel[$c.Name]
        $matched = $false
        if ($wanted) {
            foreach ($item in $c.Items) {
                if ([string]$item.Tag -eq $wanted) {
                    $c.SelectedItem = $item
                    $matched = $true
                    break
                }
            }
        }
        if (-not $matched -and $c.Items.Count -gt 0) {
            if (($c.Name -eq "CmbTargetInstance" -or $c.Name -eq "CmbSyncDst") -and $c.Items.Count -gt 1) {
                $c.SelectedIndex = $c.Items.Count - 1
            } else {
                $c.SelectedIndex = 0
            }
        }
    }
}

# Select initial language in ComboBox
foreach ($item in $CmbLanguage.Items) {
    if ([string]$item.Tag -eq $script:CurrentLang) {
        $CmbLanguage.SelectedItem = $item
        break
    }
}

$CmbLanguage.Add_SelectionChanged({
    if ($CmbLanguage.SelectedItem -and $CmbLanguage.SelectedItem.Tag) {
        $script:CurrentLang = [string]$CmbLanguage.SelectedItem.Tag
        $st = Get-CIMState
        $st.language = $script:CurrentLang
        Save-CIMState -State $st
        Apply-Localization
        Refresh-InstancesUI
        Refresh-SessionLists
        Refresh-ProtocolUI
        Refresh-UpdateAndBackupUI
        Set-Status (T "MsgReady")
    }
})

$BtnRefreshAll.Add_Click({
    Refresh-InstancesUI
    Refresh-SessionLists
    Refresh-ProtocolUI
    Refresh-UpdateAndBackupUI
    Set-Status (T "MsgReady")
})

$BtnSyncAllLinks.Add_Click({
    $totalLinked = 0
    foreach ($inst in $script:CachedInstances) {
        if (-not $inst.IsPrimary) {
            $res = Sync-ClaudeInstanceLinks -TargetDir $inst.DataDir
            $totalLinked += $res.LinkedCount
        }
    }
    Refresh-InstancesUI
    Set-Status "Hardlinks synchronized across all secondary instances ($totalLinked new files linked)."
})

$BtnColorBlue.Add_Click({   $InputInstBadgeColor.Text = "#2563EB" })
$BtnColorPurple.Add_Click({ $InputInstBadgeColor.Text = "#7C3AED" })
$BtnColorGreen.Add_Click({  $InputInstBadgeColor.Text = "#10B981" })
$BtnColorAmber.Add_Click({  $InputInstBadgeColor.Text = "#F59E0B" })
$BtnColorRose.Add_Click({   $InputInstBadgeColor.Text = "#E11D48" })

$BtnClearForm.Add_Click({
    $script:IsEditingExisting = $false
    $TxtFormTitle.Text = T "FormTitleNew"
    $InputInstId.Text = ""
    $InputInstId.IsEnabled = $true
    $InputInstDisplayName.Text = ""
    $InputInstLabel.Text = ""
    $InputInstBadgeText.Text = "N1"
    $InputInstBadgeColor.Text = "#F59E0B"
})

$BtnSaveInstance.Add_Click({
    try {
        $id = $InputInstId.Text.Trim()
        $disp = $InputInstDisplayName.Text.Trim()
        $lbl = $InputInstLabel.Text.Trim()
        $bTxt = $InputInstBadgeText.Text.Trim()
        $bCol = $InputInstBadgeColor.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($id)) {
            [System.Windows.MessageBox]::Show("Instance ID is required.", "CIM", "OK", "Warning") | Out-Null
            return
        }
        if ([string]::IsNullOrWhiteSpace($disp)) { $disp = $id }

        $exists = $script:CachedInstances | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($exists) {
            Update-ClaudeInstanceMetadata -InstanceId $id -DisplayName $disp -BadgeText $bTxt -BadgeColor $bCol -AccountLabel $lbl -RecreateShortcuts $true
            Set-Status "Updated instance '$disp' and regenerated shortcuts."
        } else {
            New-ClaudeInstance -Id $id -DisplayName $disp -BadgeText $bTxt -BadgeColor $bCol -AccountLabel $lbl | Out-Null
            Set-Status "Created instance '$disp' with NTFS hardlinks and shortcuts."
        }
        Refresh-InstancesUI
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$CmbSourceInstance.Add_SelectionChanged({ Refresh-SessionLists })
$CmbTargetInstance.Add_SelectionChanged({ Refresh-SessionLists })
$TxtSessionFilter.Add_TextChanged({ Refresh-SessionLists })

$BtnSelectAllSessions.Add_Click({ $LstSourceSessions.SelectAll() })
$BtnClearSessionSelection.Add_Click({ $LstSourceSessions.UnselectAll() })

function Invoke-SessionTransfer([bool]$MoveMode) {
    try {
        $srcItem = $CmbSourceInstance.SelectedItem
        $dstItem = $CmbTargetInstance.SelectedItem
        if (-not $srcItem -or -not $dstItem) { return }
        $srcId = [string]$srcItem.Tag
        $dstId = [string]$dstItem.Tag

        $selectedIds = @()
        foreach ($sel in $LstSourceSessions.SelectedItems) {
            $selectedIds += [string]$sel.Tag
        }
        if ($selectedIds.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Select at least one session from the source list.", "CIM", "OK", "Information") | Out-Null
            return
        }

        if ($MoveMode -and ($ChkAutoBackupMove.IsChecked -eq $true)) {
            New-ClaudeBackup -Label "pre-move" | Out-Null
        }

        $res = Copy-ClaudeSessions `
            -SourceInstanceId $srcId `
            -TargetInstanceId $dstId `
            -SessionIds $selectedIds `
            -Move $MoveMode `
            -IncludeSubSessions ($ChkIncludeSubSessions.IsChecked -eq $true)

        Refresh-SessionLists
        Refresh-InstancesUI
        Refresh-UpdateAndBackupUI
        Set-Status "Transferred $($res.Transferred) session(s) from '$srcId' to '$dstId' ($($res.FoldersAuthorized) folder(s) authorized)."
        [System.Windows.MessageBox]::Show("Transferred $($res.Transferred) session(s) to $($dstItem.Content).`nAuthorized folders: $($res.FoldersAuthorized)", "CIM", "OK", "Information") | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
}

$BtnCopySessions.Add_Click({ Invoke-SessionTransfer -MoveMode $false })
$BtnMoveSessions.Add_Click({ Invoke-SessionTransfer -MoveMode $true })

$BtnEnableProto.Add_Click({
    $mode = if ($RbProtoFixed.IsChecked -eq $true) { "fixed" } else { "ask" }
    $pinId = if ($CmbProtoFixedInstance.SelectedItem) { [string]$CmbProtoFixedInstance.SelectedItem.Tag } else { "Primary" }
    Enable-ClaudeProtocolIntercept -Mode $mode -PinnedInstanceId $pinId | Out-Null
    Refresh-ProtocolUI
    Set-Status "claude:// protocol router enabled (Mode: $mode)."
})

$BtnDisableProto.Add_Click({
    Disable-ClaudeProtocolIntercept | Out-Null
    Refresh-ProtocolUI
    Set-Status "claude:// protocol restored to Windows default."
})

$BtnPasteClipboardUrl.Add_Click({
    $clip = [System.Windows.Clipboard]::GetText()
    if (-not [string]::IsNullOrWhiteSpace($clip)) {
        $TxtManualClaudeUrl.Text = $clip.Trim()
    }
})

$BtnSendManualUrl.Add_Click({
    try {
        $url = $TxtManualClaudeUrl.Text.Trim()
        $targetItem = $CmbManualUrlInstance.SelectedItem
        if (-not $targetItem) { return }
        Send-ClaudeProtocolUrl -InstanceId ([string]$targetItem.Tag) -Url $url
        Set-Status "Dispatched claude:// URI to '$($targetItem.Content)'."
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnRunConfigSync.Add_Click({
    try {
        $srcItem = $CmbSyncSrc.SelectedItem
        $dstItem = $CmbSyncDst.SelectedItem
        if (-not $srcItem -or -not $dstItem) { return }
        Sync-ClaudeInstanceConfig `
            -SourceInstanceId ([string]$srcItem.Tag) `
            -TargetInstanceId ([string]$dstItem.Tag) `
            -IncludeMcp ($ChkSyncMcp.IsChecked -eq $true) `
            -IncludeFolderPermissions ($ChkSyncPerms.IsChecked -eq $true) `
            -IncludePreferences ($ChkSyncPrefs.IsChecked -eq $true) | Out-Null
        Set-Status "Synchronized settings from '$($srcItem.Content)' to '$($dstItem.Content)'."
        [System.Windows.MessageBox]::Show("Settings cloned successfully.", "CIM", "OK", "Information") | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnApplyUpdatePolicy.Add_Click({
    $mode = if ($RbUpdateDisabled.IsChecked -eq $true) {
        "Disabled"
    } elseif ($RbUpdateDefault.IsChecked -eq $true) {
        "Default"
    } else {
        "ManualRestart"
    }
    Set-ClaudeUpdatePolicy -Mode $mode | Out-Null
    Refresh-UpdateAndBackupUI
    Set-Status "Applied update policy '$mode' and enforced 1p mode across all instances."
})

$BtnCreateBackup.Add_Click({
    try {
        $lbl = $TxtBackupLabel.Text.Trim()
        $zip = New-ClaudeBackup -Label $lbl
        Refresh-UpdateAndBackupUI
        Set-Status "Backup created: $zip"
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnRestoreBackup.Add_Click({
    $sel = $LstBackups.SelectedItem
    if (-not $sel -or -not $sel.Tag) {
        [System.Windows.MessageBox]::Show("Select a backup archive from the list.", "CIM", "OK", "Information") | Out-Null
        return
    }
    $confirm = [System.Windows.MessageBox]::Show(
        "Restore selected backup?`n$($sel.Content)",
        "CIM",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        Restore-ClaudeBackup -ZipPath ([string]$sel.Tag) | Out-Null
        Refresh-InstancesUI
        Refresh-SessionLists
        Set-Status "Backup restored successfully."
    }
})

$BtnOpenBackupsFolder.Add_Click({
    if (Test-Path $script:CIMBackupsDir) {
        Start-Process "explorer.exe" -ArgumentList "`"$script:CIMBackupsDir`""
    }
})

Apply-Localization
Refresh-InstancesUI
Refresh-SessionLists
Refresh-ProtocolUI
Refresh-UpdateAndBackupUI
Set-Status (T "MsgReady")

[void]$Window.ShowDialog()
