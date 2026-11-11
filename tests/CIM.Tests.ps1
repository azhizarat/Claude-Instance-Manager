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

Write-Host "=== Running CIM Automated Tests ===" -ForegroundColor Cyan

# --- Task 1: Core-Instances.ps1 ---
$coreInstancesPath = Join-Path $SrcDir "Core-Instances.ps1"
Assert-True (Test-Path $coreInstancesPath) "Task 1: src/Core-Instances.ps1 exists"
if (Test-Path $coreInstancesPath) {
    . $coreInstancesPath

    $primaryDir = Get-PrimaryClaudeDataDir
    Assert-True (-not [string]::IsNullOrWhiteSpace($primaryDir)) "Task 1: Get-PrimaryClaudeDataDir resolves path ($primaryDir)"

    $exePath = Get-ClaudeExePath
    Assert-True (-not [string]::IsNullOrWhiteSpace($exePath)) "Task 1: Get-ClaudeExePath resolves executable ($exePath)"

    $instances = @(Get-ClaudeInstances)
    Assert-True ($instances.Count -ge 1) "Task 1: Get-ClaudeInstances discovers instances (found $($instances.Count))"
    $primaryInst = $instances | Where-Object { $_.IsPrimary } | Select-Object -First 1
    Assert-True ($null -ne $primaryInst) "Task 1: Primary instance identified ($($primaryInst.DisplayName))"

    # Test Ensure-UniqueConfigFile breaks hardlinks on config files
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

# --- Task 2: Core-Sessions.ps1 ---
$coreSessionsPath = Join-Path $SrcDir "Core-Sessions.ps1"
if (Test-Path $coreSessionsPath) {
    . $coreSessionsPath
    $primarySessions = @(Get-ClaudeInstanceSessions -InstanceId "Primary")
    Assert-True ($null -ne $primarySessions) "Task 2: Get-ClaudeInstanceSessions executes cleanly (found $($primarySessions.Count) in Primary)"
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
