extends RefCounted
# The allocation validator. UI-free: it holds the allocated node ids and the unspent points and answers whether a node
# can be taken or given back. The profile owns the arrays; this shares `allocated` by reference. Rules:
# 1. a node needs a link to the hub or to an allocated node, a point, and its `requires` met by the attribute totals;
# 2. attribute totals are the allocated attribute nodes of each type, nothing else;
# 3. a refund must leave every remaining node connected to the hub and every remaining `requires` still met.

const Tuning = preload("res://data/tuning.gd")
const SkillNodes = preload("res://data/skill_nodes.gd")

static var _rows := {}  # id -> row
static var _adj := {}  # id -> Array of neighbour ids (undirected), the hub under SkillNodes.HUB

var allocated: Array  # node ids
var points: int  # unspent

func _init(allocated_ids: Array = [], unspent: int = 0) -> void:
	allocated = allocated_ids
	points = unspent
	_build()

static func _build() -> void:
	if not _rows.is_empty():
		return
	_adj[SkillNodes.HUB] = []
	for row in SkillNodes.NODES:
		_rows[row["id"]] = row
		_adj[row["id"]] = []
	for id in SkillNodes.HUB_LINKS:
		_link(SkillNodes.HUB, id)
	for row in SkillNodes.NODES:
		for other in row["links"]:
			_link(row["id"], other)

static func _link(a: String, b: String) -> void:
	assert(_rows.has(a) or a == SkillNodes.HUB)
	assert(_rows.has(b) or b == SkillNodes.HUB)
	if not _adj[a].has(b):
		_adj[a].append(b)
	if not _adj[b].has(a):
		_adj[b].append(a)

static func has_node(id: String) -> bool:
	_build()
	return _rows.has(id)

static func row(id: String) -> Dictionary:
	_build()
	return _rows[id]

static func neighbours(id: String) -> Array:
	_build()
	return _adj[id]

# Points a node costs (one per node unless tuned).
static func cost(_id: String) -> int:
	return Tuning.SKILL_NODE_COST

# How many of each attribute the given node ids add: {"str": n, "dex": n, "int": n}.
static func totals_of(ids: Array) -> Dictionary:
	_build()
	var t := {}
	for a in SkillNodes.ATTRS:
		t[a] = 0
	for id in ids:
		if _rows[id]["kind"] == "attribute":
			t[_rows[id]["attr"]] += 1
	return t

func attribute_totals() -> Dictionary:
	return totals_of(allocated)

# The first requirement in `requires` that `totals` does not meet, as "needs STR 4", or "" if all are met.
static func unmet(id: String, totals: Dictionary) -> String:
	var req: Dictionary = row(id)["requires"]
	for a in req:
		if int(totals.get(a, 0)) < int(req[a]):
			return "needs %s %d" % [str(a).to_upper(), int(req[a])]
	return ""

# {ok, reason}. reason is "" when ok.
func can_allocate(id: String) -> Dictionary:
	if not has_node(id):
		return {"ok": false, "reason": "no such node"}
	if allocated.has(id):
		return {"ok": false, "reason": "already allocated"}
	var linked := false
	for n in neighbours(id):
		if n == SkillNodes.HUB or allocated.has(n):
			linked = true
			break
	if not linked:
		return {"ok": false, "reason": "not connected to your tree"}
	var why := unmet(id, attribute_totals())
	if why != "":
		return {"ok": false, "reason": why}
	if points < cost(id):
		return {"ok": false, "reason": "no unspent point"}
	return {"ok": true, "reason": ""}

func allocate(id: String) -> bool:
	if not can_allocate(id)["ok"]:
		return false
	allocated.append(id)
	points -= cost(id)
	return true

# Whether giving `id` back leaves a legal tree. {ok, reason}; the ammo a refund costs is the profile's business.
func can_refund(id: String) -> Dictionary:
	if not allocated.has(id):
		return {"ok": false, "reason": "not allocated"}
	var rest := allocated.duplicate()
	rest.erase(id)
	var seen := _connected(rest)
	for n in rest:
		if not seen.has(n):
			return {"ok": false, "reason": "would cut %s off from the hub" % row(n)["name"]}
	var totals := totals_of(rest)
	for n in rest:
		var why := unmet(n, totals)
		if why != "":
			return {"ok": false, "reason": "%s would no longer be allowed (%s)" % [row(n)["name"], why]}
	return {"ok": true, "reason": ""}

func refund(id: String) -> bool:
	if not can_refund(id)["ok"]:
		return false
	allocated.erase(id)
	points += cost(id)
	return true

# Every id in `ids` reachable from the hub through nodes in `ids` (BFS).
static func _connected(ids: Array) -> Dictionary:
	var seen := {}
	var queue: Array = [SkillNodes.HUB]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in neighbours(cur):
			if ids.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen

# Points needed to reach `id` from the hub or the allocated nodes: the unallocated nodes on the shortest route, `id`
# included. 0 if it is allocated or unknown (every node has a route). Attribute thresholds are not counted (the preview shows them apart).
func shortest_path_cost(id: String) -> int:
	return shortest_path(id).size() * Tuning.SKILL_NODE_COST

# The unallocated node ids to take, in order, to reach `id`; empty if allocated or unknown.
func shortest_path(id: String) -> Array:
	if not has_node(id) or allocated.has(id):
		return []
	var prev := {}
	var queue: Array = []
	for start in allocated + [SkillNodes.HUB]:
		prev[start] = ""
		queue.append(start)
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == id:
			break
		for n in neighbours(cur):
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	var path: Array = []
	var at := id
	while at != "" and not allocated.has(at) and at != SkillNodes.HUB:
		path.push_front(at)
		at = prev[at]
	return path
