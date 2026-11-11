param(
    [string]$Url = ""
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

. (Join-Path $PSScriptRoot "Core-Instances.ps1")
. (Join-Path $PSScriptRoot "Core-ProtocolRouter.ps1")

if ([string]::IsNullOrWhiteSpace($Url)) { exit 0 }

$state = Get-CIMState
$lang = if ($state.language) { [string]$state.language } else { "pt-BR" }
$status = Get-ClaudeProtocolStatus

# 1. If a login target was armed recently, dispatch directly
if (-not [string]::IsNullOrWhiteSpace($status.ArmedLoginInstanceId)) {
    Send-ClaudeProtocolUrl -InstanceId $status.ArmedLoginInstanceId -Url $Url
    Clear-ClaudeLoginTarget
    exit 0
}

# 2. If fixed mode is configured, dispatch directly
if ($status.Mode -eq "fixed" -and -not [string]::IsNullOrWhiteSpace($status.PinnedInstanceId)) {
    Send-ClaudeProtocolUrl -InstanceId $status.PinnedInstanceId -Url $Url
    exit 0
}

$titleText = if ($lang -eq "en-US") { "Select the target instance for this claude:// link" } else { "Selecione a instância de destino para o link claude://" }
$runningWord = if ($lang -eq "en-US") { "RUNNING" } else { "ATIVA" }
$stoppedWord = if ($lang -eq "en-US") { "STOPPED" } else { "PARADA" }

# 3. Otherwise show sleek dark-mode instance selector popup
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Protocol Router"
        Width="460" SizeToContent="Height"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True">
    <Border CornerRadius="10" Background="#18181B" BorderBrush="#3F3F46" BorderThickness="1" Padding="20" Margin="10">
        <StackPanel>
            <DockPanel LastChildFill="False" Margin="0,0,0,10">
                <TextBlock x:Name="TxtHeader" Text="" Foreground="#F4F4F5" FontSize="14" FontWeight="SemiBold" DockPanel.Dock="Left" VerticalAlignment="Center"/>
                <Button x:Name="BtnClose" Content="X" Width="26" Height="26" Background="#27272A" Foreground="#A1A1AA" BorderThickness="0" Cursor="Hand" DockPanel.Dock="Right"/>
            </DockPanel>
            <Border Background="#09090B" CornerRadius="6" Padding="8" Margin="0,0,0,14" BorderBrush="#27272A" BorderThickness="1">
                <TextBlock x:Name="TxtUrl" Text="" Foreground="#A1A1AA" FontSize="11" TextTrimming="CharacterEllipsis"/>
            </Border>
            <StackPanel x:Name="InstancesPanel" />
        </StackPanel>
    </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader($xaml)
$win = [Windows.Markup.XamlReader]::Load($reader)

$win.FindName("TxtHeader").Text = $titleText
$win.FindName("TxtUrl").Text = $Url
$win.FindName("BtnClose").Add_Click({ $win.Close() })

$panel = $win.FindName("InstancesPanel")
$instances = @(Get-ClaudeInstances)
$bc = New-Object System.Windows.Media.BrushConverter

foreach ($inst in $instances) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Height = 44
    $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $btn.Background = $bc.ConvertFromString("#27272A")
    $btn.Foreground = $bc.ConvertFromString("#F4F4F5")
    $btn.BorderBrush = $bc.ConvertFromString($inst.BadgeColor)
    $btn.BorderThickness = New-Object System.Windows.Thickness(4, 1, 1, 1)
    $btn.HorizontalContentAlignment = "Stretch"
    $btn.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
    $btn.Cursor = [System.Windows.Input.Cursors]::Hand
    $btn.Tag = $inst.Id

    $stLabel = if ($inst.IsRunning) { $runningWord } else { $stoppedWord }
    $btn.Content = "[$($inst.BadgeText)]  $($inst.DisplayName)   |   $stLabel   ($($inst.AccountLabel))"

    $btn.Add_Click({
        param($sender, $e)
        $targetId = [string]$sender.Tag
        Send-ClaudeProtocolUrl -InstanceId $targetId -Url $Url
        $win.Close()
    })

    [void]$panel.Children.Add($btn)
}

[void]$win.ShowDialog()
