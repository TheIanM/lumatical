class_name BeamSimulator
extends RefCounted

## Standalone beam simulation engine for Lumatical.
##
## Traces light beams through a grid of optical tools, applying reflection,
## absorption, and (future) splitting rules at each intersection. Produces
## a list of beam segments for rendering and a set of hit targets for
## win-condition checking.
##
## This module has no Node dependencies — it is pure logic. It is called
## by the game controller, the level editor validator, and the roguelike
## puzzle generator, ensuring one consistent codebase for beam behavior.


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


## Maximum reflections per beam before giving up (prevents infinite loops).
const MAX_BOUNCES := 50


## Run the beam simulation across the entire grid.
##
## [param grid_size] Grid dimensions in cells (width, height).
## [param tools] Dictionary mapping Vector2i cell positions to tool dicts.
##   Tool dict format:
##   - Mirror:  {"type": "mirror", "orientation": 0|1}  (0="/", 1="\")
##   - Target:  {"type": "target", "color": Color}
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
	for source in sources:
		_trace_beam(grid_size, tools, source, cell_size, result)
	return result


## Trace a single beam from its source through the grid.
static func _trace_beam(
	grid_size: Vector2i,
	tools: Dictionary,
	source: Dictionary,
	cell_size: float,
	result: SimResult,
) -> void:
	var pos: Vector2i = source["pos"]
	var direction: Vector2i = source["direction"]
	var beam_color: Color = source["color"]
	var intensity: float = source["intensity"]

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
				"target":
					result.hit_targets.append(next_pos)
					return
				"blocker":
					return
				_:
					pos = next_pos
		else:
			pos = next_pos

		# Guard against infinite reflection loops (two parallel mirrors)
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
