param([Parameter(Mandatory = $true)][string]$GameDir, [Parameter(Mandatory = $true)][string]$BundleRoot, [switch]$Nvidia, [switch]$PipelineBook, [switch]$Capture, [switch]$WaitForTextureMemory, [ValidateRange(90,94)][int]$TextureRoomPercent = 90, [ValidateSet(4,8)][int]$ThinThreads = 8, [ValidateSet(4,8)][int]$JoinParts = 8, [ValidateSet(128,1024)][int]$SnapshotPool = 1024, [switch]$GraphicsQueueReadback, [ValidateSet(180,420)][int]$Duration = 180, [ValidateSet(64,256)][int]$CardBufferMinKiB = 64)
if ($CardBufferMinKiB -ne 64 -and (!$Nvidia -or $Capture -or $PipelineBook -or $GraphicsQueueReadback -or $ThinThreads -ne 8 -or $JoinParts -ne 8 -or $SnapshotPool -ne 1024 -or $Duration -ne 180)) { throw 'Use the card buffer probe only with stock NVIDIA timing settings' }
if ($Duration -ne 180 -and (!$Nvidia -or $PipelineBook -or $WaitForTextureMemory -or $TextureRoomPercent -ne 90 -or $GraphicsQueueReadback -or $ThinThreads -ne 8 -or $JoinParts -ne 8 -or $SnapshotPool -ne 1024)) { throw 'Use extended duration only with stock NVIDIA settings' }
if ($GraphicsQueueReadback -and (!$Nvidia -or $Capture -or $PipelineBook -or $ThinThreads -ne 8 -or $JoinParts -ne 8 -or $SnapshotPool -ne 1024)) { throw 'Use release NVIDIA timing mode without other probes for the readback queue comparison' }
if ($SnapshotPool -ne 1024 -and (!$Nvidia -or $Capture -or $PipelineBook -or $ThinThreads -ne 8 -or $JoinParts -ne 8)) { throw 'Use release NVIDIA timing mode with default worker and join counts for the snapshot pool probe' }
if ($JoinParts -ne 8 -and (!$Nvidia -or $Capture -or $PipelineBook -or $ThinThreads -ne 8)) { throw 'Use release NVIDIA timing mode with default worker count for the join probe' }
if ($ThinThreads -ne 8 -and (!$Nvidia -or $Capture -or $PipelineBook)) { throw 'Use release NVIDIA timing mode for the worker-count probe' }
if ($TextureRoomPercent -ne 90 -and (!$Nvidia -or !$Capture -or $WaitForTextureMemory)) { throw 'Use -Nvidia -Capture without other probes for the texture-room comparison' }
if ($WaitForTextureMemory -and !$Capture) { throw 'Use -Capture with -WaitForTextureMemory' }
if (($PipelineBook -or $Capture) -and !$Nvidia) { throw 'Use -Nvidia with -PipelineBook or -Capture' }
if ($PipelineBook -and $Capture) { throw 'Use separate runs for capture and pipeline booking' }
$ErrorActionPreference = 'Stop'
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
$BundleRoot = (Resolve-Path -LiteralPath $BundleRoot).Path
if (!(Test-Path -LiteralPath $GameDir -PathType Container) -or !(Test-Path -LiteralPath $BundleRoot -PathType Container)) { throw 'Expected directories for GameDir and BundleRoot' }
if (Get-Process victory* -ErrorAction SilentlyContinue) { throw 'Victory already running' }
$r = Join-Path $env:LOCALAPPDATA 'Americas-Shim-measure'
$d = Join-Path $r ('memory-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $d | Out-Null
Get-ChildItem Env:VICTORY_* | Remove-Item
Remove-Item Env:RUST_LOG -ErrorAction SilentlyContinue
$env:VICTORY_GAME_DIR = $GameDir
$env:VICTORY_CACHE_DIR = Join-Path $r 'cache'
$env:VICTORY_DATA_DIR = Join-Path $r 'data'
$env:VICTORY_LOG = 'info'
$env:VICTORY_KEYS = '20:Enter,28:Enter,36:Enter,44:Enter,60:Enter,80:Enter'
$exe = 'victory-3d-rtx-pareto-residency'
$dir = Join-Path $BundleRoot 'release'
if ($Nvidia) {
    $dir = Join-Path $BundleRoot 'source'
    if (!(Test-Path -LiteralPath (Join-Path $dir 'target/release/victory.exe') -PathType Leaf)) { throw 'Build the NVIDIA probe first' }
    if (Test-Path -LiteralPath (Join-Path $dir "$exe.exe")) { throw 'Launcher would choose the packaged binary' }
    $exe = 'victory'
    $env:VICTORY_D3D12_NVIDIA = '1'
    $env:VICTORY_CACHE_DIR = Join-Path $r 'cache-nvidia-source'
    if ($Capture) {
        $dir = Join-Path $BundleRoot 'capture-runner'
        $exe = 'victory'
        if (!(Test-Path -LiteralPath (Join-Path $dir 'target/release/victory.exe') -PathType Leaf)) { throw 'Build and stage the diagnostics capture runner first' }
        if (Test-Path -LiteralPath (Join-Path $dir 'victory-3d-rtx-pareto-residency.exe')) { throw 'Capture launcher would choose the packaged binary' }
        $env:VICTORY_CAPTURE = Join-Path $d 'frames'
        $env:VICTORY_CAPTURE_WORLD = '1'
        $env:VICTORY_CAPTURE_WORLD_ALSO = '118,160'
        New-Item -ItemType Directory $env:VICTORY_CAPTURE | Out-Null
    }
}
if ($PipelineBook) { $env:VICTORY_PIPELINE_BOOK = '1' }
if ($WaitForTextureMemory) { $env:VICTORY_TEXTURE_NO_WAIT = '0' }
if ($Capture) { $env:VICTORY_TEXTURE_ROOM_PERCENT = [string]$TextureRoomPercent }
if ($Nvidia -and !$Capture -and !$PipelineBook) {
    $env:VICTORY_THIN_THREADS = [string]$ThinThreads
    $env:VICTORY_JOIN_PARTS = [string]$JoinParts
    $env:VICTORY_SNAPSHOT_POOL = [string]$SnapshotPool
    if ($GraphicsQueueReadback) { $env:VICTORY_RELAY_COPY = '0' }
}
"capture=$Capture waitForTextureMemory=$WaitForTextureMemory textureRoomPercent=$TextureRoomPercent thinThreads=$ThinThreads joinParts=$JoinParts snapshotPool=$SnapshotPool graphicsQueueReadback=$GraphicsQueueReadback"
$stdout = Join-Path $d 'stdout.log'
$stderr = Join-Path $d 'stderr.log'
$csv = Join-Path $d 'memory.csv'
'utc,committed,limit,available_mb,private,working_set,vram_mib,vram_total_mib' | Set-Content $csv
$gpu = Join-Path $d 'gpu-memory.csv'
'utc,pid,instance,dedicated,shared,total_committed' | Set-Content $gpu
$p = Start-Process $env:ComSpec -ArgumentList '/d /c Play-VIctory.cmd pareto-residency' -WorkingDirectory $dir -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
"pid=$($p.Id) logs=$d"
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    while (!$p.HasExited -and $watch.Elapsed.TotalSeconds -lt $Duration) {
        $g = Get-Process $exe -ErrorAction SilentlyContinue | Select-Object -First 1
        $m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
        $vram = & nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | Select-Object -First 1
        '{0:o},{1},{2},{3},{4},{5},{6}' -f [DateTime]::UtcNow,$m.CommittedBytes,$m.CommitLimit,$m.AvailableMBytes,$g.PrivateMemorySize64,$g.WorkingSet64,$vram | Add-Content $csv
        if ($g) {
            $stamp = [DateTime]::UtcNow.ToString('o')
            Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory -Filter "Name LIKE 'pid_$($g.Id)_%'" -ErrorAction SilentlyContinue | ForEach-Object {
                '{0},{1},{2},{3},{4},{5}' -f $stamp,$g.Id,$_.Name,$_.DedicatedUsage,$_.SharedUsage,$_.TotalCommitted | Add-Content $gpu
            }
        }
        if ($p.WaitForExit(1000)) { break }
    }
} finally {
    if (!$p.HasExited) {
        $gameProcess = $g
        & taskkill.exe /PID $p.Id /T /F
        if (!$p.WaitForExit(10000)) { throw 'Launcher did not exit after timeout' }
        # Re-enumerate after taskkill: Windows may keep the old Process handle
        # unsignaled during teardown even after the process leaves enumeration.
        $cleanup = [Diagnostics.Stopwatch]::StartNew()
        do {
            $remaining = @(Get-Process victory* -ErrorAction SilentlyContinue)
            if (!$remaining.Count) { break }
            Start-Sleep -Milliseconds 250
        } while ($cleanup.Elapsed.TotalSeconds -lt 30)
        if ($remaining.Count) { throw "Victory still present after teardown: $($remaining.Id -join ',')" }
        'test timeout'
    } else { $p.WaitForExit(); "launcher exit=$($p.ExitCode)" }
}
Import-Csv $csv | Sort-Object {[long]$_.committed} -Descending | Select-Object -First 3 | ConvertTo-Json -Compress
Select-String -LiteralPath $stderr -Pattern '0x8007000E|unhandled exception|device removed|first frame of' | Select-Object -Last 5 -ExpandProperty Line
