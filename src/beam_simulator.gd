class_name BeamSimulator
extends RefCounted

## Standalone beam simulation engine for Lumatical.
##
## Traces light beams through a grid of optical tools, applying reflection,
## refraction, absorption, and color-splitting rules at each intersection.
## Produces a list of beam segments for rendering and a set of hit targets
## for win-condition checking.
##
## This module has no Node dependencies — it is pure logic. It is called
## by the game controller, the level editor validator, and the roguelike
## puzzle generator, ensuring one consistent codebase for beam behavior.


# ── Beam Colors (from the GDD neon palette) ──────────────────────────────────

const WHITE := Color(0.91, 0.91, 1.0)   # #e8e8ff — full spectrum
const RED   := Color(1.0, 0.25, 0.2)     # #ff4033 — bright warm red
const GREEN := Color(0.0, 1.0, 0.53)     # #00ff88
const BLUE  := Color(0.3, 0.55, 1.0)     # #4d99ff — clear bright blue


## A straight segment of a beam between two grid points (in world space).
class BeamSegment:
	var start: Vector2
	var end: Vector2
	var color: Color
	var intensity: float

	func _init(p_start: Vector2, p_end: Vector2, p_color: Color, p_intensity: float = 1.0) -> void:
		start = p_start
		end = p_end
		color = p_color
		intensity = p_intensity


## Result of a full simulation pass.
class SimResult:
	var segments: Array = []
	var hit_targets: Array = []
	var destroyed_enemies: Dictionary = {}  # pos -> true


## Maximum reflections per beam before giving up (prevents infinite loops).
const MAX_BOUNCES := 50

## Beams below this intensity are too weak to matter — dropped to prevent
## infinite splitting chains (each splitter halves intensity).
const MIN_INTENSITY := 0.05


## Run the beam simulation across the entire grid.
##
## Uses a work queue so that beam-splitting tools (prisms) can spawn new
## beams that are traced independently.
##
## [param grid_size] Grid dimensions in cells (width, height).
## [param tools] Dictionary mapping Vector2i cell positions to tool dicts.
##   Tool dict format:
##   - Mirror:  {"type": "mirror", "orientation": 0|1}  (0="/", 1="\")
##   - Prism:   {"type": "prism", "orientation": 0|1}
##   - Filter:  {"type": "filter", "color": Color}
##   - Splitter:{"type": "splitter", "orientation": 0|1}
##   - Lens:    {"type": "lens", "orientation": 0|1}  (0=convex/focus, 1=concave/spread)
##   - Refractor: {"type": "refractor", "orientation": 0|1}  (0=cw 90°, 1=ccw 90°)
##   - Teleporter: {"type": "teleporter", "pair": Vector2i}  (linked portal)
##   - ShadowBlock: {"type": "shadow_block", "threshold": float}
##   - ChromShade:  {"type": "chromatic_shade", "color": Color}
##   - NullEmitter: {"type": "null_emitter"}
##   - Target:  {"type": "target", "color": Color, "intensity": float (optional min)}
##   - Blocker: {"type": "blocker"}
## [param sources] Array of source dicts:
##   {"pos": Vector2i, "direction": Vector2i, "color": Color, "intensity": float}
## [param cell_size] Pixel size of each grid cell (for world-space output).
## Returns [SimResult] containing beam segments and hit targets.
static func simulate(
	grid_size: Vector2i,
	tools: Dictionary,
	sources: Array,
	cell_size: float,
) -> SimResult:
	var result := SimResult.new()

	# Precompute null emitter dead zones (3x3 area around each emitter)
	var null_zones: Dictionary = {}
	for pos in tools:
		if tools[pos].get("type", "") == "null_emitter":
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					null_zones[pos + Vector2i(dx, dy)] = true

	var queue: Array = []

	for source in sources:
		queue.append({
			"pos": source["pos"],
			"direction": source["direction"],
			"color": source["color"],
			"intensity": source["intensity"],
		})

	while queue.size() > 0:
		# Sort by intensity descending so strong beams process first.
		# This ensures enemies are destroyed before weak beams reach them,
		# preventing order-dependent absorption bugs.
		queue.sort_custom(func(a, b): return float(a["intensity"]) > float(b["intensity"]))
		var beam: Dictionary = queue.pop_front()
		if beam["intensity"] < MIN_INTENSITY:
			continue
		_trace_single_beam(grid_size, tools, beam, cell_size, result, queue, null_zones)

	return result


## Trace a single beam from its starting position through the grid until it
## exits, is absorbed, or (in the case of a prism split) hands off new beams
## to the queue.
static func _trace_single_beam(
	grid_size: Vector2i,
	tools: Dictionary,
	beam: Dictionary,
	cell_size: float,
	result: SimResult,
	queue: Array,
	null_zones: Dictionary,
) -> void:
	var pos: Vector2i = beam["pos"]
	var direction: Vector2i = beam["direction"]
	var beam_color: Color = beam["color"]
	var intensity: float = beam["intensity"]

	var segment_start := pos
	var visited := {}

	for _bounce in MAX_BOUNCES:
		var next_pos := pos + direction

		# Beam has left the grid
		if not _in_bounds(next_pos, grid_size):
			if segment_start != pos:
				result.segments.append(BeamSegment.new(
					_to_world(segment_start, cell_size),
					_to_world(pos, cell_size),
					beam_color,
					intensity,
				))
			return

		# Null emitter dead zone — beam cancelled before reaching anything
		if null_zones.has(next_pos):
			if segment_start != pos:
				result.segments.append(BeamSegment.new(
					_to_world(segment_start, cell_size),
					_to_world(pos, cell_size),
					beam_color,
					intensity,
				))
			return

		# Check what's in the next cell
		if tools.has(next_pos):
			var tool: Dictionary = tools[next_pos]

			# Close current segment at the tool
			result.segments.append(BeamSegment.new(
				_to_world(segment_start, cell_size),
				_to_world(next_pos, cell_size),
				beam_color,
				intensity,
			))

			match tool["type"]:
				"mirror":
					direction = _reflect(direction, tool["orientation"])
					pos = next_pos
					segment_start = next_pos
				"prism":
					if _is_white(beam_color):
						# White beam splits into RGB — hand off to queue
						var orient: int = int(tool.get("orientation", 0))
						var left_dir := _turn_left(direction)
						var right_dir := _turn_right(direction)
						# Orientation 0: red=left, blue=right. Orientation 1: swapped.
						var red_dir := left_dir if orient == 0 else right_dir
						var blue_dir := right_dir if orient == 0 else left_dir
						queue.append({"pos": next_pos, "direction": direction, "color": GREEN, "intensity": intensity})
						queue.append({"pos": next_pos, "direction": red_dir, "color": RED, "intensity": intensity})
						queue.append({"pos": next_pos, "direction": blue_dir, "color": BLUE, "intensity": intensity})
						return
					else:
						# Colored beam passes through unaffected
						pos = next_pos
						segment_start = next_pos
				"filter":
					var filter_color: Color = tool["color"]
					if _is_white(beam_color):
						# White light: only the filter's color passes through
						beam_color = filter_color
						pos = next_pos
						segment_start = next_pos
					elif _colors_match(beam_color, filter_color):
						# Matching color: passes through unaffected
						pos = next_pos
						segment_start = next_pos
					else:
						# Non-matching: absorbed
						return
				"splitter":
					var sp_orient: int = int(tool.get("orientation", 0))
					var turn_dir := _turn_right(direction) if sp_orient == 0 else _turn_left(direction)
					var half_i := intensity * 0.5
					queue.append({"pos": next_pos, "direction": direction, "color": beam_color, "intensity": half_i})
					queue.append({"pos": next_pos, "direction": turn_dir, "color": beam_color, "intensity": half_i})
					return
				"lens":
					var lens_orient: int = int(tool.get("orientation", 0))
					# Convex (0): focuses beam — intensity ×1.5
					# Concave (1): spreads beam — intensity ×0.5
					intensity = intensity * (1.5 if lens_orient == 0 else 0.5)
					pos = next_pos
					segment_start = next_pos
				"refractor":
					# 90° turn regardless of entry angle
					var r_orient: int = int(tool.get("orientation", 0))
					direction = _turn_right(direction) if r_orient == 0 else _turn_left(direction)
					pos = next_pos
					segment_start = next_pos
				"teleporter":
					# Beam exits at the paired portal, same direction
					var pair_pos: Vector2i = tool.get("pair", next_pos)
					pos = pair_pos
					segment_start = pair_pos
				"target":
					# Target absorbs the beam; only counts as hit if color matches
					# and intensity meets the target's minimum (if specified).
					if _colors_match(beam_color, tool["color"]):
						var min_i: float = float(tool.get("intensity", 0.0))
						if intensity >= min_i:
							result.hit_targets.append(next_pos)
					return
				"blocker":
					return
				"shadow_block":
					if result.destroyed_enemies.has(next_pos):
						pos = next_pos
						segment_start = next_pos
					elif intensity >= float(tool.get("threshold", 0.75)):
						result.destroyed_enemies[next_pos] = true
						pos = next_pos
						segment_start = next_pos
					else:
						return
				"chromatic_shade":
					if result.destroyed_enemies.has(next_pos):
						pos = next_pos
						segment_start = next_pos
					elif _colors_match(beam_color, tool["color"]):
						result.destroyed_enemies[next_pos] = true
						pos = next_pos
						segment_start = next_pos
					else:
						return
				"null_emitter":
					return
				_:
					pos = next_pos
		else:
			pos = next_pos

		# Guard against infinite reflection loops (e.g. two parallel mirrors)
		var state_key := "%d,%d,%d,%d" % [pos.x, pos.y, direction.x, direction.y]
		if visited.has(state_key):
			return
		visited[state_key] = true


static func _in_bounds(p: Vector2i, grid_size: Vector2i) -> bool:
	return p.x >= 0 and p.x < grid_size.x and p.y >= 0 and p.y < grid_size.y


static func _to_world(grid_pos: Vector2i, cell_size: float) -> Vector2:
	return Vector2(
		(grid_pos.x + 0.5) * cell_size,
		(grid_pos.y + 0.5) * cell_size,
	)


## Check whether a beam color is white (the full spectrum that prisms split).
static func _is_white(c: Color) -> bool:
	return c.is_equal_approx(WHITE)


## Check whether two colors match for target-activation purposes.
static func _colors_match(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)


## Reflect a cardinal beam direction off a mirror.
## [param direction] Incoming beam direction (must be cardinal).
## [param orientation] 0 = "/" mirror, 1 = "\" mirror.
## Returns the reflected direction, or the input unchanged if not cardinal.
static func _reflect(direction: Vector2i, orientation: int) -> Vector2i:
	if orientation == 0:  # "/" mirror
		if direction == Vector2i.RIGHT: return Vector2i.UP
		if direction == Vector2i.UP: return Vector2i.RIGHT
		if direction == Vector2i.LEFT: return Vector2i.DOWN
		if direction == Vector2i.DOWN: return Vector2i.LEFT
	else:  # "\" mirror
		if direction == Vector2i.RIGHT: return Vector2i.DOWN
		if direction == Vector2i.DOWN: return Vector2i.RIGHT
		if direction == Vector2i.LEFT: return Vector2i.UP
		if direction == Vector2i.UP: return Vector2i.LEFT
	return direction


## Turn a cardinal direction 90 degrees counterclockwise (left).
static func _turn_left(direction: Vector2i) -> Vector2i:
	return Vector2i(direction.y, -direction.x)


## Turn a cardinal direction 90 degrees clockwise (right).
static func _turn_right(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)
