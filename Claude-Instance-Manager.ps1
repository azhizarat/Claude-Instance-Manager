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
. (Join-Path $SrcDir "Core-Metrics.ps1")
. (Join-Path $SrcDir "Core-ProtocolRouter.ps1")
. (Join-Path $SrcDir "Core-SettingsBackup.ps1")
. (Join-Path $SrcDir "Core-AutoUpdater.ps1")

$script:I18N = @{
    "pt-BR" = @{
        Subtitle              = "v1.3.0"
        BtnRefreshAll         = "Atualizar"
        BtnCheckCimUpdate     = "Verificar Atualização do CIM"
        TabInstances          = "Instâncias"
        TabSessions           = "Sessões"
        TabMetrics            = "Métricas"
        TabProtocol           = "Roteador e Sync"
        TabSettings           = "Ajustes e Backup"
        LblInstalledInstances = "Instâncias"
        BtnSyncAllLinks       = "Reparar Hardlinks"
        FormTitleNew          = "Nova Instância"
        FormTitleEdit         = "Editar Instância"
        LblInstId             = "ID:"
        LblInstDisplayName    = "Nome:"
        LblInstLabel          = "Conta / Descrição:"
        LblInstBadgeText      = "Sigla:"
        LblInstBadgeColor     = "Cor (Hex):"
        LblQuickColors        = "Cores:"
        ColorBlue             = "Azul"
        ColorPurple           = "Roxo"
        ColorGreen            = "Verde"
        ColorAmber            = "Âmbar"
        ColorRose             = "Rosa"
        BtnSaveInstance       = "Salvar"
        BtnClearForm          = "Limpar"
        PrimaryTag            = " (Primária)"
        IsolatedTag           = ""
        StatusRunning         = "ATIVA"
        StatusStopped         = "PARADA"
        BtnOpen               = "Abrir"
        BtnStop               = "Fechar"
        BtnLogin              = "Login"
        BtnRemap              = "Vincular Sessões"
        BtnEdit               = "Editar"
        BtnFolder             = "Pasta"
        LblSrcInstance        = "Origem"
        LblFilter             = "Filtro:"
        BtnSelectAll          = "Selecionar Todos"
        BtnClearSel           = "Limpar"
        BtnViewTranscript     = "Abrir HTML / MD"
        LblTransferHeader     = "Transferência Local"
        ChkIncludeSub         = "Incluir sub-sessões"
        ChkAutoBackup         = "Backup ao mover"
        BtnCopySessions       = "Copiar ->"
        BtnMoveSessions       = "Mover ->"
        LblPortableHeader     = "Pacote (.cimpack)"
        ChkPackWorkspace      = "Incluir código-fonte"
        BtnExportPack         = "Exportar .cimpack"
        BtnImportPack         = "Importar .cimpack"
        LblDstInstance        = "Destino"
        LblDstSummary         = "Sessões no destino"
        # Tab 3: Metrics
        LblMetPeriod          = "Período:"
        LblMetFrom            = "De:"
        LblMetTo              = "Até:"
        LblMetInstance        = "Instância:"
        LblMetProject         = "Projeto:"
        LblMetModel           = "Modelo:"
        LblMetCurrency        = "Moeda:"
        ChkMetSubagents       = "Subagentes"
        BtnMetApply           = "Filtrar"
        BtnMetRefreshFx       = "Atualizar Câmbio"
        BtnMetExport          = "Exportar HTML/CSV"
        BtnMetPricing         = "Preços"
        Period30d             = "30 dias"
        Period7d              = "7 dias"
        PeriodToday           = "Hoje"
        PeriodMonth           = "Este mês"
        PeriodAll             = "Tudo"
        PeriodCustom          = "Personalizado"
        FilterAllInstances    = "Todas"
        FilterAllProjects     = "Todos"
        FilterAllModels       = "Todos"
        KpiCostTitle          = "CUSTO"
        KpiSavingsTitle       = "ECONOMIA (CACHE)"
        KpiTokensTitle        = "TOKENS"
        KpiCodeTitle          = "CÓDIGO (+ / - LINHAS)"
        KpiTurnsTitle         = "TURNOS & TOOLS"
        SubTabByProject       = "Por Projeto"
        SubTabByModel         = "Por Modelo"
        SubTabByDay           = "Por Dia"
        SubTabByInstance      = "Por Instância"
        SubTabBySession       = "Top Sessões"
        SubTabByTool          = "Ferramentas e Código"
        # Tab 4 & 5
        LblProtoTitle         = "Protocolo claude://"
        LblProtoBehavior      = "Modo:"
        RbProtoAsk            = "Perguntar instância ao abrir link"
        RbProtoFixed          = "Usar instância fixa:"
        BtnEnableProto        = "Ativar Roteador"
        BtnDisableProto       = "Padrão do Windows"
        LblManualUrlTitle     = "Abrir URI claude://"
        BtnPaste              = "Colar"
        LblSendTo             = "Instância:"
        BtnSendUrl            = "Abrir"
        LblSyncTitle          = "Clonar Configurações"
        LblSyncSrc            = "Origem:"
        LblSyncDst            = "Destino:"
        ChkSyncMcp            = "Servidores MCP (mcpServers)"
        ChkSyncPerms          = "Permissões de Pastas"
        ChkSyncPrefs          = "Preferências Gerais"
        BtnRunSync            = "Clonar"
        LblUpdateTitle        = "Atualizações"
        RbUpdateManual        = "Baixar sem reiniciar automaticamente"
        RbUpdateDisabled      = "Desativar atualizações"
        RbUpdateDefault       = "Padrão (reinício automático)"
        BtnApplyUpdate        = "Aplicar"
        LblBackupTitle        = "Backups (.zip)"
        BtnCreateBackup       = "Criar Backup"
        LblAvailableBackups   = "Arquivos:"
        BtnRestoreBackup      = "Restaurar"
        BtnOpenBackupDir      = "Pasta"
        ProtoActiveHeader     = "claude:// Ativo"
        ProtoDefaultHeader    = "claude:// Padrão"
        ProtoStatusActive     = "Ativo"
        ProtoStatusDefault    = "Padrão do Windows"
        ProtoArmedPrefix      = "Alvo de login: "
        ProtoArmedNone        = "Alvo de login: —"
        UpdateModeManual      = "Reinício Manual"
        UpdateModeDisabled    = "Desativadas"
        UpdateModeDefault     = "Automático"
        MsgReady              = "Pronto."
    }
    "en-US" = @{
        Subtitle              = "v1.3.0"
        BtnRefreshAll         = "Refresh"
        BtnCheckCimUpdate     = "Check CIM Update"
        TabInstances          = "Instances"
        TabSessions           = "Sessions"
        TabMetrics            = "Metrics"
        TabProtocol           = "Router & Sync"
        TabSettings           = "Settings & Backup"
        LblInstalledInstances = "Instances"
        BtnSyncAllLinks       = "Repair Hardlinks"
        FormTitleNew          = "New Instance"
        FormTitleEdit         = "Edit Instance"
        LblInstId             = "ID:"
        LblInstDisplayName    = "Name:"
        LblInstLabel          = "Account / Description:"
        LblInstBadgeText      = "Badge:"
        LblInstBadgeColor     = "Color (Hex):"
        LblQuickColors        = "Colors:"
        ColorBlue             = "Blue"
        ColorPurple           = "Purple"
        ColorGreen            = "Green"
        ColorAmber            = "Amber"
        ColorRose             = "Rose"
        BtnSaveInstance       = "Save"
        BtnClearForm          = "Clear"
        PrimaryTag            = " (Primary)"
        IsolatedTag           = ""
        StatusRunning         = "RUNNING"
        StatusStopped         = "STOPPED"
        BtnOpen               = "Start"
        BtnStop               = "Stop"
        BtnLogin              = "Login"
        BtnRemap              = "Bind Sessions"
        BtnEdit               = "Edit"
        BtnFolder             = "Folder"
        LblSrcInstance        = "Source"
        LblFilter             = "Filter:"
        BtnSelectAll          = "Select All"
        BtnClearSel           = "Clear"
        BtnViewTranscript     = "Open HTML / MD"
        LblTransferHeader     = "Local Transfer"
        ChkIncludeSub         = "Include sub-sessions"
        ChkAutoBackup         = "Backup on move"
        BtnCopySessions       = "Copy ->"
        BtnMoveSessions       = "Move ->"
        LblPortableHeader     = "Package (.cimpack)"
        ChkPackWorkspace      = "Include source code"
        BtnExportPack         = "Export .cimpack"
        BtnImportPack         = "Import .cimpack"
        LblDstInstance        = "Target"
        LblDstSummary         = "Target sessions"
        # Tab 3: Metrics
        LblMetPeriod          = "Period:"
        LblMetFrom            = "From:"
        LblMetTo              = "To:"
        LblMetInstance        = "Instance:"
        LblMetProject         = "Project:"
        LblMetModel           = "Model:"
        LblMetCurrency        = "Currency:"
        ChkMetSubagents       = "Subagents"
        BtnMetApply           = "Filter"
        BtnMetRefreshFx       = "Refresh FX"
        BtnMetExport          = "Export HTML/CSV"
        BtnMetPricing         = "Rates"
        Period30d             = "30 days"
        Period7d              = "7 days"
        PeriodToday           = "Today"
        PeriodMonth           = "This month"
        PeriodAll             = "All"
        PeriodCustom          = "Custom"
        FilterAllInstances    = "All"
        FilterAllProjects     = "All"
        FilterAllModels       = "All"
        KpiCostTitle          = "COST"
        KpiSavingsTitle       = "CACHE SAVINGS"
        KpiTokensTitle        = "TOKENS"
        KpiCodeTitle          = "CODE (+ / - LINES)"
        KpiTurnsTitle         = "TURNS & TOOLS"
        SubTabByProject       = "By Project"
        SubTabByModel         = "By Model"
        SubTabByDay           = "By Day"
        SubTabByInstance      = "By Instance"
        SubTabBySession       = "Top Sessions"
        SubTabByTool          = "Tools & Code"
        # Tab 4 & 5
        LblProtoTitle         = "claude:// Protocol"
        LblProtoBehavior      = "Mode:"
        RbProtoAsk            = "Ask target instance on link open"
        RbProtoFixed          = "Fixed instance:"
        BtnEnableProto        = "Enable Router"
        BtnDisableProto       = "Windows Default"
        LblManualUrlTitle     = "Open claude:// URI"
        BtnPaste              = "Paste"
        LblSendTo             = "Instance:"
        BtnSendUrl            = "Open"
        LblSyncTitle          = "Clone Settings"
        LblSyncSrc            = "Source:"
        LblSyncDst            = "Target:"
        ChkSyncMcp            = "MCP Servers (mcpServers)"
        ChkSyncPerms          = "Folder Permissions"
        ChkSyncPrefs          = "General Preferences"
        BtnRunSync            = "Clone"
        LblUpdateTitle        = "Updates"
        RbUpdateManual        = "Download without automatic restart"
        RbUpdateDisabled      = "Disable updates"
        RbUpdateDefault       = "Default (automatic restart)"
        BtnApplyUpdate        = "Apply"
        LblBackupTitle        = "Backups (.zip)"
        BtnCreateBackup       = "Create Backup"
        LblAvailableBackups   = "Archives:"
        BtnRestoreBackup      = "Restore"
        BtnOpenBackupDir      = "Folder"
        ProtoActiveHeader     = "claude:// Active"
        ProtoDefaultHeader    = "claude:// Default"
        ProtoStatusActive     = "Active"
        ProtoStatusDefault    = "Windows Default"
        ProtoArmedPrefix      = "Login target: "
        ProtoArmedNone        = "Login target: —"
        UpdateModeManual      = "Manual Restart"
        UpdateModeDisabled    = "Disabled"
        UpdateModeDefault     = "Automatic"
        MsgReady              = "Ready."
    }
}

$initState = Get-CIMState
$script:CurrentLang = if ($initState.language -and $script:I18N.ContainsKey($initState.language)) { [string]$initState.language } else { "pt-BR" }
$script:IsEditingExisting = $false
$script:MetricsInitialized = $false
$script:CurrentMetricsReport = $null
$script:SuppressMetricsEvents = $false

function T([string]$Key) {
    $dict = $script:I18N[$script:CurrentLang]
    if ($dict -and $dict.ContainsKey($Key)) { return $dict[$Key] }
    return $Key
}

[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Instance Manager"
        Width="1200" Height="780" MinWidth="1000" MinHeight="640"
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

        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#09090B"/>
            <Setter Property="Foreground" Value="#F4F4F5"/>
            <Setter Property="BorderBrush" Value="#27272A"/>
            <Setter Property="RowBackground" Value="#141418"/>
            <Setter Property="AlternatingRowBackground" Value="#18181B"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#27272A"/>
            <Setter Property="VerticalGridLinesBrush" Value="#27272A"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="AutoGenerateColumns" Value="True"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>

        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#27272A"/>
            <Setter Property="Foreground" Value="#E4E4E7"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
        </Style>

        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#18181B"/>
            <Setter Property="Foreground" Value="#A1A1AA"/>
            <Setter Property="Padding" Value="16,9"/>
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

    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="14,10" Margin="0,0,0,12">
            <DockPanel LastChildFill="False">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                    <Border Width="32" Height="32" CornerRadius="7" Background="#D97757" Margin="0,0,10,0">
                        <TextBlock Text="CIM" FontSize="13" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <TextBlock Text="Claude Instance Manager" FontSize="16" FontWeight="Bold" Foreground="#F4F4F5" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <TextBlock x:Name="LblSubtitle" Text="v1.2.1" FontSize="12" Foreground="#71717A" VerticalAlignment="Center"/>
                </StackPanel>

                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                    <Button x:Name="BtnHeaderSelfUpdate" Content="Update Available" Visibility="Collapsed" Background="#059669" BorderBrush="#10B981" Foreground="White" Padding="10,5" Margin="0,0,8,0"/>
                    <ComboBox x:Name="CmbLanguage" Width="120" Height="28" Margin="0,0,8,0" VerticalContentAlignment="Center">
                        <ComboBoxItem Content="Português (BR)" Tag="pt-BR"/>
                        <ComboBoxItem Content="English (US)" Tag="en-US"/>
                    </ComboBox>
                    <Border x:Name="BadgeProtoHeader" Background="#27272A" CornerRadius="6" Padding="10,5" Margin="0,0,8,0">
                        <TextBlock x:Name="TxtProtoHeader" Text="claude://" FontSize="12" Foreground="#E4E4E7"/>
                    </Border>
                    <Button x:Name="BtnRefreshAll" Content="Refresh" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="12,5"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- Main Tabs -->
        <TabControl x:Name="MainTabControl" Grid.Row="1" Background="#141418" BorderBrush="#27272A" BorderThickness="1" Padding="14">

            <!-- TAB 1: INSTANCES -->
            <TabItem x:Name="TabInstances" Header="Instances">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="2.3*"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <DockPanel Grid.Column="0" Margin="0,0,14,0">
                        <DockPanel DockPanel.Dock="Top" LastChildFill="False" Margin="0,0,0,10">
                            <TextBlock x:Name="LblInstalledInstances" Text="" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" DockPanel.Dock="Left"/>
                            <Button x:Name="BtnSyncAllLinks" Content="" DockPanel.Dock="Right" Padding="10,5"/>
                        </DockPanel>
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="InstancesContainer" />
                        </ScrollViewer>
                    </DockPanel>

                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <StackPanel>
                            <TextBlock x:Name="TxtFormTitle" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,12"/>

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

                            <Button x:Name="BtnSaveInstance" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="12,8" Margin="0,0,0,8"/>
                            <Button x:Name="BtnClearForm" Content="" Padding="10,6"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 2: SESSIONS & PORTABLE PACK (.cimpack) -->
            <TabItem x:Name="TabSessions" Header="Sessions">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.2*"/>
                        <ColumnDefinition Width="230"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="14">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblSrcInstance" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,6"/>
                                <ComboBox x:Name="CmbSourceInstance" Height="30" Margin="0,0,0,8"/>
                                <DockPanel>
                                    <TextBlock x:Name="LblFilter" Text="" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                    <TextBox x:Name="TxtSessionFilter" />
                                </DockPanel>
                                <WrapPanel Margin="0,8,0,0">
                                    <Button x:Name="BtnSelectAllSessions" Content="" Padding="8,4" Margin="0,0,6,4" FontSize="11"/>
                                    <Button x:Name="BtnClearSessionSelection" Content="" Padding="8,4" Margin="0,0,6,4" FontSize="11"/>
                                    <Button x:Name="BtnViewTranscript" Content="" Background="#065F46" BorderBrush="#059669" Foreground="White" Padding="8,4" Margin="0,0,0,4" FontSize="11"/>
                                </WrapPanel>
                            </StackPanel>

                            <ListBox x:Name="LstSourceSessions" SelectionMode="Extended" Background="#09090B" Foreground="#F4F4F5" BorderBrush="#27272A" FontSize="12"/>
                        </DockPanel>
                    </Border>

                    <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="12,0">
                        <Border Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,12">
                            <StackPanel>
                                <TextBlock x:Name="LblTransferHeader" Text="" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" Margin="0,0,0,8"/>
                                <CheckBox x:Name="ChkIncludeSubSessions" Content="" IsChecked="True" FontSize="11"/>
                                <CheckBox x:Name="ChkAutoBackupMove" Content="" IsChecked="True" FontSize="11" Margin="0,4,0,10"/>

                                <Button x:Name="BtnCopySessions" Content="" Background="#2563EB" BorderBrush="#2563EB" Foreground="White" Padding="10,8" Margin="0,0,0,8"/>
                                <Button x:Name="BtnMoveSessions" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="10,8"/>
                            </StackPanel>
                        </Border>

                        <Border Background="#18181B" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12">
                            <StackPanel>
                                <TextBlock x:Name="LblPortableHeader" Text="" FontWeight="Bold" FontSize="13" HorizontalAlignment="Center" Foreground="#34D399" Margin="0,0,0,8"/>
                                <CheckBox x:Name="ChkPackWorkspace" Content="" IsChecked="False" FontSize="11" Margin="0,0,0,10"/>

                                <Button x:Name="BtnExportPack" Content="" Background="#059669" BorderBrush="#10B981" Foreground="White" Padding="10,8" Margin="0,0,0,8"/>
                                <Button x:Name="BtnImportPack" Content="" Background="#7C3AED" BorderBrush="#8B5CF6" Foreground="White" Padding="10,8"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>

                    <Border Grid.Column="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="14">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblDstInstance" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,6"/>
                                <ComboBox x:Name="CmbTargetInstance" Height="30" Margin="0,0,0,8"/>
                                <TextBlock x:Name="TxtTargetSummary" Text="" Foreground="#A1A1AA" FontSize="12"/>
                            </StackPanel>
                            <ListBox x:Name="LstTargetSessions" Background="#09090B" Foreground="#A1A1AA" BorderBrush="#27272A" FontSize="12"/>
                        </DockPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 3: METRICS -->
            <TabItem x:Name="TabMetrics" Header="Metrics">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Filter Bar -->
                    <Border Grid.Row="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="12,10" Margin="0,0,0,12">
                        <WrapPanel VerticalAlignment="Center">
                            <TextBlock x:Name="LblMetPeriod" Text="Period:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,6,4"/>
                            <ComboBox x:Name="CmbMetricsPeriod" Width="125" Height="28" Margin="0,0,10,4" VerticalContentAlignment="Center">
                                <ComboBoxItem x:Name="CiPeriod30d" Content="30 days" Tag="30d" IsSelected="True"/>
                                <ComboBoxItem x:Name="CiPeriod7d" Content="7 days" Tag="7d"/>
                                <ComboBoxItem x:Name="CiPeriodToday" Content="Today" Tag="today"/>
                                <ComboBoxItem x:Name="CiPeriodMonth" Content="This month" Tag="month"/>
                                <ComboBoxItem x:Name="CiPeriodAll" Content="All" Tag="all"/>
                                <ComboBoxItem x:Name="CiPeriodCustom" Content="Custom" Tag="custom"/>
                            </ComboBox>

                            <TextBlock x:Name="LblMetFrom" Text="From:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <TextBox x:Name="TxtMetricsStartDate" Width="88" Height="28" Margin="0,0,8,4" ToolTip="yyyy-MM-dd"/>

                            <TextBlock x:Name="LblMetTo" Text="To:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <TextBox x:Name="TxtMetricsEndDate" Width="88" Height="28" Margin="0,0,10,4" ToolTip="yyyy-MM-dd"/>

                            <TextBlock x:Name="LblMetInstance" Text="Instance:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <ComboBox x:Name="CmbMetricsInstance" Width="125" Height="28" Margin="0,0,10,4" VerticalContentAlignment="Center"/>

                            <TextBlock x:Name="LblMetProject" Text="Project:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <ComboBox x:Name="CmbMetricsProject" Width="140" Height="28" Margin="0,0,10,4" VerticalContentAlignment="Center"/>

                            <TextBlock x:Name="LblMetModel" Text="Model:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <ComboBox x:Name="CmbMetricsModel" Width="135" Height="28" Margin="0,0,10,4" VerticalContentAlignment="Center"/>

                            <TextBlock x:Name="LblMetCurrency" Text="Currency:" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="0,0,4,4"/>
                            <ComboBox x:Name="CmbMetricsCurrency" Width="105" Height="28" Margin="0,0,10,4" VerticalContentAlignment="Center">
                                <ComboBoxItem Content="USD ($)" Tag="USD" IsSelected="True"/>
                                <ComboBoxItem Content="BRL (R$)" Tag="BRL"/>
                                <ComboBoxItem Content="EUR (€)" Tag="EUR"/>
                                <ComboBoxItem Content="GBP (£)" Tag="GBP"/>
                                <ComboBoxItem Content="CAD (CA$)" Tag="CAD"/>
                                <ComboBoxItem Content="AUD (A$)" Tag="AUD"/>
                                <ComboBoxItem Content="JPY (¥)" Tag="JPY"/>
                                <ComboBoxItem Content="CHF (Fr)" Tag="CHF"/>
                                <ComboBoxItem Content="MXN (MX$)" Tag="MXN"/>
                            </ComboBox>

                            <CheckBox x:Name="ChkMetricsSubagents" Content="Subagents" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,4"/>

                            <Button x:Name="BtnApplyMetrics" Content="Filter" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="10,5" Margin="0,0,6,4"/>
                            <Button x:Name="BtnRefreshFx" Content="Refresh FX" Padding="10,5" Margin="0,0,6,4"/>
                            <Button x:Name="BtnExportMetrics" Content="Export HTML/CSV" Background="#065F46" BorderBrush="#059669" Foreground="White" Padding="10,5" Margin="0,0,6,4"/>
                            <Button x:Name="BtnEditPricing" Content="Rates" Padding="10,5" Margin="0,0,0,4"/>
                        </WrapPanel>
                    </Border>

                    <!-- KPI Cards -->
                    <Grid Grid.Row="1" Margin="0,0,0,12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Background="#18181B" BorderBrush="#D97757" BorderThickness="3,1,1,1" CornerRadius="10" Padding="12,10" Margin="0,0,8,0">
                            <StackPanel>
                                <TextBlock x:Name="LblKpiCost" Text="COST" Foreground="#A1A1AA" FontSize="11" FontWeight="Bold"/>
                                <TextBlock x:Name="TxtKpiCostVal" Text="$0.00" Foreground="#D97757" FontSize="20" FontWeight="Bold" Margin="0,4,0,2"/>
                                <TextBlock x:Name="TxtKpiCostSub" Text="—" Foreground="#71717A" FontSize="11"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="1" Background="#18181B" BorderBrush="#10B981" BorderThickness="3,1,1,1" CornerRadius="10" Padding="12,10" Margin="0,0,8,0">
                            <StackPanel>
                                <TextBlock x:Name="LblKpiSavings" Text="CACHE SAVINGS" Foreground="#A1A1AA" FontSize="11" FontWeight="Bold"/>
                                <TextBlock x:Name="TxtKpiSavingsVal" Text="$0.00" Foreground="#10B981" FontSize="20" FontWeight="Bold" Margin="0,4,0,2"/>
                                <TextBlock x:Name="TxtKpiSavingsSub" Text="—" Foreground="#71717A" FontSize="11"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="2" Background="#18181B" BorderBrush="#2563EB" BorderThickness="3,1,1,1" CornerRadius="10" Padding="12,10" Margin="0,0,8,0">
                            <StackPanel>
                                <TextBlock x:Name="LblKpiTokens" Text="TOKENS" Foreground="#A1A1AA" FontSize="11" FontWeight="Bold"/>
                                <TextBlock x:Name="TxtKpiTokensVal" Text="0" Foreground="#60A5FA" FontSize="20" FontWeight="Bold" Margin="0,4,0,2"/>
                                <TextBlock x:Name="TxtKpiTokensSub" Text="—" Foreground="#71717A" FontSize="11"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="3" Background="#18181B" BorderBrush="#059669" BorderThickness="3,1,1,1" CornerRadius="10" Padding="12,10" Margin="0,0,8,0">
                            <StackPanel>
                                <TextBlock x:Name="LblKpiCode" Text="CODE (+ / - LINES)" Foreground="#A1A1AA" FontSize="11" FontWeight="Bold"/>
                                <TextBlock x:Name="TxtKpiCodeVal" Text="+0 / -0" Foreground="#34D399" FontSize="19" FontWeight="Bold" Margin="0,4,0,2"/>
                                <TextBlock x:Name="TxtKpiCodeSub" Text="—" Foreground="#71717A" FontSize="11"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="4" Background="#18181B" BorderBrush="#7C3AED" BorderThickness="3,1,1,1" CornerRadius="10" Padding="12,10">
                            <StackPanel>
                                <TextBlock x:Name="LblKpiTurns" Text="TURNS &amp; TOOLS" Foreground="#A1A1AA" FontSize="11" FontWeight="Bold"/>
                                <TextBlock x:Name="TxtKpiTurnsVal" Text="0" Foreground="#F4F4F5" FontSize="20" FontWeight="Bold" Margin="0,4,0,2"/>
                                <TextBlock x:Name="TxtKpiTurnsSub" Text="—" Foreground="#71717A" FontSize="11"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <!-- Breakdown Sub-Tabs -->
                    <TabControl Grid.Row="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" Padding="8">
                        <TabItem x:Name="SubTabByProject" Header="By Project">
                            <DataGrid x:Name="DgMetricsProjects" />
                        </TabItem>
                        <TabItem x:Name="SubTabByModel" Header="By Model">
                            <DataGrid x:Name="DgMetricsModels" />
                        </TabItem>
                        <TabItem x:Name="SubTabByDay" Header="By Day">
                            <DataGrid x:Name="DgMetricsDays" FontFamily="Consolas, Segoe UI" />
                        </TabItem>
                        <TabItem x:Name="SubTabByInstance" Header="By Instance">
                            <DataGrid x:Name="DgMetricsInstances" />
                        </TabItem>
                        <TabItem x:Name="SubTabBySession" Header="Top Sessions">
                            <DataGrid x:Name="DgMetricsSessions" />
                        </TabItem>
                        <TabItem x:Name="SubTabByTool" Header="Tools &amp; Code">
                            <DataGrid x:Name="DgMetricsTools" />
                        </TabItem>
                    </TabControl>
                </Grid>
            </TabItem>

            <!-- TAB 4: PROTOCOL ROUTER & CONFIG SYNC -->
            <TabItem x:Name="TabProtocol" Header="Protocol">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1.15*"/>
                        <ColumnDefinition Width="1*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock x:Name="LblProtoTitle" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>

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

                            <WrapPanel Margin="0,0,0,16">
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
                                <ComboBox x:Name="CmbManualUrlInstance" Width="180" Height="30" Margin="0,0,8,0"/>
                                <Button x:Name="BtnSendManualUrl" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White"/>
                            </DockPanel>
                        </StackPanel>
                    </Border>

                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <StackPanel>
                            <TextBlock x:Name="LblSyncTitle" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,12"/>

                            <TextBlock x:Name="LblSyncSrc" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbSyncSrc" Height="30" Margin="0,0,0,12"/>

                            <TextBlock x:Name="LblSyncDst" Text="" Foreground="#A1A1AA" FontSize="12" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbSyncDst" Height="30" Margin="0,0,0,14"/>

                            <CheckBox x:Name="ChkSyncMcp" Content="" IsChecked="True"/>
                            <CheckBox x:Name="ChkSyncPerms" Content="" IsChecked="True"/>
                            <CheckBox x:Name="ChkSyncPrefs" Content="" IsChecked="True" Margin="0,4,0,16"/>

                            <Button x:Name="BtnRunConfigSync" Content="" Background="#2563EB" BorderBrush="#2563EB" Foreground="White" Padding="12,8"/>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 5: UPDATES & BACKUPS -->
            <TabItem x:Name="TabSettings" Header="Settings">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1*"/>
                        <ColumnDefinition Width="1.1*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock x:Name="LblUpdateTitle" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>

                            <Border Background="#09090B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,14">
                                <StackPanel>
                                    <TextBlock x:Name="TxtCurrentUpdatePolicy" Text="" FontWeight="Bold" Foreground="#10B981" FontSize="13"/>
                                    <TextBlock x:Name="TxtCurrentDeploymentMode" Text="Mode: 1p" Foreground="#A1A1AA" FontSize="11" Margin="0,4,0,0"/>
                                </StackPanel>
                            </Border>

                            <RadioButton x:Name="RbUpdateManualRestart" Content="" IsChecked="True"/>
                            <RadioButton x:Name="RbUpdateDisabled" Content=""/>
                            <RadioButton x:Name="RbUpdateDefault" Content=""/>

                            <Button x:Name="BtnApplyUpdatePolicy" Content="" Background="#D97757" BorderBrush="#D97757" Foreground="White" Padding="12,8" Margin="0,14,0,14"/>
                            <Separator Background="#27272A" Margin="0,4,0,14"/>
                            <Button x:Name="BtnCheckCimUpdate" Content="Check CIM Update" Background="#2563EB" BorderBrush="#2563EB" Foreground="White" Padding="12,8"/>
                        </StackPanel>
                    </Border>

                    <Border Grid.Column="1" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="10" Padding="16">
                        <DockPanel>
                            <StackPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                                <TextBlock x:Name="LblBackupTitle" Text="" FontSize="14" FontWeight="Bold" Margin="0,0,0,10"/>
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
        <Border Grid.Row="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="1" CornerRadius="8" Padding="12,7" Margin="0,10,0,0">
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
$MainTabControl        = $Window.FindName("MainTabControl")
$TxtStatusBar          = $Window.FindName("TxtStatusBar")
$BadgeProtoHeader      = $Window.FindName("BadgeProtoHeader")
$TxtProtoHeader        = $Window.FindName("TxtProtoHeader")
$BtnRefreshAll         = $Window.FindName("BtnRefreshAll")
$BtnHeaderSelfUpdate   = $Window.FindName("BtnHeaderSelfUpdate")
$BtnCheckCimUpdate     = $Window.FindName("BtnCheckCimUpdate")
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
$BtnViewTranscript     = $Window.FindName("BtnViewTranscript")
$LstSourceSessions     = $Window.FindName("LstSourceSessions")
$LstTargetSessions     = $Window.FindName("LstTargetSessions")
$TxtTargetSummary      = $Window.FindName("TxtTargetSummary")
$ChkIncludeSubSessions = $Window.FindName("ChkIncludeSubSessions")
$ChkAutoBackupMove     = $Window.FindName("ChkAutoBackupMove")
$BtnCopySessions       = $Window.FindName("BtnCopySessions")
$BtnMoveSessions       = $Window.FindName("BtnMoveSessions")
$ChkPackWorkspace      = $Window.FindName("ChkPackWorkspace")
$BtnExportPack         = $Window.FindName("BtnExportPack")
$BtnImportPack         = $Window.FindName("BtnImportPack")

# Tab 3: Metrics
$TabMetrics            = $Window.FindName("TabMetrics")
$CmbMetricsPeriod      = $Window.FindName("CmbMetricsPeriod")
$TxtMetricsStartDate   = $Window.FindName("TxtMetricsStartDate")
$TxtMetricsEndDate     = $Window.FindName("TxtMetricsEndDate")
$CmbMetricsInstance    = $Window.FindName("CmbMetricsInstance")
$CmbMetricsProject     = $Window.FindName("CmbMetricsProject")
$CmbMetricsModel       = $Window.FindName("CmbMetricsModel")
$CmbMetricsCurrency    = $Window.FindName("CmbMetricsCurrency")
$ChkMetricsSubagents   = $Window.FindName("ChkMetricsSubagents")
$BtnApplyMetrics       = $Window.FindName("BtnApplyMetrics")
$BtnRefreshFx          = $Window.FindName("BtnRefreshFx")
$BtnExportMetrics      = $Window.FindName("BtnExportMetrics")
$BtnEditPricing        = $Window.FindName("BtnEditPricing")
$TxtKpiCostVal         = $Window.FindName("TxtKpiCostVal")
$TxtKpiCostSub         = $Window.FindName("TxtKpiCostSub")
$TxtKpiSavingsVal      = $Window.FindName("TxtKpiSavingsVal")
$TxtKpiSavingsSub      = $Window.FindName("TxtKpiSavingsSub")
$TxtKpiTokensVal       = $Window.FindName("TxtKpiTokensVal")
$TxtKpiTokensSub       = $Window.FindName("TxtKpiTokensSub")
$TxtKpiCodeVal         = $Window.FindName("TxtKpiCodeVal")
$TxtKpiCodeSub         = $Window.FindName("TxtKpiCodeSub")
$TxtKpiTurnsVal        = $Window.FindName("TxtKpiTurnsVal")
$TxtKpiTurnsSub        = $Window.FindName("TxtKpiTurnsSub")
$DgMetricsProjects     = $Window.FindName("DgMetricsProjects")
$DgMetricsModels       = $Window.FindName("DgMetricsModels")
$DgMetricsDays         = $Window.FindName("DgMetricsDays")
$DgMetricsInstances    = $Window.FindName("DgMetricsInstances")
$DgMetricsSessions     = $Window.FindName("DgMetricsSessions")
$DgMetricsTools        = $Window.FindName("DgMetricsTools")

# Tab 4
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

# Tab 5
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
$script:SuppressComboEvents = $false

$TxtMetricsStartDate.Text = (Get-Date).AddDays(-29).ToString("yyyy-MM-dd")
$TxtMetricsEndDate.Text   = (Get-Date).ToString("yyyy-MM-dd")

function Set-Status([string]$Message) {
    $TxtStatusBar.Text = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

function Apply-Localization {
    $Window.FindName("LblSubtitle").Text          = T "Subtitle"
    $BtnRefreshAll.Content                        = T "BtnRefreshAll"
    $Window.FindName("TabInstances").Header       = T "TabInstances"
    $Window.FindName("TabSessions").Header        = T "TabSessions"
    $Window.FindName("TabMetrics").Header         = T "TabMetrics"
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
    $Window.FindName("LblSrcInstance").Text       = T "LblSrcInstance"
    $Window.FindName("LblFilter").Text            = T "LblFilter"
    $BtnSelectAllSessions.Content                 = T "BtnSelectAll"
    $BtnClearSessionSelection.Content             = T "BtnClearSel"
    $BtnViewTranscript.Content                    = T "BtnViewTranscript"
    $Window.FindName("LblTransferHeader").Text    = T "LblTransferHeader"
    $ChkIncludeSubSessions.Content                = T "ChkIncludeSub"
    $ChkAutoBackupMove.Content                    = T "ChkAutoBackup"
    $BtnCopySessions.Content                      = T "BtnCopySessions"
    $BtnMoveSessions.Content                      = T "BtnMoveSessions"
    $Window.FindName("LblPortableHeader").Text    = T "LblPortableHeader"
    $ChkPackWorkspace.Content                     = T "ChkPackWorkspace"
    $BtnExportPack.Content                        = T "BtnExportPack"
    $BtnImportPack.Content                        = T "BtnImportPack"
    $Window.FindName("LblDstInstance").Text       = T "LblDstInstance"
    # Metrics Tab
    $Window.FindName("LblMetPeriod").Text         = T "LblMetPeriod"
    $Window.FindName("LblMetFrom").Text           = T "LblMetFrom"
    $Window.FindName("LblMetTo").Text             = T "LblMetTo"
    $Window.FindName("LblMetInstance").Text       = T "LblMetInstance"
    $Window.FindName("LblMetProject").Text        = T "LblMetProject"
    $Window.FindName("LblMetModel").Text          = T "LblMetModel"
    $Window.FindName("LblMetCurrency").Text       = T "LblMetCurrency"
    $ChkMetricsSubagents.Content                  = T "ChkMetSubagents"
    $BtnApplyMetrics.Content                      = T "BtnMetApply"
    $BtnRefreshFx.Content                         = T "BtnMetRefreshFx"
    $BtnExportMetrics.Content                     = T "BtnMetExport"
    $BtnEditPricing.Content                       = T "BtnMetPricing"
    $Window.FindName("CiPeriod30d").Content       = T "Period30d"
    $Window.FindName("CiPeriod7d").Content        = T "Period7d"
    $Window.FindName("CiPeriodToday").Content     = T "PeriodToday"
    $Window.FindName("CiPeriodMonth").Content     = T "PeriodMonth"
    $Window.FindName("CiPeriodAll").Content       = T "PeriodAll"
    $Window.FindName("CiPeriodCustom").Content    = T "PeriodCustom"
    $Window.FindName("LblKpiCost").Text           = T "KpiCostTitle"
    $Window.FindName("LblKpiSavings").Text        = T "KpiSavingsTitle"
    $Window.FindName("LblKpiTokens").Text         = T "KpiTokensTitle"
    $Window.FindName("LblKpiCode").Text           = T "KpiCodeTitle"
    $Window.FindName("LblKpiTurns").Text          = T "KpiTurnsTitle"
    $Window.FindName("SubTabByProject").Header    = T "SubTabByProject"
    $Window.FindName("SubTabByModel").Header      = T "SubTabByModel"
    $Window.FindName("SubTabByDay").Header        = T "SubTabByDay"
    $Window.FindName("SubTabByInstance").Header   = T "SubTabByInstance"
    $Window.FindName("SubTabBySession").Header    = T "SubTabBySession"
    $Window.FindName("SubTabByTool").Header       = T "SubTabByTool"
    $BtnCheckCimUpdate.Content                    = T "BtnCheckCimUpdate"
    # Tab 4 & 5
    $Window.FindName("LblProtoTitle").Text        = T "LblProtoTitle"
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
    $Window.FindName("LblSyncSrc").Text           = T "LblSyncSrc"
    $Window.FindName("LblSyncDst").Text           = T "LblSyncDst"
    $ChkSyncMcp.Content                           = T "ChkSyncMcp"
    $ChkSyncPerms.Content                         = T "ChkSyncPerms"
    $ChkSyncPrefs.Content                         = T "ChkSyncPrefs"
    $BtnRunConfigSync.Content                     = T "BtnRunSync"
    $Window.FindName("LblUpdateTitle").Text       = T "LblUpdateTitle"
    $RbUpdateManualRestart.Content                = T "RbUpdateManual"
    $RbUpdateDisabled.Content                     = T "RbUpdateDisabled"
    $RbUpdateDefault.Content                      = T "RbUpdateDefault"
    $BtnApplyUpdatePolicy.Content                 = T "BtnApplyUpdate"
    $Window.FindName("LblBackupTitle").Text       = T "LblBackupTitle"
    $BtnCreateBackup.Content                      = T "BtnCreateBackup"
    $Window.FindName("LblAvailableBackups").Text  = T "LblAvailableBackups"
    $BtnRestoreBackup.Content                     = T "BtnRestoreBackup"
    $BtnOpenBackupsFolder.Content                 = T "BtnOpenBackupDir"
}

function Initialize-MetricsFilterCombos([switch]$ForceRefresh) {
    $CmbMetricsInstance.Items.Clear()
    $allInstItem = New-Object System.Windows.Controls.ComboBoxItem
    $allInstItem.Content = T "FilterAllInstances"
    $allInstItem.Tag = "ALL"
    [void]$CmbMetricsInstance.Items.Add($allInstItem)

    foreach ($inst in $script:CachedInstances) {
        $ci = New-Object System.Windows.Controls.ComboBoxItem
        $ci.Content = "[$($inst.BadgeText)] $($inst.DisplayName)"
        $ci.Tag = $inst.Id
        [void]$CmbMetricsInstance.Items.Add($ci)
    }
    $cliItem = New-Object System.Windows.Controls.ComboBoxItem
    $cliItem.Content = "CLI / Terminal"
    $cliItem.Tag = "CLI"
    [void]$CmbMetricsInstance.Items.Add($cliItem)
    $CmbMetricsInstance.SelectedIndex = 0

    $opts = Get-ClaudeMetricsFilterOptions -ForceRefresh:$ForceRefresh

    $CmbMetricsProject.Items.Clear()
    $allProjItem = New-Object System.Windows.Controls.ComboBoxItem
    $allProjItem.Content = T "FilterAllProjects"
    $allProjItem.Tag = "ALL"
    [void]$CmbMetricsProject.Items.Add($allProjItem)
    foreach ($p in $opts.Projects) {
        $ci = New-Object System.Windows.Controls.ComboBoxItem
        $ci.Content = $p
        $ci.Tag = $p
        [void]$CmbMetricsProject.Items.Add($ci)
    }
    $CmbMetricsProject.SelectedIndex = 0

    $CmbMetricsModel.Items.Clear()
    $allModItem = New-Object System.Windows.Controls.ComboBoxItem
    $allModItem.Content = T "FilterAllModels"
    $allModItem.Tag = "ALL"
    [void]$CmbMetricsModel.Items.Add($allModItem)
    foreach ($m in $opts.Models) {
        $ci = New-Object System.Windows.Controls.ComboBoxItem
        $ci.Content = $m
        $ci.Tag = $m
        [void]$CmbMetricsModel.Items.Add($ci)
    }
    $CmbMetricsModel.SelectedIndex = 0
}

function Refresh-MetricsUI([switch]$ForceRefresh) {
    $script:SuppressMetricsEvents = $true
    try {
        if (-not $script:MetricsInitialized -or $ForceRefresh) {
            Initialize-MetricsFilterCombos -ForceRefresh:$ForceRefresh
            $script:MetricsInitialized = $true
        }
    } finally {
        $script:SuppressMetricsEvents = $false
    }

    $period = if ($CmbMetricsPeriod.SelectedItem -and $CmbMetricsPeriod.SelectedItem.Tag) { [string]$CmbMetricsPeriod.SelectedItem.Tag } else { "30d" }
    $instId = if ($CmbMetricsInstance.SelectedItem -and $CmbMetricsInstance.SelectedItem.Tag) { [string]$CmbMetricsInstance.SelectedItem.Tag } else { "ALL" }
    $proj   = if ($CmbMetricsProject.SelectedItem -and $CmbMetricsProject.SelectedItem.Tag) { [string]$CmbMetricsProject.SelectedItem.Tag } else { "ALL" }
    $mod    = if ($CmbMetricsModel.SelectedItem -and $CmbMetricsModel.SelectedItem.Tag) { [string]$CmbMetricsModel.SelectedItem.Tag } else { "ALL" }
    $curr   = if ($CmbMetricsCurrency.SelectedItem -and $CmbMetricsCurrency.SelectedItem.Tag) { [string]$CmbMetricsCurrency.SelectedItem.Tag } else { "USD" }
    $incSub = ($ChkMetricsSubagents.IsChecked -eq $true)

    $rep = Get-ClaudeMetricsReport `
        -Period $period `
        -StartDate $TxtMetricsStartDate.Text `
        -EndDate $TxtMetricsEndDate.Text `
        -InstanceId $instId `
        -ProjectName $proj `
        -Model $mod `
        -IncludeSubagents $incSub `
        -Currency $curr `
        -Language $script:CurrentLang `
        -ForceRefresh:$ForceRefresh

    $script:CurrentMetricsReport = $rep
    $s = $rep.Summary

    $Window.FindName("LblKpiCost").Text = "$(T 'KpiCostTitle') ($($s.Currency))"
    $TxtKpiCostVal.Text    = $s.TotalCostFmt
    $uncachedWord = if ($script:CurrentLang -eq "pt-BR") { "Bruto" } else { "Gross" }
    $fxHint = if ($s.Currency -ne "USD") { " | 1 USD = $($s.SpotRateFmt)" } else { "" }
    $TxtKpiCostSub.Text    = "${uncachedWord}: $($s.UncachedCostFmt)${fxHint}"
    $TxtKpiSavingsVal.Text = $s.CacheSavingsFmt
    $TxtKpiSavingsSub.Text = "Hit: $($s.CacheHitRatePct)"
    $TxtKpiTokensVal.Text  = $s.TotalTokensFmt
    $TxtKpiTokensSub.Text  = "Out: $($s.OutputTokensFmt) | Cache: $($s.CacheReadFmt)"
    $TxtKpiCodeVal.Text    = "$($s.LinesAddedFmt) / $($s.LinesRemovedFmt)"
    $TxtKpiCodeSub.Text    = "Edits: $($s.EditCountFmt) | Bash: $($s.BashCountFmt)"
    $TxtKpiTurnsVal.Text   = "$($s.TotalMessagesFmt)"
    $TxtKpiTurnsSub.Text   = "Tools: $($s.TotalToolCallsFmt) | Subagents: $($s.SubagentMessagesFmt)"

    $DgMetricsProjects.ItemsSource  = $rep.ByProject
    $DgMetricsModels.ItemsSource    = $rep.ByModel
    $DgMetricsDays.ItemsSource      = $rep.ByDay
    $DgMetricsInstances.ItemsSource = $rep.ByInstance
    $DgMetricsSessions.ItemsSource  = $rep.BySession
    $DgMetricsTools.ItemsSource     = $rep.ByTool

    Set-Status "$($s.TotalMessagesFmt) turns | $($s.LinesAddedFmt)/$($s.LinesRemovedFmt) lines | $($s.TotalTokensFmt) tokens | $($s.TotalCostFmt)"
}

function Invoke-MetricsRefreshDeferred([switch]$ForceRefresh) {
    if ($script:SuppressMetricsEvents) { return }
    $loadMsg = if ($script:CurrentLang -eq "pt-BR") { "Carregando..." } else { "Loading..." }
    Set-Status $loadMsg
    $forceFlag = [bool]$ForceRefresh
    [void]$Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [Action]{
            Refresh-MetricsUI -ForceRefresh:$forceFlag
        }
    )
}

function Refresh-ProtocolUI {
    $st = Get-ClaudeProtocolStatus
    $TxtProtoProgId.Text = "ProgID: $($st.ProgId)"
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
    $TxtCurrentDeploymentMode.Text = "Mode: $($pol.DeploymentMode)"
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

function Update-SourceSessionFilterOnly {
    $LstSourceSessions.Items.Clear()
    $filter = $TxtSessionFilter.Text.Trim()
    foreach ($s in $script:CachedSourceSessions) {
        if ($filter -and ($s.DisplayLabel -notmatch [regex]::Escape($filter)) -and ($s.Cwd -notmatch [regex]::Escape($filter))) {
            continue
        }
        $li = New-Object System.Windows.Controls.ListBoxItem
        $li.Content = $s.DisplayLabel
        $li.ToolTip = "Path: $($s.Cwd)`nSessionId: $($s.SessionId)`nCLI SessionId: $($s.CliSessionId)`nModel: $($s.Model)"
        $li.Tag = $s.SessionId
        [void]$LstSourceSessions.Items.Add($li)
    }
}

function Refresh-SessionLists {
    if ($script:SuppressComboEvents) { return }
    $srcItem = $CmbSourceInstance.SelectedItem
    $dstItem = $CmbTargetInstance.SelectedItem

    if ($srcItem -and $srcItem.Tag) {
        $script:CachedSourceSessions = @(Get-ClaudeInstanceSessions -InstanceId ([string]$srcItem.Tag))
        Update-SourceSessionFilterOnly
    } else {
        $LstSourceSessions.Items.Clear()
    }

    $LstTargetSessions.Items.Clear()
    if ($dstItem -and $dstItem.Tag) {
        $dstSessions = @(Get-ClaudeInstanceSessions -InstanceId ([string]$dstItem.Tag))
        $uiCulture = Get-CultureForLanguage -Language $script:CurrentLang
        $cntStr = ([double]$dstSessions.Count).ToString("N0", $uiCulture)
        $TxtTargetSummary.Text = "$(T 'LblDstSummary') ($cntStr):"
        foreach ($s in $dstSessions) {
            $li = New-Object System.Windows.Controls.ListBoxItem
            $li.Content = $s.DisplayLabel
            $li.Tag = $s.SessionId
            [void]$LstTargetSessions.Items.Add($li)
        }
    }
}

function Refresh-InstancesUI {
    $script:SuppressComboEvents = $true
    try {
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
            $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)

            $stack = New-Object System.Windows.Controls.StackPanel

            $topDock = New-Object System.Windows.Controls.DockPanel
            $topDock.LastChildFill = $false

            $leftHeader = New-Object System.Windows.Controls.StackPanel
            $leftHeader.Orientation = "Horizontal"
            [System.Windows.Controls.DockPanel]::SetDock($leftHeader, "Left")

            $badgeBorder = New-Object System.Windows.Controls.Border
            $badgeBorder.Width = 32
            $badgeBorder.Height = 32
            $badgeBorder.CornerRadius = New-Object System.Windows.CornerRadius(16)
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
            $titleTxt.FontSize = 14
            $titleTxt.FontWeight = "Bold"
            $titleTxt.Foreground = $BrushConv.ConvertFromString("#F4F4F5")
            [void]$titleStack.Children.Add($titleTxt)

            $subTxt = New-Object System.Windows.Controls.TextBlock
            $subTxt.Text = "$($inst.AccountLabel)  |  $($inst.Id)"
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

            $uiCulture = Get-CultureForLanguage -Language $script:CurrentLang
            $ramStr = ([double]$inst.RamMB).ToString("N1", $uiCulture)
            $sessCntStr = ([double]$inst.SessionCount).ToString("N0", $uiCulture)
            if ($inst.IsRunning) {
                $statusBorder.Background = $BrushConv.ConvertFromString("#064E3B")
                $statusTxt.Foreground = $BrushConv.ConvertFromString("#34D399")
                $statusTxt.Text = "$(T 'StatusRunning') ($($inst.ProcessCount) | $ramStr MB)"
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
            $infoTxt.Text = "Account: $($inst.AccountUuid)   |   Org: $($inst.OrgUuid)   |   Sessions: $sessCntStr   |   Dispatch: $dispLabel   |   VM: $vmLabel"
            $infoTxt.FontSize = 11
            $infoTxt.Foreground = $BrushConv.ConvertFromString("#71717A")
            $infoTxt.Margin = New-Object System.Windows.Thickness(0, 6, 0, 8)
            [void]$stack.Children.Add($infoTxt)

            $btnWrap = New-Object System.Windows.Controls.WrapPanel

            if ($inst.IsRunning) {
                $btnStop = New-Object System.Windows.Controls.Button
                $btnStop.Content = T "BtnStop"
                $btnStop.Background = $BrushConv.ConvertFromString("#7F1D1D")
                $btnStop.BorderBrush = $BrushConv.ConvertFromString("#991B1B")
                $btnStop.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
                $btnStop.Tag = $inst.Id
                $btnStop.Add_Click({
                    param($s, $e)
                    $cnt = Stop-ClaudeInstance -InstanceId ([string]$s.Tag)
                    Set-Status "Stopped '$($s.Tag)' ($cnt)."
                    Refresh-InstancesUI
                })
                [void]$btnWrap.Children.Add($btnStop)
            } else {
                $btnStart = New-Object System.Windows.Controls.Button
                $btnStart.Content = T "BtnOpen"
                $btnStart.Background = $BrushConv.ConvertFromString("#065F46")
                $btnStart.BorderBrush = $BrushConv.ConvertFromString("#059669")
                $btnStart.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
                $btnStart.Tag = $inst.Id
                $btnStart.Add_Click({
                    param($s, $e)
                    Start-ClaudeInstance -InstanceId ([string]$s.Tag)
                    Set-Status "Started '$($s.Tag)'."
                    Refresh-InstancesUI
                })
                [void]$btnWrap.Children.Add($btnStart)
            }

            $btnLogin = New-Object System.Windows.Controls.Button
            $btnLogin.Content = T "BtnLogin"
            $btnLogin.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
            $btnLogin.Tag = $inst.Id
            $btnLogin.Add_Click({
                param($s, $e)
                $id = [string]$s.Tag
                $promptMsg = if ($script:CurrentLang -eq "en-US") {
                    "Clear existing session cookies in '$id' before login?"
                } else {
                    "Limpar cookies de sessão atuais de '$id' antes do login?"
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
                Set-Status "Login target: '$id' (15 min)."
            })
            [void]$btnWrap.Children.Add($btnLogin)

            $btnRemap = New-Object System.Windows.Controls.Button
            $btnRemap.Content = T "BtnRemap"
            $btnRemap.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
            $btnRemap.Tag = $inst.Id
            $btnRemap.Add_Click({
                param($s, $e)
                $id = [string]$s.Tag
                $cnt = Repair-ClaudeInstanceSessionOwnership -InstanceId $id
                Clear-ClaudeSessionCache -InstanceId $id
                Refresh-InstancesUI
                Refresh-SessionLists
                Set-Status "Bound $cnt session(s) in '$id'."
            })
            [void]$btnWrap.Children.Add($btnRemap)

            $btnDisp = New-Object System.Windows.Controls.Button
            $btnDisp.Content = if ($inst.DispatchEnabled) { "Dispatch: ON" } else { "Dispatch: OFF" }
            $btnDisp.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
            $btnDisp.Tag = $inst
            $btnDisp.Add_Click({
                param($s, $e)
                $targetInst = $s.Tag
                $newState = -not $targetInst.DispatchEnabled
                Set-ClaudeInstanceDispatch -InstanceId $targetInst.Id -Enabled $newState | Out-Null
                Refresh-InstancesUI
                Set-Status "Dispatch: $newState ($($targetInst.DisplayName))."
            })
            [void]$btnWrap.Children.Add($btnDisp)

            $btnEdit = New-Object System.Windows.Controls.Button
            $btnEdit.Content = T "BtnEdit"
            $btnEdit.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
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
            $btnFolder.Margin = New-Object System.Windows.Thickness(0, 0, 6, 4)
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
    } finally {
        $script:SuppressComboEvents = $false
    }
}

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
        if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
        Set-Status (T "MsgReady")
    }
})

$MainTabControl.Add_SelectionChanged({
    param($sender, $e)
    if ($e.Source -eq $MainTabControl -and $MainTabControl.SelectedItem -eq $TabMetrics) {
        if (-not $script:MetricsInitialized) {
            Invoke-MetricsRefreshDeferred
        }
    }
})

$BtnRefreshAll.Add_Click({
    Clear-ClaudeSessionCache
    Refresh-InstancesUI
    Refresh-SessionLists
    Refresh-ProtocolUI
    Refresh-UpdateAndBackupUI
    if ($script:MetricsInitialized -or $MainTabControl.SelectedItem -eq $TabMetrics) {
        Invoke-MetricsRefreshDeferred -ForceRefresh
    }
    Set-Status (T "MsgReady")
})

# Tab 3 Metrics Events
$BtnApplyMetrics.Add_Click({ Invoke-MetricsRefreshDeferred })
$BtnRefreshFx.Add_Click({
    Get-ClaudeFxCache -ForceOnlineUpdate | Out-Null
    Invoke-MetricsRefreshDeferred
})
$CmbMetricsPeriod.Add_SelectionChanged({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})
$CmbMetricsInstance.Add_SelectionChanged({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})
$CmbMetricsProject.Add_SelectionChanged({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})
$CmbMetricsModel.Add_SelectionChanged({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})
$CmbMetricsCurrency.Add_SelectionChanged({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})
$ChkMetricsSubagents.Add_Click({
    if ($script:MetricsInitialized) { Invoke-MetricsRefreshDeferred }
})

$BtnExportMetrics.Add_Click({
    try {
        if (-not $script:CurrentMetricsReport) { Refresh-MetricsUI }
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Output folder"
        $fbd.ShowNewFolderButton = $true
        if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $out = Export-ClaudeMetricsReport -Report $script:CurrentMetricsReport -OutputDirectory $fbd.SelectedPath -OpenHtml
        Set-Status "Exported: $($out.HtmlPath)"
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnEditPricing.Add_Click({
    $p = Get-ClaudeModelPricingTable
    $msg = @"
USD per 1M Tokens:

Opus / Fable:
  Input: `$$($p.opus.InputPerM) | Output: `$$($p.opus.OutputPerM) | Cache Write: `$$($p.opus.CacheWritePerM) | Cache Read: `$$($p.opus.CacheReadPerM)

Sonnet:
  Input: `$$($p.sonnet.InputPerM) | Output: `$$($p.sonnet.OutputPerM) | Cache Write: `$$($p.sonnet.CacheWritePerM) | Cache Read: `$$($p.sonnet.CacheReadPerM)

Haiku:
  Input: `$$($p.haiku.InputPerM) | Output: `$$($p.haiku.OutputPerM) | Cache Write: `$$($p.haiku.CacheWritePerM) | Cache Read: `$$($p.haiku.CacheReadPerM)
"@
    [System.Windows.MessageBox]::Show($msg, "USD / 1M Tokens", "OK", "Information") | Out-Null
})

$BtnSyncAllLinks.Add_Click({
    $totalLinked = 0
    foreach ($inst in $script:CachedInstances) {
        if (-not $inst.IsPrimary) {
            $res = Sync-ClaudeInstanceLinks -TargetDir $inst.DataDir -Force
            $totalLinked += $res.LinkedCount
        }
    }
    Refresh-InstancesUI
    Set-Status "Hardlinks synced ($totalLinked)."
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
            [System.Windows.MessageBox]::Show("ID required.", "CIM", "OK", "Warning") | Out-Null
            return
        }
        if ([string]::IsNullOrWhiteSpace($disp)) { $disp = $id }

        $exists = $script:CachedInstances | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($exists) {
            Update-ClaudeInstanceMetadata -InstanceId $id -DisplayName $disp -BadgeText $bTxt -BadgeColor $bCol -AccountLabel $lbl -RecreateShortcuts $true
            Set-Status "Updated '$disp'."
        } else {
            New-ClaudeInstance -Id $id -DisplayName $disp -BadgeText $bTxt -BadgeColor $bCol -AccountLabel $lbl | Out-Null
            Set-Status "Created '$disp'."
        }
        Refresh-InstancesUI
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$CmbSourceInstance.Add_SelectionChanged({ Refresh-SessionLists })
$CmbTargetInstance.Add_SelectionChanged({ Refresh-SessionLists })
$TxtSessionFilter.Add_TextChanged({ Update-SourceSessionFilterOnly })

$BtnSelectAllSessions.Add_Click({ $LstSourceSessions.SelectAll() })
$BtnClearSessionSelection.Add_Click({ $LstSourceSessions.UnselectAll() })

$BtnViewTranscript.Add_Click({
    try {
        $srcItem = $CmbSourceInstance.SelectedItem
        if (-not $srcItem -or $LstSourceSessions.SelectedItems.Count -eq 0) { return }
        $firstSid = [string]$LstSourceSessions.SelectedItems[0].Tag
        $out = Export-ClaudeSessionReadableTranscript -InstanceId ([string]$srcItem.Tag) -SessionId $firstSid -OpenInBrowser
        Set-Status "HTML: $($out.HtmlPath)"
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

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
        if ($selectedIds.Count -eq 0) { return }

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
        Set-Status "Transferred $($res.Transferred) session(s) to '$dstId'."
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
}

$BtnCopySessions.Add_Click({ Invoke-SessionTransfer -MoveMode $false })
$BtnMoveSessions.Add_Click({ Invoke-SessionTransfer -MoveMode $true })

$BtnExportPack.Add_Click({
    try {
        $srcItem = $CmbSourceInstance.SelectedItem
        if (-not $srcItem) { return }
        $srcId = [string]$srcItem.Tag

        $selectedIds = @()
        foreach ($sel in $LstSourceSessions.SelectedItems) {
            $selectedIds += [string]$sel.Tag
        }
        if ($selectedIds.Count -eq 0) { return }

        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Title = "Export .cimpack"
        $sfd.Filter = "CIM Package (*.cimpack)|*.cimpack|ZIP (*.zip)|*.zip"
        $sfd.DefaultExt = "cimpack"
        $sfd.FileName = "Claude-Export-$(Get-Date -Format 'yyyyMMdd-HHmm').cimpack"

        if ($sfd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $res = Export-ClaudePortablePack `
            -SourceInstanceId $srcId `
            -SessionIds $selectedIds `
            -OutputFilePath $sfd.FileName `
            -IncludeWorkspaceFiles ($ChkPackWorkspace.IsChecked -eq $true) `
            -IncludeSubSessions ($ChkIncludeSubSessions.IsChecked -eq $true)

        Set-Status "Exported $($res.SessionCount) session(s) -> $($res.OutputFilePath)"
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnImportPack.Add_Click({
    try {
        $dstItem = $CmbTargetInstance.SelectedItem
        if (-not $dstItem) { return }
        $dstId = [string]$dstItem.Tag

        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = "Import .cimpack"
        $ofd.Filter = "CIM Package (*.cimpack;*.zip)|*.cimpack;*.zip|All (*.*)|*.*"

        if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $manifest = Read-ClaudePortablePack -PackPath $ofd.FileName
        $pathMappings = @{}

        if ($manifest.projects) {
            foreach ($proj in $manifest.projects) {
                $origCwd = [string]$proj.originalCwd
                if ([string]::IsNullOrWhiteSpace($origCwd) -or ($origCwd -match 'scratch-workspaces')) { continue }

                $promptText = if ($script:CurrentLang -eq "en-US") {
                    "Project '$($proj.projectName)' path:`n$origCwd`n`nRemap to another local folder?"
                } else {
                    "Caminho original de '$($proj.projectName)':`n$origCwd`n`nSelecionar outra pasta local?"
                }

                $choice = [System.Windows.MessageBox]::Show(
                    $promptText,
                    $proj.projectName,
                    [System.Windows.MessageBoxButton]::YesNoCancel,
                    [System.Windows.MessageBoxImage]::Question
                )
                if ($choice -eq [System.Windows.MessageBoxResult]::Cancel) { return }
                if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
                    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
                    $fbd.Description = $proj.projectName
                    $fbd.ShowNewFolderButton = $true
                    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        $pathMappings[$origCwd] = $fbd.SelectedPath
                    }
                }
            }
        }

        $impRes = Import-ClaudePortablePack `
            -PackPath $ofd.FileName `
            -TargetInstanceId $dstId `
            -PathMappings $pathMappings `
            -ExtractWorkspaceFiles $true

        Refresh-SessionLists
        Refresh-InstancesUI
        Set-Status "Imported $($impRes.ImportedSessions) session(s) into $($dstItem.Content)."
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnEnableProto.Add_Click({
    $mode = if ($RbProtoFixed.IsChecked -eq $true) { "fixed" } else { "ask" }
    $pinId = if ($CmbProtoFixedInstance.SelectedItem) { [string]$CmbProtoFixedInstance.SelectedItem.Tag } else { "Primary" }
    Enable-ClaudeProtocolIntercept -Mode $mode -PinnedInstanceId $pinId | Out-Null
    Refresh-ProtocolUI
    Set-Status "claude:// router active ($mode)."
})

$BtnDisableProto.Add_Click({
    Disable-ClaudeProtocolIntercept | Out-Null
    Refresh-ProtocolUI
    Set-Status "claude:// restored to Windows default."
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
        Set-Status "Sent claude:// -> $($targetItem.Content)"
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
        Set-Status "Cloned settings: $($srcItem.Content) -> $($dstItem.Content)"
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
    Set-Status "Update policy: $mode"
})

$BtnCreateBackup.Add_Click({
    try {
        $lbl = $TxtBackupLabel.Text.Trim()
        $zip = New-ClaudeBackup -Label $lbl
        Refresh-UpdateAndBackupUI
        Set-Status "Backup: $zip"
    } catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Error", "OK", "Error") | Out-Null
    }
})

$BtnRestoreBackup.Add_Click({
    $sel = $LstBackups.SelectedItem
    if (-not $sel -or -not $sel.Tag) { return }
    $confirm = [System.Windows.MessageBox]::Show(
        "Restore $($sel.Content)?",
        "CIM",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        Restore-ClaudeBackup -ZipPath ([string]$sel.Tag) | Out-Null
        Clear-ClaudeSessionCache
        Refresh-InstancesUI
        Refresh-SessionLists
        Set-Status "Restored backup."
    }
})

$BtnOpenBackupsFolder.Add_Click({
    if (Test-Path $script:CIMBackupsDir) {
        Start-Process "explorer.exe" -ArgumentList "`"$script:CIMBackupsDir`""
    }
})

$script:PendingCimUpdate = $null

function Invoke-CimUpdateCheck([bool]$Interactive) {
    $u = Test-CIMUpdateAvailable
    $script:PendingCimUpdate = $u
    if ($u.IsUpdateAvailable) {
        $BtnHeaderSelfUpdate.Content = if ($script:CurrentLang -eq "pt-BR") { "Atualizar (v$($u.LatestVersion))" } else { "Update (v$($u.LatestVersion))" }
        $BtnHeaderSelfUpdate.Visibility = "Visible"
        if ($Interactive) {
            $msg = if ($script:CurrentLang -eq "pt-BR") {
                "Nova versão disponível no GitHub: v$($u.LatestVersion) (Atual: v$($u.CurrentVersion)).`n`nDeseja baixar e atualizar agora?"
            } else {
                "New version available on GitHub: v$($u.LatestVersion) (Current: v$($u.CurrentVersion)).`n`nDownload and install now?"
            }
            $ans = [System.Windows.MessageBox]::Show($msg, "CIM Update", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Information)
            if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
                Set-Status "Downloading CIM v$($u.LatestVersion)..."
                Install-CIMSelfUpdate -UpdateInfo $u -AppRootDir $PSScriptRoot | Out-Null
                $Window.Close()
            }
        } else {
            Set-Status "CIM v$($u.LatestVersion) available."
        }
    } else {
        $BtnHeaderSelfUpdate.Visibility = "Collapsed"
        if ($Interactive) {
            $msg = if ($script:CurrentLang -eq "pt-BR") { "O CIM já está na versão mais recente (v$($u.CurrentVersion))." } else { "CIM is up to date (v$($u.CurrentVersion))." }
            [System.Windows.MessageBox]::Show($msg, "CIM Update", "OK", "Information") | Out-Null
        }
    }
}

$BtnHeaderSelfUpdate.Add_Click({
    if ($script:PendingCimUpdate -and $script:PendingCimUpdate.IsUpdateAvailable) {
        Invoke-CimUpdateCheck -Interactive $true
    }
})

$BtnCheckCimUpdate.Add_Click({
    Invoke-CimUpdateCheck -Interactive $true
})

Apply-Localization

$Window.Add_ContentRendered({
    Refresh-InstancesUI
    Refresh-SessionLists
    Refresh-ProtocolUI
    Refresh-UpdateAndBackupUI
    Start-MetricsBackgroundPrewarm
    Set-Status (T "MsgReady")
    [void]$Window.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::ApplicationIdle,
        [Action]{ Invoke-CimUpdateCheck -Interactive $false }
    )
})

[void]$Window.ShowDialog()
