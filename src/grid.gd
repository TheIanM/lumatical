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

# Enemy elements (fixed, set by controller)
var shadow_blocks: Array = []     # [{"pos": Vector2i, "threshold": float}]
var chromatic_shades: Array = []  # [{"pos": Vector2i, "color": Color}]
var null_emitters: Array = []    # [Vector2i, ...]

# Player-placed tools
var mirrors: Dictionary = {}   # Vector2i -> int (0="/", 1="\")
var prisms: Dictionary = {}    # Vector2i -> int (0=default, 1=flipped)
var filters: Dictionary = {}   # Vector2i -> int color index (0=R, 1=G, 2=B)
var splitters: Dictionary = {} # Vector2i -> int (0=split-right, 1=split-left)
var lenses: Dictionary = {}    # Vector2i -> int (0=convex/focus, 1=concave/spread)

# How many of each tool the player is allowed to place
var mirror_budget: int = 2
var prism_budget: int = 0
var filter_budget: int = 0
var splitter_budget: int = 0
var lens_budget: int = 0

# Currently selected tool for placement
# 0=mirror, 1=prism, 2=filter, 3=splitter, 4=lens
var active_tool: int = 0

# Runtime — updated by the controller after simulation
var _hit_targets: Dictionary = {}
var _destroyed_enemies: Dictionary = {}

# Mouse tracking
var _hovered_cell := Vector2i(-1, -1)

# ── Colors (from the GDD neon palette) ───────────────────────────────────────
const C_GRID := Color(0.06, 0.06, 0.12, 0.6)
const C_GRID_BORDER := Color(0.1, 0.1, 0.21, 0.9)
const C_SOURCE := Color(0.91, 0.91, 1.0)          # #e8e8ff neon white
const C_SOURCE_GLOW := Color(0.91, 0.91, 1.0, 0.15)
const C_MIRROR := Color(0.0, 0.94, 1.0)           # #00f0ff neon cyan
const C_PRISM := Color(1.0, 0.0, 0.9)             # #ff00e5 neon magenta
const C_FILTER := Color(1.0, 0.9, 0.0)           # #ffe600 neon yellow
const C_SPLITTER := Color(1.0, 0.53, 0.0)        # #ff8800 neon orange
const C_LENS := Color(0.67, 0.4, 1.0)            # #aa66ff neon violet
const C_BLOCKER := Color(0.18, 0.18, 0.22)
const C_SHADOW := Color(0.12, 0.05, 0.15)         # Dark purple-black
const C_SHADE := Color(0.4, 0.4, 0.55, 0.25)      # Ghostly neutral
const C_NULL := Color(0.08, 0.0, 0.12)            # Deep void
const C_NULL_FIELD := Color(0.02, 0.0, 0.04, 0.35) # Dead zone overlay
const C_HOVER := Color(1, 1, 1, 0.06)

var _time: float = 0.0

# Filter colors — indexed by the int stored in `filters`
const FILTER_COLORS := [
	Color(1.0, 0.2, 0.33),   # RED
	Color(0.0, 1.0, 0.53),   # GREEN
	Color(0.27, 0.4, 1.0),   # BLUE
]


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_grid_lines()
	_draw_null_fields()
	_draw_blockers()
	_draw_shadow_blocks()
	_draw_chromatic_shades()
	_draw_null_emitters()
	_draw_targets()
	_draw_splitters()
	_draw_lenses()
	_draw_filters()
	_draw_prisms()
	_draw_mirrors()
	_draw_sources()
	if _hovered_cell.x >= 0:
		_draw_hover()


func _draw_grid_lines() -> void:
	var total_w := grid_width * cell_size
	var total_h := grid_height * cell_size
	# Arena floor — dark translucent backdrop gives the grid depth
	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.02, 0.02, 0.05, 0.5), true)
	# Breathing grid — subtle opacity pulse
	var breath := 0.6 + sin(_time * 0.8) * 0.15
	var grid_col := Color(C_GRID.r, C_GRID.g, C_GRID.b, C_GRID.a * breath)
	for x in range(grid_width + 1):
		var xp := x * cell_size
		draw_line(Vector2(xp, 0), Vector2(xp, total_h), grid_col, 1.0)
	for y in range(grid_height + 1):
		var yp := y * cell_size
		draw_line(Vector2(0, yp), Vector2(total_w, yp), grid_col, 1.0)
	# Bright border with subtle pulse
	var border_glow := 0.7 + sin(_time * 1.2) * 0.2
	draw_rect(Rect2(0, 0, total_w, total_h), Color(C_GRID_BORDER.r, C_GRID_BORDER.g, C_GRID_BORDER.b, border_glow), false, 2.0)


func _draw_blockers() -> void:
	for pos in blockers:
		var c := _cell_center(pos)
		var s := cell_size * 0.6
		# Dark fill
		draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), C_BLOCKER, true)
		# Subtle red-tinged border — feels ominous
		draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), Color(0.3, 0.1, 0.12, 0.6), false, 1.5)


func _draw_shadow_blocks() -> void:
	for sb in shadow_blocks:
		var pos: Vector2i = sb["pos"]
		var c := _cell_center(pos)
		var s := cell_size * 0.32
		var destroyed := _destroyed_enemies.has(pos)
		var alpha := 0.15 if destroyed else 1.0
		var pulse := 0.7 + sin(_time * 1.5) * 0.3
		# Hexagon shape — distinct from square blockers
		var pts := PackedVector2Array()
		for i in range(6):
			var angle := TAU * i / 6.0 - PI / 2.0
			pts.append(c + Vector2(cos(angle), sin(angle)) * s)
		if not destroyed:
			draw_colored_polygon(pts, Color(C_SHADOW.r, C_SHADOW.g, C_SHADOW.b, 0.7))
			for i in range(6):
				draw_line(pts[i], pts[(i + 1) % 6], Color(0.5, 0.2, 0.6, 0.8), 2.0)
			# Pulsing intensity indicator in center
			draw_circle(c, s * 0.35 * pulse, Color(0.7, 0.3, 0.8, 0.15))
		else:
			# Faint outline — destroyed
			for i in range(6):
				draw_line(pts[i], pts[(i + 1) % 6], Color(0.3, 0.15, 0.35, alpha * 0.3), 1.0)


func _draw_chromatic_shades() -> void:
	for cs in chromatic_shades:
		var pos: Vector2i = cs["pos"]
		var col: Color = cs["color"]
		var c := _cell_center(pos)
		var r := cell_size * 0.3
		var destroyed := _destroyed_enemies.has(pos)
		if destroyed:
			# Faint ghost outline
			draw_arc(c, r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.15), 1.0)
		else:
			# Ghostly translucent shape in its vulnerability color
			var pulse := 0.6 + sin(_time * 1.8) * 0.15
			draw_circle(c, r * 1.3, Color(col.r, col.g, col.b, 0.04 * pulse))
			draw_circle(c, r, Color(col.r, col.g, col.b, 0.12 * pulse))
			draw_arc(c, r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.5), 2.0)


func _draw_null_emitters() -> void:
	for pos in null_emitters:
		var c := _cell_center(pos)
		var r := cell_size * 0.22
		var pulse := 0.7 + sin(_time * 2.0) * 0.15
		# Dark core
		draw_circle(c, r * pulse, C_NULL)
		# Radiating dark ring
		draw_arc(c, r * 1.8 * pulse, 0, TAU, 24, Color(0.1, 0.0, 0.15, 0.5), 2.0)


func _draw_null_fields() -> void:
	# Draw dead zone overlay for each null emitter (3x3 area)
	for pos in null_emitters:
		var cx: float = (pos.x - 0.5) * cell_size
		var cy: float = (pos.y - 0.5) * cell_size
		var s := cell_size * 3.0
		var pulse := 0.7 + sin(_time * 1.5) * 0.15
		var col := Color(C_NULL_FIELD.r, C_NULL_FIELD.g, C_NULL_FIELD.b, C_NULL_FIELD.a * pulse)
		draw_rect(Rect2(cx, cy, s, s), col, true)


func _draw_targets() -> void:
	for pos in targets:
		var c := _cell_center(pos)
		var hit := _hit_targets.has(pos)
		var r := cell_size * 0.3
		var base_col: Color = targets[pos]["color"]
		if hit:
			# Hit target — pulsing glow when activated
			var pulse := 1.0 + sin(_time * 4.0) * 0.15
			draw_circle(c, r * 2.0 * pulse, Color(base_col.r, base_col.g, base_col.b, 0.08))
			draw_circle(c, r * 1.4, Color(base_col.r, base_col.g, base_col.b, 0.15))
			draw_arc(c, r * pulse, 0, TAU, 36, base_col, 3.0)
			draw_circle(c, r * 0.55 * pulse, base_col)
		else:
			# Unhit — dim ring with slow breathing
			var breath := 0.2 + sin(_time * 1.5 + pos.x * 0.5) * 0.05
			var col := Color(base_col.r, base_col.g, base_col.b, breath)
			draw_arc(c, r, 0, TAU, 36, col, 2.0)


func _draw_mirrors() -> void:
	for pos in mirrors:
		var orient: int = int(mirrors[pos])
		var c := _cell_center(pos)
		var h := cell_size * 0.35
		# Soft glow halo
		var glow_r := cell_size * 0.4
		draw_circle(c, glow_r, Color(C_MIRROR.r, C_MIRROR.g, C_MIRROR.b, 0.04))
		if orient == 0:  # "/"
			draw_line(c + Vector2(-h, h), c + Vector2(h, -h), C_MIRROR, 4.0)
		else:            # "\"
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), C_MIRROR, 4.0)


func _draw_prisms() -> void:
	for pos in prisms:
		var orient: int = int(prisms[pos])
		var c := _cell_center(pos)
		var s := cell_size * 0.3
		# Soft glow halo
		draw_circle(c, cell_size * 0.4, Color(C_PRISM.r, C_PRISM.g, C_PRISM.b, 0.04))
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


func _draw_filters() -> void:
	for pos in filters:
		var color_idx: int = int(filters[pos])
		var c := _cell_center(pos)
		var s := cell_size * 0.35
		var col: Color = FILTER_COLORS[color_idx]
		# Two vertical bars representing a color filter slab
		draw_rect(
			Rect2(c.x - s * 0.35, c.y - s, s * 0.7, s * 2.0),
			Color(col.r, col.g, col.b, 0.25), true)
		draw_rect(
			Rect2(c.x - s * 0.35, c.y - s, s * 0.7, s * 2.0),
			col, false, 2.5)


func _draw_splitters() -> void:
	for pos in splitters:
		var orient: int = int(splitters[pos])
		var c := _cell_center(pos)
		var s := cell_size * 0.3
		# Diamond shape — visually distinct from mirrors and prisms
		var pts := PackedVector2Array([
			c + Vector2(0, -s),
			c + Vector2(s, 0),
			c + Vector2(0, s),
			c + Vector2(-s, 0),
		])
		draw_colored_polygon(pts, Color(C_SPLITTER.r, C_SPLITTER.g, C_SPLITTER.b, 0.25))
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], C_SPLITTER, 2.0)
		# Arrow indicating split direction
		var arrow_y := s * 0.3 if orient == 0 else -s * 0.3
		draw_line(c, c + Vector2(0, arrow_y), C_SPLITTER, 1.5)


func _draw_lenses() -> void:
	for pos in lenses:
		var orient: int = int(lenses[pos])
		var c := _cell_center(pos)
		var s := cell_size * 0.3
		# Soft glow halo
		draw_circle(c, cell_size * 0.4, Color(C_LENS.r, C_LENS.g, C_LENS.b, 0.04))
		# Lens shape: two arcs forming an eye/lens outline
		# Convex (0): horizontal "()" shape (converging)
		# Concave (1): vertical ")(" shape (diverging)
		if orient == 0:
			draw_arc(c + Vector2(-s * 0.3, 0), s * 0.7, -PI / 2, PI / 2, 16, C_LENS, 2.5)
			draw_arc(c + Vector2(s * 0.3, 0), s * 0.7, PI / 2, PI * 1.5, 16, C_LENS, 2.5)
		else:
			draw_arc(c + Vector2(0, -s * 0.3), s * 0.7, 0, PI, 16, C_LENS, 2.5)
			draw_arc(c + Vector2(0, s * 0.3), s * 0.7, PI, TAU, 16, C_LENS, 2.5)


func _draw_sources() -> void:
	for src in sources:
		var c := _cell_center(src["pos"])
		var r := cell_size * 0.22
		var pulse := 1.0 + sin(_time * 2.5) * 0.12
		# Outer aura — wide and very faint, pulses
		draw_circle(c, r * 3.5 * pulse, Color(C_SOURCE.r, C_SOURCE.g, C_SOURCE.b, 0.03))
		draw_circle(c, r * 2.5 * pulse, Color(C_SOURCE.r, C_SOURCE.g, C_SOURCE.b, 0.06))
		# Mid glow
		draw_circle(c, r * 1.8, C_SOURCE_GLOW)
		# Core — bright white-hot
		draw_circle(c, r * pulse, C_SOURCE)
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
	var base: Color
	match active_tool:
		0: base = C_MIRROR
		1: base = C_PRISM
		2: base = C_FILTER
		3: base = C_SPLITTER
		4: base = C_LENS
		_: base = Color(1, 1, 1)
	draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), Color(base.r, base.g, base.b, 0.1), true)


# ── Public API ───────────────────────────────────────────────────────────────

## Called by the controller after simulation to mark which targets are hit.
func set_hit_targets(arr: Array) -> void:
	_hit_targets.clear()
	for pos in arr:
		_hit_targets[pos] = true
	queue_redraw()


## Called by the controller after simulation to mark destroyed enemies.
func set_destroyed_enemies(d: Dictionary) -> void:
	_destroyed_enemies = d.duplicate()
	queue_redraw()


## Remove all player-placed tools (mirrors, prisms, filters, splitters).
func clear_tools() -> void:
	mirrors.clear()
	prisms.clear()
	filters.clear()
	splitters.clear()
	lenses.clear()
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
				if mirror_budget > 0:
					active_tool = 0
					tools_changed.emit()
					queue_redraw()
			KEY_2:
				if prism_budget > 0:
					active_tool = 1
					tools_changed.emit()
					queue_redraw()
			KEY_3:
				if filter_budget > 0:
					active_tool = 2
					tools_changed.emit()
					queue_redraw()
			KEY_4:
				if splitter_budget > 0:
					active_tool = 3
					tools_changed.emit()
					queue_redraw()
			KEY_5:
				if lens_budget > 0:
					active_tool = 4
					tools_changed.emit()
					queue_redraw()
			KEY_R:
				_rotate_hovered()


func _place_or_toggle(gp: Vector2i) -> void:
	# Can't place on fixed elements
	if targets.has(gp) or blockers.has(gp) or _is_source(gp):
		return

	# If a tool is already here, toggle its orientation/color
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
	if filters.has(gp):
		# Cycle filter color: R -> G -> B -> R
		filters[gp] = (int(filters[gp]) + 1) % 3
		tools_changed.emit()
		queue_redraw()
		return
	if splitters.has(gp):
		splitters[gp] = 1 - int(splitters[gp])
		tools_changed.emit()
		queue_redraw()
		return
	if lenses.has(gp):
		lenses[gp] = 1 - int(lenses[gp])
		tools_changed.emit()
		queue_redraw()
		return

	# Place new tool of the active type
	match active_tool:
		0:  # Mirror
			if mirrors.size() >= mirror_budget:
				return
			mirrors[gp] = 0
		1:  # Prism
			if prisms.size() >= prism_budget:
				return
			prisms[gp] = 0
		2:  # Filter
			if filters.size() >= filter_budget:
				return
			filters[gp] = 0
		3:  # Splitter
			if splitters.size() >= splitter_budget:
				return
			splitters[gp] = 0
		4:  # Lens
			if lenses.size() >= lens_budget:
				return
			lenses[gp] = 0

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
	if filters.has(gp):
		filters.erase(gp)
		changed = true
	if splitters.has(gp):
		splitters.erase(gp)
		changed = true
	if lenses.has(gp):
		lenses.erase(gp)
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
	elif filters.has(_hovered_cell):
		filters[_hovered_cell] = (int(filters[_hovered_cell]) + 1) % 3
		tools_changed.emit()
		queue_redraw()
	elif splitters.has(_hovered_cell):
		splitters[_hovered_cell] = 1 - int(splitters[_hovered_cell])
		tools_changed.emit()
		queue_redraw()
	elif lenses.has(_hovered_cell):
		lenses[_hovered_cell] = 1 - int(lenses[_hovered_cell])
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
