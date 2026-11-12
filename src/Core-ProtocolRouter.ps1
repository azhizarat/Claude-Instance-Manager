# Core-ProtocolRouter.ps1 — claude:// Protocol Interceptor & Dispatcher

Initialize-CIMNativeEngine

$script:ProtocolVbsPath = Join-Path $PSScriptRoot "Launch-ProtocolPopup.vbs"
$script:DefaultDelegateExecute = "{A56A841F-E974-45C1-8001-7E3F8A085917}"

function Get-ClaudeAppXProgId {
    $progId = [CIMNative.Assoc]::Query(20, "claude")
    if (-not [string]::IsNullOrWhiteSpace($progId) -and (Test-Path "HKCU:\Software\Classes\$progId")) {
        return $progId
    }
    # Fallback scan in HKCU:\Software\Classes\AppX*
    $found = Get-ChildItem "HKCU:\Software\Classes" -Filter "AppX*" -ErrorAction SilentlyContinue | ForEach-Object {
        $openKey = Join-Path $_.PSPath "Shell\open"
        $p = Get-ItemProperty $openKey -ErrorAction SilentlyContinue
        if ($p -and $p.AppUserModelID -match "Claude" -and $p.ContractId -eq "Windows.Protocol") {
            return $_.PSChildName
        }
    } | Select-Object -First 1
    return [string]$found
}

function Get-ClaudeProtocolStatus {
    $state = Get-CIMState
    $progId = Get-ClaudeAppXProgId
    $isIntercepted = $false
    $currentCmd = ""
    $delegateExec = ""

    if (-not [string]::IsNullOrWhiteSpace($progId)) {
        $cmdKey = "HKCU:\Software\Classes\$progId\Shell\open\command"
        if (Test-Path $cmdKey) {
            $props = Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue
            if ($props.'(default)') { $currentCmd = [string]$props.'(default)' }
            if ($props.DelegateExecute) { $delegateExec = [string]$props.DelegateExecute }
            if ($currentCmd -match "Launch-ProtocolPopup\.vbs|Protocol-Popup\.ps1" -and [string]::IsNullOrWhiteSpace($delegateExec)) {
                $isIntercepted = $true
            }
        }
    }

    $armedId = [string]$state.protocol.armedLoginInstanceId
    $armedExp = 0
    if ($state.protocol.armedLoginExpiresAt) {
        [void][int64]::TryParse([string]$state.protocol.armedLoginExpiresAt, [ref]$armedExp)
    }
    $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    if ($armedExp -le $nowMs) {
        $armedId = ""
    }

    return [PSCustomObject]@{
        ProgId               = $progId
        IsIntercepted        = $isIntercepted
        CurrentCommand       = $currentCmd
        DelegateExecute      = $delegateExec
        Mode                 = if ($state.protocol.mode) { [string]$state.protocol.mode } else { "ask" }
        PinnedInstanceId     = if ($state.protocol.pinnedInstanceId) { [string]$state.protocol.pinnedInstanceId } else { "Primary" }
        ArmedLoginInstanceId = $armedId
    }
}

function Enable-ClaudeProtocolIntercept([string]$Mode = "ask", [string]$PinnedInstanceId = "Primary") {
    $state = Get-CIMState
    $state.protocol.mode = $Mode
    $state.protocol.pinnedInstanceId = $PinnedInstanceId

    $progId = Get-ClaudeAppXProgId
    $expectedCmd = "`"C:\Windows\System32\wscript.exe`" `"$script:ProtocolVbsPath`" `"%1`""

    if (-not [string]::IsNullOrWhiteSpace($progId)) {
        $cmdKey = "HKCU:\Software\Classes\$progId\Shell\open\command"
        if (-not (Test-Path $cmdKey)) {
            New-Item -Path $cmdKey -Force | Out-Null
        }
        $existing = Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue
        if ($existing -and $existing.DelegateExecute) {
            $state.protocol.backupDelegateExecute = [string]$existing.DelegateExecute
        }
        Set-ItemProperty -Path $cmdKey -Name "(default)" -Value $expectedCmd
        Remove-ItemProperty -Path $cmdKey -Name "DelegateExecute" -ErrorAction SilentlyContinue
    }

    # Also set fallback HKCU:\Software\Classes\claude\shell\open\command
    $fallbackKey = "HKCU:\Software\Classes\claude\shell\open\command"
    if (-not (Test-Path $fallbackKey)) {
        New-Item -Path $fallbackKey -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Classes\claude" -Name "(default)" -Value "URL:claude" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Classes\claude" -Name "URL Protocol" -Value "" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $fallbackKey -Name "(default)" -Value $expectedCmd

    Save-CIMState -State $state
    return Get-ClaudeProtocolStatus
}

function Disable-ClaudeProtocolIntercept {
    $state = Get-CIMState
    $progId = Get-ClaudeAppXProgId
    $delegate = if ($state.protocol.backupDelegateExecute) { [string]$state.protocol.backupDelegateExecute } else { $script:DefaultDelegateExecute }

    if (-not [string]::IsNullOrWhiteSpace($progId)) {
        $cmdKey = "HKCU:\Software\Classes\$progId\Shell\open\command"
        if (Test-Path $cmdKey) {
            Set-ItemProperty -Path $cmdKey -Name "DelegateExecute" -Value $delegate
            Remove-ItemProperty -Path $cmdKey -Name "(default)" -ErrorAction SilentlyContinue
        }
    }

    $fallbackKey = "HKCU:\Software\Classes\claude\shell\open\command"
    if (Test-Path $fallbackKey) {
        Remove-Item -Path "HKCU:\Software\Classes\claude\shell" -Recurse -Force -ErrorAction SilentlyContinue
    }

    $state.protocol.armedLoginInstanceId = ""
    $state.protocol.armedLoginExpiresAt = ""
    Save-CIMState -State $state
    return Get-ClaudeProtocolStatus
}

function Set-ClaudeLoginTarget([string]$InstanceId, [int]$MinutesValid = 15) {
    $state = Get-CIMState
    $expMs = [DateTimeOffset]::UtcNow.AddMinutes($MinutesValid).ToUnixTimeMilliseconds()
    $state.protocol.armedLoginInstanceId = $InstanceId
    $state.protocol.armedLoginExpiresAt = [string]$expMs
    Save-CIMState -State $state

    $status = Get-ClaudeProtocolStatus
    if (-not $status.IsIntercepted) {
        Enable-ClaudeProtocolIntercept -Mode $state.protocol.mode -PinnedInstanceId $state.protocol.pinnedInstanceId | Out-Null
    }
}

function Clear-ClaudeLoginTarget {
    $state = Get-CIMState
    $state.protocol.armedLoginInstanceId = ""
    $state.protocol.armedLoginExpiresAt = ""
    Save-CIMState -State $state
}

function Send-ClaudeProtocolUrl([string]$InstanceId, [string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url) -or ($Url -notmatch "^claude://")) {
        throw "URL inválida. Deve começar com claude://"
    }
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) {
        throw "Instância não encontrada: $InstanceId"
    }

    $exePath = Get-ClaudeExePath
    if ($inst.IsPrimary) {
        Start-Process -FilePath $exePath -ArgumentList "`"$Url`""
    } else {
        Sync-ClaudeInstanceLinks -TargetDir $inst.DataDir | Out-Null
        Start-Process -FilePath $exePath -ArgumentList "--user-data-dir=`"$($inst.DataDir)`" `"$Url`""
    }
}
