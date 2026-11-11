# Core-SettingsBackup.ps1 — Auto-Update Control, Anti-Gateway Fix, Dispatch Toggle, Config Sync & ZIP Backups

Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:ConfigLibDir = Join-Path $env:LOCALAPPDATA "Claude-3p\configLibrary"
$script:ManagedProfileFile = Join-Path $script:ConfigLibDir "00000000-0000-4000-8000-000000000001.json"
$script:ManagedMetaFile = Join-Path $script:ConfigLibDir "_meta.json"

function Get-ClaudeUpdatePolicy {
    $depMode = "1p"
    $disableAuto = $false
    $enfHours = 24
    $instEnf = $true
    $mode = "Default"

    if (Test-Path $script:ManagedProfileFile) {
        try {
            $raw = Get-Content $script:ManagedProfileFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.deploymentMode) { $depMode = [string]$raw.deploymentMode }
            if ($null -ne $raw.disableAutoUpdates) { $disableAuto = [bool]$raw.disableAutoUpdates }
            if ($null -ne $raw.autoUpdaterEnforcementHours) { $enfHours = [int]$raw.autoUpdaterEnforcementHours }
            if ($null -ne $raw.installedUpdateEnforcementEnabled) { $instEnf = [bool]$raw.installedUpdateEnforcementEnabled }

            if ($disableAuto -eq $true) {
                $mode = "Disabled"
            } elseif ($instEnf -eq $false -and $enfHours -ge 72) {
                $mode = "ManualRestart"
            }
        } catch {}
    }

    return [PSCustomObject]@{
        Mode                 = $mode
        DeploymentMode       = $depMode
        DisableAutoUpdates   = $disableAuto
        EnforcementHours     = $enfHours
        InstalledEnforcement = $instEnf
    }
}

function Set-ClaudeUpdatePolicy {
    param(
        [ValidateSet("ManualRestart", "Disabled", "Default")]
        [string]$Mode = "ManualRestart"
    )

    if (-not (Test-Path $script:ConfigLibDir)) {
        New-Item -ItemType Directory -Path $script:ConfigLibDir -Force | Out-Null
    }

    $profileObj = @{
        version                           = 1
        deploymentMode                    = "1p"
        disableAutoUpdates                = ($Mode -eq "Disabled")
        autoUpdaterEnforcementHours       = if ($Mode -eq "Default") { 24 } else { 72 }
        installedUpdateEnforcementEnabled = ($Mode -eq "Default")
    }
    $metaObj = @{
        selectedProfileId = "00000000-0000-4000-8000-000000000001"
        updatedAt         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($script:ManagedProfileFile, ($profileObj | ConvertTo-Json -Depth 5), $utf8NoBom)
    [System.IO.File]::WriteAllText($script:ManagedMetaFile, ($metaObj | ConvertTo-Json -Depth 5), $utf8NoBom)

    # Sync orgRestrictions across all instances
    $instances = @(Get-ClaudeInstances)
    $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    foreach ($inst in $instances) {
        $cfgPath = Join-Path $inst.DataDir "claude_desktop_config.json"
        Ensure-UniqueConfigFile -FilePath $cfgPath
        $cfgObj = @{}
        if (Test-Path $cfgPath) {
            try {
                $parsed = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($p in $parsed.PSObject.Properties) { $cfgObj[$p.Name] = $p.Value }
            } catch {}
        }
        if (-not $cfgObj["preferences"]) {
            $cfgObj["preferences"] = [PSCustomObject]@{}
        }
        $prefs = $cfgObj["preferences"]
        if ($Mode -eq "Default") {
            if ($prefs.PSObject.Properties["orgRestrictions"]) {
                $prefs.PSObject.Properties.Remove("orgRestrictions")
            }
        } else {
            $restr = [PSCustomObject]@{
                off = @("auto_updates")
                at  = $nowMs
            }
            $prefs | Add-Member -NotePropertyName "orgRestrictions" -NotePropertyValue $restr -Force
        }
        [System.IO.File]::WriteAllText($cfgPath, ($cfgObj | ConvertTo-Json -Depth 12), $utf8NoBom)
    }

    return Get-ClaudeUpdatePolicy
}

function Set-ClaudeInstanceDispatch([string]$InstanceId, [bool]$Enabled) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instância não encontrada: $InstanceId" }

    $ident = Resolve-InstanceIdentity -DataDir $inst.DataDir
    $acc = if ($ident.AccountUuid) { $ident.AccountUuid } else { "default" }
    $org = if ($ident.OrgUuid) { $ident.OrgUuid } else { "default" }
    $key = "${org}:${acc}"

    $bridgePath = Join-Path $inst.DataDir "bridge-state.json"
    Ensure-UniqueConfigFile -FilePath $bridgePath

    $bridgeObj = @{
        schemaVersion = 1
        enabledByKey  = @{}
    }
    if (Test-Path $bridgePath) {
        try {
            $raw = Get-Content $bridgePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.enabledByKey) {
                foreach ($p in $raw.enabledByKey.PSObject.Properties) {
                    $bridgeObj.enabledByKey[$p.Name] = $p.Value
                }
            }
        } catch {}
    }

    $bridgeObj.enabledByKey[$key] = @{
        enabled       = $Enabled
        userConsented = $true
        updatedAt     = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($bridgePath, ($bridgeObj | ConvertTo-Json -Depth 8), $utf8NoBom)
    return $Enabled
}

function Sync-ClaudeInstanceConfig {
    param(
        [Parameter(Mandatory=$true)][string]$SourceInstanceId,
        [Parameter(Mandatory=$true)][string]$TargetInstanceId,
        [bool]$IncludeMcp = $true,
        [bool]$IncludeFolderPermissions = $true,
        [bool]$IncludePreferences = $true
    )

    if ($SourceInstanceId -eq $TargetInstanceId) {
        throw "Selecione instâncias de origem e destino diferentes."
    }

    $srcInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $SourceInstanceId } | Select-Object -First 1
    $dstInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $TargetInstanceId } | Select-Object -First 1
    if (-not $srcInst -or -not $dstInst) { throw "Instância não encontrada." }

    $srcCfgPath = Join-Path $srcInst.DataDir "claude_desktop_config.json"
    $dstCfgPath = Join-Path $dstInst.DataDir "claude_desktop_config.json"
    if (-not (Test-Path $srcCfgPath)) { throw "Arquivo claude_desktop_config.json não encontrado na origem." }

    Ensure-UniqueConfigFile -FilePath $dstCfgPath

    $srcCfg = Get-Content $srcCfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $dstCfg = if (Test-Path $dstCfgPath) {
        try { Get-Content $dstCfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { [PSCustomObject]@{} }
    } else {
        [PSCustomObject]@{}
    }

    if ($IncludeMcp -and $srcCfg.PSObject.Properties["mcpServers"]) {
        $dstCfg | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue $srcCfg.mcpServers -Force
    }

    if (-not $dstCfg.PSObject.Properties["preferences"]) {
        $dstCfg | Add-Member -NotePropertyName "preferences" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    if ($srcCfg.PSObject.Properties["preferences"]) {
        $srcPrefs = $srcCfg.preferences
        $dstPrefs = $dstCfg.preferences

        if ($IncludePreferences) {
            foreach ($prop in $srcPrefs.PSObject.Properties) {
                if ($prop.Name -notmatch "^epitaxy-folder-permission-mode") {
                    $dstPrefs | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                }
            }
        }

        if ($IncludeFolderPermissions) {
            $dstIdent = Resolve-InstanceIdentity -DataDir $dstInst.DataDir
            $dstAcc = if ($dstIdent.AccountUuid) { $dstIdent.AccountUuid } else { $dstInst.AccountUuid }
            if ($dstAcc -and $dstAcc -ne "Não autenticado") {
                $targetPermKey = "epitaxy-folder-permission-mode-v2.$dstAcc"
                if (-not $dstPrefs.PSObject.Properties[$targetPermKey]) {
                    $dstPrefs | Add-Member -NotePropertyName $targetPermKey -NotePropertyValue ([PSCustomObject]@{}) -Force
                }
                $targetPermObj = $dstPrefs.PSObject.Properties[$targetPermKey].Value
                foreach ($prop in $srcPrefs.PSObject.Properties) {
                    if ($prop.Name -match "^epitaxy-folder-permission-mode-v2\.") {
                        foreach ($folderProp in $prop.Value.PSObject.Properties) {
                            $targetPermObj | Add-Member -NotePropertyName $folderProp.Name -NotePropertyValue $folderProp.Value -Force
                        }
                    }
                }
            }
        }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($dstCfgPath, ($dstCfg | ConvertTo-Json -Depth 12), $utf8NoBom)
    return $true
}

function New-ClaudeBackup([string]$Label = "manual") {
    Initialize-CIMDirectories
    $cleanLabel = ($Label -replace '[^a-zA-Z0-9_-]', '')
    if ([string]::IsNullOrWhiteSpace($cleanLabel)) { $cleanLabel = "backup" }
    $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $zipName = "CIM-Backup-$ts-$cleanLabel.zip"
    $zipPath = Join-Path $script:CIMBackupsDir $zipName

    $stagingDir = Join-Path $env:TEMP "cim_backup_stage_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    try {
        if (Test-Path $script:CIMStateFile) {
            Copy-Item -Path $script:CIMStateFile -Destination (Join-Path $stagingDir "cim-state.json") -Force
        }

        $instances = @(Get-ClaudeInstances)
        foreach ($inst in $instances) {
            $instStage = Join-Path $stagingDir $inst.Id
            New-Item -ItemType Directory -Path $instStage -Force | Out-Null

            foreach ($cfgName in @("claude_desktop_config.json", "config.json", "bridge-state.json")) {
                $srcFile = Join-Path $inst.DataDir $cfgName
                if (Test-Path $srcFile) {
                    Copy-Item -Path $srcFile -Destination (Join-Path $instStage $cfgName) -Force
                }
            }

            foreach ($dirName in @("claude-code-sessions", "local-agent-mode-sessions", "side-session-notes")) {
                $srcFolder = Join-Path $inst.DataDir $dirName
                if (Test-Path $srcFolder) {
                    Copy-Item -Path $srcFolder -Destination (Join-Path $instStage $dirName) -Recurse -Force
                }
            }
        }

        if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $zipPath)
    } finally {
        Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    return $zipPath
}

function Get-ClaudeBackups {
    Initialize-CIMDirectories
    $files = Get-ChildItem -Path $script:CIMBackupsDir -Filter "*.zip" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    $list = @()
    foreach ($f in $files) {
        $sizeKB = [math]::Round($f.Length / 1KB, 1)
        $list += [PSCustomObject]@{
            FileName  = $f.Name
            FullPath  = $f.FullName
            CreatedAt = $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
            SizeKB    = $sizeKB
            Label     = "$($f.Name)  ($($f.LastWriteTime.ToString('dd/MM/yyyy HH:mm')) — $sizeKB KB)"
        }
    }
    return $list
}

function Restore-ClaudeBackup([string]$ZipPath) {
    if (-not (Test-Path $ZipPath)) { throw "Arquivo de backup não encontrado: $ZipPath" }

    $stagingDir = Join-Path $env:TEMP "cim_restore_stage_$([guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $stagingDir)
        $instances = @(Get-ClaudeInstances)
        foreach ($inst in $instances) {
            $instStage = Join-Path $stagingDir $inst.Id
            if (-not (Test-Path $instStage)) { continue }

            foreach ($cfgName in @("claude_desktop_config.json", "config.json", "bridge-state.json")) {
                $srcFile = Join-Path $instStage $cfgName
                if (Test-Path $srcFile) {
                    $dstFile = Join-Path $inst.DataDir $cfgName
                    Ensure-UniqueConfigFile -FilePath $dstFile
                    Copy-Item -Path $srcFile -Destination $dstFile -Force
                }
            }

            foreach ($dirName in @("claude-code-sessions", "local-agent-mode-sessions", "side-session-notes")) {
                $srcFolder = Join-Path $instStage $dirName
                if (Test-Path $srcFolder) {
                    $dstFolder = Join-Path $inst.DataDir $dirName
                    Copy-Item -Path $srcFolder -Destination $inst.DataDir -Recurse -Force
                }
            }
        }
    } finally {
        Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $true
}
