# Core-Sessions.ps1 — Fast C#-Accelerated Session Discovery, Local Migration, Cross-Machine Portable Pack (.cimpack) & HTML/MD Transcript Viewer

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web

$script:SessionMemoryCache = @{}

function Clear-ClaudeSessionCache([string]$InstanceId = "") {
    if ([string]::IsNullOrWhiteSpace($InstanceId)) {
        $script:SessionMemoryCache = @{}
    } elseif ($script:SessionMemoryCache.ContainsKey($InstanceId)) {
        $script:SessionMemoryCache.Remove($InstanceId)
    }
}

function ConvertTo-ClaudeEncodedPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    $trimmed = $Path.TrimEnd('\', '/')
    return [regex]::Replace($trimmed, '[^a-zA-Z0-9]', '-')
}

function Get-ClaudeInstanceSessions([string]$InstanceId, [switch]$ForceRefresh) {
    if (-not $ForceRefresh -and $script:SessionMemoryCache.ContainsKey($InstanceId)) {
        return $script:SessionMemoryCache[$InstanceId]
    }

    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { return @() }

    Initialize-CIMNativeEngine
    $rawList = [CIMNative.FastSessionScanner]::ScanInstance($inst.DataDir)
    $sorted = @($rawList | Sort-Object @{Expression="ProjectName"; Ascending=$true}, @{Expression="LastActivityAt"; Descending=$false})
    # Reverse sort by LastActivityAt within ProjectName
    $sorted = @($rawList | Sort-Object @{Expression="ProjectName"; Ascending=$true}, @{Expression={ -$_.LastActivityAt }; Ascending=$true})

    $script:SessionMemoryCache[$InstanceId] = $sorted
    return $sorted
}

function Copy-ClaudeSessions {
    param(
        [Parameter(Mandatory=$true)][string]$SourceInstanceId,
        [Parameter(Mandatory=$true)][string]$TargetInstanceId,
        [Parameter(Mandatory=$true)][string[]]$SessionIds,
        [bool]$Move = $false,
        [bool]$IncludeSubSessions = $true
    )

    if ($SourceInstanceId -eq $TargetInstanceId) {
        throw "Source and target instances must be different."
    }

    $srcInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $SourceInstanceId } | Select-Object -First 1
    $dstInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $TargetInstanceId } | Select-Object -First 1
    if (-not $srcInst -or -not $dstInst) {
        throw "Source or target instance not found."
    }

    $dstIdent = Resolve-InstanceIdentity -DataDir $dstInst.DataDir
    if ([string]::IsNullOrWhiteSpace($dstIdent.AccountUuid) -or [string]::IsNullOrWhiteSpace($dstIdent.OrgUuid)) {
        throw "Target instance ($($dstInst.DisplayName)) has no identified AccountUuid/OrgUuid yet. Sign in to that instance at least once before migrating sessions."
    }

    $allSrcSessions = @(Get-ClaudeInstanceSessions -InstanceId $SourceInstanceId -ForceRefresh)
    $selectedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $SessionIds) { [void]$selectedSet.Add($id) }

    if ($IncludeSubSessions) {
        foreach ($s in $allSrcSessions) {
            if ($s.ParentSessionId -and $selectedSet.Contains($s.ParentSessionId)) {
                [void]$selectedSet.Add($s.SessionId)
            }
        }
    }

    $toTransfer = @($allSrcSessions | Where-Object { $selectedSet.Contains($_.SessionId) })
    if ($toTransfer.Count -eq 0) {
        return [PSCustomObject]@{
            Transferred       = 0
            FoldersAuthorized = 0
            BackupPath        = ""
        }
    }

    $transferredCount = 0
    $cwdsToAuthorize = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    $srcNotesRoot = Join-Path $srcInst.DataDir "side-session-notes"
    $dstNotesRoot = Join-Path $dstInst.DataDir "side-session-notes"

    foreach ($sess in $toTransfer) {
        $baseFolderName = if ($sess.Kind -eq "Cowork") { "local-agent-mode-sessions" } else { "claude-code-sessions" }
        $dstFolder = Join-Path $dstInst.DataDir "$baseFolderName\$($dstIdent.AccountUuid)\$($dstIdent.OrgUuid)"
        if (-not (Test-Path $dstFolder)) {
            New-Item -ItemType Directory -Path $dstFolder -Force | Out-Null
        }

        $dstFile = Join-Path $dstFolder $sess.FileName
        Copy-Item -Path $sess.FullPath -Destination $dstFile -Force

        $srcNoteDir = Join-Path $srcNotesRoot $sess.SessionId
        if (Test-Path $srcNoteDir) {
            if (-not (Test-Path $dstNotesRoot)) {
                New-Item -ItemType Directory -Path $dstNotesRoot -Force | Out-Null
            }
            $dstNoteDir = Join-Path $dstNotesRoot $sess.SessionId
            if (Test-Path $dstNoteDir) {
                Remove-Item -Path $dstNoteDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -Path $srcNoteDir -Destination $dstNoteDir -Recurse -Force
            if ($Move) {
                Remove-Item -Path $srcNoteDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        if ($Move) {
            Remove-Item -Path $sess.FullPath -Force -ErrorAction SilentlyContinue
        }

        if (-not [string]::IsNullOrWhiteSpace($sess.Cwd)) {
            [void]$cwdsToAuthorize.Add($sess.Cwd)
        }
        $transferredCount++
    }

    Authorize-ClaudeInstanceFolders -InstanceDir $dstInst.DataDir -AccountUuid $dstIdent.AccountUuid -Cwds $cwdsToAuthorize

    Clear-ClaudeSessionCache -InstanceId $SourceInstanceId
    Clear-ClaudeSessionCache -InstanceId $TargetInstanceId

    return [PSCustomObject]@{
        Transferred       = $transferredCount
        FoldersAuthorized = $cwdsToAuthorize.Count
        BackupPath        = ""
    }
}

function Authorize-ClaudeInstanceFolders([string]$InstanceDir, [string]$AccountUuid, [System.Collections.Generic.IEnumerable[string]]$Cwds) {
    $dstCfgPath = Join-Path $InstanceDir "claude_desktop_config.json"
    Ensure-UniqueConfigFile -FilePath $dstCfgPath
    $cfgObj = @{}
    if (Test-Path $dstCfgPath) {
        try {
            $parsed = Get-Content $dstCfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $parsed.PSObject.Properties) { $cfgObj[$p.Name] = $p.Value }
        } catch {}
    }
    if (-not $cfgObj["preferences"]) {
        $cfgObj["preferences"] = [PSCustomObject]@{}
    }
    $prefs = $cfgObj["preferences"]
    if (-not [string]::IsNullOrWhiteSpace($AccountUuid) -and $AccountUuid -ne "Unauthenticated" -and $AccountUuid -ne "Não autenticado") {
        $permKey = "epitaxy-folder-permission-mode-v2.$AccountUuid"
        if (-not $prefs.PSObject.Properties[$permKey]) {
            $prefs | Add-Member -NotePropertyName $permKey -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        $permMap = $prefs.PSObject.Properties[$permKey].Value
        foreach ($cwd in $Cwds) {
            if (-not [string]::IsNullOrWhiteSpace($cwd)) {
                $permMap | Add-Member -NotePropertyName $cwd -NotePropertyValue "bypassPermissions" -Force
            }
        }
    }

    if (-not $prefs.PSObject.Properties["localAgentMode.sessionListDisplayPrefs"]) {
        $prefs | Add-Member -NotePropertyName "localAgentMode.sessionListDisplayPrefs" -NotePropertyValue ([PSCustomObject]@{ groupBy = "folder" }) -Force
    } else {
        $prefs.PSObject.Properties["localAgentMode.sessionListDisplayPrefs"].Value | Add-Member -NotePropertyName "groupBy" -NotePropertyValue "folder" -Force
    }

    $outJson = $cfgObj | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($dstCfgPath, $outJson, (New-Object System.Text.UTF8Encoding($false)))
}

function Find-ClaudeCliTranscriptFile([string]$CliSessionId, [string]$Cwd) {
    if ([string]::IsNullOrWhiteSpace($CliSessionId)) { return $null }
    $projectsRoot = Join-Path $env:USERPROFILE ".claude\projects"
    if (-not (Test-Path $projectsRoot)) { return $null }

    if (-not [string]::IsNullOrWhiteSpace($Cwd)) {
        $enc = ConvertTo-ClaudeEncodedPath -Path $Cwd
        $candidate = Join-Path $projectsRoot "$enc\$CliSessionId.jsonl"
        if (Test-Path $candidate) { return $candidate }
    }

    $found = Get-ChildItem -Path $projectsRoot -Filter "$CliSessionId.jsonl" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Convert-ClaudeJsonlToReadable([string]$JsonlPath, [string]$Title, [string]$Cwd, [string]$Model, [string]$SessionId) {
    $mdSb = New-Object System.Text.StringBuilder
    $htmlSb = New-Object System.Text.StringBuilder

    [void]$mdSb.AppendLine("# $Title")
    [void]$mdSb.AppendLine("")
    [void]$mdSb.AppendLine("- **Project Path:** $Cwd")
    [void]$mdSb.AppendLine("- **Model:** $Model")
    [void]$mdSb.AppendLine("- **Session ID:** $SessionId")
    [void]$mdSb.AppendLine("")
    [void]$mdSb.AppendLine("---")
    [void]$mdSb.AppendLine("")

    $safeTitle = [System.Web.HttpUtility]::HtmlEncode($Title)
    $safeCwd = [System.Web.HttpUtility]::HtmlEncode($Cwd)
    $safeModel = [System.Web.HttpUtility]::HtmlEncode($Model)

    [void]$htmlSb.AppendLine(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$safeTitle — Claude Code Transcript</title>
<style>
  body { background: #0f0f12; color: #f4f4f5; font-family: 'Segoe UI', system-ui, sans-serif; margin: 0; padding: 24px; line-height: 1.55; }
  .container { max-width: 960px; margin: 0 auto; }
  .header { background: #18181b; border: 1px solid #27272a; border-left: 4px solid #d97757; border-radius: 10px; padding: 18px 22px; margin-bottom: 24px; }
  .header h1 { margin: 0 0 8px 0; font-size: 20px; color: #ffffff; }
  .meta { color: #a1a1aa; font-size: 12px; }
  .turn { background: #18181b; border: 1px solid #27272a; border-radius: 10px; padding: 16px 20px; margin-bottom: 16px; }
  .turn.user { border-left: 4px solid #2563eb; }
  .turn.assistant { border-left: 4px solid #10b981; }
  .role { font-weight: 700; font-size: 13px; margin-bottom: 8px; display: flex; justify-content: space-between; }
  .role.user { color: #60a5fa; }
  .role.assistant { color: #34d399; }
  .timestamp { color: #71717a; font-weight: 400; font-size: 11px; }
  pre, code { font-family: Consolas, 'Cascadia Code', monospace; background: #09090b; border-radius: 6px; }
  pre { padding: 12px; overflow-x: auto; border: 1px solid #27272a; white-space: pre-wrap; word-wrap: break-word; }
  details { background: #121215; border: 1px solid #27272a; border-radius: 6px; padding: 8px 12px; margin: 8px 0; }
  summary { cursor: pointer; color: #a1a1aa; font-size: 12px; font-weight: 600; }
  .msg-text { white-space: pre-wrap; word-wrap: break-word; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>$safeTitle</h1>
    <div class="meta">Project: <strong>$safeCwd</strong> &nbsp;|&nbsp; Model: <strong>$safeModel</strong> &nbsp;|&nbsp; Session: <strong>$SessionId</strong></div>
  </div>
"@)

    if (Test-Path $JsonlPath) {
        foreach ($line in [System.IO.File]::ReadLines($JsonlPath, [System.Text.Encoding]::UTF8)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -notmatch '"type"\s*:\s*"(user|assistant)"') { continue }
            try {
                $obj = $line | ConvertFrom-Json
                if ($obj.type -ne "user" -and $obj.type -ne "assistant") { continue }
                if (-not $obj.message) { continue }

                $roleName = if ($obj.type -eq "user") { "User" } else { "Claude" }
                $roleClass = $obj.type
                $ts = if ($obj.timestamp) { [string]$obj.timestamp } else { "" }

                $contentBlocks = @()
                if ($obj.message.content -is [string]) {
                    $contentBlocks += [PSCustomObject]@{ Kind = "text"; Text = [string]$obj.message.content }
                } elseif ($obj.message.content -is [System.Collections.IEnumerable]) {
                    foreach ($blk in $obj.message.content) {
                        if ($blk -is [string]) {
                            $contentBlocks += [PSCustomObject]@{ Kind = "text"; Text = $blk }
                        } elseif ($blk.type -eq "text" -and $blk.text) {
                            $contentBlocks += [PSCustomObject]@{ Kind = "text"; Text = [string]$blk.text }
                        } elseif ($blk.type -eq "thinking" -and $blk.thinking) {
                            $contentBlocks += [PSCustomObject]@{ Kind = "thinking"; Text = [string]$blk.thinking }
                        } elseif ($blk.type -eq "tool_use") {
                            $inJson = try { $blk.input | ConvertTo-Json -Compress -Depth 5 } catch { "" }
                            $contentBlocks += [PSCustomObject]@{ Kind = "tool"; Text = "Tool: $($blk.name)`nInput: $inJson" }
                        }
                    }
                }

                if ($contentBlocks.Count -eq 0) { continue }

                [void]$mdSb.AppendLine("### $roleName $(if ($ts) { "($ts)" })")
                [void]$mdSb.AppendLine("")

                [void]$htmlSb.AppendLine("<div class='turn $roleClass'>")
                [void]$htmlSb.AppendLine("  <div class='role $roleClass'><span>$roleName</span><span class='timestamp'>$([System.Web.HttpUtility]::HtmlEncode($ts))</span></div>")

                foreach ($cb in $contentBlocks) {
                    $encText = [System.Web.HttpUtility]::HtmlEncode($cb.Text)
                    if ($cb.Kind -eq "thinking") {
                        [void]$mdSb.AppendLine("<details><summary>Thinking</summary>`n`n$($cb.Text)`n</details>`n")
                        [void]$htmlSb.AppendLine("  <details><summary>Thinking Process</summary><pre>$encText</pre></details>")
                    } elseif ($cb.Kind -eq "tool") {
                        [void]$mdSb.AppendLine("``````text`n$($cb.Text)`n```````n")
                        [void]$htmlSb.AppendLine("  <details><summary>Tool Invocation</summary><pre>$encText</pre></details>")
                    } else {
                        [void]$mdSb.AppendLine("$($cb.Text)`n")
                        [void]$htmlSb.AppendLine("  <div class='msg-text'>$encText</div>")
                    }
                }

                [void]$htmlSb.AppendLine("</div>")
            } catch {}
        }
    } else {
        [void]$mdSb.AppendLine("_No CLI JSONL transcript found on this machine for session $SessionId._")
        [void]$htmlSb.AppendLine("<div class='turn'><div class='msg-text'>No CLI JSONL transcript found on this machine for session $SessionId.</div></div>")
    }

    [void]$htmlSb.AppendLine("</div></body></html>")

    return [PSCustomObject]@{
        Markdown = $mdSb.ToString()
        Html     = $htmlSb.ToString()
    }
}

function Export-ClaudeSessionReadableTranscript {
    param(
        [Parameter(Mandatory=$true)][string]$InstanceId,
        [Parameter(Mandatory=$true)][string]$SessionId,
        [string]$OutputDirectory = "",
        [switch]$OpenInBrowser
    )

    $sessions = @(Get-ClaudeInstanceSessions -InstanceId $InstanceId)
    $sess = $sessions | Where-Object { $_.SessionId -eq $SessionId } | Select-Object -First 1
    if (-not $sess) { throw "Session not found: $SessionId" }

    $jsonlPath = Find-ClaudeCliTranscriptFile -CliSessionId $sess.CliSessionId -Cwd $sess.Cwd
    $rendered = Convert-ClaudeJsonlToReadable -JsonlPath $jsonlPath -Title $sess.Title -Cwd $sess.Cwd -Model $sess.Model -SessionId $sess.SessionId

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $env:TEMP "CIM-Transcripts"
    }
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $safeName = ($sess.Title -replace '[^a-zA-Z0-9_-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = $sess.SessionId }
    if ($safeName.Length -gt 50) { $safeName = $safeName.Substring(0, 50) }

    $htmlPath = Join-Path $OutputDirectory "$safeName.html"
    $mdPath = Join-Path $OutputDirectory "$safeName.md"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($htmlPath, $rendered.Html, $utf8NoBom)
    [System.IO.File]::WriteAllText($mdPath, $rendered.Markdown, $utf8NoBom)

    if ($OpenInBrowser) {
        Start-Process $htmlPath
    }

    return [PSCustomObject]@{
        HtmlPath = $htmlPath
        MdPath   = $mdPath
    }
}

function Copy-FilteredWorkspaceDirectory([string]$SourceDir, [string]$DestDir) {
    if (-not (Test-Path $SourceDir)) { return }
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    $excludedDirs = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($d in @(".git", "node_modules", "bin", "obj", ".vs", "dist", "build", "__pycache__", ".venv", "venv", ".next", "target", "packages")) {
        [void]$excludedDirs.Add($d)
    }

    foreach ($item in Get-ChildItem -Path $SourceDir -Force -ErrorAction SilentlyContinue) {
        if ($item.PSIsContainer) {
            if ($excludedDirs.Contains($item.Name)) { continue }
            Copy-FilteredWorkspaceDirectory -SourceDir $item.FullName -DestDir (Join-Path $DestDir $item.Name)
        } else {
            # Skip huge binary artifacts > 50 MB
            if ($item.Length -le 52428800) {
                Copy-Item -Path $item.FullName -Destination (Join-Path $DestDir $item.Name) -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Export-ClaudePortablePack {
    param(
        [Parameter(Mandatory=$true)][string]$SourceInstanceId,
        [Parameter(Mandatory=$true)][string[]]$SessionIds,
        [Parameter(Mandatory=$true)][string]$OutputFilePath,
        [bool]$IncludeWorkspaceFiles = $false,
        [bool]$IncludeSubSessions = $true
    )

    $srcInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $SourceInstanceId } | Select-Object -First 1
    if (-not $srcInst) { throw "Source instance not found: $SourceInstanceId" }

    $allSessions = @(Get-ClaudeInstanceSessions -InstanceId $SourceInstanceId -ForceRefresh)
    $selectedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in $SessionIds) { [void]$selectedSet.Add($id) }

    if ($IncludeSubSessions) {
        foreach ($s in $allSessions) {
            if ($s.ParentSessionId -and $selectedSet.Contains($s.ParentSessionId)) {
                [void]$selectedSet.Add($s.SessionId)
            }
        }
    }

    $toExport = @($allSessions | Where-Object { $selectedSet.Contains($_.SessionId) })
    if ($toExport.Count -eq 0) { throw "No matching sessions found to export." }

    $stageDir = Join-Path $env:TEMP "cim_pack_export_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

    try {
        $sessionsDir = Join-Path $stageDir "sessions"
        $notesStage = Join-Path $stageDir "side-session-notes"
        $globalStage = Join-Path $stageDir "claude-global"
        $readableStage = Join-Path $stageDir "transcripts-readable"
        $workspaceStage = Join-Path $stageDir "workspace-files"

        foreach ($d in @($sessionsDir, $notesStage, $globalStage, $readableStage)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }

        $srcNotesRoot = Join-Path $srcInst.DataDir "side-session-notes"
        $claudeRoot = Join-Path $env:USERPROFILE ".claude"
        $projectsMap = @{}
        $manifestSessions = @()
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

        foreach ($sess in $toExport) {
            $kindDir = Join-Path $sessionsDir $sess.Kind
            if (-not (Test-Path $kindDir)) { New-Item -ItemType Directory -Path $kindDir -Force | Out-Null }
            Copy-Item -Path $sess.FullPath -Destination (Join-Path $kindDir $sess.FileName) -Force

            # Side notes
            $sNote = Join-Path $srcNotesRoot $sess.SessionId
            if (Test-Path $sNote) {
                Copy-Item -Path $sNote -Destination (Join-Path $notesStage $sess.SessionId) -Recurse -Force
            }

            $encCwd = ConvertTo-ClaudeEncodedPath -Path $sess.Cwd

            # Global .claude/projects/<encoded-cwd> artifacts
            if (-not [string]::IsNullOrWhiteSpace($sess.CliSessionId)) {
                $jsonlFile = Find-ClaudeCliTranscriptFile -CliSessionId $sess.CliSessionId -Cwd $sess.Cwd
                if ($jsonlFile -and (Test-Path $jsonlFile)) {
                    $projDir = Split-Path -Parent $jsonlFile
                    $actualEncName = Split-Path -Leaf $projDir
                    if ([string]::IsNullOrWhiteSpace($encCwd)) { $encCwd = $actualEncName }

                    $dstProjStage = Join-Path $globalStage "projects\$encCwd"
                    if (-not (Test-Path $dstProjStage)) {
                        New-Item -ItemType Directory -Path $dstProjStage -Force | Out-Null
                    }

                    Copy-Item -Path $jsonlFile -Destination (Join-Path $dstProjStage "$($sess.CliSessionId).jsonl") -Force

                    $subFolder = Join-Path $projDir $sess.CliSessionId
                    if (Test-Path $subFolder) {
                        Copy-Item -Path $subFolder -Destination (Join-Path $dstProjStage $sess.CliSessionId) -Recurse -Force
                    }

                    $memFolder = Join-Path $projDir "memory"
                    $dstMemFolder = Join-Path $dstProjStage "memory"
                    if ((Test-Path $memFolder) -and -not (Test-Path $dstMemFolder)) {
                        Copy-Item -Path $memFolder -Destination $dstMemFolder -Recurse -Force
                    }

                    # Readable HTML & MD transcripts
                    $rendered = Convert-ClaudeJsonlToReadable -JsonlPath $jsonlFile -Title $sess.Title -Cwd $sess.Cwd -Model $sess.Model -SessionId $sess.SessionId
                    $safeFile = (($sess.ProjectName + "-" + $sess.Title) -replace '[^a-zA-Z0-9_-]', '_').Trim('_')
                    if ($safeFile.Length -gt 60) { $safeFile = $safeFile.Substring(0, 60) }
                    $safeFile = "$safeFile-$($sess.SessionId.Substring([Math]::Max(0, $sess.SessionId.Length - 6)))"
                    [System.IO.File]::WriteAllText((Join-Path $readableStage "$safeFile.html"), $rendered.Html, $utf8NoBom)
                    [System.IO.File]::WriteAllText((Join-Path $readableStage "$safeFile.md"), $rendered.Markdown, $utf8NoBom)
                }

                # file-history & session-env
                foreach ($auxFolder in @("file-history", "session-env")) {
                    $srcAux = Join-Path $claudeRoot "$auxFolder\$($sess.CliSessionId)"
                    if (Test-Path $srcAux) {
                        $dstAuxParent = Join-Path $globalStage $auxFolder
                        if (-not (Test-Path $dstAuxParent)) { New-Item -ItemType Directory -Path $dstAuxParent -Force | Out-Null }
                        Copy-Item -Path $srcAux -Destination (Join-Path $dstAuxParent $sess.CliSessionId) -Recurse -Force
                    }
                }
            }

            $isScratch = ($sess.Cwd -match 'scratch-workspaces')
            $shouldPackWorkspace = ($IncludeWorkspaceFiles -or $isScratch) -and (-not [string]::IsNullOrWhiteSpace($sess.Cwd)) -and (Test-Path $sess.Cwd)

            if (-not [string]::IsNullOrWhiteSpace($sess.Cwd)) {
                if (-not $projectsMap.ContainsKey($sess.Cwd)) {
                    if ($shouldPackWorkspace) {
                        $dstWs = Join-Path $workspaceStage $encCwd
                        Copy-FilteredWorkspaceDirectory -SourceDir $sess.Cwd -DestDir $dstWs
                    }
                    $projectsMap[$sess.Cwd] = @{
                        originalCwd       = $sess.Cwd
                        encodedCwd        = $encCwd
                        projectName       = $sess.ProjectName
                        isScratch         = $isScratch
                        hasWorkspaceFiles = $shouldPackWorkspace
                        sessionCount      = 1
                    }
                } else {
                    $projectsMap[$sess.Cwd].sessionCount++
                }
            }

            $manifestSessions += @{
                sessionId      = $sess.SessionId
                cliSessionId   = $sess.CliSessionId
                fileName       = $sess.FileName
                kind           = $sess.Kind
                title          = $sess.Title
                originalCwd    = $sess.Cwd
                encodedCwd     = $encCwd
                projectName    = $sess.ProjectName
                model          = $sess.Model
                lastActivityAt = $sess.LastActivityAt
            }
        }

        $manifest = @{
            schemaVersion  = 1
            exportedAt     = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            sourceMachine  = $env:COMPUTERNAME
            sourceInstance = $srcInst.DisplayName
            projects       = @($projectsMap.Values)
            sessions       = $manifestSessions
        }

        $manifestPath = Join-Path $stageDir "cim-manifest.json"
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), $utf8NoBom)

        $outParent = Split-Path -Parent $OutputFilePath
        if (-not (Test-Path $outParent)) { New-Item -ItemType Directory -Path $outParent -Force | Out-Null }
        if (Test-Path $OutputFilePath) { Remove-Item -Path $OutputFilePath -Force }

        [System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $OutputFilePath)
    } finally {
        Remove-Item -Path $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    return [PSCustomObject]@{
        OutputFilePath = $OutputFilePath
        SessionCount   = $toExport.Count
        ProjectCount   = $projectsMap.Count
    }
}

function Read-ClaudePortablePack([string]$PackPath) {
    if (-not (Test-Path $PackPath)) { throw "Package file not found: $PackPath" }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($PackPath)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq "cim-manifest.json" } | Select-Object -First 1
        if (-not $entry) {
            throw "Invalid .cimpack archive: cim-manifest.json not found."
        }
        $sr = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::UTF8)
        $json = $sr.ReadToEnd()
        $sr.Close()
        return ($json | ConvertFrom-Json)
    } finally {
        $zip.Dispose()
    }
}

function Rewrite-JsonPathReferences([string]$JsonText, [string]$OldPath, [string]$NewPath) {
    if ([string]::IsNullOrWhiteSpace($OldPath) -or [string]::IsNullOrWhiteSpace($NewPath) -or ($OldPath -eq $NewPath)) {
        return $JsonText
    }
    $oldEscaped = $OldPath.Replace('\', '\\')
    $newEscaped = $NewPath.Replace('\', '\\')
    $updated = $JsonText.Replace($oldEscaped, $newEscaped)
    # Also replace forward-slash variant if present
    $oldSlash = $OldPath.Replace('\', '/')
    $newSlash = $NewPath.Replace('\', '/')
    $updated = $updated.Replace($oldSlash, $newSlash)
    return $updated
}

function Import-ClaudePortablePack {
    param(
        [Parameter(Mandatory=$true)][string]$PackPath,
        [Parameter(Mandatory=$true)][string]$TargetInstanceId,
        [hashtable]$PathMappings = @{},
        [bool]$ExtractWorkspaceFiles = $true
    )

    if (-not (Test-Path $PackPath)) { throw "Package file not found: $PackPath" }

    $dstInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $TargetInstanceId } | Select-Object -First 1
    if (-not $dstInst) { throw "Target instance not found: $TargetInstanceId" }

    $dstIdent = Resolve-InstanceIdentity -DataDir $dstInst.DataDir
    if ([string]::IsNullOrWhiteSpace($dstIdent.AccountUuid) -or [string]::IsNullOrWhiteSpace($dstIdent.OrgUuid)) {
        throw "Target instance ($($dstInst.DisplayName)) has no AccountUuid/OrgUuid. Sign in to that instance at least once before importing."
    }

    $stageDir = Join-Path $env:TEMP "cim_pack_import_$([guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($PackPath, $stageDir)
        $manifestFile = Join-Path $stageDir "cim-manifest.json"
        if (-not (Test-Path $manifestFile)) { throw "Invalid .cimpack file: missing cim-manifest.json" }

        $manifest = Get-Content $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $claudeRoot = Join-Path $env:USERPROFILE ".claude"
        $cwdsAuthorized = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $importedSessions = 0

        # Resolve effective CWD mapping for each project
        $effectiveMap = @{}
        if ($manifest.projects) {
            foreach ($proj in $manifest.projects) {
                $orig = [string]$proj.originalCwd
                $enc = [string]$proj.encodedCwd
                $newPath = $orig

                if ($PathMappings -and $PathMappings.ContainsKey($orig) -and -not [string]::IsNullOrWhiteSpace($PathMappings[$orig])) {
                    $newPath = [string]$PathMappings[$orig]
                } elseif ($orig -match 'scratch-workspaces') {
                    $leaf = Split-Path -Leaf $orig
                    $newPath = Join-Path $dstInst.DataDir "scratch-workspaces\$($dstIdent.AccountUuid)\$($dstIdent.OrgUuid)\$leaf"
                }

                $effectiveMap[$orig] = $newPath

                # Extract packaged workspace files if present and requested
                $wsStage = Join-Path $stageDir "workspace-files\$enc"
                if ($ExtractWorkspaceFiles -and (Test-Path $wsStage) -and -not [string]::IsNullOrWhiteSpace($newPath)) {
                    if (-not (Test-Path $newPath)) {
                        New-Item -ItemType Directory -Path $newPath -Force | Out-Null
                    }
                    Copy-Item -Path (Join-Path $wsStage "*") -Destination $newPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        foreach ($sess in $manifest.sessions) {
            $origCwd = [string]$sess.originalCwd
            $encCwd = [string]$sess.encodedCwd
            $targetCwd = if ($effectiveMap.ContainsKey($origCwd)) { $effectiveMap[$origCwd] } else { $origCwd }
            $newEncCwd = ConvertTo-ClaudeEncodedPath -Path $targetCwd

            # 1. Import Desktop session JSON
            $srcSessJsonPath = Join-Path $stageDir "sessions\$($sess.kind)\$($sess.fileName)"
            if (Test-Path $srcSessJsonPath) {
                $baseFolder = if ($sess.kind -eq "Cowork") { "local-agent-mode-sessions" } else { "claude-code-sessions" }
                $dstFolder = Join-Path $dstInst.DataDir "$baseFolder\$($dstIdent.AccountUuid)\$($dstIdent.OrgUuid)"
                if (-not (Test-Path $dstFolder)) {
                    New-Item -ItemType Directory -Path $dstFolder -Force | Out-Null
                }

                $jsonContent = [System.IO.File]::ReadAllText($srcSessJsonPath, [System.Text.Encoding]::UTF8)
                $jsonContent = Rewrite-JsonPathReferences -JsonText $jsonContent -OldPath $origCwd -NewPath $targetCwd
                [System.IO.File]::WriteAllText((Join-Path $dstFolder $sess.fileName), $jsonContent, $utf8NoBom)
                $importedSessions++
            }

            # 2. Import side-session-notes
            $srcNotes = Join-Path $stageDir "side-session-notes\$($sess.sessionId)"
            if (Test-Path $srcNotes) {
                $dstNotesRoot = Join-Path $dstInst.DataDir "side-session-notes"
                if (-not (Test-Path $dstNotesRoot)) { New-Item -ItemType Directory -Path $dstNotesRoot -Force | Out-Null }
                $dstNoteDir = Join-Path $dstNotesRoot $sess.sessionId
                if (Test-Path $dstNoteDir) { Remove-Item -Path $dstNoteDir -Recurse -Force -ErrorAction SilentlyContinue }
                Copy-Item -Path $srcNotes -Destination $dstNoteDir -Recurse -Force
            }

            # 3. Import global ~/.claude/projects/<new-encoded-cwd> transcript, subagents, and memory
            if (-not [string]::IsNullOrWhiteSpace($encCwd)) {
                $srcGlobalProj = Join-Path $stageDir "claude-global\projects\$encCwd"
                if (Test-Path $srcGlobalProj) {
                    $dstGlobalProj = Join-Path $claudeRoot "projects\$newEncCwd"
                    if (-not (Test-Path $dstGlobalProj)) {
                        New-Item -ItemType Directory -Path $dstGlobalProj -Force | Out-Null
                    }

                    if (-not [string]::IsNullOrWhiteSpace($sess.cliSessionId)) {
                        $srcJsonl = Join-Path $srcGlobalProj "$($sess.cliSessionId).jsonl"
                        if (Test-Path $srcJsonl) {
                            $jsonlText = [System.IO.File]::ReadAllText($srcJsonl, [System.Text.Encoding]::UTF8)
                            $jsonlText = Rewrite-JsonPathReferences -JsonText $jsonlText -OldPath $origCwd -NewPath $targetCwd
                            [System.IO.File]::WriteAllText((Join-Path $dstGlobalProj "$($sess.cliSessionId).jsonl"), $jsonlText, $utf8NoBom)
                        }

                        $srcSubDir = Join-Path $srcGlobalProj $sess.cliSessionId
                        if (Test-Path $srcSubDir) {
                            $dstSubDir = Join-Path $dstGlobalProj $sess.cliSessionId
                            if (Test-Path $dstSubDir) { Remove-Item -Path $dstSubDir -Recurse -Force -ErrorAction SilentlyContinue }
                            Copy-Item -Path $srcSubDir -Destination $dstSubDir -Recurse -Force
                        }
                    }

                    $srcMem = Join-Path $srcGlobalProj "memory"
                    if (Test-Path $srcMem) {
                        $dstMem = Join-Path $dstGlobalProj "memory"
                        if (-not (Test-Path $dstMem)) { New-Item -ItemType Directory -Path $dstMem -Force | Out-Null }
                        Copy-Item -Path (Join-Path $srcMem "*") -Destination $dstMem -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # 4. Import file-history & session-env
            if (-not [string]::IsNullOrWhiteSpace($sess.cliSessionId)) {
                foreach ($aux in @("file-history", "session-env")) {
                    $srcAux = Join-Path $stageDir "claude-global\$aux\$($sess.cliSessionId)"
                    if (Test-Path $srcAux) {
                        $dstAuxParent = Join-Path $claudeRoot $aux
                        if (-not (Test-Path $dstAuxParent)) { New-Item -ItemType Directory -Path $dstAuxParent -Force | Out-Null }
                        $dstAux = Join-Path $dstAuxParent $sess.cliSessionId
                        if (Test-Path $dstAux) { Remove-Item -Path $dstAux -Recurse -Force -ErrorAction SilentlyContinue }
                        Copy-Item -Path $srcAux -Destination $dstAux -Recurse -Force
                    }
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($targetCwd)) {
                [void]$cwdsAuthorized.Add($targetCwd)
            }
        }

        Authorize-ClaudeInstanceFolders -InstanceDir $dstInst.DataDir -AccountUuid $dstIdent.AccountUuid -Cwds $cwdsAuthorized
        Clear-ClaudeSessionCache -InstanceId $TargetInstanceId

        return [PSCustomObject]@{
            ImportedSessions  = $importedSessions
            FoldersAuthorized = $cwdsAuthorized.Count
        }
    } finally {
        Remove-Item -Path $stageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
