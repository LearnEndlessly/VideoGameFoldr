# Run: Godot --headless --path <project> -s tools/summarize_telemetry.gd -- <file.jsonl | folder> [...]
# Prints the first five design measures (docs/DESIGN_METRICS.md) over every raid file given.
# Formulas (R = raids, all means over raids that have the data; missing events count as 0 / skipped):
#   extract rate        = raids with raid.end outcome "extracted" / R;  mean duration = mean(raid.end.duration)
#   threat reach rate   = raids with raid.end threat_reached or a raid.start.clock event / R
#   ammo burn ratio     = sum(raid.end.ammo_spent) / sum(raid.start.start_ammo + ammo taken in open.crate)
#   dry-fire rate       = count(fire outcome dry) / count(fire events)
#   item use-through    = count(use.item outcome ok) / sum(qty in open.crate taken)
#   damage per kill     = sum(enemy.hit.player dmg) / count(player.kill.enemy)
#   time to first alert = mean over raids with an alert of t of the first enemy.alert.group
extends SceneTree

func _init() -> void:
	var files: Array = []
	for arg in OS.get_cmdline_user_args():
		if DirAccess.dir_exists_absolute(arg):
			for f in DirAccess.get_files_at(arg):
				if f.ends_with(".jsonl"):
					files.append(arg.path_join(f))
		elif FileAccess.file_exists(arg):
			files.append(arg)
	var raids := 0
	var extracted := 0
	var reached := 0
	var duration := 0.0
	var spent := 0.0
	var available := 0.0
	var fires := 0
	var dries := 0
	var used := 0
	var picked := 0
	var hit_dmg := 0.0
	var kills := 0
	var alert_ts: Array = []
	for path in files:
		raids += 1
		var first_alert := -1.0
		var clock := false
		for line in FileAccess.get_file_as_string(path).split("\n", false):
			var e = JSON.parse_string(line)
			if typeof(e) != TYPE_DICTIONARY:
				continue
			match e.get("ev", ""):
				"raid.start.raid":
					available += float(e.get("start_ammo", 0))
				"raid.start.clock":
					clock = true
				"raid.end.raid":
					extracted += 1 if e.get("outcome") == "extracted" else 0
					duration += float(e.get("duration", 0.0))
					spent += float(e.get("ammo_spent", 0))
					clock = clock or bool(e.get("threat_reached", false))
				"player.fire.weapon":
					fires += 1
					dries += 1 if e.get("outcome") == "dry" else 0
				"player.open.crate":
					var taken: Dictionary = e.get("taken", {})
					for id in taken:
						picked += int(taken[id])
						if id == "ammo":
							available += float(taken[id])
				"player.use.item":
					used += 1 if e.get("outcome") == "ok" else 0
				"enemy.hit.player":
					hit_dmg += float(e.get("dmg", 0))
				"player.kill.enemy":
					kills += 1
				"enemy.alert.group":
					if first_alert < 0.0:
						first_alert = float(e.get("t", 0.0))
		reached += 1 if clock else 0
		if first_alert >= 0.0:
			alert_ts.append(first_alert)
	if raids == 0:
		print("no raid files found")
		quit(1)
		return
	var alert_mean := 0.0
	for t in alert_ts:
		alert_mean += t
	print("raids                   %d" % raids)
	print("extract rate            %.2f" % (float(extracted) / raids))
	print("mean raid duration      %.1f s" % (duration / raids))
	print("threat clock reach      %.2f" % (float(reached) / raids))
	print("ammo burn ratio         %s" % ("%.2f" % (spent / available) if available > 0.0 else "n/a"))
	print("dry-fire rate           %s" % ("%.2f" % (float(dries) / fires) if fires > 0 else "n/a"))
	print("item use-through        %s" % ("%.2f" % (float(used) / picked) if picked > 0 else "n/a"))
	print("damage taken per kill   %s" % ("%.1f" % (hit_dmg / kills) if kills > 0 else "n/a"))
	print("mean time to 1st alert  %s" % ("%.1f s" % (alert_mean / alert_ts.size()) if not alert_ts.is_empty() else "n/a"))
	quit(0)
