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
param([string[]] $Extra = @(), [string] $Gun = '', [int] $Fire = 0, [switch] $Report, [switch] $KeepLog)
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
# -Report: ask the pack what it actually DREW, and put the answer in the boot log.
#
# The report is a console command, and the shared boot test has no way to send one -- so this writes
# a two-lump helper pk3 that fires the event just before the run ends. GENERATED HERE rather than kept
# as a file, because a hand-made throwaway is a thing somebody edits and forgets: this one cannot
# drift from the switch that uses it.
if ($Report) {
    $helperDir = Join-Path $scratch 'report_helper'
    New-Item -ItemType Directory -Force $helperDir | Out-Null
    @'
version "4.10"
class RsbReportHelper : EventHandler
{
	int t;
	override void WorldTick()
	{
		t++;
		// Just before the boot test's own 420-tic marker, so everything that was going to draw has.
		if (t == 410) EventHandler.SendNetworkEvent("rsb_shotreport");
	}
}
'@ | Set-Content -Encoding utf8 (Join-Path $helperDir 'zscript.txt')
    @'
gameinfo
{
	AddEventHandlers = "RsbReportHelper"
}
'@ | Set-Content -Encoding utf8 (Join-Path $helperDir 'MAPINFO.txt')
    $helperPk3 = Join-Path $scratch 'rsb_report_helper.pk3'
    if (Test-Path $helperPk3) { Remove-Item $helperPk3 -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($helperDir, $helperPk3)
    $Extra += $helperPk3
}

$bootArgs = @{ Zdl = $zdl }
if ($Extra.Count -gt 0) { $bootArgs['ExtraFiles'] = $Extra }
if ($Gun) { $bootArgs['Gun'] = $Gun }
if ($Fire -gt 0) { $bootArgs['Fire'] = $Fire }
# CAPTURE THE RUN'S OWN LOG PATH, never the newest file in the folder.
#
# EVERY LANE BOOT-TESTS INTO ONE SHARED DIRECTORY. Globbing for the most recent boot_*.txt reads
# whichever session finished last -- and it does happen: four logs landed in one minute from three
# lanes, and this tool confidently reported a run that fired HX_Nuker as the answer to a question
# about WM_Pistolet. A verifier reading somebody else's evidence is worse than no verifier, because
# it is believed. main_boottest prints the path it wrote; that is the only one that is ours.
# A SCRATCH OF OUR OWN, so two lanes testing at once stop fighting over one file.
#
# main_boottest derives everything it writes from $env:TEMP -- its working directory, its scratch
# config, the boottest.pk3 it packs and the logs it keeps. Every lane therefore shares ONE
# boottest.pk3, and a run that starts while another is live dies at "Cannot remove boottest.pk3 --
# being used by another process". That is not a fault in anybody's mod and it reads exactly like one.
#
# Pointing TEMP at a private directory for the duration of the call fixes the file fight without
# touching the shared harness. It does NOT fix the other half -- main_boottest's cleanup sweep kills
# every doomxr whose command line contains 'doomxr_boottest', which is still every lane's -- so a run
# can still be killed by another lane FINISHING. That one is the build lane's to fix and is reported.
$savedTemp = $env:TEMP
$savedTmp  = $env:TMP
$mine = Join-Path $scratch 'harness'
New-Item -ItemType Directory -Force $mine | Out-Null
$env:TEMP = $mine
$env:TMP  = $mine
try {
    $runOut = & 'E:\DOOMWork\tools\main_boottest\main_boottest.ps1' @bootArgs
} finally {
    $env:TEMP = $savedTemp
    $env:TMP  = $savedTmp
}
$runOut | ForEach-Object { if ($_ -match '^(GREEN|RED)') { Write-Output $_ } }

# A RED RUN IS NOT VERIFIED, however clean its profile list looks. This tool used to print RED and
# then pass, because it only asked whether RSBDEFS loaded and nothing was refused -- and both are
# true of a run that was killed at 35 tics before firing a shot. A verifier that reports a failure
# and then says the word 'verified' is worse than one that says nothing.
if ($runOut | Where-Object { $_ -match '^RED' }) {
    throw 'the boot test reported RED -- the level never reached its marker, so nothing here is verified. (Another lane running the shared harness kills this one: see the build lane.)'
}

$logPath = $null
foreach ($line in $runOut) {
    if ($line -match '^full output:\s*(.+?)\s*$') { $logPath = $Matches[1] }
}
if (-not $logPath) { throw 'the boot test did not say which log it wrote -- cannot verify a run I cannot identify' }
$log = Get-Item -LiteralPath $logPath -ErrorAction SilentlyContinue
if (-not $log) { throw "the boot test named a log that is not there: $logPath" }

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
if ($Report) {
    $drew = Select-String -Path $log.FullName -Pattern 'shot report'
    if ($drew) {
        Write-Output ''
        Select-String -Path $log.FullName -Pattern 'shot report|^\s+\d+ x |effects across' |
            ForEach-Object { Write-Output ($_.Line -replace '\x1b\[[0-9;]*m', '') }
    } else {
        throw 'asked for a shot report and the pack never printed one -- the command did not arrive.'
    }
}
if ($KeepLog) { Write-Output "log: $($log.FullName)" }
