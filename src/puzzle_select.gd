extends Control

## Lumatical — Puzzle Selection.
##
## Scrollable list of all puzzles. Click one to start playing.

const TITLE_COLOR := Color(0.91, 0.91, 1.0)
const ACCENT_CYAN := Color(0.0, 0.94, 1.0)
const ACCENT_GREEN := Color(0.0, 1.0, 0.53)

var _time: float = 0.0


func _ready() -> void:
	_create_ui()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Subtle gradient background
	var vs := get_viewport_rect().size
	var c := Vector2(vs.x * 0.5, vs.y * 0.3)
	var breath := 0.5 + sin(_time * 0.3) * 0.5
	var r := vs.length() * (0.3 + breath * 0.05)
	for i in range(10):
		var t := float(i) / 9.0
		var alpha := (1.0 - t) * 0.3
		draw_circle(c, r * (1.0 - t * 0.85), Color(0.0, 0.08, 0.12, alpha))


func _create_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "Select Puzzle"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-150, 24)
	title.size = Vector2(300, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 140
	scroll.offset_top = 80
	scroll.offset_right = -140
	scroll.offset_bottom = -80
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# Populate puzzle buttons from Main's LEVELS array
	var levels = Main.LEVELS
	for i in range(levels.size()):
		var level: Dictionary = levels[i]
		var name: String = level.get("name", "Untitled")
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, name]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 16)

		# Color by chapter
		var chapter := _chapter_for(i)
		btn.add_theme_color_override("font_color", chapter)
		btn.add_theme_color_override("font_hover_color", chapter.lightened(0.3))

		var idx := i  # Capture
		btn.pressed.connect(func(): _play_puzzle(idx))
		vbox.add_child(btn)

	# Back button
	var back := Button.new()
	back.text = "← Back to Menu"
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 16
	back.offset_top = -56
	back.offset_right = 200
	back.offset_bottom = -16
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_color_override("font_color", ACCENT_CYAN)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	add_child(back)


func _chapter_for(index: int) -> Color:
	match index / 4:
		0: return ACCENT_CYAN       # Ch I: Mirrors
		1: return Color(1.0, 0.0, 0.9)  # Ch II: Prisms
		2: return Color(1.0, 0.9, 0.0)  # Ch III: Lenses
		3: return Color(0.5, 0.2, 0.6)  # Ch IV: Enemies
		_: return ACCENT_GREEN       # Ch V: Advanced


func _play_puzzle(index: int) -> void:
	Main.start_level = index
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
