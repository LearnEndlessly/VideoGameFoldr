# Runs the playbot (tools/playbot.gd) on seeds 1..N and writes a markdown summary: extract rate, death rate,
# timeouts, median time to extract and to death, and (when the bot reports it) which extract it used.
#   powershell -ExecutionPolicy Bypass -File tools/run_baseline.ps1 -Out docs/baseline_before_extract.md -Title "Before"
# The bot is not seeded for patrol movement or pellet spread, so a rerun can differ a little: trust only large changes.
param(
	[string]$Out = "docs/baseline.md",
	[string]$Title = "Playbot baseline",
	[int]$Seeds = 40,
	[int]$MaxSeconds = 240,
	[int]$TimeoutSec = 120,
	[string]$Godot = $(if ($env:GODOT_PATH) { $env:GODOT_PATH } else { "D:\Godot_v4.7.2-stable_win64.exe" })
)

$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$rows = @()
foreach ($seed in 1..$Seeds) {
	$log = Join-Path $env:TEMP "pb_$seed.log"
	$args = @('--headless', '--fixed-fps', '60', '--path', "`"$project`"", '-s', 'tools/playbot.gd', '--', "$seed", "$MaxSeconds")
	$p = Start-Process $Godot -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError (Join-Path $env:TEMP "pb_$seed.err") -PassThru -NoNewWindow
	$null = $p.Handle
	if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill() }
	$line = Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -like 'RESULT *' } | Select-Object -Last 1
	if ($line) {
		$rows += ($line.Substring(7) | ConvertFrom-Json)
	} else {
		$rows += [pscustomobject]@{ seed = $seed; outcome = "no result"; t = 0 }
	}
}

function Median($xs) {
	$s = @($xs | Sort-Object)
	if ($s.Count -eq 0) { return "n/a" }
	$mid = [int][math]::Floor($s.Count / 2)
	if ($s.Count % 2 -eq 1) { return $s[$mid] } else { return [math]::Round(($s[$mid - 1] + $s[$mid]) / 2, 1) }
}
$n = $rows.Count
$ext = @($rows | Where-Object { $_.outcome -eq "extracted" })
$dead = @($rows | Where-Object { $_.outcome -eq "dead" })
$other = @($rows | Where-Object { $_.outcome -ne "extracted" -and $_.outcome -ne "dead" })
function Pct($k) { "{0:N0}%" -f (100.0 * $k / [math]::Max($n, 1)) }

$md = @()
$md += "# $Title"
$md += ""
$md += "Playbot, $n seeds (1..$n), one raid each, max $MaxSeconds game seconds, run on $(Get-Date -Format 'yyyy-MM-dd'). Commit: $(git -C $project rev-parse --short HEAD)."
$md += "The bot is cautious and clumsy (see tools/playbot.gd) and not seeded for patrols or pellet spread: use this to compare builds, not to judge human difficulty, and trust only large differences."
$md += ""
$md += "| Metric | Value |"
$md += "|---|---|"
$md += "| Extract rate | $(Pct $ext.Count) ($($ext.Count) of $n) |"
$md += "| Death rate | $(Pct $dead.Count) ($($dead.Count) of $n) |"
$md += "| Timeout / no result | $(Pct $other.Count) ($($other.Count) of $n) |"
$md += "| Median time to extract (s) | $(Median ($ext | ForEach-Object { $_.t })) |"
$md += "| Median time to death (s) | $(Median ($dead | ForEach-Object { $_.t })) |"
$md += "| Median kills per raid | $(Median ($rows | ForEach-Object { $_.kills })) |"
$md += "| Raids where the threat clock started | $(@($rows | Where-Object { $_.threat }).Count) of $n |"
if ($rows | Where-Object { $_.extract }) {
	foreach ($z in @("A", "B")) {
		$chose = @($rows | Where-Object { $_.extract -eq $z })
		$won = @($chose | Where-Object { $_.outcome -eq "extracted" })
		$md += "| Bot headed for extract $z | $($chose.Count) raids, $($won.Count) extracted, median time to extract $(Median ($won | ForEach-Object { $_.t })) s |"
	}
}
$md += ""
$md += "## Per seed"
$md += ""
$md += "| Seed | Outcome | Time (s) | Kills | HP | Threat clock | Extract |"
$md += "|---|---|---|---|---|---|---|"
foreach ($r in $rows) {
	$md += "| $($r.seed) | $($r.outcome) | $($r.t) | $($r.kills) | $($r.hp) | $(if ($r.threat) { 'yes' } else { 'no' }) | $(if ($r.extract) { $r.extract } else { '-' }) |"
}
$md -join "`n" | Set-Content -Path (Join-Path $project $Out) -Encoding utf8
Write-Output ("{0}: extract {1}, dead {2}, other {3}, median extract t {4}, median death t {5}" -f $Out, (Pct $ext.Count), (Pct $dead.Count), (Pct $other.Count), (Median ($ext | ForEach-Object { $_.t })), (Median ($dead | ForEach-Object { $_.t })))
