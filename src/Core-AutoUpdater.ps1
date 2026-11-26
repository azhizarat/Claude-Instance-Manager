# Core-AutoUpdater.ps1 — GitHub Release Auto-Updater for Claude Instance Manager (CIM)

$script:CIMGitHubRepo = "azhizarat/Claude-Instance-Manager"
$script:CIMLatestReleaseApi = "https://api.github.com/repos/$script:CIMGitHubRepo/releases/latest"

function Get-CIMCurrentVersion {
    if ($script:CIMVersion) { return $script:CIMVersion }
    return "1.3.0"
}

function Test-CIMUpdateAvailable {
    $currStr = (Get-CIMCurrentVersion).TrimStart('v', 'V')
    $currVer = [version]"1.0.0"
    [void][version]::TryParse($currStr, [ref]$currVer)

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{
            "User-Agent" = "Claude-Instance-Manager/$currStr"
            "Accept"     = "application/vnd.github+json"
        }
        $resp = Invoke-RestMethod -Uri $script:CIMLatestReleaseApi -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        if (-not $resp -or -not $resp.tag_name) {
            return [PSCustomObject]@{
                CurrentVersion    = $currStr
                LatestVersion     = $currStr
                IsUpdateAvailable = $false
                ExeDownloadUrl    = ""
                ZipDownloadUrl    = ""
                ReleaseUrl        = ""
            }
        }

        $latestStr = ([string]$resp.tag_name).TrimStart('v', 'V')
        $latestVer = [version]"1.0.0"
        [void][version]::TryParse($latestStr, [ref]$latestVer)

        $exeAsset = $resp.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
        $zipAsset = $resp.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

        return [PSCustomObject]@{
            CurrentVersion    = $currStr
            LatestVersion     = $latestStr
            IsUpdateAvailable = ($latestVer -gt $currVer)
            ExeDownloadUrl    = if ($exeAsset) { [string]$exeAsset.browser_download_url } else { "" }
            ZipDownloadUrl    = if ($zipAsset) { [string]$zipAsset.browser_download_url } else { "" }
            ReleaseUrl        = [string]$resp.html_url
        }
    } catch {
        return [PSCustomObject]@{
            CurrentVersion    = $currStr
            LatestVersion     = $currStr
            IsUpdateAvailable = $false
            ExeDownloadUrl    = ""
            ZipDownloadUrl    = ""
            ReleaseUrl        = ""
        }
    }
}

function Install-CIMSelfUpdate {
    param(
        [Parameter(Mandatory=$true)]$UpdateInfo,
        [Parameter(Mandatory=$true)][string]$AppRootDir
    )

    if ([string]::IsNullOrWhiteSpace($UpdateInfo.ExeDownloadUrl)) {
        throw "Executable asset URL not found in GitHub release."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tempDir = Join-Path $env:TEMP "cim_self_update_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $tempExe = Join-Path $tempDir "Claude-Instance-Manager.exe"
    Invoke-WebRequest -Uri $UpdateInfo.ExeDownloadUrl -OutFile $tempExe -UseBasicParsing -TimeoutSec 30

    if (-not (Test-Path $tempExe) -or ((Get-Item $tempExe).Length -lt 10240)) {
        throw "Downloaded executable is invalid or incomplete."
    }

    # If portable ZIP is also available, update local .ps1 files in AppRootDir and %LOCALAPPDATA%\Claude-Instances\Manager
    if (-not [string]::IsNullOrWhiteSpace($UpdateInfo.ZipDownloadUrl)) {
        try {
            $tempZip = Join-Path $tempDir "update.zip"
            Invoke-WebRequest -Uri $UpdateInfo.ZipDownloadUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 30
            $extractDir = Join-Path $tempDir "extracted"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $extractDir)

            foreach ($destRoot in @($AppRootDir, (Join-Path $env:LOCALAPPDATA "Claude-Instances\Manager"))) {
                if (Test-Path (Join-Path $destRoot "Claude-Instance-Manager.ps1")) {
                    Copy-Item -Path (Join-Path $extractDir "Claude-Instance-Manager.ps1") -Destination $destRoot -Force -ErrorAction SilentlyContinue
                    if (Test-Path (Join-Path $extractDir "src")) {
                        Copy-Item -Path (Join-Path $extractDir "src\*") -Destination (Join-Path $destRoot "src") -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {}
    }

    $targetExe = Join-Path $AppRootDir "Claude-Instance-Manager.exe"
    if (-not (Test-Path $targetExe)) {
        $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Claude Instance Manager.lnk"
        if (Test-Path $desktopShortcut) {
            try {
                $wsh = New-Object -ComObject WScript.Shell
                $sc = $wsh.CreateShortcut($desktopShortcut)
                if ($sc.TargetPath -like "*.exe") { $targetExe = $sc.TargetPath }
            } catch {}
        }
    }

    $cmdFile = Join-Path $tempDir "apply-update.cmd"
    $cmdScript = @"
@echo off
ping 127.0.0.1 -n 2 > nul
copy /Y "$tempExe" "$targetExe" > nul
start "" "$targetExe"
"@
    [System.IO.File]::WriteAllText($cmdFile, $cmdScript, [System.Text.Encoding]::ASCII)
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$cmdFile`"" -WindowStyle Hidden
    return $true
}
