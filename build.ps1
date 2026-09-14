# Build RS_Ballistics.pk3
#
# The same pattern as RS_VR_PistolTest's build: entry-by-entry ZipArchive with
# forward slashes and an ALLOWLIST (Compress-Archive writes backslashes SLADE
# will not open, and a lump name ignores its extension, so a stray .bak in the
# root can silently shadow the real lump).
#
# THE MENU IS LINTED FIRST. tools/menu_lint.py fails the build on a control for
# a cvar nothing reads, before it can reach a headset.
#
# -NoCompileCheck skips the last step, which runs doomxr.exe -norun -- for a
# builder whose rule is never to run doomxr at all.
#
# -OutFile packs somewhere other than the installed RS_Ballistics.pk3: a scratch
# pack to compile-check BEFORE it replaces the one the owner loads. (Not -Out:
# PowerShell variables ignore case, so $Out would be $out below.)
param([switch]$NoCompileCheck, [string]$OutFile = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$out  = if ($OutFile) { $OutFile } else { Join-Path $root 'RS_Ballistics.pk3' }

# THE PACKAGE RS_Ballistics IS COMPILE-CHECKED WITH. One variable on purpose:
# the reload system is being renamed RS_VR_PistolTest -> RS_VR_Reload, and this
# is the only line that changes when it is. Load order: RS_Ballistics first,
# because the reload system requires it.
$reloadPk3 = 'E:\DOOMWork\RS_VR_Reload\RS_VR_Reload.pk3'

& python 'E:\DOOMWork\tools\menu_lint.py' $root --prefix rsb_
if ($LASTEXITCODE -ne 0) { throw "menu lint failed -- a control would be dead. See above." }

$rootLumps = @('zscript.txt', 'RSBDEFS.txt', 'MAPINFO.txt', 'MODELDEF.txt', 'CVARINFO.txt', 'MENUDEF.txt', 'SNDINFO.txt', 'PARTICLEDEFS.txt', 'SURFACES.txt', 'KEYCONF.txt', 'DAMAGEDEFS.txt')
$files = @()
foreach ($l in $rootLumps) {
    $p = Join-Path $root $l
    if (-not (Test-Path $p)) { throw "missing required lump: $l" }
    $files += Get-Item $p
}
$files += Get-ChildItem -Path (Join-Path $root 'zscript') -Recurse -File -Filter *.zs
foreach ($d in @('models', 'sprites', 'sounds', 'licenses', 'damage')) {
    $p = Join-Path $root $d
    if (Test-Path $p) { $files += Get-ChildItem -Path $p -Recurse -File }
}

if (Test-Path $out) { Remove-Item $out -Force }
$fs  = [System.IO.File]::Open($out, [System.IO.FileMode]::CreateNew)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($f in $files) {
    $rel = ($f.FullName.Substring($root.Length + 1)) -replace ([regex]::Escape([char]92)), '/'
    $e = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $st = $e.Open(); $b = [System.IO.File]::ReadAllBytes($f.FullName)
    $st.Write($b, 0, $b.Length); $st.Dispose()
}
$zip.Dispose(); $fs.Dispose()

# Verify rather than trust: a lump that fails to pack is SILENT.
$check = [System.IO.Compression.ZipFile]::OpenRead($out)
$names = $check.Entries | ForEach-Object { $_.FullName }
$check.Dispose()
$must = @('zscript.txt', 'RSBDEFS.txt', 'MAPINFO.txt', 'MODELDEF.txt', 'CVARINFO.txt', 'MENUDEF.txt', 'SNDINFO.txt', 'PARTICLEDEFS.txt', 'SURFACES.txt', 'KEYCONF.txt', 'DAMAGEDEFS.txt', 'damage/rsb/hole_chip_a.png',
          'zscript/rsb/log.zs', 'zscript/rsb/hash.zs', 'zscript/rsb/defs.zs', 'zscript/rsb/parser.zs',
          'zscript/rsb/registry.zs', 'zscript/rsb/settings.zs', 'zscript/rsb/materials.zs',
          'zscript/rsb/impact.zs', 'zscript/rsb/bullet.zs', 'zscript/rsb/flash.zs',
          'zscript/rsb/ejecta.zs', 'zscript/rsb/preview.zs', 'zscript/rsb/service.zs', 'zscript/rsb/flamer.zs', 'zscript/rsb/bench.zs', 'zscript/rsb/projectiles.zs', 'zscript/rsb/heat.zs', 'zscript/rsb/trail.zs', 'zscript/rsb/casings.zs', 'zscript/rsb/barrel.zs', 'zscript/rsb/hotspot.zs',
          'sprites/RSBTA1.png', 'sprites/RSCSA0.png', 'sprites/RSSKA0.png', 'sprites/RSMFB0.png', 'models/rocket/rocket.kvx', 'models/rocket/rocket_pal.png', 'models/debris/chunk.png',
          'sounds/rsb/impact_concrete/bulletimpact1.ogg', 'sounds/rsb/whiz/whizby1.wav', 'sounds/rsb/flame/flamer_loop.ogg')
foreach ($m in $must) {
    if ($names -notcontains $m) { throw "verification failed: $m missing" }
}
Write-Output "RS_Ballistics.pk3  --  $($names.Count) entries, verified"

if ($NoCompileCheck) { Write-Output "compile check SKIPPED (-NoCompileCheck) -- NOT proven to compile"; return }

# PROVE IT COMPILES, every build, through the shared hidden check, WITH the
# reload system -- RS_Ballistics first, as in the owner's load order.
#
# Called in-process with `&`, not `powershell -File`: an array does not survive
# -File argument passing (-Files a,b arrives as the single string "a,b"). The
# check ends with `exit`, which here returns to this script with $LASTEXITCODE.
& 'E:\DOOMWork\tools\compile_check.ps1' -Files @($out, $reloadPk3)
if ($LASTEXITCODE -ne 0) { throw "compile check FAILED -- see above" }
