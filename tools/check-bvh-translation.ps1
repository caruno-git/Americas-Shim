param(
    [Parameter(Mandatory = $true)][ValidateCount(3,3)][string[]]$ShaderPaths,
    [Parameter(Mandatory = $true)][string]$Runner
)
$ErrorActionPreference = 'Stop'
$paths = @($ShaderPaths | ForEach-Object {
    $path = (Resolve-Path -LiteralPath $_).Path
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Expected shader files' }
    $path
})
$runnerPath = (Resolve-Path -LiteralPath $Runner).Path
$env:VICTORY_HOST_MAX_WAVE = '32'
Remove-Item Env:VICTORY_WAVE_WIDE, Env:VICTORY_WAVE_LOCAL, Env:VICTORY_WAVE_DEEP_SKIPS -ErrorAction SilentlyContinue
$env:VICTORY_WAVE_WHY = '1'
# Merge the optional retry diagnostics from stderr without treating them as PowerShell errors.
$ErrorActionPreference = 'Continue'
$lines = @(& $runnerPath translate --validate --pipelines --list --jobs 2 @paths 2>&1 | ForEach-Object { $_.ToString() })
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$lines | Write-Output
if ($code -ne 0) { exit $code }
$summary = @($lines | Select-String -Pattern '^\s*(\d+) emitted of (\d+) compute programs; (\d+) validated, (\d+) pipelines\s*$')
if ($summary.Count -ne 1) { throw 'Missing or ambiguous compute summary' }
$groups = $summary[0].Matches[0].Groups
if ($groups[2].Value -ne '3') { throw "Expected exactly three compute programs, got $($groups[2].Value)" }
if ($groups[1].Value -ne '3' -or $groups[3].Value -ne '3' -or $groups[4].Value -ne '3') {
    Write-Output 'FAIL: expected 3/3 emitted, validated and accepted by D3D12.'
    exit 1
}
Write-Output 'PASS: 3/3 emitted, validated and accepted by D3D12. Dispatch not tested.'
exit 0
