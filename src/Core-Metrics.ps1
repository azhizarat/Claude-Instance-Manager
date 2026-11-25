# Core-Metrics.ps1 — Token Usage, Multi-Currency Historical Daily FX (Frankfurter/OpenER Public APIs), Locale-Aware Formatting (pt-BR / en-US) & Executive HTML/CSV Exporter

Add-Type -AssemblyName System.Web

$script:CachedRawTurnRecords = $null
$script:CachedSessionLookup = $null
$script:FxCacheFile = Join-Path $env:LOCALAPPDATA "Claude-Instances\cim-fx-cache.json"
$script:FxMemoryCache = $null

function Get-SupportedCurrencies {
    return @(
        [PSCustomObject]@{ Code = "USD"; Symbol = "$";   SymbolPt = "US$ "; NamePt = "Dólar Americano (USD)"; NameEn = "US Dollar (USD)" },
        [PSCustomObject]@{ Code = "BRL"; Symbol = "R$ "; SymbolPt = "R$ ";  NamePt = "Real Brasileiro (BRL)"; NameEn = "Brazilian Real (BRL)" },
        [PSCustomObject]@{ Code = "EUR"; Symbol = "€";   SymbolPt = "€ ";   NamePt = "Euro (EUR)";            NameEn = "Euro (EUR)" },
        [PSCustomObject]@{ Code = "GBP"; Symbol = "£";   SymbolPt = "£ ";   NamePt = "Libra Esterlina (GBP)"; NameEn = "British Pound (GBP)" },
        [PSCustomObject]@{ Code = "CAD"; Symbol = "CA$"; SymbolPt = "CA$ "; NamePt = "Dólar Canadense (CAD)"; NameEn = "Canadian Dollar (CAD)" },
        [PSCustomObject]@{ Code = "AUD"; Symbol = "A$";  SymbolPt = "A$ ";  NamePt = "Dólar Australiano (AUD)"; NameEn = "Australian Dollar (AUD)" },
        [PSCustomObject]@{ Code = "JPY"; Symbol = "¥";   SymbolPt = "¥ ";   NamePt = "Iene Japonês (JPY)";    NameEn = "Japanese Yen (JPY)" },
        [PSCustomObject]@{ Code = "CHF"; Symbol = "CHF ";SymbolPt = "CHF "; NamePt = "Franco Suíço (CHF)";    NameEn = "Swiss Franc (CHF)" },
        [PSCustomObject]@{ Code = "MXN"; Symbol = "MX$"; SymbolPt = "MX$ "; NamePt = "Peso Mexicano (MXN)";   NameEn = "Mexican Peso (MXN)" }
    )
}

function Get-CultureForLanguage([string]$Language = "") {
    if ([string]::IsNullOrWhiteSpace($Language)) {
        $st = Get-CIMState
        $Language = if ($st.language) { [string]$st.language } else { "pt-BR" }
    }
    if ($Language -like "pt*") {
        return [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
    }
    return [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
}

function Format-LocaleNumber([double]$Value, [int]$Decimals = 0, [System.Globalization.CultureInfo]$Culture) {
    if ($null -eq $Culture) { $Culture = Get-CultureForLanguage }
    $fmt = "N$Decimals"
    return $Value.ToString($fmt, $Culture)
}

function Format-TokenCount([int64]$Tokens, [System.Globalization.CultureInfo]$Culture) {
    if ($null -eq $Culture) { $Culture = Get-CultureForLanguage }
    if ($Tokens -ge 1000000000) {
        return (($Tokens / 1000000000.0).ToString("N2", $Culture) + " B")
    } elseif ($Tokens -ge 1000000) {
        return (($Tokens / 1000000.0).ToString("N2", $Culture) + " M")
    } elseif ($Tokens -ge 1000) {
        return (($Tokens / 1000.0).ToString("N1", $Culture) + " K")
    }
    return $Tokens.ToString("N0", $Culture)
}

function Format-CurrencyValue([double]$Amount, [string]$CurrencyCode = "USD", [System.Globalization.CultureInfo]$Culture) {
    if ($null -eq $Culture) { $Culture = Get-CultureForLanguage }
    $curr = Get-SupportedCurrencies | Where-Object { $_.Code -eq $CurrencyCode } | Select-Object -First 1
    $isPt = ($Culture.Name -like "pt*")
    $prefix = if ($curr) {
        if ($isPt) { $curr.SymbolPt } else { $curr.Symbol }
    } else {
        "$CurrencyCode "
    }
    $decimals = if ($CurrencyCode -eq "JPY") { 0 } else { 2 }
    return "$prefix$($Amount.ToString("N$decimals", $Culture))"
}

function Get-DefaultFallbackRates {
    return @{
        "USD" = 1.0
        "BRL" = 5.89
        "EUR" = 0.91
        "GBP" = 0.76
        "CAD" = 1.40
        "AUD" = 1.54
        "JPY" = 154.50
        "CHF" = 0.88
        "MXN" = 20.35
    }
}

function Get-ClaudeFxCache([switch]$ForceOnlineUpdate) {
    if (-not $ForceOnlineUpdate -and $null -ne $script:FxMemoryCache) {
        return $script:FxMemoryCache
    }

    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    $cacheObj = @{
        updatedDate = ""
        source      = "Fallback"
        latest      = Get-DefaultFallbackRates
        daily       = @{}
    }

    if (Test-Path $script:FxCacheFile) {
        try {
            $raw = Get-Content $script:FxCacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.updatedDate) { $cacheObj.updatedDate = [string]$raw.updatedDate }
            if ($raw.source)      { $cacheObj.source      = [string]$raw.source }
            if ($raw.latest) {
                foreach ($p in $raw.latest.PSObject.Properties) {
                    $cacheObj.latest[$p.Name] = [double]$p.Value
                }
            }
            if ($raw.daily) {
                foreach ($dProp in $raw.daily.PSObject.Properties) {
                    $dayRates = @{}
                    foreach ($cProp in $dProp.Value.PSObject.Properties) {
                        $dayRates[$cProp.Name] = [double]$cProp.Value
                    }
                    $cacheObj.daily[$dProp.Name] = $dayRates
                }
            }
        } catch {}
    }

    if ($ForceOnlineUpdate -or $cacheObj.updatedDate -ne $todayStr -or $cacheObj.daily.Count -eq 0) {
        $symbols = "BRL,EUR,GBP,CAD,AUD,JPY,CHF,MXN"
        $startHist = (Get-Date).AddDays(-365).ToString("yyyy-MM-dd")
        $fetchedOnline = $false

        # 1. Fetch historical daily time-series from Frankfurter (ECB public API)
        try {
            $histUrl = "https://api.frankfurter.app/${startHist}..${todayStr}?from=USD&to=${symbols}"
            $histResp = Invoke-RestMethod -Uri $histUrl -TimeoutSec 5 -ErrorAction Stop
            if ($histResp -and $histResp.rates) {
                foreach ($dProp in $histResp.rates.PSObject.Properties) {
                    $dayMap = @{ "USD" = 1.0 }
                    foreach ($cProp in $dProp.Value.PSObject.Properties) {
                        $dayMap[$cProp.Name] = [double]$cProp.Value
                    }
                    $cacheObj.daily[$dProp.Name] = $dayMap
                }
                $sortedDates = @($cacheObj.daily.Keys | Sort-Object)
                if ($sortedDates.Count -gt 0) {
                    $lastDay = $sortedDates[$sortedDates.Count - 1]
                    foreach ($k in $cacheObj.daily[$lastDay].Keys) {
                        $cacheObj.latest[$k] = $cacheObj.daily[$lastDay][$k]
                    }
                }
                $cacheObj.source = "Frankfurter ECB Historical + Spot API"
                $fetchedOnline = $true
            }
        } catch {}

        # 2. Fetch live spot rates from open.er-api.com for today's exact rate
        try {
            $spotResp = Invoke-RestMethod -Uri "https://open.er-api.com/v6/latest/USD" -TimeoutSec 4 -ErrorAction Stop
            if ($spotResp -and $spotResp.rates) {
                $todayMap = @{ "USD" = 1.0 }
                foreach ($code in @("BRL", "EUR", "GBP", "CAD", "AUD", "JPY", "CHF", "MXN")) {
                    if ($spotResp.rates.PSObject.Properties[$code]) {
                        $val = [double]$spotResp.rates.PSObject.Properties[$code].Value
                        $cacheObj.latest[$code] = $val
                        $todayMap[$code] = $val
                    }
                }
                $cacheObj.daily[$todayStr] = $todayMap
                if (-not $fetchedOnline) {
                    $cacheObj.source = "Open Exchange Rates Public API"
                }
                $fetchedOnline = $true
            }
        } catch {}

        if ($fetchedOnline) {
            $cacheObj.updatedDate = $todayStr
            try {
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($script:FxCacheFile, ($cacheObj | ConvertTo-Json -Depth 6), $utf8NoBom)
            } catch {}
        }
    }

    # Build sorted date array for fast prior-trading-day lookup on weekends/holidays
    $cacheObj["sortedDates"] = @($cacheObj.daily.Keys | Sort-Object)
    $script:FxMemoryCache = $cacheObj
    return $cacheObj
}

function Get-ClaudeExchangeRateForDate([string]$CurrencyCode, [string]$DateStr, [hashtable]$FxCache) {
    if ([string]::IsNullOrWhiteSpace($CurrencyCode) -or $CurrencyCode -eq "USD") { return 1.0 }
    if ($null -eq $FxCache) { $FxCache = Get-ClaudeFxCache }

    if (-not [string]::IsNullOrWhiteSpace($DateStr) -and $FxCache.daily) {
        if ($FxCache.daily.ContainsKey($DateStr)) {
            $dayMap = $FxCache.daily[$DateStr]
            if ($dayMap.ContainsKey($CurrencyCode)) { return [double]$dayMap[$CurrencyCode] }
        }
        # Find closest prior trading day for weekend/holiday dates
        $sorted = $FxCache["sortedDates"]
        if ($sorted -and $sorted.Count -gt 0) {
            $priorRate = $null
            foreach ($d in $sorted) {
                if ($d -le $DateStr) {
                    $dm = $FxCache.daily[$d]
                    if ($dm.ContainsKey($CurrencyCode)) { $priorRate = [double]$dm[$CurrencyCode] }
                } else {
                    break
                }
            }
            if ($null -ne $priorRate) { return $priorRate }
        }
    }

    if ($FxCache.latest -and $FxCache.latest.ContainsKey($CurrencyCode)) {
        return [double]$FxCache.latest[$CurrencyCode]
    }
    return 1.0
}

function Start-MetricsBackgroundPrewarm {
    Initialize-CIMNativeEngine
    $projectsRoot = Join-Path $env:USERPROFILE ".claude\projects"
    [CIMNative.FastMetricsScanner]::StartBackgroundPrewarm($projectsRoot)
}

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
    $raw = [CIMNative.FastMetricsScanner]::ScanAllProjects($projectsRoot, [bool]$ForceRefresh)
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
        [string]$Currency = "USD",
        [string]$Language = "",
        [switch]$ForceRefresh
    )

    $culture = Get-CultureForLanguage -Language $Language
    $records = Get-RawClaudeTurnRecords -ForceRefresh:$ForceRefresh
    $pricing = Get-ClaudeModelPricingTable
    $fxCache = Get-ClaudeFxCache -ForceOnlineUpdate:$ForceRefresh
    $spotRate = Get-ClaudeExchangeRateForDate -CurrencyCode $Currency -DateStr "" -FxCache $fxCache

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
    $totalCostConv = [double]0.0
    $totalUncachedConv = [double]0.0

    $projAgg = @{}
    $modelAgg = @{}
    $dayAgg = @{}
    $instAgg = @{}
    $sessAgg = @{}
    $dateRateMemo = @{}

    foreach ($r in $records) {
        if (-not $IncludeSubagents -and $r.IsSubagent) { continue }
        if ($r.DateLocal -lt $minDate -or $r.DateLocal -gt $maxDate) { continue }
        if ($InstanceId -ne "ALL" -and $r.InstanceId -ne $InstanceId) { continue }
        if ($ProjectName -ne "ALL" -and $r.ProjectName -ne $ProjectName) { continue }
        if ($Model -ne "ALL" -and $r.Model -ne $Model) { continue }

        $dk = $r.DateLocal
        if (-not $dateRateMemo.ContainsKey($dk)) {
            $dateRateMemo[$dk] = Get-ClaudeExchangeRateForDate -CurrencyCode $Currency -DateStr $dk -FxCache $fxCache
        }
        $dayFxRate = [double]$dateRateMemo[$dk]

        $rates = Resolve-ModelTierRates -ModelName $r.Model -PricingTable $pricing
        $costUsd = (
            ($r.InputTokens      * $rates.InputPerM) +
            ($r.OutputTokens     * $rates.OutputPerM) +
            ($r.CacheWriteTokens * $rates.CacheWritePerM) +
            ($r.CacheReadTokens  * $rates.CacheReadPerM)
        ) / 1000000.0

        $uncachedUsd = (
            (($r.InputTokens + $r.CacheWriteTokens + $r.CacheReadTokens) * $rates.InputPerM) +
            ($r.OutputTokens * $rates.OutputPerM)
        ) / 1000000.0

        $cost = $costUsd * $dayFxRate
        $uncached = $uncachedUsd * $dayFxRate
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
        $totalCostConv += $cost
        $totalUncachedConv += $uncached

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
                Cost             = [double]0.0
                Savings          = [double]0.0
            }
        }
        $pa = $projAgg[$pk]
        $pa.Messages += $tCount
        $pa.InputTokens += $r.InputTokens
        $pa.OutputTokens += $r.OutputTokens
        $pa.CacheWriteTokens += $r.CacheWriteTokens
        $pa.CacheReadTokens += $r.CacheReadTokens
        $pa.TotalTokens += $r.TotalTokens
        $pa.Cost += $cost
        $pa.Savings += $savings

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
                Cost             = [double]0.0
                Savings          = [double]0.0
            }
        }
        $ma = $modelAgg[$mk]
        $ma.Messages += $tCount
        $ma.InputTokens += $r.InputTokens
        $ma.OutputTokens += $r.OutputTokens
        $ma.CacheWriteTokens += $r.CacheWriteTokens
        $ma.CacheReadTokens += $r.CacheReadTokens
        $ma.TotalTokens += $r.TotalTokens
        $ma.Cost += $cost
        $ma.Savings += $savings

        # 3. Daily Aggregation
        if (-not $dayAgg.ContainsKey($dk)) {
            $dayAgg[$dk] = @{
                Date        = $dk
                FxRate      = $dayFxRate
                Messages    = 0
                InputTokens = [int64]0
                OutputTokens= [int64]0
                CacheTokens = [int64]0
                TotalTokens = [int64]0
                Cost        = [double]0.0
                Savings     = [double]0.0
            }
        }
        $da = $dayAgg[$dk]
        $da.Messages += $tCount
        $da.InputTokens += $r.InputTokens
        $da.OutputTokens += $r.OutputTokens
        $da.CacheTokens += ($r.CacheReadTokens + $r.CacheWriteTokens)
        $da.TotalTokens += $r.TotalTokens
        $da.Cost += $cost
        $da.Savings += $savings

        # 4. Instance Aggregation
        $ik = $r.InstanceName
        if (-not $instAgg.ContainsKey($ik)) {
            $instAgg[$ik] = @{
                InstanceName = $ik
                Messages     = 0
                TotalTokens  = [int64]0
                Cost         = [double]0.0
                Savings      = [double]0.0
            }
        }
        $ia = $instAgg[$ik]
        $ia.Messages += $tCount
        $ia.TotalTokens += $r.TotalTokens
        $ia.Cost += $cost
        $ia.Savings += $savings

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
                Cost         = [double]0.0
                Savings      = [double]0.0
            }
        }
        $sa = $sessAgg[$sk]
        $sa.Messages += $tCount
        $sa.TotalTokens += $r.TotalTokens
        $sa.Cost += $cost
        $sa.Savings += $savings
        if ($r.DateLocal -gt $sa.LastDate) { $sa.LastDate = $r.DateLocal }
    }

    $totalSavingsConv = [Math]::Max(0.0, ($totalUncachedConv - $totalCostConv))
    $totalInputPrompt = $totalIn + $totalCWrite + $totalCRead
    $cacheHitPctVal = if ($totalInputPrompt -gt 0) { ($totalCRead * 100.0) / $totalInputPrompt } else { 0.0 }
    $cacheHitPctStr = ($cacheHitPctVal.ToString("N1", $culture) + "%")

    $byProjectList = @($projAgg.Values | Sort-Object { $_.Cost } -Descending | ForEach-Object {
        $shareVal = if ($totalCostConv -gt 0) { ($_.Cost * 100.0) / $totalCostConv } else { 0.0 }
        [PSCustomObject]@{
            ProjectName  = $_.ProjectName
            InstanceName = $_.InstanceName
            Turns        = Format-LocaleNumber -Value $_.Messages -Decimals 0 -Culture $culture
            InputFmt     = Format-TokenCount ($_.InputTokens + $_.CacheWriteTokens) $culture
            CacheReadFmt = Format-TokenCount $_.CacheReadTokens $culture
            OutputFmt    = Format-TokenCount $_.OutputTokens $culture
            TotalFmt     = Format-TokenCount $_.TotalTokens $culture
            TotalTokens  = $_.TotalTokens
            CostRaw      = [math]::Round($_.Cost, 2)
            CostFmt      = Format-CurrencyValue -Amount $_.Cost -CurrencyCode $Currency -Culture $culture
            SavingsFmt   = Format-CurrencyValue -Amount $_.Savings -CurrencyCode $Currency -Culture $culture
            SharePct     = ($shareVal.ToString("N1", $culture) + "%")
        }
    })

    $byModelList = @($modelAgg.Values | Sort-Object { $_.Cost } -Descending | ForEach-Object {
        $shareVal = if ($totalCostConv -gt 0) { ($_.Cost * 100.0) / $totalCostConv } else { 0.0 }
        [PSCustomObject]@{
            Model        = $_.Model
            Turns        = Format-LocaleNumber -Value $_.Messages -Decimals 0 -Culture $culture
            InputFmt     = Format-TokenCount ($_.InputTokens + $_.CacheWriteTokens) $culture
            CacheReadFmt = Format-TokenCount $_.CacheReadTokens $culture
            OutputFmt    = Format-TokenCount $_.OutputTokens $culture
            TotalFmt     = Format-TokenCount $_.TotalTokens $culture
            TotalTokens  = $_.TotalTokens
            CostRaw      = [math]::Round($_.Cost, 2)
            CostFmt      = Format-CurrencyValue -Amount $_.Cost -CurrencyCode $Currency -Culture $culture
            SavingsFmt   = Format-CurrencyValue -Amount $_.Savings -CurrencyCode $Currency -Culture $culture
            SharePct     = ($shareVal.ToString("N1", $culture) + "%")
        }
    })

    $maxDayCost = 0.01
    foreach ($d in $dayAgg.Values) {
        if ($d.Cost -gt $maxDayCost) { $maxDayCost = $d.Cost }
    }

    $byDayList = @($dayAgg.Values | Sort-Object { $_.Date } -Descending | ForEach-Object {
        $blocks = [int][Math]::Round(($_.Cost / $maxDayCost) * 20)
        if ($blocks -lt 1 -and $_.TotalTokens -gt 0) { $blocks = 1 }
        $barStr = ("#" * $blocks).PadRight(20, ".")
        [PSCustomObject]@{
            Date        = $_.Date
            FxRateFmt   = if ($Currency -eq "USD") { "1.00" } else { $_.FxRate.ToString("N4", $culture) }
            Turns       = Format-LocaleNumber -Value $_.Messages -Decimals 0 -Culture $culture
            InputFmt    = Format-TokenCount $_.InputTokens $culture
            OutputFmt   = Format-TokenCount $_.OutputTokens $culture
            CacheFmt    = Format-TokenCount $_.CacheTokens $culture
            TotalFmt    = Format-TokenCount $_.TotalTokens $culture
            TotalTokens = $_.TotalTokens
            CostRaw     = [math]::Round($_.Cost, 2)
            CostFmt     = Format-CurrencyValue -Amount $_.Cost -CurrencyCode $Currency -Culture $culture
            SavingsFmt  = Format-CurrencyValue -Amount $_.Savings -CurrencyCode $Currency -Culture $culture
            TrendBar    = $barStr
        }
    })

    $byInstanceList = @($instAgg.Values | Sort-Object { $_.Cost } -Descending | ForEach-Object {
        $shareVal = if ($totalCostConv -gt 0) { ($_.Cost * 100.0) / $totalCostConv } else { 0.0 }
        [PSCustomObject]@{
            InstanceName = $_.InstanceName
            Turns        = Format-LocaleNumber -Value $_.Messages -Decimals 0 -Culture $culture
            TotalFmt     = Format-TokenCount $_.TotalTokens $culture
            CostRaw      = [math]::Round($_.Cost, 2)
            CostFmt      = Format-CurrencyValue -Amount $_.Cost -CurrencyCode $Currency -Culture $culture
            SavingsFmt   = Format-CurrencyValue -Amount $_.Savings -CurrencyCode $Currency -Culture $culture
            SharePct     = ($shareVal.ToString("N1", $culture) + "%")
        }
    })

    $bySessionList = @($sessAgg.Values | Sort-Object { $_.Cost } -Descending | Select-Object -First 100 | ForEach-Object {
        [PSCustomObject]@{
            Title        = $_.Title
            ProjectName  = $_.ProjectName
            InstanceName = $_.InstanceName
            Model        = $_.Model
            LastDate     = $_.LastDate
            Turns        = Format-LocaleNumber -Value $_.Messages -Decimals 0 -Culture $culture
            TotalFmt     = Format-TokenCount $_.TotalTokens $culture
            CostRaw      = [math]::Round($_.Cost, 2)
            CostFmt      = Format-CurrencyValue -Amount $_.Cost -CurrencyCode $Currency -Culture $culture
            SavingsFmt   = Format-CurrencyValue -Amount $_.Savings -CurrencyCode $Currency -Culture $culture
        }
    })

    return [PSCustomObject]@{
        Summary = [PSCustomObject]@{
            Currency           = $Currency
            SpotRateFmt        = $spotRate.ToString("N4", $culture)
            FxSource           = $fxCache.source
            TotalTokens        = $totalTok
            TotalTokensFmt     = Format-TokenCount $totalTok $culture
            InputTokens        = $totalIn
            InputTokensFmt     = Format-TokenCount $totalIn $culture
            OutputTokens       = $totalOut
            OutputTokensFmt    = Format-TokenCount $totalOut $culture
            ThinkingTokens     = $totalThink
            ThinkingTokensFmt  = Format-TokenCount $totalThink $culture
            CacheWriteTokens   = $totalCWrite
            CacheWriteFmt      = Format-TokenCount $totalCWrite $culture
            CacheReadTokens    = $totalCRead
            CacheReadFmt       = Format-TokenCount $totalCRead $culture
            TotalMessages      = $totalMsgs
            TotalMessagesFmt   = Format-LocaleNumber -Value $totalMsgs -Decimals 0 -Culture $culture
            SubagentMessages   = $subagentMsgs
            SubagentMessagesFmt= Format-LocaleNumber -Value $subagentMsgs -Decimals 0 -Culture $culture
            TotalCostUSD       = [math]::Round($totalCostConv, 2)
            TotalCostFmt       = Format-CurrencyValue -Amount $totalCostConv -CurrencyCode $Currency -Culture $culture
            UncachedCostUSD    = [math]::Round($totalUncachedConv, 2)
            UncachedCostFmt    = Format-CurrencyValue -Amount $totalUncachedConv -CurrencyCode $Currency -Culture $culture
            CacheSavingsUSD    = [math]::Round($totalSavingsConv, 2)
            CacheSavingsFmt    = Format-CurrencyValue -Amount $totalSavingsConv -CurrencyCode $Currency -Culture $culture
            CacheHitRatePct    = $cacheHitPctStr
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

    $Report.ByProject | Select-Object ProjectName,InstanceName,Turns,TotalTokens,TotalFmt,CostRaw,CostFmt,SavingsFmt,SharePct |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    $s = $Report.Summary
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine(@"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Claude Instance Manager — FinOps &amp; Token Usage Report ($($s.Currency))</title>
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
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <h1>Claude Code &amp; Desktop — Token Usage &amp; FinOps Report ($($s.Currency))</h1>
    <div class="sub">Generated by Claude Instance Manager (CIM) on $(Get-Date -Format 'dd/MM/yyyy HH:mm') &nbsp;|&nbsp; FX Source: $($s.FxSource) (Daily Historical Rates Applied)</div>
  </div>
  <div class="kpis">
    <div class="kpi">
      <div class="lbl">Estimated API Value ($($s.Currency))</div>
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
      <div class="val" style="color:#f4f4f5;">$($s.TotalMessagesFmt)</div>
      <div class="hint">Subagent Turns: $($s.SubagentMessagesFmt)</div>
    </div>
  </div>
"@)

    [void]$sb.AppendLine("<div class='section'><h2>Usage and Cost by Project</h2><table><thead><tr><th>Project</th><th>Instance</th><th class='right'>Turns</th><th class='right'>Input / Cache Write</th><th class='right'>Cache Read</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost ($($s.Currency))</th><th class='right'>Cache Saved</th><th class='right'>Share</th></tr></thead><tbody>")
    foreach ($p in $Report.ByProject) {
        [void]$sb.AppendLine("<tr><td><strong>$([System.Web.HttpUtility]::HtmlEncode($p.ProjectName))</strong></td><td>$([System.Web.HttpUtility]::HtmlEncode($p.InstanceName))</td><td class='right'>$($p.Turns)</td><td class='right'>$($p.InputFmt)</td><td class='right'>$($p.CacheReadFmt)</td><td class='right'>$($p.OutputFmt)</td><td class='right'>$($p.TotalFmt)</td><td class='right'><strong>$($p.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($p.SavingsFmt)</td><td class='right'>$($p.SharePct)</td></tr>")
    }
    [void]$sb.AppendLine("</tbody></table></div>")

    [void]$sb.AppendLine("<div class='section'><h2>Usage and Cost by Model</h2><table><thead><tr><th>Model</th><th class='right'>Turns</th><th class='right'>Input / Cache Write</th><th class='right'>Cache Read</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost ($($s.Currency))</th><th class='right'>Cache Saved</th><th class='right'>Share</th></tr></thead><tbody>")
    foreach ($m in $Report.ByModel) {
        [void]$sb.AppendLine("<tr><td><strong>$([System.Web.HttpUtility]::HtmlEncode($m.Model))</strong></td><td class='right'>$($m.Turns)</td><td class='right'>$($m.InputFmt)</td><td class='right'>$($m.CacheReadFmt)</td><td class='right'>$($m.OutputFmt)</td><td class='right'>$($m.TotalFmt)</td><td class='right'><strong>$($m.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($m.SavingsFmt)</td><td class='right'>$($m.SharePct)</td></tr>")
    }
    [void]$sb.AppendLine("</tbody></table></div>")

    [void]$sb.AppendLine("<div class='section'><h2>Daily Consumption Timeline (with Daily FX Rate)</h2><table><thead><tr><th>Date</th><th class='right'>Daily FX (1 USD)</th><th class='right'>Turns</th><th class='right'>Input</th><th class='right'>Cache</th><th class='right'>Output</th><th class='right'>Total Tokens</th><th class='right'>Cost ($($s.Currency))</th><th class='right'>Cache Saved</th></tr></thead><tbody>")
    foreach ($d in $Report.ByDay) {
        [void]$sb.AppendLine("<tr><td><strong>$($d.Date)</strong></td><td class='right'>$($d.FxRateFmt)</td><td class='right'>$($d.Turns)</td><td class='right'>$($d.InputFmt)</td><td class='right'>$($d.CacheFmt)</td><td class='right'>$($d.OutputFmt)</td><td class='right'>$($d.TotalFmt)</td><td class='right'><strong>$($d.CostFmt)</strong></td><td class='right' style='color:#10b981;'>$($d.SavingsFmt)</td></tr>")
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
