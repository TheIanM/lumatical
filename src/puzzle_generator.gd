class_name PuzzleGenerator
extends RefCounted

## Solution-first puzzle generator for Lumatical's roguelike mode.
##
## Generates puzzles that are guaranteed solvable by construction:
## 1. Place a source
## 2. Place random tools to route the beam (the solution)
## 3. Run BeamSimulator to trace where the beams end up
## 4. Place targets at beam endpoints with matching colors
## 5. Strip solution tools and return the puzzle with derived budgets
##
## Difficulty scales with floor number — more tools, more targets,
## and more complex mechanics at higher floors.

const GRID_W := 12
const GRID_H := 8
const CELL_SIZE := 64.0

# Tool types available at each difficulty tier
const TIER_MIRRORS := ["mirror"]
const TIER_COLOR := ["mirror", "prism", "filter"]
const TIER_ADVANCED := ["mirror", "prism", "filter", "splitter", "lens"]
const TIER_ENEMIES := ["mirror", "prism", "filter", "splitter", "lens", "refractor", "teleporter"]


## Generate a puzzle for the given floor number (1-based).
## Returns a level Dictionary matching the LEVELS format.
static func generate(floor_num: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("floor_%d_%d" % [floor_num, randi()])

	var params := _difficulty_params(floor_num)

	# Step 1: Place source
	var source_pos := _random_edge_cell(rng)
	var source_dir := _direction_from_edge(source_pos)
	var source_color := BeamSimulator.WHITE
	var source_intensity := 1.0

	# Weak sources at higher difficulties
	if params.weak_source and rng.randf() < 0.4:
		source_intensity = 0.5

	var source := {
		"pos": source_pos,
		"direction": source_dir,
		"color": source_color,
		"intensity": source_intensity,
	}

	# Step 2: Place solution tools
	var tools: Dictionary = {}
	var solution_tool_count: int = rng.randi_range(params.min_tools, params.max_tools)
	var placed := 0
	var attempts := 0
	while placed < solution_tool_count and attempts < 50:
		attempts += 1
		var pos := Vector2i(rng.randi_range(2, GRID_W - 3), rng.randi_range(1, GRID_H - 2))
		if tools.has(pos) or pos == source_pos:
			continue
		var tool_type: String = params.tool_pool[rng.randi() % params.tool_pool.size()]
		var tool := _make_random_tool(tool_type, rng)
		tools[pos] = tool
		placed += 1

	# Step 3: Simulate
	var result := BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H),
		tools,
		[source],
		CELL_SIZE,
	)

	# Step 4: Extract targets from beam paths
	var targets := _extract_targets(result, tools, params.target_count, rng, source_pos)

	# If we couldn't find enough targets, retry with more tools
	if targets.size() < params.target_count and attempts < 100:
		return generate(floor_num)

	# Step 5: Build the puzzle — strip tools, set budgets
	var level := {
		"name": "Floor %d" % floor_num,
		"sources": [source],
		"targets": targets,
		"blockers": [],
	}

	# Derive budgets from solution
	var tool_counts: Dictionary = {}
	for pos in tools:
		var ttype: String = tools[pos]["type"]
		tool_counts[ttype] = tool_counts.get(ttype, 0) + 1

	# Map tool types to budget keys
	var budget_map := {
		"mirror": "mirror_budget", "prism": "prism_budget",
		"filter": "filter_budget", "splitter": "splitter_budget",
		"lens": "lens_budget", "refractor": "refractor_budget",
		"teleporter": "teleporter_budget",
	}
	for ttype in tool_counts:
		var key: String = budget_map.get(ttype, "")
		if key != "":
			level[key] = tool_counts[ttype]

	# Ensure at least mirror_budget exists
	if not level.has("mirror_budget"):
		level["mirror_budget"] = 0

	# Step 6: Add obstacles/enemies for difficulty
	if params.use_blockers:
		_add_blockers(level, rng, params)
	if params.use_enemies:
		_add_enemies(level, rng, params)

	# Step 7: Validate — re-simulate with solution tools to confirm all
	# targets are still reachable even with blockers/enemies placed.
	# This is the same pattern as the level editor's _run_validation().
	if not _validate(level, tools, source):
		return generate(floor_num)

	return level


# ── Validation ──────────────────────────────────────────────────────────────────

## Re-simulate the puzzle with the solution tools + all fixed elements
## to confirm every target is reachable. Returns true if all targets hit.
static func _validate(level: Dictionary, solution_tools: Dictionary, source: Dictionary) -> bool:
	# Build a tools dict with solution tools + all fixed elements from the level
	var tools: Dictionary = {}

	# Add targets
	for pos in level["targets"]:
		var tdata := {"type": "target", "color": level["targets"][pos]["color"]}
		if level["targets"][pos].has("intensity"):
			tdata["intensity"] = level["targets"][pos]["intensity"]
		tools[pos] = tdata

	# Add blockers
	for pos in level.get("blockers", []):
		tools[pos] = {"type": "blocker"}

	# Add enemies
	for sb in level.get("shadow_blocks", []):
		tools[sb["pos"]] = {"type": "shadow_block", "threshold": float(sb.get("threshold", 0.75))}
	for cs in level.get("chromatic_shades", []):
		tools[cs["pos"]] = {"type": "chromatic_shade", "color": cs["color"]}
	for pos in level.get("null_emitters", []):
		tools[pos] = {"type": "null_emitter"}

	# Add solution tools — skip any that conflict with fixed elements
	for pos in solution_tools:
		if tools.has(pos):
			continue
		tools[pos] = solution_tools[pos]

	# Simulate
	var result := BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H),
		tools,
		[source],
		CELL_SIZE,
	)

	# Check all targets are hit
	for pos in level["targets"]:
		if not pos in result.hit_targets:
			return false

	# Also verify the puzzle is NOT trivially solvable — i.e., at least
	# one target should NOT be hit when no player tools are placed.
	# This prevents the source from pointing directly at a target.
	var no_tools: Dictionary = {}
	for pos in level["targets"]:
		var tdata := {"type": "target", "color": level["targets"][pos]["color"]}
		if level["targets"][pos].has("intensity"):
			tdata["intensity"] = level["targets"][pos]["intensity"]
		no_tools[pos] = tdata
	for pos in level.get("blockers", []):
		no_tools[pos] = {"type": "blocker"}
	for sb in level.get("shadow_blocks", []):
		no_tools[sb["pos"]] = {"type": "shadow_block", "threshold": float(sb.get("threshold", 0.75))}
	for cs in level.get("chromatic_shades", []):
		no_tools[cs["pos"]] = {"type": "chromatic_shade", "color": cs["color"]}
	for pos in level.get("null_emitters", []):
		no_tools[pos] = {"type": "null_emitter"}

	var trivial_result := BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H),
		no_tools,
		[source],
		CELL_SIZE,
	)
	# If every target is hit with zero tools, the puzzle is trivial
	var trivially_solved := true
	for pos in level["targets"]:
		if not pos in trivial_result.hit_targets:
			trivially_solved = false
			break
	return not trivially_solved

class DiffParams:
	var min_tools: int = 1
	var max_tools: int = 2
	var target_count: int = 1
	var tool_pool: Array = TIER_MIRRORS
	var use_blockers: bool = false
	var use_enemies: bool = false
	var weak_source: bool = false
	var blocker_count: int = 0
	var enemy_count: int = 0


static func _difficulty_params(floor_num: int) -> DiffParams:
	var p := DiffParams.new()

	if floor_num <= 5:
		# Easy — mirrors only, 1-2 tools, 1 target
		p.min_tools = 1
		p.max_tools = 2
		p.target_count = 1
		p.tool_pool = TIER_MIRRORS
		p.use_blockers = floor_num >= 3
		p.blocker_count = 1
	elif floor_num <= 15:
		# Normal — add prisms and filters, 2-3 tools, 1-2 targets
		p.min_tools = 2
		p.max_tools = 3
		p.target_count = rng_range(1, 2)
		p.tool_pool = TIER_COLOR
		p.use_blockers = true
		p.blocker_count = rng_range(1, 2)
	elif floor_num <= 30:
		# Hard — add splitters and lenses, 3-4 tools, 2-3 targets
		p.min_tools = 3
		p.max_tools = 4
		p.target_count = rng_range(2, 3)
		p.tool_pool = TIER_ADVANCED
		p.use_blockers = true
		p.blocker_count = rng_range(1, 3)
		p.weak_source = true
	else:
		# Brutal — all tools + enemies, 4-5 tools, 2-3 targets
		p.min_tools = 4
		p.max_tools = 5
		p.target_count = rng_range(2, 3)
		p.tool_pool = TIER_ENEMIES
		p.use_blockers = true
		p.blocker_count = rng_range(2, 3)
		p.use_enemies = true
		p.enemy_count = rng_range(1, 2)
		p.weak_source = true

	return p


# ── Target Extraction ─────────────────────────────────────────────────────────

## Walk along each beam segment and collect every cell the beam passes
## through. These are all valid target positions — the beam clearly
## travels through them with the segment's color.
static func _extract_targets(
	result: BeamSimulator.SimResult,
	tools: Dictionary,
	count: int,
	rng: RandomNumberGenerator,
	source_pos: Vector2i,
) -> Dictionary:
	var candidate_positions: Array = []
	for seg in result.segments:
		var start_grid := Vector2i(
			int(seg.start.x / CELL_SIZE),
			int(seg.start.y / CELL_SIZE),
		)
		var end_grid := Vector2i(
			int(seg.end.x / CELL_SIZE),
			int(seg.end.y / CELL_SIZE),
		)
		# Walk step by step from start to end (inclusive)
		var dx: int = end_grid.x - start_grid.x
		var dy: int = end_grid.y - start_grid.y
		var step := Vector2i(signi(dx), signi(dy))
		var dist := maxi(absi(dx), absi(dy))
		for i in range(dist + 1):
			var cell := start_grid + step * i
			if not _in_bounds(cell):
				continue
			if tools.has(cell):
				continue
			if cell == source_pos:
				continue
			# Avoid duplicates
			var already := false
			for c in candidate_positions:
				if c["pos"] == cell:
					already = true
					break
			if not already:
				candidate_positions.append({"pos": cell, "color": seg.color})

	# Pick unique positions for targets
	var targets: Dictionary = {}
	var used_positions: Array = []
	rng.randomize()
	var shuffled := candidate_positions.duplicate()
	shuffled.shuffle()

	for c in shuffled:
		if targets.size() >= count:
			break
		var pos: Vector2i = c["pos"]
		if pos in used_positions:
			continue
		if targets.has(pos):
			continue
		used_positions.append(pos)
		targets[pos] = {"color": c["color"]}

	return targets


# ── Obstacles ──────────────────────────────────────────────────────────────────

static func _add_blockers(level: Dictionary, rng: RandomNumberGenerator, params: DiffParams) -> void:
	var blockers: Array = []
	var source_pos: Vector2i = level["sources"][0]["pos"]
	for i in range(params.blocker_count):
		var pos := Vector2i(rng.randi_range(3, GRID_W - 4), rng.randi_range(1, GRID_H - 2))
		if pos == source_pos or pos in blockers:
			continue
		# Don't place on targets
		if level["targets"].has(pos):
			continue
		blockers.append(pos)
	level["blockers"] = blockers


static func _add_enemies(level: Dictionary, rng: RandomNumberGenerator, params: DiffParams) -> void:
	var source_pos: Vector2i = level["sources"][0]["pos"]
	for i in range(params.enemy_count):
		var pos := Vector2i(rng.randi_range(4, GRID_W - 4), rng.randi_range(1, GRID_H - 2))
		if pos == source_pos or level["targets"].has(pos) or pos in level.get("blockers", []):
			continue
		var roll := rng.randf()
		if roll < 0.4:
			if not level.has("shadow_blocks"):
				level["shadow_blocks"] = []
			level["shadow_blocks"].append({"pos": pos, "threshold": 0.75})
		elif roll < 0.8:
			if not level.has("chromatic_shades"):
				level["chromatic_shades"] = []
			var colors := [BeamSimulator.RED, BeamSimulator.GREEN, BeamSimulator.BLUE]
			level["chromatic_shades"].append({"pos": pos, "color": colors[rng.randi() % 3]})
		else:
			if not level.has("null_emitters"):
				level["null_emitters"] = []
			level["null_emitters"].append(pos)


# ── Helpers ────────────────────────────────────────────────────────────────────

static func _random_edge_cell(rng: RandomNumberGenerator) -> Vector2i:
	var side := rng.randi() % 4
	match side:
		0: return Vector2i(0, rng.randi_range(1, GRID_H - 2))           # Left
		1: return Vector2i(GRID_W - 1, rng.randi_range(1, GRID_H - 2))   # Right
		2: return Vector2i(rng.randi_range(1, GRID_W - 2), 0)            # Top
		_: return Vector2i(rng.randi_range(1, GRID_W - 2), GRID_H - 1)   # Bottom


static func _direction_from_edge(pos: Vector2i) -> Vector2i:
	if pos.x == 0:           return Vector2i(1, 0)   # Left edge → right
	if pos.x == GRID_W - 1:  return Vector2i(-1, 0)  # Right edge → left
	if pos.y == 0:           return Vector2i(0, 1)   # Top edge → down
	return Vector2i(0, -1)                           # Bottom edge → up


static func _make_random_tool(tool_type: String, rng: RandomNumberGenerator) -> Dictionary:
	match tool_type:
		"mirror":     return {"type": "mirror", "orientation": rng.randi() % 2}
		"prism":      return {"type": "prism", "orientation": rng.randi() % 2}
		"filter":
			var colors := [BeamSimulator.RED, BeamSimulator.GREEN, BeamSimulator.BLUE]
			return {"type": "filter", "color": colors[rng.randi() % 3]}
		"splitter":   return {"type": "splitter", "orientation": rng.randi() % 2}
		"lens":       return {"type": "lens", "orientation": rng.randi() % 2}
		"refractor":  return {"type": "refractor", "orientation": rng.randi() % 2}
		_:            return {"type": "mirror", "orientation": 0}


static func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < GRID_W and p.y >= 0 and p.y < GRID_H


static func rng_range(min_val: int, max_val: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(min_val, max_val)
