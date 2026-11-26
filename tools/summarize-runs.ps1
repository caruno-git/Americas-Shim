param([Parameter(Mandatory = $true)][string]$LogDir, [switch]$AsObjects)
$ErrorActionPreference = 'Stop'
$rows = Get-ChildItem -LiteralPath $LogDir -File -Filter '*.log' | Where-Object Name -Match '^(baseline|warm-.+\.stderr)\.log$' | Sort-Object Name | ForEach-Object {
    $hits = [System.Collections.Generic.List[double]]::new()
    $textureMs = [System.Collections.Generic.List[double]]::new()
    $copyMs = [System.Collections.Generic.List[double]]::new()
    $frameMs = [System.Collections.Generic.List[double]]::new()
    $prepareMs = [System.Collections.Generic.List[double]]::new()
    $gpuMs = [System.Collections.Generic.List[double]]::new()
    $copyBackMs = [System.Collections.Generic.List[double]]::new()
    $peakRemapWaitMs = $null
    $peakDeferredPerFrame = $null
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $crashes = [System.Collections.Generic.HashSet[string]]::new()
    $refused = [System.Collections.Generic.HashSet[string]]::new()
    $deviceLost = $false
    $backgroundOff = $null
    $last = ''
    $stream = [IO.File]::Open($_.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try { while ($null -ne ($raw = $reader.ReadLine())) {
        $line = $raw -replace '\x1b\[[0-9;]*m',''
        if ($line -match '(?<fps>\d+\.\d+) fps, (?<frame>\d+\.\d+) ms/frame \((?<prep>\d+\.\d+) preparing: copies (?<copy>\d+\.\d+) ms .*?textures (?<texture>\d+\.\d+) ms .*?; (?<gpu>\d+\.\d+) on the GPU; (?<back>\d+\.\d+) copying back .*?\), (?<draws>\d+) draws/frame') {
            if ([int]$Matches.draws -ge 1000) {
                $hits.Add([double]::Parse($Matches.fps, $culture))
                $textureMs.Add([double]::Parse($Matches.texture, $culture))
                $copyMs.Add([double]::Parse($Matches.copy, $culture))
                $frameMs.Add([double]::Parse($Matches.frame, $culture))
                $prepareMs.Add([double]::Parse($Matches.prep, $culture))
                $gpuMs.Add([double]::Parse($Matches.gpu, $culture))
                $copyBackMs.Add([double]::Parse($Matches.back, $culture))
            }
            $last = ($line -split ';',2)[0]
        }
        if ($line -match 'texture refreshes per frame, all threads:.*?([0-9.]+) ms waiting for title memory') {
            $peakRemapWaitMs = [Math]::Max([double]$peakRemapWaitMs, [double]::Parse($Matches[1], $culture))
        }
        if ($line -match 'texture refreshes that did not wait.*?([0-9.]+) left for the next refresh') {
            $peakDeferredPerFrame = [Math]::Max([double]$peakDeferredPerFrame, [double]::Parse($Matches[1], $culture))
        }
        if ($line -match 'unhandled exception (0x\w+) at .*?\+(0x\w+)') { [void]$crashes.Add("$($Matches[1]) @ $($Matches[2])") }
        if ($line -match 'host pipeline refused.*shaders=\[(.+)\]') { [void]$refused.Add($Matches[1]) }
        if ($line -match 'host GPU device removed|DXGI_ERROR_DEVICE_(HUNG|REMOVED|RESET)') { $deviceLost = $true }
        if ($line -match 'background shader work is switched off.*\bok=(true|false)\b') { $backgroundOff = $Matches[1] -eq 'true' }
    } } finally { $reader.Dispose() }
    $ordered = @($hits | Sort-Object)
    $median = $null
    if ($ordered.Count -gt 0) {
        $lo = [int][Math]::Floor(($ordered.Count - 1) / 2)
        $hi = [int][Math]::Floor($ordered.Count / 2)
        $median = ($ordered[$lo] + $ordered[$hi]) / 2
    }
    $medianTextureMs = $null
    $medianCopyMs = $null
    if ($ordered.Count -gt 0) {
        $textures = @($textureMs | Sort-Object)
        $copies = @($copyMs | Sort-Object)
        $medianTextureMs = ($textures[$lo] + $textures[$hi]) / 2
        $medianCopyMs = ($copies[$lo] + $copies[$hi]) / 2
    }
    $summary = [ordered]@{ Log = $_.Name; HeavyIntervals = $ordered.Count; MedianFps = $median; MedianTextureMs = $medianTextureMs; MedianCopyMs = $medianCopyMs }
    $timings = [ordered]@{ MedianFrameMs = $frameMs; MedianPrepareMs = $prepareMs; MedianGpuMs = $gpuMs; MedianCopyBackMs = $copyBackMs }
    foreach ($key in $timings.Keys) {
        $summary[$key] = $null
        if ($ordered.Count -gt 0) {
            $sorted = @($timings[$key] | Sort-Object)
            $summary[$key] = ($sorted[$lo] + $sorted[$hi]) / 2
        }
    }
    $summary.PeakRemapWaitMsAllIntervals = $peakRemapWaitMs
    $summary.PeakDeferredPerFrameAllIntervals = $peakDeferredPerFrame
    $summary.Exceptions = $crashes -join ', '
    $summary.UniqueRefusedPipelines = $refused.Count
    $summary.DeviceLost = $deviceLost
    $summary.DriverBackgroundOff = $backgroundOff
    $summary.LastFrameSample = $last
    [pscustomobject]$summary
}
if ($AsObjects) { $rows } else { $rows | Format-List }
