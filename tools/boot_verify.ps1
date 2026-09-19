# Boot the scratch pack in the owner's load order AND FAIL ON A REFUSED PROFILE.
#
# WHY THIS EXISTS. A boot test can go GREEN with twelve of my profiles dead. It happened: the flare
# gun's flash used a key `flash` has never had and every Blood impact used hotspot burst syntax, so
# RSBDEFS refused twelve profiles, printed twelve red lines into a four-thousand-line log, and the run
# reported GREEN because the level still ran. The engine's validation was perfect and nothing was
# reading it.
#
# The compile check cannot catch these -- they are data, not code. check_set_coverage.py cannot either:
# it verifies that a name RESOLVES, and a refused profile is exactly a name that does not exist yet
# looks like one that does. The only place the truth is stated is the boot log, so this reads it.
#
#   .\tools\boot_verify.ps1                      # pack, boot, fail on any refusal
#   .\tools\boot_verify.ps1 -Extra a.pk3,b.pk3   # with a throwaway stand-in loaded too
#   .\tools\boot_verify.ps1 -Gun WM_Pistolet -Fire 60
#
# It never touches the installed pk3: it packs to a scratch file and rewrites a COPY of the owner's
# test.zdl to point at it, so a failing build cannot reach a headset.
[CmdletBinding()]
param([string[]] $Extra = @(), [string] $Gun = '', [int] $Fire = 0, [switch] $KeepLog)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$scratch = Join-Path $env:TEMP 'rsb_boot_verify'
New-Item -ItemType Directory -Force $scratch | Out-Null
$pk3 = Join-Path $scratch 'RS_Ballistics_verify.pk3'
$zdl = Join-Path $scratch 'verify.zdl'

& (Join-Path $root 'build.ps1') -OutFile $pk3
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

# The owner's load order with MY pack swapped in. His test.zdl is never written.
$src = Join-Path $env:USERPROFILE 'Desktop\test.zdl'
if (-not (Test-Path $src)) { throw "no load order at $src" }
$hit = 0
$lines = foreach ($l in (Get-Content $src)) {
    if ($l -match '^file(\d+)=(.*RS_Ballistics\.pk3)\s*$') { $hit++; "file$($Matches[1])=$pk3" } else { $l }
}
if ($hit -ne 1) { throw "expected exactly one RS_Ballistics line in the load order, found $hit" }
$lines | Set-Content -Encoding utf8 $zdl

# A HASHTABLE, NOT AN ARRAY. Splatting an ARRAY in PowerShell passes its elements POSITIONALLY,
# so @('-Zdl', $zdl) handed the string "-Zdl" to the callee's first parameter -- which is
# [int] $TimeoutSec -- and the error named TimeoutSec and this script, neither of which was the
# mistake. Only a hashtable splats as NAMED parameters.
#
# (Do not call it $args either: that is an automatic variable holding this script's own
# arguments, and assigning to it is a second, quieter way to pass the wrong thing.)
$bootArgs = @{ Zdl = $zdl }
if ($Extra.Count -gt 0) { $bootArgs['ExtraFiles'] = $Extra }
if ($Gun) { $bootArgs['Gun'] = $Gun }
if ($Fire -gt 0) { $bootArgs['Fire'] = $Fire }
& 'E:\DOOMWork\tools\main_boottest\main_boottest.ps1' @bootArgs | ForEach-Object {
    if ($_ -match '^(GREEN|RED)') { Write-Output $_ }
}

$log = Get-ChildItem (Join-Path $env:TEMP 'doomxr_boottest\boot_*.txt') | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $log) { throw 'no boot log was written' }

# THE WHOLE POINT. A refused profile is silent in play and green in the runner.
$refused = Select-String -Path $log.FullName -Pattern 'RSB ERROR|RSB WARN'
$summary = Select-String -Path $log.FullName -Pattern 'RSB RS_Ballistics: (\d+) profile\(s\).*?(\d+) refused'

if ($summary) {
    $m = [regex]::Match($summary[0].Line, '(\d+) profile\(s\) from \d+ RSBDEFS lump\(s\), (\d+) refused')
    if ($m.Success) {
        Write-Output "RSBDEFS: $($m.Groups[1].Value) profiles, $($m.Groups[2].Value) refused"
        if ([int]$m.Groups[2].Value -ne 0) {
            $refused | ForEach-Object { Write-Output ("  " + $_.Line.Trim()) }
            throw "$($m.Groups[2].Value) PROFILE(S) REFUSED -- they are dead in play and the run still said GREEN. See above."
        }
    }
} else {
    throw 'the pack never reported its profile count -- RSBDEFS did not load at all'
}

if ($refused) {
    $refused | ForEach-Object { Write-Output ("  " + $_.Line.Trim()) }
    throw 'RSB logged an error or warning during boot. See above.'
}
Write-Output 'boot verified: every profile loaded, nothing refused, nothing warned.'
if ($KeepLog) { Write-Output "log: $($log.FullName)" }
