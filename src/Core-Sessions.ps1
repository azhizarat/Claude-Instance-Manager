# Core-Sessions.ps1 — Project & Session Discovery, Copy/Clone & Move across Claude Instances

function Get-ClaudeInstanceSessions([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { return @() }

    $sessions = @()
    $roots = @(
        @{ Kind = "Code";   Path = (Join-Path $inst.DataDir "claude-code-sessions") },
        @{ Kind = "Cowork"; Path = (Join-Path $inst.DataDir "local-agent-mode-sessions") }
    )

    $sideNotesRoot = Join-Path $inst.DataDir "side-session-notes"

    foreach ($r in $roots) {
        if (-not (Test-Path $r.Path)) { continue }
        $files = Get-ChildItem -Path $r.Path -Filter "local_*.json" -Recurse -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $raw = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $sid = if ($raw.sessionId) { [string]$raw.sessionId } else { $f.BaseName }
                $cwd = if ($raw.cwd) { [string]$raw.cwd } else { "" }
                $projName = if (-not [string]::IsNullOrWhiteSpace($cwd)) { Split-Path -Leaf $cwd } else { "(Geral / Sem Pasta)" }
                $title = if ($raw.title) { [string]$raw.title } else { $sid }
                $model = if ($raw.model) { [string]$raw.model } else { "default" }
                $lastAct = if ($raw.lastActivityAt) { [int64]$raw.lastActivityAt } else { 0 }
                $lastDateStr = if ($lastAct -gt 0) {
                    ([DateTimeOffset]::FromUnixTimeMilliseconds($lastAct)).LocalDateTime.ToString("dd/MM/yyyy HH:mm")
                } else {
                    $f.LastWriteTime.ToString("dd/MM/yyyy HH:mm")
                }
                $parentSid = if ($raw.parentSessionId) { [string]$raw.parentSessionId } else { "" }
                $isArchived = [bool]($raw.isArchived -eq $true)
                $hasNotes = Test-Path (Join-Path $sideNotesRoot $sid)

                # Extract accountUuid / orgUuid from parent path
                $orgDir = $f.Directory
                $accDir = if ($orgDir) { $orgDir.Parent } else { $null }

                $prefix = if ($parentSid) { "  ↳ " } else { "" }
                $notesTag = if ($hasNotes) { " [Notas]" } else { "" }

                $sessions += [PSCustomObject]@{
                    SessionId             = $sid
                    FileName              = $f.Name
                    FullPath              = $f.FullName
                    Kind                  = $r.Kind
                    Title                 = $title
                    Cwd                   = $cwd
                    ProjectName           = $projName
                    Model                 = $model
                    LastActivityAt        = $lastAct
                    LastActivityFormatted = $lastDateStr
                    ParentSessionId       = $parentSid
                    HasSideNotes          = $hasNotes
                    IsArchived            = $isArchived
                    AccountUuid           = if ($accDir) { $accDir.Name } else { "" }
                    OrgUuid               = if ($orgDir) { $orgDir.Name } else { "" }
                    DisplayLabel          = "[$projName] $prefix$title ($lastDateStr)$notesTag"
                }
            } catch {}
        }
    }

    return @($sessions | Sort-Object @{Expression="ProjectName"; Ascending=$true}, @{Expression="LastActivityAt"; Descending=$true})
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
        throw "A instância de origem e de destino devem ser diferentes."
    }

    $srcInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $SourceInstanceId } | Select-Object -First 1
    $dstInst = Get-ClaudeInstances | Where-Object { $_.Id -eq $TargetInstanceId } | Select-Object -First 1
    if (-not $srcInst -or -not $dstInst) {
        throw "Instância de origem ou destino não encontrada."
    }

    $dstIdent = Resolve-InstanceIdentity -DataDir $dstInst.DataDir
    if ([string]::IsNullOrWhiteSpace($dstIdent.AccountUuid) -or [string]::IsNullOrWhiteSpace($dstIdent.OrgUuid)) {
        throw "A instância de destino ($($dstInst.DisplayName)) ainda não possui AccountUuid/OrgUuid identificado. Faça login nela ao menos uma vez antes de migrar sessões."
    }

    $allSrcSessions = @(Get-ClaudeInstanceSessions -InstanceId $SourceInstanceId)
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

        # Copy side-session-notes if present
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

    # Update target claude_desktop_config.json with folder permissions & groupBy: folder
    $dstCfgPath = Join-Path $dstInst.DataDir "claude_desktop_config.json"
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
    $permKey = "epitaxy-folder-permission-mode-v2.$($dstIdent.AccountUuid)"
    if (-not $prefs.PSObject.Properties[$permKey]) {
        $prefs | Add-Member -NotePropertyName $permKey -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    $permMap = $prefs.PSObject.Properties[$permKey].Value
    foreach ($cwd in $cwdsToAuthorize) {
        $permMap | Add-Member -NotePropertyName $cwd -NotePropertyValue "bypassPermissions" -Force
    }

    if (-not $prefs.PSObject.Properties["localAgentMode.sessionListDisplayPrefs"]) {
        $prefs | Add-Member -NotePropertyName "localAgentMode.sessionListDisplayPrefs" -NotePropertyValue ([PSCustomObject]@{ groupBy = "folder" }) -Force
    } else {
        $prefs.PSObject.Properties["localAgentMode.sessionListDisplayPrefs"].Value | Add-Member -NotePropertyName "groupBy" -NotePropertyValue "folder" -Force
    }

    $outJson = $cfgObj | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($dstCfgPath, $outJson, (New-Object System.Text.UTF8Encoding($false)))

    return [PSCustomObject]@{
        Transferred       = $transferredCount
        FoldersAuthorized = $cwdsToAuthorize.Count
        BackupPath        = ""
    }
}
