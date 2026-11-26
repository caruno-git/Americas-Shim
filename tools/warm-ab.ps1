param([Parameter(Mandatory = $true)][string]$Runner, [Parameter(Mandatory = $true)][string]$Executable, [switch]$Scripted, [int]$WaitForPid = 0, [switch]$TextureProbe, [switch]$DriverBackgroundProbe, [switch]$WideRefreshProbe)
$probeCount = [int][bool]$TextureProbe + [int][bool]$DriverBackgroundProbe + [int][bool]$WideRefreshProbe
if ($probeCount -gt 0 -and !$Scripted) { throw 'Probes require Scripted input' }
if ($probeCount -gt 1) { throw 'Choose one probe' }
$ErrorActionPreference = 'Stop'
$runnerPath = (Resolve-Path -LiteralPath $Runner).Path
$game = (Resolve-Path -LiteralPath $Executable).Path
if (!(Test-Path -LiteralPath $runnerPath -PathType Leaf) -or !(Test-Path -LiteralPath $game -PathType Leaf)) { throw 'Expected executable files' }
$workingDir = Split-Path -Parent $runnerPath
$root = Join-Path $env:LOCALAPPDATA 'Americas-Shim-warm'
$env:VICTORY_CACHE_DIR = Join-Path $root 'cache'
$env:VICTORY_DATA_DIR = Join-Path $root 'data'
if ($WaitForPid -gt 0) {
    $prior = Get-Process -Id $WaitForPid -ErrorAction SilentlyContinue
    if ($prior) { Wait-Process -InputObject $prior -Timeout 620 }
}
if ($Scripted) { $env:VICTORY_KEYS = '20:Enter,28:Enter,36:Enter,44:Enter' } else { Remove-Item Env:VICTORY_KEYS -ErrorAction SilentlyContinue }
if (Get-Process victory -ErrorAction SilentlyContinue) { throw 'Another victory process is running' }
$prefix = if ($WideRefreshProbe) { 'warm-refresh' } elseif ($DriverBackgroundProbe) { 'warm-driver' } elseif ($TextureProbe) { 'warm-texture' } elseif ($Scripted) { 'warm-scripted' } else { 'warm' }
$variants = if ($WideRefreshProbe) { 'a1','wide-refresh','a2' } elseif ($DriverBackgroundProbe) { 'a1','background-off','a2' } elseif ($TextureProbe) { 'a1','no-wait','a2' } else { 'a1','relay2','a2' }
$logDir = Join-Path $root ($prefix + '-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $logDir -Force)
Write-Output "Run logs: $logDir"
if ($probeCount -gt 0) {
    Remove-Item Env:VICTORY_WAVE_WIDE, Env:VICTORY_D3D12_DEBUG, Env:VICTORY_D3D12_DRED, Env:VICTORY_D3D12_GBV, Env:VICTORY_D3D12_WARP, Env:VICTORY_WARP, Env:VICTORY_CAPTURE, Env:VICTORY_CAPTURE_WORLD, Env:VICTORY_CAPTURE_FRAMES, Env:VICTORY_DUMP_TARGETS, Env:VICTORY_D3D12_BACKGROUND, Env:VICTORY_WIDE_REFRESH -ErrorAction SilentlyContinue
}
foreach ($variant in $variants) {
    if (Get-Process victory -ErrorAction SilentlyContinue) { throw 'Another victory process is running' }
    $name = "$prefix-$variant"
    $out = Join-Path $logDir "$name.stdout.log"
    $err = Join-Path $logDir "$name.stderr.log"
    if ((Test-Path -LiteralPath $out) -or (Test-Path -LiteralPath $err)) { throw "Existing logs: $name" }
    Remove-Item Env:VICTORY_RELAY, Env:VICTORY_TEXTURE_NO_WAIT -ErrorAction SilentlyContinue
    if ($variant -eq 'relay2') { $env:VICTORY_RELAY = '2' }
    if ($variant -eq 'no-wait') { $env:VICTORY_TEXTURE_NO_WAIT = '1' }
    if ($DriverBackgroundProbe) {
        Remove-Item Env:VICTORY_D3D12_BACKGROUND -ErrorAction SilentlyContinue
        if ($variant -eq 'background-off') { $env:VICTORY_D3D12_BACKGROUND = '0' }
    }
    if ($WideRefreshProbe) {
        Remove-Item Env:VICTORY_WIDE_REFRESH -ErrorAction SilentlyContinue
        if ($variant -eq 'wide-refresh') { $env:VICTORY_WIDE_REFRESH = '1' }
        Write-Output "$name VICTORY_WIDE_REFRESH=$env:VICTORY_WIDE_REFRESH"
    }
    $p = Start-Process -FilePath $runnerPath -ArgumentList ('run "{0}" --execute' -f $game) -WorkingDirectory $workingDir -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
    Write-Output "$name started pid=$($p.Id)"
    if (!$p.WaitForExit(180000)) {
        $closed = $p.CloseMainWindow()
        if (!$closed -or !$p.WaitForExit(5000)) {
            try { if (!$p.HasExited) { $p.Kill() } }
            catch { if (!$p.HasExited) { throw } }
            $p.WaitForExit()
        }
        Write-Output "$name reached the 180-second limit; check the game log for concurrent failures"
    } else {
        Write-Output "$name game process exited with $($p.ExitCode)"
    }
    if (Get-Process victory -ErrorAction SilentlyContinue) { throw 'Overlapping victory process detected; subsequent runs would be invalid' }
}
