class_name Roguelike
extends Node2D

## Lumatical — Roguelike Mode.
##
## Persistent inventory roguelike. Player starts with a small set of tools
## and earns more between floors. Running out of tools to solve a puzzle
## ends the run.

const CELL_SIZE := 64.0
const GRID_W := 12
const GRID_H := 8
const GRID_OFFSET := Vector2(256, 104)

const BEAM_COLOR := BeamSimulator.WHITE

const TOOL_KEYS := ["mirror", "prism", "filter", "splitter", "lens", "refractor"]
const TOOL_NAMES := ["Mirror", "Prism", "Filter", "Splitter", "Lens", "Refractor"]
const TOOL_COLORS := [
	Color(0.0, 0.94, 1.0), Color(1.0, 0.0, 0.9), Color(1.0, 0.9, 0.0),
	Color(1.0, 0.53, 0.0), Color(0.67, 0.4, 1.0), Color(0.5, 1.0, 0.8),
]

var _floor := 1
var _score := 0
var _current_level: Dictionary
var _solved := false

# Persistent inventory across the entire run
# {tool_type: count_available}
var _inventory: Dictionary = {}

# Mode and seed
var _mode := "endless"
var _run_seed := -1

@onready var grid: Grid = $Grid
@onready var beam_layer: BeamLayer = $BeamLayer
@onready var audio: AudioManager = $AudioManager
@onready var status_label: Label = $UI/StatusLabel

var _overlay: ColorRect
var _overlay_vbox: VBoxContainer
var _solve_title: Label

# Called by menu to set the run mode before scene loads.
static var run_mode := "endless"
static var run_seed := -1


func _enter_tree() -> void:
	_mode = run_mode
	_run_seed = run_seed


func _ready() -> void:
	grid.position = GRID_OFFSET
	beam_layer.position = GRID_OFFSET
	grid.cell_size = CELL_SIZE
	grid.grid_width = GRID_W
	grid.grid_height = GRID_H
	grid.tools_changed.connect(_on_tools_changed)
	_create_overlay()
	_create_top_bar()
	_init_inventory()
	_load_floor(1)


# ── Inventory ──────────────────────────────────────────────────────────────────

func _init_inventory() -> void:
	# Starting inventory — enough to solve early floors but not much more
	_inventory = {
		"mirror": 5,
		"prism": 0,
		"filter": 0,
		"splitter": 0,
		"lens": 0,
		"refractor": 0,
	}
	# Floor 3+: give a prism so color puzzles are possible
	if _floor >= 3:
		_inventory["prism"] = 1


## Returns the budget keys for grid from the current inventory.
## Budget = total inventory of that type (player can spend from it).
func _inventory_budgets() -> Dictionary:
	return {
		"mirror_budget": _inventory.get("mirror", 0),
		"prism_budget": _inventory.get("prism", 0),
		"filter_budget": _inventory.get("filter", 0),
		"splitter_budget": _inventory.get("splitter", 0),
		"lens_budget": _inventory.get("lens", 0),
		"refractor_budget": _inventory.get("refractor", 0),
		"teleporter_budget": 0,
	}


## Consume placed tools from inventory on solve.
func _consume_placed_tools() -> void:
	# Only consume tools that are actually placed when the puzzle is solved.
	# Tools removed before solving are not consumed.
	# We count tools currently on the grid.
	_inventory["mirror"] = max(0, _inventory.get("mirror", 0) - grid.mirrors.size())
	_inventory["prism"] = max(0, _inventory.get("prism", 0) - grid.prisms.size())
	_inventory["filter"] = max(0, _inventory.get("filter", 0) - grid.filters.size())
	_inventory["splitter"] = max(0, _inventory.get("splitter", 0) - grid.splitters.size())
	_inventory["lens"] = max(0, _inventory.get("lens", 0) - grid.lenses.size())
	_inventory["refractor"] = max(0, _inventory.get("refractor", 0) - grid.refractors.size())


## Check if the player has any tools left at all.
func _has_any_tools() -> bool:
	for key in _inventory:
		if _inventory[key] > 0:
			return true
	return false


# ── Overlay ────────────────────────────────────────────────────────────────────

func _create_overlay() -> void:
	var ui: CanvasLayer = $UI
	_overlay = ColorRect.new()
	_overlay.color = Color(0.004, 0.004, 0.01, 0.92)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.modulate.a = 0.0
	ui.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_overlay_vbox = VBoxContainer.new()
	_overlay_vbox.add_theme_constant_override("separation", 20)
	center.add_child(_overlay_vbox)


func _show_solve_overlay() -> void:
	_clear_overlay_content()
	_solve_title = Label.new()
	_solve_title.text = "◆ FLOOR %d CLEARED ◆" % _floor
	_solve_title.add_theme_font_size_override("font_size", 36)
	_solve_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))
	_solve_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(_solve_title)

	var sub := Label.new()
	sub.text = "Score: %d" % _score
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(sub)

	# Inventory summary
	var inv_label := Label.new()
	inv_label.text = _inventory_summary()
	inv_label.add_theme_font_size_override("font_size", 14)
	inv_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(inv_label)

	# Descend button
	var btn := Button.new()
	btn.text = "Descend →"
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(220, 56)
	btn.pressed.connect(_on_next_floor)
	_overlay_vbox.add_child(btn)

	var quit_btn := Button.new()
	quit_btn.text = "End Run"
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.custom_minimum_size = Vector2(160, 44)
	quit_btn.pressed.connect(_on_quit_run)
	_overlay_vbox.add_child(quit_btn)

	_overlay.visible = true
	grid.interactive = false
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.3)


func _show_reward_screen() -> void:
	_clear_overlay_content()

	var heading := Label.new()
	heading.text = "CHOOSE A REWARD"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.91, 0.91, 1.0))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(heading)

	var sub := Label.new()
	sub.text = "Floor %d cleared — pick one tool to add to your inventory" % _floor
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(sub)

	# Generate 3 random reward options
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("reward_%d_%d" % [_floor, _run_seed])
	var options: Array = []
	var pool := TOOL_KEYS.duplicate()

	# Weighted: mirrors more common, advanced tools rarer
	for ttype in pool:
		options.append(ttype)
		if ttype == "mirror":
			options.append("mirror")  # Extra weight
		if ttype in ["prism", "filter"]:
			options.append(ttype)

	options.shuffle()
	var chosen: Array = []
	for opt in options:
		if opt not in chosen:
			chosen.append(opt)
		if chosen.size() >= 3:
			break
	# Fallback if not enough unique
	while chosen.size() < 3:
		chosen.append("mirror")

	# Reward buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_overlay_vbox.add_child(btn_row)

	for i in range(chosen.size()):
		var ttype: String = chosen[i]
		var idx: int = TOOL_KEYS.find(ttype)
		var col: Color = TOOL_COLORS[idx] if idx >= 0 else Color.WHITE
		var reward_btn := Button.new()
		reward_btn.text = "+1 %s" % TOOL_NAMES[idx]
		reward_btn.custom_minimum_size = Vector2(180, 64)
		reward_btn.add_theme_font_size_override("font_size", 18)
		reward_btn.add_theme_color_override("font_color", col)
		reward_btn.add_theme_color_override("font_hover_color", col.lightened(0.4))
		reward_btn.pressed.connect(_on_reward_chosen.bind(ttype))
		btn_row.add_child(reward_btn)

	_overlay.visible = true
	grid.interactive = false
	_overlay.modulate.a = 1.0


func _show_run_over() -> void:
	_clear_overlay_content()

	var heading := Label.new()
	heading.text = "RUN OVER"
	heading.add_theme_font_size_override("font_size", 48)
	heading.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(heading)

	var sub := Label.new()
	sub.text = "Reached Floor %d\nScore: %d" % [_floor, _score]
	sub.text += "\n\n" + _inventory_summary()
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_vbox.add_child(sub)

	# Share code
	if _run_seed >= 0:
		var code_label := Label.new()
		code_label.text = "Share Code: %s" % RunManager.encode_seed(_run_seed)
		code_label.add_theme_font_size_override("font_size", 16)
		code_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overlay_vbox.add_child(code_label)

	var btn := Button.new()
	btn.text = "← Back to Menu"
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(220, 56)
	btn.pressed.connect(_on_quit_run)
	_overlay_vbox.add_child(btn)

	_overlay.visible = true
	grid.interactive = false
	_overlay.modulate.a = 1.0


func _clear_overlay_content() -> void:
	for child in _overlay_vbox.get_children():
		child.queue_free()


func _inventory_summary() -> String:
	var parts: Array = []
	for i in range(TOOL_KEYS.size()):
		var count: int = _inventory.get(TOOL_KEYS[i], 0)
		if count > 0:
			parts.append("%s: %d" % [TOOL_NAMES[i], count])
	return "  |  ".join(parts) if not parts.is_empty() else "No tools remaining"


# ── Top Bar ─────────────────────────────────────────────────────────────────────

func _create_top_bar() -> void:
	var ui: CanvasLayer = $UI

	var menu_btn := Button.new()
	menu_btn.text = "☰ Menu"
	menu_btn.add_theme_font_size_override("font_size", 13)
	menu_btn.custom_minimum_size = Vector2(90, 32)
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 16
	menu_btn.offset_top = 12
	menu_btn.offset_right = 112
	menu_btn.offset_bottom = 44
	menu_btn.pressed.connect(_on_quit_run)
	ui.add_child(menu_btn)


# ── Floor Loading ──────────────────────────────────────────────────────────────

func _load_floor(floor_num: int) -> void:
	_floor = floor_num

	# Generate with inventory constraints — the puzzle must be solvable
	# using only tools the player actually has.
	var available_tools: Dictionary = {}
	for ttype in _inventory:
		if _inventory[ttype] > 0:
			available_tools[ttype] = _inventory[ttype]

	_current_level = PuzzleGenerator.generate(floor_num, _run_seed, available_tools)
	_solved = false

	grid.sources = _current_level["sources"].duplicate(true)
	grid.targets = _current_level["targets"].duplicate(true)
	grid.blockers = _current_level.get("blockers", []).duplicate(true)
	grid.shadow_blocks = _current_level.get("shadow_blocks", []).duplicate(true)
	grid.chromatic_shades = _current_level.get("chromatic_shades", []).duplicate(true)
	grid.null_emitters = _current_level.get("null_emitters", []).duplicate(true)

	# Set grid budgets from inventory, not from the level dict
	var budgets := _inventory_budgets()
	grid.mirror_budget = budgets["mirror_budget"]
	grid.prism_budget = budgets["prism_budget"]
	grid.filter_budget = budgets["filter_budget"]
	grid.splitter_budget = budgets["splitter_budget"]
	grid.lens_budget = budgets["lens_budget"]
	grid.refractor_budget = budgets["refractor_budget"]
	grid.teleporter_budget = 0

	grid.active_tool = 0
	grid.interactive = true
	grid.mirrors.clear()
	grid.prisms.clear()
	grid.filters.clear()
	grid.splitters.clear()
	grid.lenses.clear()
	grid.refractors.clear()
	grid.teleporters.clear()
	grid._hit_targets.clear()
	grid._destroyed_enemies.clear()
	grid.queue_redraw()

	_create_toolbelt()
	_run_simulation(false)
	_update_status()


# ── Toolbelt ───────────────────────────────────────────────────────────────────

var _toolbelt: HBoxContainer
var _tool_buttons: Array = []


func _create_toolbelt() -> void:
	if _toolbelt:
		_toolbelt.queue_free()
	_tool_buttons.clear()

	_toolbelt = HBoxContainer.new()
	_toolbelt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toolbelt.offset_top = -76
	_toolbelt.offset_bottom = -12
	_toolbelt.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbelt.add_theme_constant_override("separation", 8)
	$UI.add_child(_toolbelt)

	# Only show tools the player has in inventory
	for i in range(TOOL_KEYS.size()):
		var ttype: String = TOOL_KEYS[i]
		var count: int = _inventory.get(ttype, 0)
		var btn := Button.new()
		btn.text = "[%d] %s" % [i + 1, TOOL_NAMES[i]]
		btn.custom_minimum_size = Vector2(130, 56)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_toolbelt_button.bind(i))
		_toolbelt.add_child(btn)
		_tool_buttons.append({"btn": btn, "type": ttype})
	_update_toolbelt()


func _update_toolbelt() -> void:
	for entry in _tool_buttons:
		var btn: Button = entry["btn"]
		var ttype: String = entry["type"]
		var total: int = _inventory.get(ttype, 0)
		var used := _tools_on_grid(ttype)
		if total == 0:
			btn.visible = false
			continue
		btn.visible = true
		btn.text = "%s  %d/%d" % [_tool_label(ttype), used, total]
		var idx: int = TOOL_KEYS.find(ttype)
		var col: Color = TOOL_COLORS[idx]
		var is_active := _is_tool_active(ttype)
		btn.add_theme_color_override("font_color", col if is_active else Color(0.5, 0.5, 0.6))
		btn.add_theme_color_override("font_hover_color", col.lightened(0.3))


func _tool_label(ttype: String) -> String:
	var idx: int = TOOL_KEYS.find(ttype)
	if idx >= 0:
		return "[%d] %s" % [idx + 1, TOOL_NAMES[idx]]
	return ttype


func _tools_on_grid(ttype: String) -> int:
	match ttype:
		"mirror": return grid.mirrors.size()
		"prism": return grid.prisms.size()
		"filter": return grid.filters.size()
		"splitter": return grid.splitters.size()
		"lens": return grid.lenses.size()
		"refractor": return grid.refractors.size()
	return 0


func _is_tool_active(ttype: String) -> bool:
	var idx: int = TOOL_KEYS.find(ttype)
	return grid.active_tool == idx


func _on_toolbelt_button(tool_index: int) -> void:
	grid.active_tool = tool_index
	_update_toolbelt()
	grid.queue_redraw()


# ── Simulation ────────────────────────────────────────────────────────────────

func _on_tools_changed() -> void:
	_run_simulation()
	_update_status()


func _run_simulation(play_audio := true) -> void:
	var tools := _build_tools_dict()
	var result := BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H), tools, grid.sources, CELL_SIZE,
	)
	beam_layer.set_segments(result.segments)
	grid.set_hit_targets(result.hit_targets)
	grid.set_destroyed_enemies(result.destroyed_enemies)

	var was_solved := _solved
	_solved = _check_win(result.hit_targets)
	if _solved and not was_solved:
		audio.play_solve_chord()
		_score += _floor * 10
		_consume_placed_tools()
		_show_solve_overlay()
	elif not _solved and was_solved:
		_overlay.visible = false
		grid.interactive = true


func _build_tools_dict() -> Dictionary:
	var d := {}
	for pos in grid.targets:
		d[pos] = {"type": "target", "color": grid.targets[pos]["color"]}
	for pos in grid.blockers:
		d[pos] = {"type": "blocker"}
	for sb in grid.shadow_blocks:
		d[sb["pos"]] = {"type": "shadow_block", "threshold": float(sb.get("threshold", 0.75))}
	for cs in grid.chromatic_shades:
		d[cs["pos"]] = {"type": "chromatic_shade", "color": cs["color"]}
	for pos in grid.null_emitters:
		d[pos] = {"type": "null_emitter"}
	for pos in grid.mirrors:
		d[pos] = {"type": "mirror", "orientation": int(grid.mirrors[pos])}
	for pos in grid.prisms:
		d[pos] = {"type": "prism", "orientation": int(grid.prisms[pos])}
	for pos in grid.filters:
		d[pos] = {"type": "filter", "color": Grid.FILTER_COLORS[int(grid.filters[pos])]}
	for pos in grid.splitters:
		d[pos] = {"type": "splitter", "orientation": int(grid.splitters[pos])}
	for pos in grid.lenses:
		d[pos] = {"type": "lens", "orientation": int(grid.lenses[pos])}
	for pos in grid.refractors:
		d[pos] = {"type": "refractor", "orientation": int(grid.refractors[pos])}
	return d


func _check_win(hit_targets: Array) -> bool:
	if grid.targets.is_empty():
		return false
	for pos in grid.targets:
		if not pos in hit_targets:
			return false
	return true


# ── Status ─────────────────────────────────────────────────────────────────────

func _update_status() -> void:
	if _solved:
		return
	var mode_label := _mode.capitalize()
	if _mode == "daily":
		mode_label = "Daily %s" % RunManager.get_daily_label()
	if _mode == "shared" and _run_seed >= 0:
		mode_label = "Shared: %s" % RunManager.encode_seed(_run_seed)
	status_label.text = "%s | Floor %d | Score: %d | %s" % [
		mode_label, _floor, _score, _inventory_summary(),
	]
	_update_toolbelt()


func _difficulty_name(floor_num: int) -> String:
	if floor_num <= 5:   return "Easy"
	if floor_num <= 15:  return "Normal"
	if floor_num <= 30:  return "Hard"
	return "Brutal"


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_next_floor() -> void:
	_overlay.visible = false
	grid.interactive = true
	audio.stop_all_tones()

	# Show reward screen before next floor
	_show_reward_screen()


func _on_reward_chosen(ttype: String) -> void:
	_inventory[ttype] = _inventory.get(ttype, 0) + 1
	_overlay.visible = false
	_load_floor(_floor + 1)


func _on_quit_run() -> void:
	if _floor > 1 or _score > 0:
		RunManager.submit_score(_mode, _floor, _score, _run_seed)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if _solved and _overlay.modulate.a >= 0.9:
				_on_next_floor()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		audio.toggle_mute()
