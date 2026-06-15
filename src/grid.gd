class_name Grid
extends Node2D

## Isometric grid system for Lumatical (top-down 2D prototype).
##
## Manages all cell-based game state: fixed elements (sources, targets,
## blockers) and player-placed tools (mirrors, prisms). Handles keyboard
## and mouse input for tool placement, rotation, and removal. Draws the
## elements via _draw().

signal tools_changed

@export var cell_size: float = 64.0
@export var grid_width: int = 12
@export var grid_height: int = 8

# Level data — set by the game controller before _ready()
var sources: Array = []
var targets: Dictionary = {}   # Vector2i -> {"color": Color}
var blockers: Array = []

# Player-placed tools
var mirrors: Dictionary = {}   # Vector2i -> int (0="/", 1="\")
var prisms: Dictionary = {}    # Vector2i -> int (0=default, 1=flipped)

# How many of each tool the player is allowed to place
var mirror_budget: int = 2
var prism_budget: int = 0

# Currently selected tool for placement (0=mirror, 1=prism)
var active_tool: int = 0

# Runtime — updated by the controller after simulation
var _hit_targets: Dictionary = {}

# Mouse tracking
var _hovered_cell := Vector2i(-1, -1)

# ── Colors (from the GDD neon palette) ───────────────────────────────────────
const C_GRID := Color(0.06, 0.06, 0.12, 0.6)
const C_GRID_BORDER := Color(0.1, 0.1, 0.21, 0.9)
const C_SOURCE := Color(0.91, 0.91, 1.0)          # #e8e8ff neon white
const C_SOURCE_GLOW := Color(0.91, 0.91, 1.0, 0.15)
const C_MIRROR := Color(0.0, 0.94, 1.0)           # #00f0ff neon cyan
const C_PRISM := Color(1.0, 0.0, 0.9)             # #ff00e5 neon magenta
const C_BLOCKER := Color(0.18, 0.18, 0.22)
const C_HOVER := Color(1, 1, 1, 0.06)


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	queue_redraw()


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_grid_lines()
	_draw_blockers()
	_draw_targets()
	_draw_prisms()
	_draw_mirrors()
	_draw_sources()
	if _hovered_cell.x >= 0:
		_draw_hover()


func _draw_grid_lines() -> void:
	var total_w := grid_width * cell_size
	var total_h := grid_height * cell_size
	for x in range(grid_width + 1):
		var xp := x * cell_size
		draw_line(Vector2(xp, 0), Vector2(xp, total_h), C_GRID, 1.0)
	for y in range(grid_height + 1):
		var yp := y * cell_size
		draw_line(Vector2(0, yp), Vector2(total_w, yp), C_GRID, 1.0)
	# Bright border
	draw_rect(Rect2(0, 0, total_w, total_h), C_GRID_BORDER, false, 2.0)


func _draw_blockers() -> void:
	for pos in blockers:
		var c := _cell_center(pos)
		var s := cell_size * 0.6
		draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), C_BLOCKER, true)


func _draw_targets() -> void:
	for pos in targets:
		var c := _cell_center(pos)
		var hit := _hit_targets.has(pos)
		var r := cell_size * 0.3
		var base_col: Color = targets[pos]["color"]
		var col := base_col if hit else Color(base_col.r, base_col.g, base_col.b, 0.25)
		# Ring
		draw_arc(c, r, 0, TAU, 36, col, 3.0)
		# Filled dot when hit
		if hit:
			draw_circle(c, r * 0.55, col)


func _draw_mirrors() -> void:
	for pos in mirrors:
		var orient: int = int(mirrors[pos])
		var c := _cell_center(pos)
		var h := cell_size * 0.35
		if orient == 0:  # "/"
			draw_line(c + Vector2(-h, h), c + Vector2(h, -h), C_MIRROR, 4.0)
		else:            # "\"
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), C_MIRROR, 4.0)


func _draw_prisms() -> void:
	for pos in prisms:
		var orient: int = int(prisms[pos])
		var c := _cell_center(pos)
		var s := cell_size * 0.3
		# Triangle — the classic prism shape. Orientation flips it vertically.
		var pts := PackedVector2Array()
		if orient == 0:
			pts.append(c + Vector2(0, -s))
			pts.append(c + Vector2(-s, s))
			pts.append(c + Vector2(s, s))
		else:
			pts.append(c + Vector2(0, s))
			pts.append(c + Vector2(-s, -s))
			pts.append(c + Vector2(s, -s))
		draw_colored_polygon(pts, Color(C_PRISM.r, C_PRISM.g, C_PRISM.b, 0.25))
		for i in range(3):
			draw_line(pts[i], pts[(i + 1) % 3], C_PRISM, 2.5)


func _draw_sources() -> void:
	for src in sources:
		var c := _cell_center(src["pos"])
		var r := cell_size * 0.22
		# Soft glow
		draw_circle(c, r * 1.8, C_SOURCE_GLOW)
		# Core
		draw_circle(c, r, C_SOURCE)
		# Direction arrow
		var d := Vector2(src["direction"])
		var tip := c + d * cell_size * 0.42
		draw_line(c + d * r * 0.8, tip, C_SOURCE, 3.0)
		# Arrowhead
		var perp := Vector2(-d.y, d.x)
		draw_line(tip, tip - d * 8 + perp * 6, C_SOURCE, 2.5)
		draw_line(tip, tip - d * 8 - perp * 6, C_SOURCE, 2.5)


func _draw_hover() -> void:
	if not _in_bounds(_hovered_cell):
		return
	if targets.has(_hovered_cell) or blockers.has(_hovered_cell) or _is_source(_hovered_cell):
		return
	var c := _cell_center(_hovered_cell)
	var s := cell_size * 0.92
	var col: Color = C_HOVER
	if active_tool == 1:
		col = Color(C_PRISM.r, C_PRISM.g, C_PRISM.b, 0.1)
	else:
		col = Color(C_MIRROR.r, C_MIRROR.g, C_MIRROR.b, 0.1)
	draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), col, true)


# ── Public API ───────────────────────────────────────────────────────────────

## Called by the controller after simulation to mark which targets are hit.
func set_hit_targets(arr: Array) -> void:
	_hit_targets.clear()
	for pos in arr:
		_hit_targets[pos] = true
	queue_redraw()


## Remove all player-placed mirrors.
func clear_mirrors() -> void:
	mirrors.clear()
	tools_changed.emit()
	queue_redraw()


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var old := _hovered_cell
		_hovered_cell = _world_to_grid(to_local(get_global_mouse_position()))
		if _hovered_cell != old:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		var gp := _world_to_grid(to_local(get_global_mouse_position()))
		if not _in_bounds(gp):
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_place_or_toggle(gp)
			MOUSE_BUTTON_RIGHT:
				_remove(gp)

	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				active_tool = 0
				tools_changed.emit()
				queue_redraw()
			KEY_2:
				active_tool = 1
				tools_changed.emit()
				queue_redraw()
			KEY_R:
				_rotate_hovered()


func _place_or_toggle(gp: Vector2i) -> void:
	# Can't place on fixed elements
	if targets.has(gp) or blockers.has(gp) or _is_source(gp):
		return

	# If a tool is already here, toggle its orientation
	if mirrors.has(gp):
		mirrors[gp] = 1 - int(mirrors[gp])
		tools_changed.emit()
		queue_redraw()
		return
	if prisms.has(gp):
		prisms[gp] = 1 - int(prisms[gp])
		tools_changed.emit()
		queue_redraw()
		return

	# Place new tool of the active type
	if active_tool == 0:  # Mirror
		if mirrors.size() >= mirror_budget:
			return
		mirrors[gp] = 0
	elif active_tool == 1:  # Prism
		if prisms.size() >= prism_budget:
			return
		prisms[gp] = 0

	tools_changed.emit()
	queue_redraw()


func _remove(gp: Vector2i) -> void:
	var changed := false
	if mirrors.has(gp):
		mirrors.erase(gp)
		changed = true
	if prisms.has(gp):
		prisms.erase(gp)
		changed = true
	if changed:
		tools_changed.emit()
		queue_redraw()


func _rotate_hovered() -> void:
	if mirrors.has(_hovered_cell):
		mirrors[_hovered_cell] = 1 - int(mirrors[_hovered_cell])
		tools_changed.emit()
		queue_redraw()
	elif prisms.has(_hovered_cell):
		prisms[_hovered_cell] = 1 - int(prisms[_hovered_cell])
		tools_changed.emit()
		queue_redraw()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _is_source(gp: Vector2i) -> bool:
	for src in sources:
		if src["pos"] == gp:
			return true
	return false


func _in_bounds(gp: Vector2i) -> bool:
	return gp.x >= 0 and gp.x < grid_width and gp.y >= 0 and gp.y < grid_height


func _cell_center(gp: Vector2i) -> Vector2:
	return Vector2(
		(gp.x + 0.5) * cell_size,
		(gp.y + 0.5) * cell_size,
	)


func _world_to_grid(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(local_pos.x / cell_size),
		int(local_pos.y / cell_size),
	)
