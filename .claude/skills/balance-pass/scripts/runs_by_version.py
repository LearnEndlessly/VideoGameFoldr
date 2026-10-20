"""Group finished raids from runs.jsonl by game version and tuning, and print the headline
measures for each group. Raids played under different tuning must not be pooled, so each
distinct (version, tuning) pair is its own row.

    python runs_by_version.py [path to runs.jsonl or its folder]

Default path: %APPDATA%\\Godot\\app_userdata\\VideoGame Beta\\telemetry\\runs.jsonl
Prints a table, then which tuning values differ between groups. Reads only.
"""
import json
import os
import sys
from collections import defaultdict


def default_path():
    return os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata",
                        "VideoGame Beta", "telemetry", "runs.jsonl")


def load(path):
    if os.path.isdir(path):
        path = os.path.join(path, "runs.jsonl")
    if not os.path.exists(path):
        sys.exit("No runs.jsonl at %s. Play some raids first (the game must be run windowed, not headless)." % path)
    runs = []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                runs.append(json.loads(line))
            except json.JSONDecodeError:
                print("skipping unreadable line %d" % n, file=sys.stderr)
    return runs


def mean(values):
    return sum(values) / len(values) if values else float("nan")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else default_path()
    runs = load(path)
    if not runs:
        sys.exit("runs.jsonl is empty.")
    groups = defaultdict(list)
    for r in runs:
        key = (r.get("version", "?"), json.dumps(r.get("tuning", {}), sort_keys=True))
        groups[key].append(r)

    print("%d raids in %d group(s)\n" % (len(runs), len(groups)))
    header = "%-3s %-7s %4s %8s %9s %6s %6s %8s %8s %7s" % (
        "grp", "version", "n", "extract", "duration", "kills", "shots", "ammo_use", "threat", "loot")
    print(header)
    keys = sorted(groups, key=lambda k: min(r.get("when", 0) for r in groups[k]))
    for i, key in enumerate(keys):
        g = groups[key]
        extracted = [r for r in g if r.get("outcome") == "extracted"]
        loot_items = [sum(r.get("loot", {}).values()) for r in g]
        note = "" if len(g) >= 20 else "  <- small sample (n < 20)"
        print("%-3d %-7s %4d %7.0f%% %8.0fs %6.1f %6.1f %8.1f %7.0f%% %7.1f%s" % (
            i + 1, key[0], len(g), 100 * len(extracted) / len(g),
            mean([r.get("duration", 0) for r in g]), mean([r.get("kills", 0) for r in g]),
            mean([r.get("shots", 0) for r in g]), mean([r.get("ammo_spent", 0) for r in g]),
            100 * mean([1.0 if r.get("threat_reached") else 0.0 for r in g]),
            mean(loot_items), note))

    if len(keys) > 1:
        print("\nTuning that differs between groups:")
        tunings = [json.loads(k[1]) for k in keys]
        for name in sorted({n for t in tunings for n in t}):
            values = [t.get(name) for t in tunings]
            if len(set(map(str, values))) > 1:
                print("  %-18s %s" % (name, "  |  ".join("grp %d: %s" % (i + 1, v) for i, v in enumerate(values))))


if __name__ == "__main__":
    main()
