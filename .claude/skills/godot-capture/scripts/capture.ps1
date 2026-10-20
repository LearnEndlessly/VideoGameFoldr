# Runs tools/capture.gd with rendering (a game window appears for about 15 seconds and grabs
# the mouse) and prints the screenshots it saved. Each run clears the folder first and the tool
# keeps at most 24 files, so the cache never grows.
#   powershell -ExecutionPolicy Bypass -File capture.ps1 [-Seed 3] [-Out <folder>]
param(
	[int]$Seed = 3,
	[string]$Out = (Join-Path $env:TEMP "videogame-capture"),
	[int]$TimeoutSec = 120,
	[string]$Godot = $(if ($env:GODOT_PATH) { $env:GODOT_PATH } else { "D:\Godot_v4.7.2-stable_win64.exe" })
)

$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
if (-not (Test-Path $Godot)) { Write-Output "Godot not found. Set GODOT_PATH or pass -Godot."; exit 2 }
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $env:TEMP "gc.log"
$err = Join-Path $env:TEMP "gc.err"
Remove-Item $log, $err -ErrorAction SilentlyContinue

# Quoted paths: the project path has spaces. Not headless: it must render.
$args = @('--path', "`"$project`"", '-s', 'tools/capture.gd', '--', "`"$Out`"", "$Seed")
$p = Start-Process $Godot -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
$null = $p.Handle
if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill(); Write-Output "TIMED OUT after $TimeoutSec s" }

Get-Content $log | Where-Object { $_ -match '^map |screenshots saved' }
$bad = Get-Content $err -ErrorAction SilentlyContinue | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Invalid' } | Select-Object -First 6
if ($bad) { Write-Output "ERRORS:"; $bad | ForEach-Object { Write-Output "  $_" } }
$files = Get-ChildItem $Out -Filter *.png | Sort-Object Name
$mb = [math]::Round((($files | Measure-Object Length -Sum).Sum) / 1MB, 2)
Write-Output "$($files.Count) screenshots, $mb MB, in $Out"
$files | ForEach-Object { Write-Output "  $($_.FullName)" }
if ($files.Count -eq 0) { exit 1 }
