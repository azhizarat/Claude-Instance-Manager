# Core-Instances.ps1 — Instance Discovery, Hardlink Engine, Process Telemetry, Icon & Shortcut Generator

if (-not ("CIMNative.HardLink" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace CIMNative {
    public static class HardLink {
        [DllImport("Kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CreateHardLink(string lpFileName, string lpExistingFileName, IntPtr lpSecurityAttributes);
    }
}
"@
}

Add-Type -AssemblyName System.Drawing

$script:CIMRootDir = Join-Path $env:LOCALAPPDATA "Claude-Instances"
$script:CIMStateFile = Join-Path $script:CIMRootDir "cim-state.json"
$script:CIMIconsDir = Join-Path $script:CIMRootDir "icons"
$script:CIMBackupsDir = Join-Path $script:CIMRootDir "Backups"
$script:ReservedFolderNames = @("icons", "Backups", "Manager", "logs", "temp")

function Initialize-CIMDirectories {
    foreach ($d in @($script:CIMRootDir, $script:CIMIconsDir, $script:CIMBackupsDir)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

function Get-CIMState {
    Initialize-CIMDirectories
    $defaultLang = if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -like "pt*") { "pt-BR" } else { "en-US" }
    $defaultState = @{
        language  = $defaultLang
        instances = @{
            "Primary" = @{
                displayName  = "Principal"
                badgeText    = "P1"
                badgeColor   = "#2563EB"
                accountLabel = "Primary Account (MSIX)"
                iconPath     = (Join-Path $script:CIMIconsDir "claude-primary.ico")
            }
        }
        protocol = @{
            mode                  = "ask"
            pinnedInstanceId      = "Primary"
            armedLoginInstanceId  = ""
            armedLoginExpiresAt   = ""
            backupDelegateExecute = "{A56A841F-E974-45C1-8001-7E3F8A085917}"
        }
    }

    if (Test-Path $script:CIMStateFile) {
        try {
            $raw = Get-Content $script:CIMStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.language) { $defaultState.language = [string]$raw.language }
            if ($raw.instances) {
                foreach ($prop in $raw.instances.PSObject.Properties) {
                    $defaultState.instances[$prop.Name] = @{
                        displayName  = if ($prop.Value.displayName) { [string]$prop.Value.displayName } else { $prop.Name }
                        badgeText    = if ($prop.Value.badgeText) { [string]$prop.Value.badgeText } else { $prop.Name.Substring(0, [Math]::Min(2, $prop.Name.Length)).ToUpper() }
                        badgeColor   = if ($prop.Value.badgeColor) { [string]$prop.Value.badgeColor } else { "#D97757" }
                        accountLabel = if ($prop.Value.accountLabel) { [string]$prop.Value.accountLabel } else { "" }
                        iconPath     = if ($prop.Value.iconPath) { [string]$prop.Value.iconPath } else { Join-Path $script:CIMIconsDir "claude-$($prop.Name.ToLower()).ico" }
                    }
                }
            }
            if ($raw.protocol) {
                foreach ($p in $raw.protocol.PSObject.Properties) {
                    $defaultState.protocol[$p.Name] = $p.Value
                }
            }
        } catch {}
    } else {
        Save-CIMState -State $defaultState
    }
    return $defaultState
}

function Save-CIMState([hashtable]$State) {
    Initialize-CIMDirectories
    $json = $State | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($script:CIMStateFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-PrimaryClaudeDataDir {
    $newPath = Join-Path $env:LOCALAPPDATA "Claude-Data\claude_pzs8sxrjxfjjc"
    if (Test-Path $newPath) { return $newPath }
    $legacyPath = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude"
    if (Test-Path $legacyPath) { return $legacyPath }
    $roamingPath = Join-Path $env:APPDATA "Claude"
    if (Test-Path $roamingPath) { return $roamingPath }
    return $newPath
}

function Get-ClaudeExePath {
    $alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\claude-desktop.exe"
    if (Test-Path $alias) { return $alias }
    try {
        $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $exe = Join-Path $pkg.InstallLocation "app\Claude.exe"
            if (Test-Path $exe) { return $exe }
        }
    } catch {}
    return $alias
}

function Ensure-UniqueConfigFile([string]$FilePath) {
    if (-not (Test-Path $FilePath)) { return }
    try {
        $links = @(fsutil hardlink list $FilePath 2>$null)
        if ($links.Count -gt 1) {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            Remove-Item -Path $FilePath -Force
            [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        }
    } catch {}
}

function Resolve-InstanceIdentity([string]$DataDir) {
    $accUuid = $null
    $orgUuid = $null

    $cfgPath = Join-Path $DataDir "config.json"
    if (Test-Path $cfgPath) {
        try {
            $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.lastKnownAccountUuid) { $accUuid = [string]$cfg.lastKnownAccountUuid }
            if ($cfg.sshTransportFlagLastAnswer -and $cfg.sshTransportFlagLastAnswer.orgUuid) {
                $orgUuid = [string]$cfg.sshTransportFlagLastAnswer.orgUuid
            }
        } catch {}
    }

    $sessionsRoot = Join-Path $DataDir "claude-code-sessions"
    if (Test-Path $sessionsRoot) {
        $accDirs = @(Get-ChildItem -Path $sessionsRoot -Directory -ErrorAction SilentlyContinue)
        if (-not $accUuid -and $accDirs.Count -gt 0) {
            $accUuid = ($accDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
        }
        if ($accUuid) {
            $accPath = Join-Path $sessionsRoot $accUuid
            if (Test-Path $accPath) {
                $orgDirs = @(Get-ChildItem -Path $accPath -Directory -ErrorAction SilentlyContinue)
                if ($orgDirs.Count -gt 0) {
                    if (-not $orgUuid -or -not (Test-Path (Join-Path $accPath $orgUuid))) {
                        $bestOrg = $orgDirs | Sort-Object { @(Get-ChildItem $_.FullName -Filter "local_*.json" -ErrorAction SilentlyContinue).Count } -Descending | Select-Object -First 1
                        $orgUuid = $bestOrg.Name
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        AccountUuid = $accUuid
        OrgUuid     = $orgUuid
    }
}

function Get-ClaudeInstances {
    $state = Get-CIMState
    $primaryDir = Get-PrimaryClaudeDataDir

    # Query running claude.exe processes once
    $claudeProcs = @()
    try {
        $claudeProcs = @(Get-CimInstance Win32_Process -Filter "Name = 'claude.exe'" -ErrorAction SilentlyContinue)
    } catch {}

    $rawList = @(
        [PSCustomObject]@{
            Id        = "Primary"
            DataDir   = $primaryDir
            IsPrimary = $true
        }
    )

    if (Test-Path $script:CIMRootDir) {
        $subDirs = Get-ChildItem -Path $script:CIMRootDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $script:ReservedFolderNames -notcontains $_.Name }
        foreach ($d in $subDirs) {
            $rawList += [PSCustomObject]@{
                Id        = $d.Name
                DataDir   = $d.FullName
                IsPrimary = $false
            }
        }
    }

    $results = @()
    foreach ($item in $rawList) {
        $meta = $state.instances[$item.Id]
        if (-not $meta) {
            $meta = @{
                displayName  = $item.Id
                badgeText    = $item.Id.Substring(0, [Math]::Min(2, $item.Id.Length)).ToUpper()
                badgeColor   = "#D97757"
                accountLabel = "Instância Secundária"
                iconPath     = (Join-Path $script:CIMIconsDir "claude-$($item.Id.ToLower()).ico")
            }
        }

        $ident = Resolve-InstanceIdentity -DataDir $item.DataDir

        # Match processes
        $instProcs = @()
        if ($item.IsPrimary) {
            $instProcs = @($claudeProcs | Where-Object { $_.CommandLine -notmatch "--user-data-dir" })
        } else {
            $escapedDir = [regex]::Escape($item.DataDir)
            $instProcs = @($claudeProcs | Where-Object { $_.CommandLine -match $escapedDir })
        }

        $ramBytes = 0
        foreach ($p in $instProcs) {
            if ($p.WorkingSetSize) { $ramBytes += [int64]$p.WorkingSetSize }
        }
        $ramMB = [math]::Round($ramBytes / 1MB, 1)

        # Count sessions
        $sessionCount = 0
        $sessionsBase = Join-Path $item.DataDir "claude-code-sessions"
        if (Test-Path $sessionsBase) {
            $sessionCount = @(Get-ChildItem -Path $sessionsBase -Filter "local_*.json" -Recurse -ErrorAction SilentlyContinue).Count
        }

        # Check VM disk
        $vhdxPath = Join-Path $item.DataDir "vm_bundles\claudevm.bundle\sessiondata.vhdx"
        $vmPresent = Test-Path $vhdxPath

        # Check Dispatch (bridge-state.json)
        $dispatchEnabled = $false
        $bridgePath = Join-Path $item.DataDir "bridge-state.json"
        if (Test-Path $bridgePath) {
            try {
                $bRaw = Get-Content $bridgePath -Raw -Encoding UTF8
                if ($bRaw -match '"enabled"\s*:\s*true') { $dispatchEnabled = $true }
            } catch {}
        }

        $results += [PSCustomObject]@{
            Id              = $item.Id
            DisplayName     = $meta.displayName
            DataDir         = $item.DataDir
            IsPrimary       = $item.IsPrimary
            AccountUuid     = if ($ident.AccountUuid) { $ident.AccountUuid } else { "Não autenticado" }
            OrgUuid         = if ($ident.OrgUuid) { $ident.OrgUuid } else { "—" }
            AccountLabel    = $meta.accountLabel
            BadgeText       = $meta.badgeText
            BadgeColor      = $meta.badgeColor
            IconPath        = $meta.iconPath
            IsRunning       = ($instProcs.Count -gt 0)
            ProcessCount    = $instProcs.Count
            RamMB           = $ramMB
            VmDiskPresent   = $vmPresent
            SessionCount    = $sessionCount
            DispatchEnabled = $dispatchEnabled
        }
    }

    return $results
}

function Sync-ClaudeInstanceLinks([string]$TargetDir) {
    $primaryDir = Get-PrimaryClaudeDataDir
    if (-not (Test-Path $primaryDir)) {
        throw "Diretório da instância primária não encontrado: $primaryDir"
    }
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $sharedDirs = @(
        "claude-code",
        "claude-code-vm",
        "claude-ssh-remote",
        "terminal-shell-integration",
        "Claude Extensions"
    )

    $linked = 0
    $skipped = 0

    function Copy-HardlinkTree([string]$SrcRoot, [string]$DstRoot, [string[]]$ExcludeFiles = @()) {
        if (-not (Test-Path $SrcRoot)) { return }
        if (-not (Test-Path $DstRoot)) {
            New-Item -ItemType Directory -Path $DstRoot -Force | Out-Null
        }
        $files = Get-ChildItem -Path $SrcRoot -Recurse -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($ExcludeFiles -contains $file.Name) {
                $script:skipped++
                continue
            }
            $rel = $file.FullName.Substring($SrcRoot.Length).TrimStart('\')
            $destFile = Join-Path $DstRoot $rel
            $destParent = Split-Path -Parent $destFile
            if (-not (Test-Path $destParent)) {
                New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            }
            if (Test-Path $destFile) {
                $destItem = Get-Item $destFile -ErrorAction SilentlyContinue
                if ($destItem -and $destItem.Length -eq $file.Length) {
                    $script:skipped++
                    continue
                }
                Remove-Item -Path $destFile -Force -ErrorAction SilentlyContinue
            }
            $ok = [CIMNative.HardLink]::CreateHardLink($destFile, $file.FullName, [IntPtr]::Zero)
            if (-not $ok) {
                Copy-Item -Path $file.FullName -Destination $destFile -Force
            }
            $script:linked++
        }
    }

    foreach ($dirName in $sharedDirs) {
        Copy-HardlinkTree -SrcRoot (Join-Path $primaryDir $dirName) -DstRoot (Join-Path $TargetDir $dirName)
    }

    # VM bundle: link read-only rootfs/efi/kernel, never link sessiondata.vhdx or sessiondata.img
    Copy-HardlinkTree `
        -SrcRoot (Join-Path $primaryDir "vm_bundles\claudevm.bundle") `
        -DstRoot (Join-Path $TargetDir "vm_bundles\claudevm.bundle") `
        -ExcludeFiles @("sessiondata.vhdx", "sessiondata.img")

    # Ensure config files exist as independent non-hardlinked files
    foreach ($cfgName in @("claude_desktop_config.json", "config.json", "bridge-state.json")) {
        $cfgTarget = Join-Path $TargetDir $cfgName
        if (Test-Path $cfgTarget) {
            Ensure-UniqueConfigFile -FilePath $cfgTarget
        } elseif ($cfgName -eq "claude_desktop_config.json") {
            $primaryCfg = Join-Path $primaryDir "claude_desktop_config.json"
            if (Test-Path $primaryCfg) {
                Copy-Item -Path $primaryCfg -Destination $cfgTarget -Force
                Ensure-UniqueConfigFile -FilePath $cfgTarget
            } else {
                '{"preferences":{"orgRestrictions":{"off":["auto_updates"],"at":1794000000000}}}' | Set-Content -Path $cfgTarget -Encoding UTF8
            }
        }
    }

    return [PSCustomObject]@{
        LinkedCount  = $linked
        SkippedCount = $skipped
    }
}

function Get-ClaudeBaseBitmap {
    try {
        $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $candidates = Get-ChildItem -Path (Join-Path $pkg.InstallLocation "Assets") -Filter "Square150x150Logo*.png" -ErrorAction SilentlyContinue |
                Sort-Object Length -Descending
            if ($candidates -and $candidates.Count -gt 0) {
                return [System.Drawing.Bitmap]::FromFile($candidates[0].FullName)
            }
        }
    } catch {}

    # Fallback: draw stylized Claude burst icon
    $bmp = New-Object System.Drawing.Bitmap(256, 256)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#D97757"))
    $g.FillEllipse($brush, 20, 20, 216, 216)
    $brush.Dispose()
    $g.Dispose()
    return $bmp
}

function New-ClaudeBadgeIcon([string]$OutputIcoPath, [string]$BadgeText, [string]$BadgeColorHex) {
    $parent = Split-Path -Parent $OutputIcoPath
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $baseBmp = Get-ClaudeBaseBitmap
    $sizes = @(256, 48, 32, 16)
    $pngBuffers = @()

    try {
        $badgeColor = [System.Drawing.ColorTranslator]::FromHtml($BadgeColorHex)
    } catch {
        $badgeColor = [System.Drawing.ColorTranslator]::FromHtml("#2563EB")
    }

    foreach ($sz in $sizes) {
        $canvas = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $g.DrawImage($baseBmp, 0, 0, $sz, $sz)

        # Draw bottom-right circular badge
        $bDiam = [Math]::Max(8, [int][Math]::Round($sz * 0.46))
        $bx = $sz - $bDiam
        $by = $sz - $bDiam

        $fillBrush = New-Object System.Drawing.SolidBrush($badgeColor)
        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(240, 20, 20, 24), [Math]::Max(1.0, [float]($sz * 0.04)))

        $g.FillEllipse($fillBrush, $bx, $by, $bDiam - 1, $bDiam - 1)
        $g.DrawEllipse($borderPen, $bx, $by, $bDiam - 1, $bDiam - 1)

        if (-not [string]::IsNullOrWhiteSpace($BadgeText) -and $sz -ge 24) {
            $txt = $BadgeText.Trim().ToUpper()
            $fontScale = if ($txt.Length -ge 2) { 0.42 } else { 0.52 }
            $fontSize = [Math]::Max(6.0, [float]($bDiam * $fontScale))
            $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat
            $sf.Alignment = [System.Drawing.StringAlignment]::Center
            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $rect = New-Object System.Drawing.RectangleF([float]$bx, [float]$by, [float]$bDiam, [float]$bDiam)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $g.DrawString($txt, $font, $textBrush, $rect, $sf)
            $textBrush.Dispose()
            $font.Dispose()
            $sf.Dispose()
        }

        $fillBrush.Dispose()
        $borderPen.Dispose()
        $g.Dispose()

        $ms = New-Object System.IO.MemoryStream
        $canvas.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBuffers += ,($ms.ToArray())
        $ms.Dispose()
        $canvas.Dispose()
    }
    $baseBmp.Dispose()

    # Write standard multi-image ICO container
    $fs = [System.IO.File]::Open($OutputIcoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$sizes.Count)

    $offset = 6 + (16 * $sizes.Count)
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]
        $bVal = if ($s -ge 256) { [byte]0 } else { [byte]$s }
        $len = $pngBuffers[$i].Length
        $bw.Write($bVal)
        $bw.Write($bVal)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$len)
        $bw.Write([uint32]$offset)
        $offset += $len
    }

    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $bw.Write($pngBuffers[$i])
    }

    $bw.Flush()
    $bw.Close()
    $fs.Close()
}

function New-ClaudeInstanceShortcuts([string]$InstanceId, [string]$DisplayName, [string]$DataDir, [string]$IconPath, [bool]$IsPrimary) {
    Initialize-CIMDirectories
    $exePath = Get-ClaudeExePath
    $wsh = New-Object -ComObject WScript.Shell
    $desktopDir = [Environment]::GetFolderPath("Desktop")
    $startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Claude Instances"
    if (-not (Test-Path $startMenuDir)) {
        New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
    }

    if ($IsPrimary) {
        foreach ($folder in @($desktopDir, $startMenuDir)) {
            $lnkPath = Join-Path $folder "Claude - $DisplayName.lnk"
            $sc = $wsh.CreateShortcut($lnkPath)
            $sc.TargetPath = $exePath
            $sc.Arguments = ""
            if (Test-Path $IconPath) { $sc.IconLocation = "$IconPath,0" }
            $sc.Description = "Claude Desktop ($DisplayName)"
            $sc.Save()
        }
    } else {
        $vbsPath = Join-Path $script:CIMRootDir "Launch-$InstanceId.vbs"
        $launcherPs1 = Join-Path $script:CIMRootDir "Claude-MultiInstance-Launcher.ps1"
        if (Test-Path $launcherPs1) {
            $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$launcherPs1"" -InstanceName ""$InstanceId""", 0, False
"@
        } else {
            $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$exePath"" --user-data-dir=""$DataDir""", 1, False
"@
        }
        [System.IO.File]::WriteAllText($vbsPath, $vbsContent, [System.Text.Encoding]::ASCII)

        foreach ($folder in @($desktopDir, $startMenuDir)) {
            $lnkPath = Join-Path $folder "Claude - $DisplayName.lnk"
            $sc = $wsh.CreateShortcut($lnkPath)
            $sc.TargetPath = "C:\Windows\System32\wscript.exe"
            $sc.Arguments = "`"$vbsPath`""
            if (Test-Path $IconPath) { $sc.IconLocation = "$IconPath,0" }
            $sc.Description = "Claude Desktop ($DisplayName)"
            $sc.Save()
        }
    }
}

function New-ClaudeInstance([string]$Id, [string]$DisplayName, [string]$BadgeText, [string]$BadgeColor, [string]$AccountLabel) {
    $cleanId = ($Id -replace '[^a-zA-Z0-9_-]', '')
    if ([string]::IsNullOrWhiteSpace($cleanId)) {
        throw "O identificador da instância deve conter letras ou números."
    }
    if ($script:ReservedFolderNames -contains $cleanId -or $cleanId -eq "Primary") {
        throw "Nome de instância reservado: $cleanId"
    }

    $targetDir = Join-Path $script:CIMRootDir $cleanId
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $icoPath = Join-Path $script:CIMIconsDir "claude-$($cleanId.ToLower()).ico"
    New-ClaudeBadgeIcon -OutputIcoPath $icoPath -BadgeText $BadgeText -BadgeColorHex $BadgeColor

    $state = Get-CIMState
    $state.instances[$cleanId] = @{
        displayName  = if ($DisplayName) { $DisplayName } else { $cleanId }
        badgeText    = if ($BadgeText) { $BadgeText } else { $cleanId.Substring(0, [Math]::Min(2, $cleanId.Length)).ToUpper() }
        badgeColor   = if ($BadgeColor) { $BadgeColor } else { "#F59E0B" }
        accountLabel = if ($AccountLabel) { $AccountLabel } else { "Nova Instância" }
        iconPath     = $icoPath
    }
    Save-CIMState -State $state

    $syncRes = Sync-ClaudeInstanceLinks -TargetDir $targetDir
    New-ClaudeInstanceShortcuts -InstanceId $cleanId -DisplayName $state.instances[$cleanId].displayName -DataDir $targetDir -IconPath $icoPath -IsPrimary $false
    return $syncRes
}

function Update-ClaudeInstanceMetadata([string]$InstanceId, [string]$DisplayName, [string]$BadgeText, [string]$BadgeColor, [string]$AccountLabel, [bool]$RecreateShortcuts = $true) {
    $state = Get-CIMState
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }

    $icoPath = Join-Path $script:CIMIconsDir "claude-$($InstanceId.ToLower()).ico"
    New-ClaudeBadgeIcon -OutputIcoPath $icoPath -BadgeText $BadgeText -BadgeColorHex $BadgeColor

    $state.instances[$InstanceId] = @{
        displayName  = $DisplayName
        badgeText    = $BadgeText
        badgeColor   = $BadgeColor
        accountLabel = $AccountLabel
        iconPath     = $icoPath
    }
    Save-CIMState -State $state

    if ($RecreateShortcuts) {
        New-ClaudeInstanceShortcuts -InstanceId $InstanceId -DisplayName $DisplayName -DataDir $inst.DataDir -IconPath $icoPath -IsPrimary $inst.IsPrimary
    }
}

function Start-ClaudeInstance([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }
    $exePath = Get-ClaudeExePath

    if ($inst.IsPrimary) {
        Start-Process -FilePath $exePath
    } else {
        Sync-ClaudeInstanceLinks -TargetDir $inst.DataDir | Out-Null
        Start-Process -FilePath $exePath -ArgumentList "--user-data-dir=`"$($inst.DataDir)`""
    }
}

function Stop-ClaudeInstance([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }

    $claudeProcs = @(Get-CimInstance Win32_Process -Filter "Name = 'claude.exe'" -ErrorAction SilentlyContinue)
    $targetProcs = @()
    if ($inst.IsPrimary) {
        $targetProcs = @($claudeProcs | Where-Object { $_.CommandLine -notmatch "--user-data-dir" })
    } else {
        $escaped = [regex]::Escape($inst.DataDir)
        $targetProcs = @($claudeProcs | Where-Object { $_.CommandLine -match $escaped })
    }

    foreach ($p in $targetProcs) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
    return $targetProcs.Count
}

function Clear-ClaudeInstanceAuth([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }

    Stop-ClaudeInstance -InstanceId $InstanceId | Out-Null
    Start-Sleep -Milliseconds 600

    # Delete only web session/cookies/storage so user can log into another account without losing projects or MCPs
    $authPaths = @(
        (Join-Path $inst.DataDir "Network\Cookies"),
        (Join-Path $inst.DataDir "Network\Cookies-journal"),
        (Join-Path $inst.DataDir "Session Storage"),
        (Join-Path $inst.DataDir "Local Storage")
    )
    foreach ($ap in $authPaths) {
        if (Test-Path $ap) {
            Remove-Item -Path $ap -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Clear stored oauth token in config.json while preserving structure
    $cfgPath = Join-Path $inst.DataDir "config.json"
    if (Test-Path $cfgPath) {
        Ensure-UniqueConfigFile -FilePath $cfgPath
        try {
            $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.PSObject.Properties["oauth:tokenCache"]) {
                $cfg.PSObject.Properties.Remove("oauth:tokenCache")
            }
            $json = $cfg | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($cfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch {}
    }

    return $true
}

function Repair-ClaudeInstanceSessionOwnership([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }

    $cfgPath = Join-Path $inst.DataDir "config.json"
    if (-not (Test-Path $cfgPath)) { return 0 }
    $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $activeAcc = [string]$cfg.lastKnownAccountUuid
    $activeOrg = if ($cfg.sshTransportFlagLastAnswer) { [string]$cfg.sshTransportFlagLastAnswer.orgUuid } else { $null }
    if ([string]::IsNullOrWhiteSpace($activeAcc) -or [string]::IsNullOrWhiteSpace($activeOrg)) {
        return 0
    }

    $sessionsRoot = Join-Path $inst.DataDir "claude-code-sessions"
    if (-not (Test-Path $sessionsRoot)) { return 0 }

    $targetFolder = Join-Path $sessionsRoot "$activeAcc\$activeOrg"
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    }

    $migrated = 0
    $allSessionFiles = Get-ChildItem -Path $sessionsRoot -Filter "local_*.json" -Recurse -ErrorAction SilentlyContinue
    foreach ($sf in $allSessionFiles) {
        if ($sf.DirectoryName -ne $targetFolder) {
            $dest = Join-Path $targetFolder $sf.Name
            if (-not (Test-Path $dest)) {
                Move-Item -Path $sf.FullName -Destination $dest -Force
                $migrated++
            }
        }
    }
    return $migrated
}
