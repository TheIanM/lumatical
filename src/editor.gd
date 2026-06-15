extends Node2D

## Lumatical — Level Editor.
##
## Solution-first puzzle editor:
## 1. Place fixed elements (sources, targets, blockers, enemies).
## 2. Place solution tools (mirrors, prisms, etc.) to prove solvability.
## 3. Validate — runs BeamSimulator, confirms all targets are hit.
## 4. Export — saves JSON with budgets derived from solution tool count.
##
## Palette (left side): select element type, then click grid to place.
## Right-click removes anything at that cell.

const CELL_SIZE := 56.0
const GRID_W := 12
const GRID_H := 8
const GRID_OFFSET := Vector2(200, 80)

# Palette indices
enum Pal {
	SOURCE, TARGET_WHITE, TARGET_RED, TARGET_GREEN, TARGET_BLUE,
	BLOCKER, SHADOW_BLOCK, SHADE_RED, SHADE_GREEN, SHADE_BLUE, NULL_EMITTER,
	SOL_MIRROR, SOL_PRISM, SOL_FILTER_R, SOL_FILTER_G, SOL_FILTER_B,
	SOL_SPLITTER, SOL_LENS_CONVEX, SOL_LENS_CONCAVE,
	ERASE,
}

var _palette_index: int = Pal.SOURCE

# Fixed elements (part of the puzzle)
var _sources: Array = []
var _targets: Dictionary = {}
var _blockers: Array = []
var _shadow_blocks: Array = []
var _chromatic_shades: Array = []
var _null_emitters: Array = []

# Solution tools (proof of solvability — stripped on export)
var _sol_mirrors: Dictionary = {}
var _sol_prisms: Dictionary = {}
var _sol_filters: Dictionary = {}
var _sol_splitters: Dictionary = {}
var _sol_lenses: Dictionary = {}

var _time: float = 0.0
var _hovered_cell := Vector2i(-1, -1)
var _sim_result: BeamSimulator.SimResult = null
var _validation_msg := "Place elements, then click Validate."

var _palette_buttons: Dictionary = {}  # Pal enum -> Button

@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	$Grid.position = GRID_OFFSET
	$BeamLayer.position = GRID_OFFSET
	_create_palette()
	_create_toolbar()
	_run_validation()


func _process(delta: float) -> void:
	_time += delta
	$Grid.queue_redraw()
	$BeamLayer.queue_redraw()


# ── Palette ───────────────────────────────────────────────────────────────────

const PALETTE_LAYOUT := [
	[Pal.SOURCE, "Source", Color(0.91, 0.91, 1.0)],
	[Pal.TARGET_WHITE, "Target: White", Color(0.91, 0.91, 1.0)],
	[Pal.TARGET_RED, "Target: Red", BeamSimulator.RED],
	[Pal.TARGET_GREEN, "Target: Green", BeamSimulator.GREEN],
	[Pal.TARGET_BLUE, "Target: Blue", BeamSimulator.BLUE],
	[Pal.BLOCKER, "Blocker", Color(0.4, 0.4, 0.45)],
	[Pal.SHADOW_BLOCK, "Shadow Block", Color(0.5, 0.2, 0.6)],
	[Pal.SHADE_RED, "Shade: Red", BeamSimulator.RED],
	[Pal.SHADE_GREEN, "Shade: Green", BeamSimulator.GREEN],
	[Pal.SHADE_BLUE, "Shade: Blue", BeamSimulator.BLUE],
	[Pal.NULL_EMITTER, "Null Emitter", Color(0.3, 0.0, 0.4)],
	[Pal.SOL_MIRROR, "Sol: Mirror", Color(0.0, 0.94, 1.0)],
	[Pal.SOL_PRISM, "Sol: Prism", Color(1.0, 0.0, 0.9)],
	[Pal.SOL_FILTER_R, "Sol: Filter R", BeamSimulator.RED],
	[Pal.SOL_FILTER_G, "Sol: Filter G", BeamSimulator.GREEN],
	[Pal.SOL_FILTER_B, "Sol: Filter B", BeamSimulator.BLUE],
	[Pal.SOL_SPLITTER, "Sol: Splitter", Color(1.0, 0.53, 0.0)],
	[Pal.SOL_LENS_CONVEX, "Sol: Lens +", Color(0.67, 0.4, 1.0)],
	[Pal.SOL_LENS_CONCAVE, "Sol: Lens -", Color(0.5, 0.3, 0.8)],
	[Pal.ERASE, "Erase", Color(0.8, 0.2, 0.2)],
]


func _create_palette() -> void:
	var panel := ScrollContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 8
	panel.offset_top = 8
	panel.offset_right = 188
	panel.offset_bottom = -90
	_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "PALETTE"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	vbox.add_child(header)

	for entry in PALETTE_LAYOUT:
		var idx: int = entry[0]
		var label: String = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(170, 28)
		btn.pressed.connect(_on_palette_select.bind(idx))
		vbox.add_child(btn)
		_palette_buttons[idx] = btn

	_update_palette_highlight()


func _update_palette_highlight() -> void:
	for idx in _palette_buttons:
		var btn: Button = _palette_buttons[idx]
		if idx == _palette_index:
			var entry = PALETTE_LAYOUT[_palette_index]
			btn.add_theme_color_override("font_color", entry[2])
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))


func _on_palette_select(idx: int) -> void:
	_palette_index = idx
	_update_palette_highlight()


# ── Toolbar ───────────────────────────────────────────────────────────────────

func _create_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -48
	bar.offset_bottom = -8
	bar.offset_left = 200
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_theme_constant_override("separation", 8)
	_ui.add_child(bar)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.custom_minimum_size = Vector2(120, 36)
	validate_btn.pressed.connect(_run_validation)
	bar.add_child(validate_btn)

	var export_btn := Button.new()
	export_btn.text = "Export JSON"
	export_btn.custom_minimum_size = Vector2(120, 36)
	export_btn.pressed.connect(_export)
	bar.add_child(export_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(100, 36)
	clear_btn.pressed.connect(_clear_all)
	bar.add_child(clear_btn)

	var back_btn := Button.new()
	back_btn.text = "← Back to Game"
	back_btn.custom_minimum_size = Vector2(140, 36)
	back_btn.pressed.connect(_back_to_game)
	bar.add_child(back_btn)


# ── Grid Drawing ──────────────────────────────────────────────────────────────

func _draw_grid() -> void:
	# Drawn via the Grid child node — we use a simple Node2D with a custom draw
	pass


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var grid_node: Node2D = $Grid
	if event is InputEventMouseMotion:
		var old := _hovered_cell
		_hovered_cell = _world_to_grid(grid_node.to_local(get_global_mouse_position()))
		if _hovered_cell != old:
			grid_node.queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		var gp := _world_to_grid(grid_node.to_local(get_global_mouse_position()))
		if not _in_bounds(gp):
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_place(gp)
			MOUSE_BUTTON_RIGHT:
				_erase_at(gp)

	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotate_solution_tool(_hovered_cell)


func _place(gp: Vector2i) -> void:
	# Can't overlap fixed elements with other fixed elements
	match _palette_index:
		Pal.SOURCE:
			if _is_occupied(gp):
				return
			_sources.append({"pos": gp, "direction": Vector2i(1, 0), "color": BeamSimulator.WHITE, "intensity": 1.0})
		Pal.TARGET_WHITE:
			if _is_occupied(gp): return
			_targets[gp] = {"color": BeamSimulator.WHITE}
		Pal.TARGET_RED:
			if _is_occupied(gp): return
			_targets[gp] = {"color": BeamSimulator.RED}
		Pal.TARGET_GREEN:
			if _is_occupied(gp): return
			_targets[gp] = {"color": BeamSimulator.GREEN}
		Pal.TARGET_BLUE:
			if _is_occupied(gp): return
			_targets[gp] = {"color": BeamSimulator.BLUE}
		Pal.BLOCKER:
			if _is_occupied(gp): return
			_blockers.append(gp)
		Pal.SHADOW_BLOCK:
			if _is_occupied(gp): return
			_shadow_blocks.append({"pos": gp, "threshold": 0.75})
		Pal.SHADE_RED:
			if _is_occupied(gp): return
			_chromatic_shades.append({"pos": gp, "color": BeamSimulator.RED})
		Pal.SHADE_GREEN:
			if _is_occupied(gp): return
			_chromatic_shades.append({"pos": gp, "color": BeamSimulator.GREEN})
		Pal.SHADE_BLUE:
			if _is_occupied(gp): return
			_chromatic_shades.append({"pos": gp, "color": BeamSimulator.BLUE})
		Pal.NULL_EMITTER:
			if _is_occupied(gp): return
			_null_emitters.append(gp)
		# Solution tools — can only place on empty cells (not on fixed elements)
		Pal.SOL_MIRROR:
			if _is_fixed(gp): return
			_sol_mirrors[gp] = 0
		Pal.SOL_PRISM:
			if _is_fixed(gp): return
			_sol_prisms[gp] = 0
		Pal.SOL_FILTER_R:
			if _is_fixed(gp): return
			_sol_filters[gp] = 0
		Pal.SOL_FILTER_G:
			if _is_fixed(gp): return
			_sol_filters[gp] = 1
		Pal.SOL_FILTER_B:
			if _is_fixed(gp): return
			_sol_filters[gp] = 2
		Pal.SOL_SPLITTER:
			if _is_fixed(gp): return
			_sol_splitters[gp] = 0
		Pal.SOL_LENS_CONVEX:
			if _is_fixed(gp): return
			_sol_lenses[gp] = 0
		Pal.SOL_LENS_CONCAVE:
			if _is_fixed(gp): return
			_sol_lenses[gp] = 1
		Pal.ERASE:
			_erase_at(gp)

	_run_validation()


func _erase_at(gp: Vector2i) -> void:
	var changed := false
	# Erase solution tools first
	if _sol_mirrors.has(gp): _sol_mirrors.erase(gp); changed = true
	if _sol_prisms.has(gp): _sol_prisms.erase(gp); changed = true
	if _sol_filters.has(gp): _sol_filters.erase(gp); changed = true
	if _sol_splitters.has(gp): _sol_splitters.erase(gp); changed = true
	if _sol_lenses.has(gp): _sol_lenses.erase(gp); changed = true
	if changed:
		_run_validation()
		return
	# Erase fixed elements
	for i in range(_sources.size()):
		if _sources[i]["pos"] == gp:
			_sources.remove_at(i)
			changed = true
			break
	if _targets.has(gp): _targets.erase(gp); changed = true
	if _blockers.has(gp): _blockers.erase(gp); changed = true
	for i in range(_shadow_blocks.size()):
		if _shadow_blocks[i]["pos"] == gp:
			_shadow_blocks.remove_at(i)
			changed = true
			break
	for i in range(_chromatic_shades.size()):
		if _chromatic_shades[i]["pos"] == gp:
			_chromatic_shades.remove_at(i)
			changed = true
			break
	if _null_emitters.has(gp): _null_emitters.erase(gp); changed = true
	if changed:
		_run_validation()


func _rotate_solution_tool(gp: Vector2i) -> void:
	if _sol_mirrors.has(gp):
		_sol_mirrors[gp] = 1 - int(_sol_mirrors[gp])
		_run_validation()
	elif _sol_prisms.has(gp):
		_sol_prisms[gp] = 1 - int(_sol_prisms[gp])
		_run_validation()
	elif _sol_filters.has(gp):
		_sol_filters[gp] = (int(_sol_filters[gp]) + 1) % 3
		_run_validation()
	elif _sol_splitters.has(gp):
		_sol_splitters[gp] = 1 - int(_sol_splitters[gp])
		_run_validation()
	elif _sol_lenses.has(gp):
		_sol_lenses[gp] = 1 - int(_sol_lenses[gp])
		_run_validation()
	# Also rotate source directions
	for src in _sources:
		if src["pos"] == gp:
			src["direction"] = _rotate_direction(src["direction"])
			_run_validation()
			return


func _rotate_direction(d: Vector2i) -> Vector2i:
	return Vector2i(-d.y, d.x)


# ── Validation ────────────────────────────────────────────────────────────────

func _run_validation() -> void:
	var tools := _build_tools_dict()
	_sim_result = BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H),
		tools,
		_sources,
		CELL_SIZE,
	)

	# Update beam renderer
	var beam_layer: BeamLayer = $BeamLayer
	beam_layer.set_segments(_sim_result.segments)

	# Check solvability
	var all_hit := true
	var missed: Array = []
	for pos in _targets:
		if not pos in _sim_result.hit_targets:
			all_hit = false
			missed.append(pos)

	if _sources.is_empty():
		_validation_msg = "⚠ No light source placed."
	elif _targets.is_empty():
		_validation_msg = "⚠ No targets placed."
	elif all_hit:
		var total_tools := _sol_mirrors.size() + _sol_prisms.size() + _sol_filters.size() + _sol_splitters.size() + _sol_lenses.size()
		_validation_msg = "✓ SOLVABLE — %d targets hit, %d solution tools used." % [_targets.size(), total_tools]
	else:
		_validation_msg = "✗ NOT SOLVABLE — %d/%d targets hit. Missing: %s" % [_targets.size() - missed.size(), _targets.size(), _format_positions(missed)]

	# Update status label
	var label: Label = _ui.get_node("StatusLabel")
	label.text = _validation_msg
	if all_hit and not _sources.is_empty() and not _targets.is_empty():
		label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))
	else:
		label.add_theme_color_override("font_color", Color(0.91, 0.91, 1.0))

	$Grid.queue_redraw()


func _build_tools_dict() -> Dictionary:
	var d := {}
	for pos in _targets:
		d[pos] = {"type": "target", "color": _targets[pos]["color"]}
	for pos in _blockers:
		d[pos] = {"type": "blocker"}
	for sb in _shadow_blocks:
		d[sb["pos"]] = {"type": "shadow_block", "threshold": float(sb.get("threshold", 0.75))}
	for cs in _chromatic_shades:
		d[cs["pos"]] = {"type": "chromatic_shade", "color": cs["color"]}
	for pos in _null_emitters:
		d[pos] = {"type": "null_emitter"}
	for pos in _sol_mirrors:
		d[pos] = {"type": "mirror", "orientation": int(_sol_mirrors[pos])}
	for pos in _sol_prisms:
		d[pos] = {"type": "prism", "orientation": int(_sol_prisms[pos])}
	for pos in _sol_filters:
		d[pos] = {"type": "filter", "color": Grid.FILTER_COLORS[int(_sol_filters[pos])]}
	for pos in _sol_splitters:
		d[pos] = {"type": "splitter", "orientation": int(_sol_splitters[pos])}
	for pos in _sol_lenses:
		d[pos] = {"type": "lens", "orientation": int(_sol_lenses[pos])}
	return d


# ── Export ─────────────────────────────────────────────────────────────────────

func _export() -> void:
	if _sim_result == null:
		_validation_msg = "Validate first."
		return

	# Verify solvability
	var all_hit := true
	for pos in _targets:
		if not pos in _sim_result.hit_targets:
			all_hit = false
			break
	if not all_hit:
		_validation_msg = "✗ Cannot export — puzzle is not solvable."
		return

	# Derive budgets from solution tools
	var level := {
		"name": "Custom Puzzle",
		"sources": _sources.duplicate(true),
		"targets": _targets.duplicate(true),
		"blockers": _blockers.duplicate(true),
		"mirror_budget": _sol_mirrors.size(),
		"prism_budget": _sol_prisms.size(),
		"filter_budget": _sol_filters.size(),
		"splitter_budget": _sol_splitters.size(),
		"lens_budget": _sol_lenses.size(),
	}
	if not _shadow_blocks.is_empty():
		level["shadow_blocks"] = _shadow_blocks.duplicate(true)
	if not _chromatic_shades.is_empty():
		level["chromatic_shades"] = _chromatic_shades.duplicate(true)
	if not _null_emitters.is_empty():
		level["null_emitters"] = _null_emitters.duplicate(true)

	var filename := "custom_%s.json" % Time.get_datetime_string_from_system(false).replace(":", "").replace(" ", "_")
	if PuzzleSerializer.save_to_file(level, filename):
		_validation_msg = "✓ Exported to puzzles/%s" % filename
		var label: Label = _ui.get_node("StatusLabel")
		label.text = _validation_msg
		label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))


# ── Actions ────────────────────────────────────────────────────────────────────

func _clear_all() -> void:
	_sources.clear()
	_targets.clear()
	_blockers.clear()
	_shadow_blocks.clear()
	_chromatic_shades.clear()
	_null_emitters.clear()
	_sol_mirrors.clear()
	_sol_prisms.clear()
	_sol_filters.clear()
	_sol_splitters.clear()
	_sol_lenses.clear()
	_run_validation()


func _back_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_occupied(gp: Vector2i) -> bool:
	return _is_fixed(gp) or _sol_mirrors.has(gp) or _sol_prisms.has(gp) or _sol_filters.has(gp) or _sol_splitters.has(gp) or _sol_lenses.has(gp)


func _is_fixed(gp: Vector2i) -> bool:
	if _targets.has(gp): return true
	if gp in _blockers: return true
	for sb in _shadow_blocks:
		if sb["pos"] == gp: return true
	for cs in _chromatic_shades:
		if cs["pos"] == gp: return true
	if gp in _null_emitters: return true
	for src in _sources:
		if src["pos"] == gp: return true
	return false


func _in_bounds(gp: Vector2i) -> bool:
	return gp.x >= 0 and gp.x < GRID_W and gp.y >= 0 and gp.y < GRID_H


func _world_to_grid(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(local_pos.x / CELL_SIZE),
		int(local_pos.y / CELL_SIZE),
	)


func _cell_center(gp: Vector2i) -> Vector2:
	return Vector2(
		(gp.x + 0.5) * CELL_SIZE,
		(gp.y + 0.5) * CELL_SIZE,
	)


func _format_positions(positions: Array) -> String:
	var parts: Array = []
	for p in positions:
		parts.append("(%d,%d)" % [p.x, p.y])
	return ", ".join(parts)
