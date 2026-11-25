# Core-Metrics.ps1 — Token Usage, USD Cost FinOps, Prompt Cache Savings, Multi-Dimensional Filtering & Executive HTML/CSV Exporter

Add-Type -AssemblyName System.Web

$script:CachedRawTurnRecords = $null
$script:CachedSessionLookup = $null

function Get-DefaultClaudeModelPricing {
    return @{
        "opus"   = @{ InputPerM = 15.00; OutputPerM = 75.00; CacheWritePerM = 18.75; CacheReadPerM = 1.50 }
        "fable"  = @{ InputPerM = 15.00; OutputPerM = 75.00; CacheWritePerM = 18.75; CacheReadPerM = 1.50 }
        "sonnet" = @{ InputPerM = 3.00;  OutputPerM = 15.00; CacheWritePerM = 3.75;  CacheReadPerM = 0.30 }
        "haiku"  = @{ InputPerM = 1.00;  OutputPerM = 5.00;  CacheWritePerM = 1.25;  CacheReadPerM = 0.10 }
    }
}

function Get-ClaudeModelPricingTable {
    $st = Get-CIMState
    $defaults = Get-DefaultClaudeModelPricing
    if ($st.ContainsKey("pricing") -and $st["pricing"]) {
        foreach ($tier in @("opus", "fable", "sonnet", "haiku")) {
            $custom = $st["pricing"][$tier]
            if ($custom) {
                if ($null -ne $custom.InputPerM)      { $defaults[$tier].InputPerM      = [double]$custom.InputPerM }
                if ($null -ne $custom.OutputPerM)     { $defaults[$tier].OutputPerM     = [double]$custom.OutputPerM }
                if ($null -ne $custom.CacheWritePerM) { $defaults[$tier].CacheWritePerM = [double]$custom.CacheWritePerM }
                if ($null -ne $custom.CacheReadPerM)  { $defaults[$tier].CacheReadPerM  = [double]$custom.CacheReadPerM }
            }
        }
    }
    return $defaults
}

function Save-ClaudeModelPricingTable([hashtable]$PricingTable) {
    $st = Get-CIMState
    $st["pricing"] = $PricingTable
    Save-CIMState -State $st
}

function Resolve-ModelTierRates([string]$ModelName, [hashtable]$PricingTable) {
    $m = if ($ModelName) { $ModelName.ToLower() } else { "" }
    if ($m -match "opus")   { return $PricingTable["opus"] }
    if ($m -match "fable")  { return $PricingTable["fable"] }
    if ($m -match "haiku")  { return $PricingTable["haiku"] }
    if ($m -match "sonnet") { return $PricingTable["sonnet"] }
    return $PricingTable["sonnet"]
}

function Format-TokenCount([int64]$Tokens) {
    if ($Tokens -ge 1000000000) {
        return ("{0:N2} B" -f ($Tokens / 1000000000.0))
    } elseif ($Tokens -ge 1000000) {
        return ("{0:N2} M" -f ($Tokens / 1000000.0))
    } elseif ($Tokens -ge 1000) {
        return ("{0:N1} K" -f ($Tokens / 1000.0))
    }
    return "$Tokens"
}

function Build-SessionInstanceLookup([switch]$ForceRefresh) {
    if (-not $ForceRefresh -and $null -ne $script:CachedSessionLookup) {
        return $script:CachedSessionLookup
    }

    $byCliId = @{}
    $byCwd = @{}
    $instances = @(Get-ClaudeInstances)

    foreach ($inst in $instances) {
        $sessions = @(Get-ClaudeInstanceSessions -InstanceId $inst.Id -ForceRefresh:$ForceRefresh)
        foreach ($s in $sessions) {
            $entry = [PSCustomObject]@{
                InstanceId   = $inst.Id
                InstanceName = $inst.DisplayName
                SessionId    = $s.SessionId
                CliSessionId = $s.CliSessionId
                Title        = $s.Title
                ProjectName  = $s.ProjectName
                Cwd          = $s.Cwd
            }
            if (-not [string]::IsNullOrWhiteSpace($s.CliSessionId)) {
                $byCliId[$s.CliSessionId] = $entry
            }
            if (-not [string]::IsNullOrWhiteSpace($s.Cwd) -and -not $byCwd.ContainsKey($s.Cwd)) {
                $byCwd[$s.Cwd] = $entry
            }
        }
    }

    $script:CachedSessionLookup = @{
        ByCliId = $byCliId
        ByCwd   = $byCwd
    }
    return $script:CachedSessionLookup
}

function Get-RawClaudeTurnRecords([switch]$ForceRefresh) {
    if (-not $ForceRefresh -and $null -ne $script:CachedRawTurnRecords) {
        return $script:CachedRawTurnRecords
    }

    Initialize-CIMNativeEngine
    $projectsRoot = Join-Path $env:USERPROFILE ".claude\projects"
    $raw = [CIMNative.FastMetricsScanner]::ScanAllProjects($projectsRoot)
    $lookup = Build-SessionInstanceLookup -ForceRefresh:$ForceRefresh

    $enriched = New-Object 'System.Collections.Generic.List[PSCustomObject]'
    foreach ($r in $raw) {
        $instId = "CLI"
        $instName = "CLI / Terminal"
        $projName = ""
        $sessTitle = $r.CliSessionId
        $cwd = $r.Cwd

        if (-not [string]::IsNullOrWhiteSpace($r.CliSessionId) -and $lookup.ByCliId.ContainsKey($r.CliSessionId)) {
            $m = $lookup.ByCliId[$r.CliSessionId]
            $instId = $m.InstanceId
            $instName = $m.InstanceName
            $projName = $m.ProjectName
            $sessTitle = $m.Title
            if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = $m.Cwd }
        } elseif (-not [string]::IsNullOrWhiteSpace($cwd) -and $lookup.ByCwd.ContainsKey($cwd)) {
            $m = $lookup.ByCwd[$cwd]
            $instId = $m.InstanceId
            $instName = $m.InstanceName
            $projName = $m.ProjectName
        }

        if ([string]::IsNullOrWhiteSpace($projName)) {
            if (-not [string]::IsNullOrWhiteSpace($cwd)) {
                if ($cwd -match 'scratch-workspaces') {
                    $projName = "(Scratch Workspace)"
                } else {
                    $trimmed = $cwd.TrimEnd('\', '/')
                    $projName = Split-Path -Leaf $trimmed
                }
            } else {
                $projName = $r.EncodedProjectDir
            }
        }

        $tCount = if ($r.TurnCount -gt 0) { [int]$r.TurnCount } else { 1 }
        $enriched.Add([PSCustomObject]@{
            TurnCount        = $tCount
            CliSessionId     = $r.CliSessionId
            SessionTitle     = $sessTitle
            InstanceId       = $instId
            InstanceName     = $instName
            ProjectName      = $projName
            Cwd              = $cwd
            IsSubagent       = $r.IsSubagent
            DateLocal        = $r.DateLocal
            Model            = $r.Model
            InputTokens      = [int64]$r.InputTokens
            OutputTokens     = [int64]$r.OutputTokens
            ThinkingTokens   = [int64]$r.ThinkingTokens
            CacheReadTokens  = [int64]$r.CacheReadTokens
            CacheWriteTokens = [int64]$r.CacheWriteTokens
            TotalTokens      = [int64]($r.InputTokens + $r.OutputTokens + $r.CacheReadTokens + $r.CacheWriteTokens)
        })
    }

    $script:CachedRawTurnRecords = $enriched
    return $enriched
}

function Get-ClaudeMetricsFilterOptions([switch]$ForceRefresh) {
    $records = Get-RawClaudeTurnRecords -ForceRefresh:$ForceRefresh
    $projects = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $models = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

    foreach ($r in $records) {
        if (-not [string]::IsNullOrWhiteSpace($r.ProjectName)) { [void]$projects.Add($r.ProjectName) }
        if (-not [string]::IsNullOrWhiteSpace($r.Model))       { [void]$models.Add($r.Model) }
    }

    return [PSCustomObject]@{
        Projects = @($projects | Sort-Object)
        Models   = @($models | Sort-Object)
    }
}

function Get-ClaudeMetricsReport {
    param(
        [string]$Period = "30d",
        [string]$StartDate = "",
        [string]$EndDate = "",
        [string]$InstanceId = "ALL",
        [string]$ProjectName = "ALL",
        [string]$Model = "ALL",
        [bool]$IncludeSubagents = $true,
        [switch]$ForceRefresh
    )

    $records = Get-RawClaudeTurnRecords -ForceRefresh:$ForceRefresh
    $pricing = Get-ClaudeModelPricingTable

    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    $minDate = "0000-01-01"
    $maxDate = "9999-12-31"

    switch ($Period) {
        "today" {
            $minDate = $todayStr
            $maxDate = $todayStr
        }
        "7d" {
            $minDate = (Get-Date).AddDays(-6).ToString("yyyy-MM-dd")
            $maxDate = $todayStr
        }
        "30d" {
            $minDate = (Get-Date).AddDays(-29).ToString("yyyy-MM-dd")
            $maxDate = $todayStr
        }
        "month" {
            $now = Get-Date
            $minDate = (Get-Date -Year $now.Year -Month $now.Month -Day 1).ToString("yyyy-MM-dd")
            $maxDate = $todayStr
        }
        "custom" {
            if (-not [string]::IsNullOrWhiteSpace($StartDate)) { $minDate = $StartDate.Trim() }
            if (-not [string]::IsNullOrWhiteSpace($EndDate))   { $maxDate = $EndDate.Trim() }
        }
    }

    $totalIn = [int64]0
    $totalOut = [int64]0
    $totalThink = [int64]0
    $totalCRead = [int64]0
    $totalCWrite = [int64]0
    $totalTok = [int64]0
    $totalMsgs = 0
    $subagentMsgs = 0
    $totalCostUSD = [double]0.0
    $totalUncachedUSD = [double]0.0

    $projAgg = @{}
    $modelAgg = @{}
    $dayAgg = @{}
    $instAgg = @{}
    $sessAgg = @{}

    foreach ($r in $records) {
        if (-not $IncludeSubagents -and $r.IsSubagent) { continue }
        if ($r.DateLocal -lt $minDate -or $r.DateLocal -gt $maxDate) { continue }
        if ($InstanceId -ne "ALL" -and $r.InstanceId -ne $InstanceId) { continue }
        if ($ProjectName -ne "ALL" -and $r.ProjectName -ne $ProjectName) { continue }
        if ($Model -ne "ALL" -and $r.Model -ne $Model) { continue }

        $rates = Resolve-ModelTierRates -ModelName $r.Model -PricingTable $pricing
        $cost = (
            ($r.InputTokens      * $rates.InputPerM) +
            ($r.OutputTokens     * $rates.OutputPerM) +
            ($r.CacheWriteTokens * $rates.CacheWritePerM) +
            ($r.CacheReadTokens  * $rates.CacheReadPerM)
        ) / 1000000.0

        $uncached = (
            (($r.InputTokens + $r.CacheWriteTokens + $r.CacheReadTokens) * $rates.InputPerM) +
            ($r.OutputTokens * $rates.OutputPerM)
        ) / 1000000.0

        $savings = [Math]::Max(0.0, ($uncached - $cost))

        $tCount = [int]$r.TurnCount
        $totalIn += $r.InputTokens
        $totalOut += $r.OutputTokens
        $totalThink += $r.ThinkingTokens
        $totalCRead += $r.CacheReadTokens
        $totalCWrite += $r.CacheWriteTokens
        $totalTok += $r.TotalTokens
        $totalMsgs += $tCount
        if ($r.IsSubagent) { $subagentMsgs += $tCount }
        $totalCostUSD += $cost
        $totalUncachedUSD += $uncached

        # 1. Project Aggregation
        $pk = if ($r.ProjectName) { $r.ProjectName } else { "(Unknown)" }
        if (-not $projAgg.ContainsKey($pk)) {
            $projAgg[$pk] = @{
                ProjectName      = $pk
                Cwd              = $r.Cwd
                InstanceName     = $r.InstanceName
                Messages         = 0
                InputTokens      = [int64]0
                OutputTokens     = [int64]0
                CacheWriteTokens = [int64]0
                CacheReadTokens  = [int64]0
                TotalTokens      = [int64]0
                CostUSD          = [double]0.0
                SavingsUSD       = [double]0.0
            }
        }
        $pa = $projAgg[$pk]
        $pa.Messages += $tCount
        $pa.InputTokens += $r.InputTokens
        $pa.OutputTokens += $r.OutputTokens
        $pa.CacheWriteTokens += $r.CacheWriteTokens
        $pa.CacheReadTokens += $r.CacheReadTokens
        $pa.TotalTokens += $r.TotalTokens
        $pa.CostUSD += $cost
        $pa.SavingsUSD += $savings

        # 2. Model Aggregation
        $mk = if ($r.Model) { $r.Model } else { "unknown" }
        if (-not $modelAgg.ContainsKey($mk)) {
            $modelAgg[$mk] = @{
                Model            = $mk
                Messages         = 0
                InputTokens      = [int64]0
                OutputTokens     = [int64]0
                CacheWriteTokens = [int64]0
                CacheReadTokens  = [int64]0
                TotalTokens      = [int64]0
                CostUSD          = [double]0.0
                SavingsUSD       = [double]0.0
            }
        }
        $ma = $modelAgg[$mk]
        $ma.Messages += $tCount
        $ma.InputTokens += $r.InputTokens
        $ma.OutputTokens += $r.OutputTokens
        $ma.CacheWriteTokens += $r.CacheWriteTokens
        $ma.CacheReadTokens += $r.CacheReadTokens
        $ma.TotalTokens += $r.TotalTokens
        $ma.CostUSD += $cost
        $ma.SavingsUSD += $savings

        # 3. Daily Aggregation
        $dk = $r.DateLocal
        if (-not $dayAgg.ContainsKey($dk)) {
            $dayAgg[$dk] = @{
                Date        = $dk
                Messages    = 0
                InputTokens = [int64]0
                OutputTokens= [int64]0
                CacheTokens = [int64]0
                TotalTokens = [int64]0
                CostUSD     = [double]0.0
                SavingsUSD  = [double]0.0
            }
        }
        $da = $dayAgg[$dk]
        $da.Messages += $tCount
        $da.InputTokens += $r.InputTokens
        $da.OutputTokens += $r.OutputTokens
        $da.CacheTokens += ($r.CacheReadTokens + $r.CacheWriteTokens)
        $da.TotalTokens += $r.TotalTokens
        $da.CostUSD += $cost
        $da.SavingsUSD += $savings

        # 4. Instance Aggregation
        $ik = $r.InstanceName
        if (-not $instAgg.ContainsKey($ik)) {
            $instAgg[$ik] = @{
                InstanceName = $ik
                Messages     = 0
                TotalTokens  = [int64]0
                CostUSD      = [double]0.0
                SavingsUSD   = [double]0.0
            }
        }
        $ia = $instAgg[$ik]
        $ia.Messages += $tCount
        $ia.TotalTokens += $r.TotalTokens
        $ia.CostUSD += $cost
        $ia.SavingsUSD += $savings

        # 5. Session Aggregation
        $sk = if ($r.CliSessionId) { $r.CliSessionId } else { $pk }
        if (-not $sessAgg.ContainsKey($sk)) {
            $sessAgg[$sk] = @{
                CliSessionId = $sk
                Title        = $r.SessionTitle
                ProjectName  = $pk
                InstanceName = $r.InstanceName
                Model        = $mk
                LastDate     = $r.DateLocal
                Messages     = 0
                TotalTokens  = [int64]0
                CostUSD      = [double]0.0
                SavingsUSD   = [double]0.0
            }
        }
        $sa = $sessAgg[$sk]
        $sa.Messages += $tCount
        $sa.TotalTokens += $r.TotalTokens
        $sa.CostUSD += $cost
        $sa.SavingsUSD += $savings
        if ($r.DateLocal -gt $sa.LastDate) { $sa.LastDate = $r.DateLocal }
    }

    $totalSavingsUSD = [Math]::Max(0.0, ($totalUncachedUSD - $totalCostUSD))
    $totalInputPrompt = $totalIn + $totalCWrite + $totalCRead
    $cacheHitPct = if ($totalInputPrompt -gt 0) { [math]::Round(($totalCRead * 100.0) / $totalInputPrompt, 1) } else { 0.0 }

    $byProjectList = @($projAgg.Values | Sort-Object { $_.CostUSD } -Descending | ForEach-Object {
        $share = if ($totalCostUSD -gt 0) { [math]::Round(($_.CostUSD * 100.0) / $totalCostUSD, 1) } else { 0.0 }
        [PSCustomObject]@{
            ProjectName  = $_.ProjectName
            InstanceName = $_.InstanceName
            Messages     = $_.Messages
            InputFmt     = Format-TokenCount ($_.InputTokens + $_.CacheWriteTokens)
            CacheReadFmt = Format-TokenCount $_.CacheReadTokens
            OutputFmt    = Format-TokenCount $_.OutputTokens
            TotalFmt     = Format-TokenCount $_.TotalTokens
            TotalTokens  = $_.TotalTokens
            CostUSD      = [math]::Round($_.CostUSD, 2)
            CostFmt      = ("`${0:N2}" -f $_.CostUSD)
            SavingsFmt   = ("`${0:N2}" -f $_.SavingsUSD)
            SharePct     = "$share%"
        }
    })

    $byModelList = @($modelAgg.Values | Sort-Object { $_.CostUSD } -Descending | ForEach-Object {
        $share = if ($totalCostUSD -gt 0) { [math]::Round(($_.CostUSD * 100.0) / $totalCostUSD, 1) } else { 0.0 }
        [PSCustomObject]@{
            Model        = $_.Model
            Messages     = $_.Messages
            InputFmt     = Format-TokenCount ($_.InputTokens + $_.CacheWriteTokens)
            CacheReadFmt = Format-TokenCount $_.CacheReadTokens
            OutputFmt    = Format-TokenCount $_.OutputTokens
            TotalFmt     = Format-TokenCount $_.TotalTokens
            TotalTokens  = $_.TotalTokens
            CostUSD      = [math]::Round($_.CostUSD, 2)
            CostFmt      = ("`${0:N2}" -f $_.CostUSD)
            SavingsFmt   = ("`${0:N2}" -f $_.SavingsUSD)
            SharePct     = "$share%"
        }
    })

    $maxDayCost = 0.01
    foreach ($d in $dayAgg.Values) {
        if ($d.CostUSD -gt $maxDayCost) { $maxDayCost = $d.CostUSD }
    }

    $byDayList = @($dayAgg.Values | Sort-Object { $_.Date } -Descending | ForEach-Object {
        $blocks = [int][Math]::Round(($_.CostUSD / $maxDayCost) * 20)
        if ($blocks -lt 1 -and $_.TotalTokens -gt 0) { $blocks = 1 }
        $barStr = ("#" * $blocks).PadRight(20, ".")
        [PSCustomObject]@{
            Date        = $_.Date
            Messages    = $_.Messages
            InputFmt    = Format-TokenCount $_.InputTokens
            OutputFmt   = Format-TokenCount $_.OutputTokens
            CacheFmt    = Format-TokenCount $_.CacheTokens
            TotalFmt    = Format-TokenCount $_.TotalTokens
            TotalTokens = $_.TotalTokens
            CostUSD     = [math]::Round($_.CostUSD, 2)
            CostFmt     = ("`${0:N2}" -f $_.CostUSD)
            SavingsFmt  = ("`${0:N2}" -f $_.SavingsUSD)
            TrendBar    = $barStr
        }
    })

    $byInstanceList = @($instAgg.Values | Sort-Object { $_.CostUSD } -Descending | ForEach-Object {
        $share = if ($totalCostUSD -gt 0) { [math]::Round(($_.CostUSD * 100.0) / $totalCostUSD, 1) } else { 0.0 }
        [PSCustomObject]@{
            InstanceName = $_.InstanceName
            Messages     = $_.Messages
            TotalFmt     = Format-TokenCount $_.TotalTokens
            CostUSD      = [math]::Round($_.CostUSD, 2)
            CostFmt      = ("`${0:N2}" -f $_.CostUSD)
            SavingsFmt   = ("`${0:N2}" -f $_.SavingsUSD)
            SharePct     = "$share%"
        }
    })

    $bySessionList = @($sessAgg.Values | Sort-Object { $_.CostUSD } -Descending | Select-Object -First 100 | ForEach-Object {
        [PSCustomObject]@{
            Title        = $_.Title
            ProjectName  = $_.ProjectName
            InstanceName = $_.InstanceName
            Model        = $_.Model
            LastDate     = $_.LastDate
            Messages     = $_.Messages
            TotalFmt     = Format-TokenCount $_.TotalTokens
            CostUSD      = [math]::Round($_.CostUSD, 2)
            CostFmt      = ("`${0:N2}" -f $_.CostUSD)
            SavingsFmt   = ("`${0:N2}" -f $_.SavingsUSD)
        }
    })

    return [PSCustomObject]@{
        Summary = [PSCustomObject]@{
            TotalTokens        = $totalTok
            TotalTokensFmt     = Format-TokenCount $totalTok
            InputTokens        = $totalIn
            InputTokensFmt     = Format-TokenCount $totalIn
            OutputTokens       = $totalOut
            OutputTokensFmt    = Format-TokenCount $totalOut
            ThinkingTokens     = $totalThink
            ThinkingTokensFmt  = Format-TokenCount $totalThink
            CacheWriteTokens   = $totalCWrite
            CacheWriteFmt      = Format-TokenCount $totalCWrite
            CacheReadTokens    = $totalCRead
            CacheReadFmt       = Format-TokenCount $totalCRead
            TotalMessages      = $totalMsgs
            SubagentMessages   = $subagentMsgs
            TotalCostUSD       = [math]::Round($totalCostUSD, 2)
            TotalCostFmt       = ("`${0:N2}" -f $totalCostUSD)
            UncachedCostUSD    = [math]::Round($totalUncachedUSD, 2)
            UncachedCostFmt    = ("`${0:N2}" -f $totalUncachedUSD)
            CacheSavingsUSD    = [math]::Round($totalSavingsUSD, 2)
            CacheSavingsFmt    = ("`${0:N2}" -f $totalSavingsUSD)
            CacheHitRatePct    = "$cacheHitPct%"
            MinDate            = $minDate
            MaxDate            = $maxDate
        }
        ByProject  = $byProjectList
        ByModel    = $byModelList
        ByDay      = $byDayList
        ByInstance = $byInstanceList
        BySession  = $bySessionList
    }
}

function Export-ClaudeMetricsReport {
    param(
        [Parameter(Mandatory=$true)]$Report,
        [Parameter(Mandatory=$true)][string]$OutputDirectory,
        [switch]$OpenHtml
    )

    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $csvPath = Join-Path $OutputDirectory "CIM-Metrics-Projects-$ts.csv"
    $htmlPath = Join-Path $OutputDirectory "CIM-Executive-Report-$ts.html"

    # 1. Export CSV
    $Report.ByProject | Select-Object ProjectName,InstanceName,Messages,TotalTokens,TotalFmt,CostUSD,CostFmt,SavingsFmt,SharePct |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    # 2. Generate Executive Dark Mode HTML Report
    $s = $Report.Summary
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Claude Instance Manager — FinOps &amp; Token Usage Report</title>
<style>
  body { background: #0f0f12; color: #f4f4f5; font-family: 'Segoe UI', system-ui, sans-serif; margin: 0; padding: 28px; }
  .wrap { max-width: 1120px; margin: 0 auto; }
  .header { background: #18181b; border: 1px solid #27272a; border-left: 4px solid #d97757; border-radius: 10px; padding: 18px 24px; margin-bottom: 20px; }
  .header h1 { margin: 0 0 6px 0; font-size: 22px; }
  .sub { color: #a1a1aa; font-size: 13px; }
  .kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 24px; }
  .kpi { background: #18181b; border: 1px solid #27272a; border-radius: 10px; padding: 16px; }
  .kpi .lbl { color: #a1a1aa; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
  .kpi .val { font-size: 24px; font-weight: 700; margin: 6px 0 4px 0; }
  .kpi .hint { color: #71717a; font-size: 11px; }
  .section { background: #18181b; border: 1px solid #27272a; border-radius: 10px; padding: 18px 22px; margin-bottom: 20px; }
  .section h2 { margin: 0 0 14px 0; font-size: 16px; color: #e4e4e7; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 9px 10px; border-bottom: 1px solid #27272a; }
  th { color: #a1a1aa; font-weight: 600; background: #121215; }
  .right { text-align: right; }
  .bar-bg { background: #27272a; height: 8px; border-radius: 4px; width: 120px; display: inline-block; overflow: hidden; vertical-align: middle; margin-right: 8px; }
  .bar-fill { background: #d97757; height: 100%; }
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <h1>Claude Code &amp; Desktop — Token Usage &amp; FinOps Executive Report</h1>
    <div class="sub">Generated by Claude Instance Manager (CIM) on $(Get-Date -Format 'dd/MM/yyyy HH:mm')</div>
  </div>
  <div class="kpis">
    <div class="kpi">
      <div class="lbl">Estimated API Value (USD)</div>
      <div class="val" style="color:#d97757;">$($s.TotalCostFmt)</div>
      <div class="hint">Without Prompt Cache: $($s.UncachedCostFmt)</div>
    </div>
    <div class="kpi">
      <div class="lbl">Prompt Cache Savings</div>
      <div class="val" style="color:#10b981;">$($s.CacheSavingsFmt)</div>
      <div class="hint">Cache Hit Rate: $($s.CacheHitRatePct)</div>
    </div>
    <div class="kpi">
      <div class="lbl">Total Tokens Processed</div>
      <div class="val" style="color:#60a5fa;">$($s.TotalTokensFmt)</div>
      <div class="hint">Out: $($s.OutputTokensFmt) | Cache Read: $($s.CacheReadFmt)</div>
    </div>
    <div class="kpi">
      <div class="lbl">API Requests / Turns</div>
      <div class="val" style="color:#f4f4f5;">$($s.TotalMessages)</div>
      <div class="hint">Subagent Turns: $($s.SubagentMessages)</div>
    </div>
  </div>
"@)

    # By Project Table
    [void]$sb.AppendLine("<div class='section'><h2>Usage and Cost by Project</h2><table><thead><tr><th>Project</th><th>Instance</th><th class='right'>Turns</th><th class='right'>Input / Cache Write</th><th class='right'>Cache Read</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost (USD)</th><th class='right'>Cache Saved</th><th class='right'>Share</th></tr></thead><tbody>")
    foreach ($p in $Report.ByProject) {
        [void]$sb.AppendLine("<tr><td><strong>$([System.Web.HttpUtility]::HtmlEncode($p.ProjectName))</strong></td><td>$([System.Web.HttpUtility]::HtmlEncode($p.InstanceName))</td><td class='right'>$($p.Messages)</td><td class='right'>$($p.InputFmt)</td><td class='right'>$($p.CacheReadFmt)</td><td class='right'>$($p.OutputFmt)</td><td class='right'>$($p.TotalFmt)</td><td class='right'><strong>$($p.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($p.SavingsFmt)</td><td class='right'>$($p.SharePct)</td></tr>")
    }
    [void]$sb.AppendLine("</tbody></table></div>")

    # By Model Table
    [void]$sb.AppendLine("<div class='section'><h2>Usage and Cost by Model</h2><table><thead><tr><th>Model</th><th class='right'>Turns</th><th class='right'>Input / Cache Write</th><th class='right'>Cache Read</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost (USD)</th><th class='right'>Cache Saved</th><th class='right'>Share</th></tr></thead><tbody>")
    foreach ($m in $Report.ByModel) {
        [void]$sb.AppendLine("<tr><td><strong>$([System.Web.HttpUtility]::HtmlEncode($m.Model))</strong></td><td class='right'>$($m.Messages)</td><td class='right'>$($m.InputFmt)</td><td class='right'>$($m.CacheReadFmt)</td><td class='right'>$($m.OutputFmt)</td><td class='right'>$($m.TotalFmt)</td><td class='right'><strong>$($m.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($m.SavingsFmt)</td><td class='right'>$($m.SharePct)</td></tr>")
    }
    [void]$sb.AppendLine("</tbody></table></div>")

    # By Day Table
    [void]$sb.AppendLine("<div class='section'><h2>Daily Consumption Timeline</h2><table><thead><tr><th>Date</th><th class='right'>Turns</th><th class='right'>Input</th><th class='right'>Cache</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost (USD)</th><th class='right'>Cache Saved</th></tr></thead><tbody>")
    foreach ($d in $Report.ByDay) {
        [void]$sb.AppendLine("<tr><td><strong>$($d.Date)</strong></td><td class='right'>$($d.Messages)</td><td class='right'>$($d.InputFmt)</td><td class='right'>$($d.CacheFmt)</td><td class='right'>$($d.OutputFmt)</td><td class='right'>$($d.TotalFmt)</td><td class='right'><strong>$($d.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($d.SavingsFmt)</td></tr>")
    }
    [void]$sb.AppendLine("</tbody></table></div></div></body></html>")

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($htmlPath, $sb.ToString(), $utf8NoBom)

    if ($OpenHtml) {
        Start-Process $htmlPath
    }

    return [PSCustomObject]@{
        HtmlPath = $htmlPath
        CsvPath  = $csvPath
    }
}
