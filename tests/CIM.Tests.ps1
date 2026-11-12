$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SrcDir = Join-Path $ProjectRoot "src"

$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "=== Running CIM Automated Tests (v1.1.0) ===" -ForegroundColor Cyan

# --- Task 1: Core-Instances.ps1 & Native Engine ---
$coreInstancesPath = Join-Path $SrcDir "Core-Instances.ps1"
Assert-True (Test-Path $coreInstancesPath) "Task 1: src/Core-Instances.ps1 exists"
if (Test-Path $coreInstancesPath) {
    . $coreInstancesPath

    $primaryDir = Get-PrimaryClaudeDataDir
    Assert-True (-not [string]::IsNullOrWhiteSpace($primaryDir)) "Task 1: Get-PrimaryClaudeDataDir resolves path ($primaryDir)"

    $exePath = Get-ClaudeExePath
    Assert-True (-not [string]::IsNullOrWhiteSpace($exePath)) "Task 1: Get-ClaudeExePath resolves executable ($exePath)"

    $swInst = [System.Diagnostics.Stopwatch]::StartNew()
    $instances = @(Get-ClaudeInstances)
    $swInst.Stop()
    Assert-True ($instances.Count -ge 1) "Task 1: Get-ClaudeInstances discovers instances ($($instances.Count) in $($swInst.ElapsedMilliseconds) ms)"
    $primaryInst = $instances | Where-Object { $_.IsPrimary } | Select-Object -First 1
    Assert-True ($null -ne $primaryInst) "Task 1: Primary instance identified ($($primaryInst.DisplayName))"

    $tempDir = Join-Path $env:TEMP "cim_test_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        $f1 = Join-Path $tempDir "orig.json"
        $f2 = Join-Path $tempDir "linked.json"
        '{"test":1}' | Set-Content -Path $f1 -Encoding UTF8
        [CIMNative.HardLink]::CreateHardLink($f2, $f1, [IntPtr]::Zero) | Out-Null
        Ensure-UniqueConfigFile -FilePath $f2
        '{"test":2}' | Set-Content -Path $f2 -Encoding UTF8
        $c1 = (Get-Content $f1 -Raw).Trim()
        $c2 = (Get-Content $f2 -Raw).Trim()
        Assert-True ($c1 -eq '{"test":1}' -and $c2 -eq '{"test":2}') "Task 1: Ensure-UniqueConfigFile detaches hardlinked JSON before edit"

        $icoPath = Join-Path $tempDir "test-badge.ico"
        New-ClaudeBadgeIcon -OutputIcoPath $icoPath -BadgeText "T1" -BadgeColorHex "#10B981"
        Assert-True ((Test-Path $icoPath) -and ((Get-Item $icoPath).Length -gt 500)) "Task 1: New-ClaudeBadgeIcon generates valid multi-res .ico file"
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Task 2: Core-Sessions.ps1 (Fast C# Scanner + Portable .cimpack Export/Import) ---
$coreSessionsPath = Join-Path $SrcDir "Core-Sessions.ps1"
if (Test-Path $coreSessionsPath) {
    . $coreSessionsPath
    $swSess = [System.Diagnostics.Stopwatch]::StartNew()
    $primarySessions = @(Get-ClaudeInstanceSessions -InstanceId "Primary" -ForceRefresh)
    $swSess.Stop()
    Assert-True ($null -ne $primarySessions) "Task 2: FastSessionScanner scanned $($primarySessions.Count) sessions in $($swSess.ElapsedMilliseconds) ms"
    Assert-True ($swSess.ElapsedMilliseconds -lt 1000) "Task 2: FastSessionScanner completed under 1000 ms ($($swSess.ElapsedMilliseconds) ms)"

    if ($primarySessions.Count -gt 0) {
        $testPackFile = Join-Path $env:TEMP "cim_test_pack_$([guid]::NewGuid().ToString('N')).cimpack"
        try {
            $sampleSid = $primarySessions[0].SessionId
            $expRes = Export-ClaudePortablePack -SourceInstanceId "Primary" -SessionIds @($sampleSid) -OutputFilePath $testPackFile -IncludeWorkspaceFiles $false -IncludeSubSessions $false
            Assert-True ((Test-Path $testPackFile) -and $expRes.SessionCount -ge 1) "Task 2: Export-ClaudePortablePack creates valid .cimpack archive"

            $manifest = Read-ClaudePortablePack -PackPath $testPackFile
            Assert-True ($manifest.schemaVersion -eq 1 -and $manifest.sessions.Count -ge 1) "Task 2: Read-ClaudePortablePack parses cim-manifest.json"
        } finally {
            Remove-Item -Path $testPackFile -Force -ErrorAction SilentlyContinue
        }
    }

    # Test .gitignore filtering in Copy-FilteredWorkspaceDirectory
    $wsSrc = Join-Path $env:TEMP "cim_gitignore_src_$([guid]::NewGuid().ToString('N'))"
    $wsDst = Join-Path $env:TEMP "cim_gitignore_dst_$([guid]::NewGuid().ToString('N'))"
    try {
        New-Item -ItemType Directory -Path (Join-Path $wsSrc "src") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $wsSrc "custom_ignored_dir") -Force | Out-Null
        "*.secret`ncustom_ignored_dir/`nignored_file.txt" | Set-Content -Path (Join-Path $wsSrc ".gitignore") -Encoding UTF8
        "keep" | Set-Content -Path (Join-Path $wsSrc "src\main.ps1") -Encoding UTF8
        "drop1" | Set-Content -Path (Join-Path $wsSrc "api.secret") -Encoding UTF8
        "drop2" | Set-Content -Path (Join-Path $wsSrc "ignored_file.txt") -Encoding UTF8
        "drop3" | Set-Content -Path (Join-Path $wsSrc "custom_ignored_dir\temp.dat") -Encoding UTF8

        Copy-FilteredWorkspaceDirectory -SourceDir $wsSrc -DestDir $wsDst
        $keptMain = Test-Path (Join-Path $wsDst "src\main.ps1")
        $droppedSecret = -not (Test-Path (Join-Path $wsDst "api.secret"))
        $droppedTxt = -not (Test-Path (Join-Path $wsDst "ignored_file.txt"))
        $droppedDir = -not (Test-Path (Join-Path $wsDst "custom_ignored_dir"))
        Assert-True ($keptMain -and $droppedSecret -and $droppedTxt -and $droppedDir) "Task 2: Copy-FilteredWorkspaceDirectory respects .gitignore rules"
    } finally {
        Remove-Item -Path $wsSrc -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $wsDst -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Task 3: Core-ProtocolRouter.ps1 ---
$coreProtoPath = Join-Path $SrcDir "Core-ProtocolRouter.ps1"
if (Test-Path $coreProtoPath) {
    . $coreProtoPath
    $protoStatus = Get-ClaudeProtocolStatus
    Assert-True ($null -ne $protoStatus) "Task 3: Get-ClaudeProtocolStatus resolves protocol state (ProgId=$($protoStatus.ProgId))"
}

# --- Task 4: Core-SettingsBackup.ps1 ---
$coreSettingsPath = Join-Path $SrcDir "Core-SettingsBackup.ps1"
if (Test-Path $coreSettingsPath) {
    . $coreSettingsPath
    $policy = Get-ClaudeUpdatePolicy
    Assert-True ($policy.DeploymentMode -eq "1p") "Task 4: Get-ClaudeUpdatePolicy reads 1p deploymentMode (Mode=$($policy.Mode))"
}

# --- Task 5: Main WPF GUI XAML Check ---
$mainGuiPath = Join-Path $ProjectRoot "Claude-Instance-Manager.ps1"
if (Test-Path $mainGuiPath) {
    $checkOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $mainGuiPath -CheckOnly 2>&1
    Assert-True ($LASTEXITCODE -eq 0 -and ($checkOut -join " ") -match "CIM_GUI_OK") "Task 5: Claude-Instance-Manager.ps1 -CheckOnly validates XAML & bindings"
}

Write-Host "`n=== Summary: $passed passed, $failed failed ===" -ForegroundColor Cyan
if ($failed -gt 0) { exit 1 }
