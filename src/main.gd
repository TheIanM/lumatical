extends Node2D

## Lumatical — Main game controller.
##
## Orchestrates the game loop: loads level data, runs the beam simulation
## whenever the player places/moves/removes a tool, updates the beam
## renderer, checks the win condition, and shows a solve overlay with
## a "Next Puzzle" button.

const CELL_SIZE := 64.0
const GRID_W := 12
const GRID_H := 8
const GRID_OFFSET := Vector2(256, 104)

# Beam colors — BeamSimulator is the single source of truth
const BEAM_COLOR := BeamSimulator.WHITE
const C_RED   := BeamSimulator.RED
const C_GREEN := BeamSimulator.GREEN
const C_BLUE  := BeamSimulator.BLUE

# ── Level Definitions ────────────────────────────────────────────────────────
const LEVELS := [
	# ── Chapter I: Mirrors ──
	# Puzzle 1: One corner — learn mirrors redirect light.
	{
		"name": "First Light",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 1): {"color": BEAM_COLOR}},
		"blockers": [],
		"mirror_budget": 2,
		"prism_budget": 0,
	},
	# Puzzle 2: Blocker forces a detour — route around obstacles.
	{
		"name": "Detour",
		"sources": [{"pos": Vector2i(1, 1), "direction": Vector2i(0, 1), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 6): {"color": BEAM_COLOR}},
		"blockers": [Vector2i(1, 6)],
		"mirror_budget": 2,
		"prism_budget": 0,
	},
	# Puzzle 3: Two corners, no blocker — plan a multi-step path.
	{
		"name": "The Long Way",
		"sources": [{"pos": Vector2i(1, 1), "direction": Vector2i(0, 1), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 1): {"color": BEAM_COLOR}},
		"blockers": [],
		"mirror_budget": 2,
		"prism_budget": 0,
	},
	# ── Chapter II: Prisms & Color ──
	# Puzzle 4: Meet the prism — split white into red and green, one mirror.
	{
		"name": "Spectrum",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 4): {"color": C_GREEN},
		},
		"blockers": [],
		"mirror_budget": 1,
		"prism_budget": 1,
	},
	# Puzzle 5: Full spectrum — split into RGB, mirrors for red and blue.
	{
		"name": "Full Spectrum",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 7): {"color": C_BLUE},
		},
		"blockers": [],
		"mirror_budget": 2,
		"prism_budget": 1,
	},
	# Puzzle 6: Filter and bend — extract blue from white, route around blocker.
	{
		"name": "Sieve",
		"sources": [{"pos": Vector2i(1, 1), "direction": Vector2i(0, 1), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 6): {"color": C_BLUE}},
		"blockers": [Vector2i(1, 6)],
		"mirror_budget": 2,
		"prism_budget": 0,
		"filter_budget": 1,
	},
	# Puzzle 7: Beam split — duplicate a beam to hit two targets.
	{
		"name": "Twin Beams",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 1): {"color": BEAM_COLOR},
			Vector2i(10, 4): {"color": BEAM_COLOR},
		},
		"blockers": [],
		"mirror_budget": 1,
		"splitter_budget": 1,
	},
	# Puzzle 8: Split decision — prism + splitter to reach two green targets.
	{
		"name": "Split Decision",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 7): {"color": C_GREEN},
		},
		"blockers": [],
		"mirror_budget": 1,
		"prism_budget": 1,
		"splitter_budget": 1,
	},
	# ── Chapter III: Lenses & Intensity ──
	# Puzzle 9: Focus — a split beam is too weak; focus it through a convex lens.
	{
		"name": "Focus",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": BEAM_COLOR, "intensity": 0.75},
			Vector2i(10, 7): {"color": BEAM_COLOR},
		},
		"blockers": [],
		"mirror_budget": 1,
		"splitter_budget": 1,
		"lens_budget": 1,
	},
	# Puzzle 10: Prism + lens — weak source, split into colors, focus the green beam.
	{
		"name": "Convergence",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 0.5}],
		"targets": {
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 4): {"color": C_GREEN, "intensity": 0.75},
		},
		"blockers": [],
		"mirror_budget": 1,
		"prism_budget": 1,
		"lens_budget": 1,
	},
	# ── Chapter IV: Enemies ──
	# Puzzle 11: Shadow block — weak source needs a convex lens to break through.
	{
		"name": "Shadow",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 0.5}],
		"targets": {Vector2i(10, 4): {"color": BEAM_COLOR}},
		"blockers": [],
		"shadow_blocks": [{"pos": Vector2i(6, 4), "threshold": 0.75}],
		"mirror_budget": 0,
		"lens_budget": 1,
	},
	# Puzzle 12: Spectre — chromatic shade blocks the green beam's path.
	{
		"name": "Spectre",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 1): {"color": C_RED},
		},
		"blockers": [],
		"chromatic_shades": [{"pos": Vector2i(6, 4), "color": C_GREEN}],
		"mirror_budget": 1,
		"prism_budget": 1,
	},
	# Puzzle 13: Void — null emitter forces a detour around its dead zone.
	{
		"name": "Void",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 6): {"color": BEAM_COLOR}},
		"blockers": [],
		"null_emitters": [Vector2i(6, 3)],
		"mirror_budget": 2,
	},
	# Puzzle 14: Gauntlet — shadow block + prism. Split beams stay at full
	# intensity (unlike splitter), so prism beams can break through.
	{
		"name": "Gauntlet",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 7): {"color": C_BLUE},
		},
		"blockers": [],
		"shadow_blocks": [{"pos": Vector2i(7, 4), "threshold": 0.75}],
		"mirror_budget": 2,
		"prism_budget": 1,
	},
	# Puzzle 15: Convergence — shadow block + chromatic shade + prism.
	{
		"name": "Convergence",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 7): {"color": C_BLUE},
		},
		"blockers": [],
		"shadow_blocks": [{"pos": Vector2i(7, 4), "threshold": 0.75}],
		"chromatic_shades": [{"pos": Vector2i(7, 7), "color": C_BLUE}],
		"mirror_budget": 2,
		"prism_budget": 1,
	},
	# ── Chapter V: Advanced Combinations ──
	# Puzzle 16: Sieve + shade — filter a color, then destroy a shade with it.
	{
		"name": "Purge",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(10, 4): {"color": C_RED}},
		"blockers": [],
		"chromatic_shades": [{"pos": Vector2i(7, 4), "color": C_RED}],
		"mirror_budget": 0,
		"filter_budget": 1,
	},
	# Puzzle 17: Split + focus — splitter halves the beam, lens restores it,
	# then it breaks through a shadow block to reach one target.
	# The other split beam reaches a second target directly.
	{
		"name": "Amplify",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": BEAM_COLOR},
			Vector2i(10, 1): {"color": BEAM_COLOR},
		},
		"blockers": [],
		"shadow_blocks": [{"pos": Vector2i(8, 4), "threshold": 0.75}],
		"mirror_budget": 1,
		"splitter_budget": 1,
		"lens_budget": 1,
	},
	# Puzzle 18: Corridor — null emitter blocks direct path, requiring a detour.
	{
		"name": "Corridor",
		"sources": [{"pos": Vector2i(3, 1), "direction": Vector2i(0, 1), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {Vector2i(5, 7): {"color": BEAM_COLOR}},
		"blockers": [],
		"null_emitters": [Vector2i(3, 4)],
		"mirror_budget": 2,
	},
	# Puzzle 19: Color gauntlet — three shades block three colored paths.
	{
		"name": "Spectrum Run",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 1): {"color": C_RED},
			Vector2i(10, 4): {"color": C_GREEN},
			Vector2i(10, 7): {"color": C_BLUE},
		},
		"blockers": [],
		"chromatic_shades": [
			{"pos": Vector2i(7, 1), "color": C_RED},
			{"pos": Vector2i(7, 4), "color": C_GREEN},
			{"pos": Vector2i(7, 7), "color": C_BLUE},
		],
		"mirror_budget": 2,
		"prism_budget": 1,
	},
	# Puzzle 20: Masterwork — prism + splitter + lens + intensity target.
	# The culmination: split white into green, split the green beam, focus one
	# half to meet an intensity-gated target, route the other to a plain target.
	{
		"name": "Masterwork",
		"sources": [{"pos": Vector2i(1, 4), "direction": Vector2i(1, 0), "color": BEAM_COLOR, "intensity": 1.0}],
		"targets": {
			Vector2i(10, 4): {"color": C_GREEN, "intensity": 0.75},
			Vector2i(10, 7): {"color": C_GREEN},
		},
		"blockers": [],
		"mirror_budget": 1,
		"prism_budget": 1,
		"splitter_budget": 1,
		"lens_budget": 1,
	},
]

var _current_level := 0
var _solved := false

@onready var grid: Grid = $Grid
@onready var beam_layer: BeamLayer = $BeamLayer
@onready var status_label: Label = $UI/StatusLabel

# Solve overlay nodes (created in code)
var _overlay: ColorRect
var _solve_title: Label
var _next_button: Button

# Toolbelt nodes
var _toolbelt: HBoxContainer
var _tool_buttons: Array = []

const TOOL_NAMES := ["Mirror", "Prism", "Filter", "Splitter", "Lens"]
const TOOL_COLORS := [
	Color(0.0, 0.94, 1.0),   # Mirror — cyan
	Color(1.0, 0.0, 0.9),    # Prism — magenta
	Color(1.0, 0.9, 0.0),    # Filter — yellow
	Color(1.0, 0.53, 0.0),   # Splitter — orange
	Color(0.67, 0.4, 1.0),   # Lens — violet
]


func _ready() -> void:
	grid.position = GRID_OFFSET
	beam_layer.position = GRID_OFFSET

	grid.cell_size = CELL_SIZE
	grid.grid_width = GRID_W
	grid.grid_height = GRID_H

	grid.tools_changed.connect(_on_tools_changed)

	_create_overlay()
	_create_toolbelt()
	_load_level(0)


# ── Overlay ──────────────────────────────────────────────────────────────────

func _create_overlay() -> void:
	var ui: CanvasLayer = $UI

	_overlay = ColorRect.new()
	_overlay.color = Color(0.004, 0.004, 0.01, 0.92)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	ui.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	_solve_title = Label.new()
	_solve_title.text = "◆ PUZZLE SOLVED ◆"
	_solve_title.add_theme_font_size_override("font_size", 40)
	_solve_title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.53))
	_solve_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_solve_title)

	var subtitle := Label.new()
	subtitle.text = "The grid ignites with color."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var btn_wrapper := HBoxContainer.new()
	btn_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_wrapper)

	_next_button = Button.new()
	_next_button.text = "Next Puzzle →"
	_next_button.add_theme_font_size_override("font_size", 20)
	_next_button.custom_minimum_size = Vector2(220, 56)
	_next_button.pressed.connect(_on_next_pressed)
	btn_wrapper.add_child(_next_button)


func _show_solve_overlay() -> void:
	if _current_level == LEVELS.size() - 1:
		_next_button.text = "↻ Back to Puzzle 1"
	else:
		_next_button.text = "Next Puzzle →"
	_solve_title.add_theme_color_override("font_color", _dominant_target_color())
	_overlay.visible = true


func _on_next_pressed() -> void:
	_overlay.visible = false
	var next_index := (_current_level + 1) % LEVELS.size()
	_load_level(next_index)


# ── Toolbelt ─────────────────────────────────────────────────────────────────

func _create_toolbelt() -> void:
	var ui: CanvasLayer = $UI

	_toolbelt = HBoxContainer.new()
	_toolbelt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toolbelt.offset_top = -76
	_toolbelt.offset_bottom = -12
	_toolbelt.alignment = BoxContainer.ALIGNMENT_CENTER
	_toolbelt.add_theme_constant_override("separation", 8)
	ui.add_child(_toolbelt)

	for i in range(5):
		var btn := Button.new()
		btn.text = "[%d] %s" % [i + 1, TOOL_NAMES[i]]
		btn.custom_minimum_size = Vector2(150, 56)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_toolbelt_button.bind(i))
		_toolbelt.add_child(btn)
		_tool_buttons.append(btn)


func _update_toolbelt() -> void:
	var budgets := [
		LEVELS[_current_level]["mirror_budget"],
		LEVELS[_current_level].get("prism_budget", 0),
		LEVELS[_current_level].get("filter_budget", 0),
		LEVELS[_current_level].get("splitter_budget", 0),
		LEVELS[_current_level].get("lens_budget", 0),
	]
	var used := [
		grid.mirrors.size(),
		grid.prisms.size(),
		grid.filters.size(),
		grid.splitters.size(),
		grid.lenses.size(),
	]

	for i in range(5):
		var btn: Button = _tool_buttons[i]
		if budgets[i] == 0:
			btn.visible = false
			continue
		btn.visible = true
		btn.text = "[%d] %s  %d/%d" % [i + 1, TOOL_NAMES[i], used[i], budgets[i]]
		var col: Color = TOOL_COLORS[i] if grid.active_tool == i else Color(0.5, 0.5, 0.6)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", col.lightened(0.3))


func _on_toolbelt_button(tool_index: int) -> void:
	grid.active_tool = tool_index
	_update_status()
	grid.queue_redraw()


# ── Level Loading ────────────────────────────────────────────────────────────

func _load_level(index: int) -> void:
	_current_level = index
	var level: Dictionary = LEVELS[index]
	_solved = false

	grid.sources = level["sources"].duplicate(true)
	grid.targets = level["targets"].duplicate(true)
	grid.blockers = level["blockers"].duplicate(true)
	grid.shadow_blocks = level.get("shadow_blocks", []).duplicate(true)
	grid.chromatic_shades = level.get("chromatic_shades", []).duplicate(true)
	grid.null_emitters = level.get("null_emitters", []).duplicate(true)
	grid.mirror_budget = level["mirror_budget"]
	grid.prism_budget = level.get("prism_budget", 0)
	grid.filter_budget = level.get("filter_budget", 0)
	grid.splitter_budget = level.get("splitter_budget", 0)
	grid.lens_budget = level.get("lens_budget", 0)
	grid.active_tool = 0
	grid.mirrors.clear()
	grid.prisms.clear()
	grid.filters.clear()
	grid.splitters.clear()
	grid.lenses.clear()
	grid._destroyed_enemies.clear()
	grid.queue_redraw()

	status_label.remove_theme_color_override("font_color")
	_run_simulation()
	_update_status()


# ── Simulation ───────────────────────────────────────────────────────────────

func _on_tools_changed() -> void:
	_run_simulation()
	_update_status()


func _run_simulation() -> void:
	var tools := _build_tools_dict()

	var result := BeamSimulator.simulate(
		Vector2i(GRID_W, GRID_H),
		tools,
		grid.sources,
		CELL_SIZE,
	)

	beam_layer.set_segments(result.segments)
	grid.set_hit_targets(result.hit_targets)
	grid.set_destroyed_enemies(result.destroyed_enemies)

	# Win detection — show overlay on transition to solved
	var was_solved := _solved
	_solved = _check_win(result.hit_targets)
	if _solved and not was_solved:
		_show_solve_overlay()
	elif not _solved and was_solved:
		_overlay.visible = false


func _build_tools_dict() -> Dictionary:
	var d := {}
	for pos in grid.targets:
		var tdata := {"type": "target", "color": grid.targets[pos]["color"]}
		if grid.targets[pos].has("intensity"):
			tdata["intensity"] = grid.targets[pos]["intensity"]
		d[pos] = tdata
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
	return d


func _check_win(hit_targets: Array) -> bool:
	for pos in grid.targets:
		if not pos in hit_targets:
			return false
	return true


## Returns the color to use for the solve overlay — the single target color
## if all targets share one, or white (full spectrum) if they differ.
func _dominant_target_color() -> Color:
	var unique: Array = []
	for pos in grid.targets:
		var col: Color = grid.targets[pos]["color"]
		var found := false
		for existing in unique:
			if existing.is_equal_approx(col):
				found = true
				break
		if not found:
			unique.append(col)
	if unique.size() == 1:
		return unique[0]
	return BeamSimulator.WHITE


func _update_status() -> void:
	if _solved:
		return
	var level_name: String = LEVELS[_current_level].get("name", "Untitled")
	status_label.text = "%d. %s" % [_current_level + 1, level_name]
	_update_toolbelt()


# ── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_on_next_pressed()
