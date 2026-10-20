# Runs the project's headless Godot tests one at a time and prints a PASS/FAIL table.
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1                 (all tests/*.gd)
#   powershell -ExecutionPolicy Bypass -File run_tests.ps1 -Tests check,smoke
# Exit code 1 if any test fails. Never edits project files.
param(
	[string[]]$Tests = @(),
	[int]$TimeoutSec = 280,
	[string]$Godot = $(if ($env:GODOT_PATH) { $env:GODOT_PATH } else { "D:\Godot_v4.7.2-stable_win64.exe" })
)

# The skill lives in <project>/.claude/skills/godot-test/scripts, so the project is four levels up.
$project = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
if (-not (Test-Path $Godot)) {
	$found = Get-Command godot* -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($found) { $Godot = $found.Source } else { Write-Output "Godot not found. Set GODOT_PATH or pass -Godot."; exit 2 }
}
# `powershell -File` hands a comma list over as one string ("a,b"), so split it here.
$Tests = @($Tests | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Tests.Count -eq 0) {
	$Tests = Get-ChildItem (Join-Path $project "tests") -Filter *.gd |
		Where-Object { $_.Name -notlike "dbg*" } | ForEach-Object { $_.BaseName }
}

# Tests must never write to the player's real logs; compare the folder before and after.
$logDir = Join-Path $env:APPDATA "Godot\app_userdata\VideoGame Beta\telemetry"
function Count-Logs { if (Test-Path $logDir) { (Get-ChildItem $logDir -File | Measure-Object).Count } else { 0 } }
$logsBefore = Count-Logs
# Same for the real save: tests that start a raid without naming a profile get a scratch one (VG_PROFILE),
# and the real profile must come out byte for byte as it went in.
$userDir = Join-Path $env:APPDATA "Godot\app_userdata\VideoGame Beta"
$realProfile = Join-Path $userDir "profile.json"
function Profile-Hash { if (Test-Path $realProfile) { (Get-FileHash $realProfile).Hash } else { "none" } }
$profileBefore = Profile-Hash
$env:VG_PROFILE = "user://test_run_profile.json"

# Noise that is expected: leaks at exit, backtraces, and profile_unit's deliberate corrupt-file case.
$noise = 'leaked|ObjectDB|^\s*$|at: cleanup|current_scene|reload_current|Parse JSON failed|GDScript backtrace|^\s+\[\d+\]|^\s+at:|WARNING: Profile at'

$results = @()
foreach ($name in $Tests) {
	$log = Join-Path $env:TEMP "gt_$name.log"
	$err = Join-Path $env:TEMP "gt_$name.err"
	Remove-Item $log, $err -ErrorAction SilentlyContinue
	Remove-Item (Join-Path $userDir "test_run_profile.json*") -ErrorAction SilentlyContinue  # every test starts from an empty profile
	# The embedded quotes matter: the project path has spaces and Godot otherwise reports
	# "Invalid project path" and tests nothing.
	$args = @('--headless', '--path', "`"$project`"", '-s', "tests/$name.gd")
	$p = Start-Process $Godot -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError $err -PassThru -NoNewWindow
	$null = $p.Handle  # keeps the exit code readable after exit
	$timedOut = -not $p.WaitForExit($TimeoutSec * 1000)
	if ($timedOut) { $p.Kill() }  # a script error inside a test can hang Godot forever
	$last = (Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
	$errors = @(Get-Content $err -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch $noise } | Select-Object -First 6)
	$passLine = $last -match '0 failure|checks passed|smoke ok'
	$ok = (-not $timedOut) -and ($p.ExitCode -eq 0) -and $passLine -and -not ($errors -match 'SCRIPT ERROR|Parse Error')
	$results += [pscustomobject]@{ Test = $name; Result = $(if ($ok) { "PASS" } else { "FAIL" }); Exit = $(if ($timedOut) { "timeout" } else { $p.ExitCode }); Last = $last; Errors = $errors }
}

$results | ForEach-Object { "{0,-14} {1,-5} exit {2,-7} {3}" -f $_.Test, $_.Result, $_.Exit, $_.Last }
foreach ($r in ($results | Where-Object { $_.Result -eq "FAIL" })) {
	Write-Output ""
	Write-Output "--- $($r.Test) failed. First error lines:"
	$r.Errors | ForEach-Object { Write-Output "    $_" }
}
$logsAfter = Count-Logs
if ($logsAfter -ne $logsBefore) { Write-Output "`nWARNING: real telemetry folder changed ($logsBefore -> $logsAfter files); a test wrote to it." }
if ((Profile-Hash) -ne $profileBefore) { Write-Output "`
WARNING: the real profile.json changed; a test wrote to it." }
$failed = @($results | Where-Object { $_.Result -eq "FAIL" }).Count
Write-Output ""
Write-Output ("{0} passed, {1} failed." -f ($results.Count - $failed), $failed)
if ($failed -gt 0) { exit 1 }
