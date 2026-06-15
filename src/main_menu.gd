extends Control

## Lumatical — Main Menu.
##
## Title screen with animated background, puzzle selection, and navigation
## to the level editor.

const TITLE_COLOR := Color(0.91, 0.91, 1.0)
const ACCENT_CYAN := Color(0.0, 0.94, 1.0)
const ACCENT_MAGENTA := Color(1.0, 0.0, 0.9)
const ACCENT_GREEN := Color(0.0, 1.0, 0.53)

var _time: float = 0.0
var _particles: Array = []
var _viewport_size: Vector2


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_spawn_particles()
	_create_ui()


func _process(delta: float) -> void:
	_time += delta
	_viewport_size = get_viewport_rect().size
	for p in _particles:
		p["pos"] += p["vel"] * delta
		if p["pos"].x < -20:
			p["pos"].x = _viewport_size.x + 20
		elif p["pos"].x > _viewport_size.x + 20:
			p["pos"].x = -20
		if p["pos"].y < -20:
			p["pos"].y = _viewport_size.y + 20
		elif p["pos"].y > _viewport_size.y + 20:
			p["pos"].y = -20
	queue_redraw()


func _draw() -> void:
	_draw_void()
	_draw_wireframes()
	_draw_particles()
	_draw_title_beams()


func _draw_void() -> void:
	var breath := 0.5 + sin(_time * 0.3) * 0.5
	var c1 := Vector2(_viewport_size.x * 0.3, _viewport_size.y * 0.35)
	var c2 := Vector2(_viewport_size.x * 0.7, _viewport_size.y * 0.65)
	var r1 := _viewport_size.length() * (0.25 + breath * 0.05)
	var r2 := _viewport_size.length() * (0.2 + (1.0 - breath) * 0.05)
	for i in range(12):
		var t := float(i) / 11.0
		var alpha := (1.0 - t) * 0.5
		draw_circle(c1, r1 * (1.0 - t * 0.85), Color(0.0, 0.12, 0.16, alpha))
		draw_circle(c2, r2 * (1.0 - t * 0.85), Color(0.12, 0.0, 0.12, alpha))


func _draw_wireframes() -> void:
	var shapes := [
		{"c": Vector2(_viewport_size.x * 0.15, _viewport_size.y * 0.2), "r": 160.0, "sides": 6, "speed": 0.05},
		{"c": Vector2(_viewport_size.x * 0.85, _viewport_size.y * 0.75), "r": 200.0, "sides": 5, "speed": -0.03},
	]
	for shape in shapes:
		var rot: float = _time * shape["speed"]
		var breath := 1.0 + sin(_time * 0.4) * 0.05
		var r: float = float(shape["r"]) * breath
		var pts := PackedVector2Array()
		for i in range(shape["sides"]):
			var angle := rot + TAU * i / float(shape["sides"])
			pts.append(shape["c"] + Vector2(cos(angle), sin(angle)) * r)
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(ACCENT_CYAN.r, ACCENT_CYAN.g, ACCENT_CYAN.b, 0.04), 1.5)


func _draw_particles() -> void:
	for p in _particles:
		var phase := sin(_time * p["flicker_speed"] + p["flicker_offset"])
		var brightness := 0.5 + phase * 0.5
		var col: Color = p["color"]
		var a: float = float(p["base_alpha"]) * brightness
		draw_circle(p["pos"], p["size"] * 2.5, Color(col.r, col.g, col.b, a * 0.15))
		draw_circle(p["pos"], p["size"], Color(col.r, col.g, col.b, a))


func _draw_title_beams() -> void:
	_draw_beam_text("LUMATICAL", Vector2(_viewport_size.x * 0.5, 120), 40.0, TITLE_COLOR)


## Draw a string of letters as glowing beam segments.
func _draw_beam_text(text: String, center: Vector2, letter_h: float, col: Color) -> void:
	var chars := text.to_upper()
	var letter_w := letter_h * 0.55
	var spacing := letter_w * 1.3
	var total_w := spacing * (chars.length() - 1)
	var start_x := center.x - total_w * 0.5

	var pulse := 1.0 + sin(_time * 1.5) * 0.04
	var i := 0
	for ch in chars:
		var glyph := _get_glyph(ch)
		if glyph.is_empty():
			i += 1
			continue
		var origin := Vector2(start_x + i * spacing, center.y)
		for seg in glyph:
			var p1 := origin + Vector2(seg[0].x * letter_w, seg[0].y * letter_h)
			var p2 := origin + Vector2(seg[1].x * letter_w, seg[1].y * letter_h)
			_draw_glow_line(p1, p2, col, pulse)
		i += 1


func _draw_glow_line(p1: Vector2, p2: Vector2, col: Color, pulse: float) -> void:
	var i := pulse
	# 5-layer additive glow (same as BeamLayer)
	draw_line(p1, p2, Color(col.r, col.g, col.b, 0.02 * i), 22.0)
	draw_line(p1, p2, Color(col.r, col.g, col.b, 0.05 * i), 14.0)
	draw_line(p1, p2, Color(col.r, col.g, col.b, 0.12 * i), 8.0)
	draw_line(p1, p2, Color(col.r, col.g, col.b, 0.3 * i), 4.0)
	var core := col.lerp(Color.WHITE, 0.35 * i)
	draw_line(p1, p2, core, 2.0)
	# Endpoint glow
	draw_circle(p2, 6.0 * i, Color(col.r, col.g, col.b, 0.06))


## Stroke font — each letter is an array of [start, end] pairs in
## normalized coords (x: 0-1 width, y: 0-1.4 height, origin = top-left).
func _get_glyph(ch: String) -> Array:
	match ch:
		"L": return [[Vector2(0, 0), Vector2(0, 1.4)], [Vector2(0, 1.4), Vector2(0.7, 1.4)]]
		"U": return [[Vector2(0, 0), Vector2(0, 1.2)], [Vector2(0, 1.2), Vector2(0.7, 1.2)], [Vector2(0.7, 1.2), Vector2(0.7, 0)]]
		"M": return [[Vector2(0, 0), Vector2(0, 1.4)], [Vector2(0, 0), Vector2(0.35, 0.7)], [Vector2(0.35, 0.7), Vector2(0.7, 0)], [Vector2(0.7, 0), Vector2(0.7, 1.4)]]
		"A": return [[Vector2(0, 1.4), Vector2(0.35, 0)], [Vector2(0.35, 0), Vector2(0.7, 1.4)], [Vector2(0.12, 0.9), Vector2(0.58, 0.9)]]
		"T": return [[Vector2(0, 0), Vector2(0.7, 0)], [Vector2(0.35, 0), Vector2(0.35, 1.4)]]
		"I": return [[Vector2(0.15, 0), Vector2(0.55, 0)], [Vector2(0.35, 0), Vector2(0.35, 1.4)], [Vector2(0.15, 1.4), Vector2(0.55, 1.4)]]
		"C": return [[Vector2(0.7, 0.2), Vector2(0.5, 0)], [Vector2(0.5, 0), Vector2(0.2, 0)], [Vector2(0.2, 0), Vector2(0, 0.25)], [Vector2(0, 0.25), Vector2(0, 1.15)], [Vector2(0, 1.15), Vector2(0.2, 1.4)], [Vector2(0.2, 1.4), Vector2(0.5, 1.4)], [Vector2(0.5, 1.4), Vector2(0.7, 1.2)]]
		_: return []


func _spawn_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lumatical_menu")
	var palette := [ACCENT_CYAN, ACCENT_MAGENTA, TITLE_COLOR, ACCENT_GREEN, Color(1.0, 0.9, 0.0)]
	for i in range(70):
		_particles.append({
			"pos": Vector2(rng.randf() * _viewport_size.x, rng.randf() * _viewport_size.y),
			"vel": Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-4.0, 4.0)),
			"size": rng.randf_range(1.0, 2.5),
			"color": palette[rng.randi() % palette.size()],
			"base_alpha": rng.randf_range(0.15, 0.35),
			"flicker_speed": rng.randf_range(0.5, 2.0),
			"flicker_offset": rng.randf() * TAU,
		})


# ── UI ─────────────────────────────────────────────────────────────────────────

func _create_ui() -> void:
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Light is your instrument"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-150, 200)
	subtitle.size = Vector2(300, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", ACCENT_CYAN)
	add_child(subtitle)

	# Button container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-130, 20)
	vbox.size = Vector2(260, 0)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	_play_btn("Play", vbox, _on_play, ACCENT_GREEN)
	_play_btn("Level Editor", vbox, _on_editor, ACCENT_MAGENTA)
	_play_btn("How to Play", vbox, _on_help, ACCENT_CYAN)
	_play_btn("Quit", vbox, _on_quit, Color(0.6, 0.6, 0.7))

	# Version label
	var ver := Label.new()
	ver.text = "v0.1 — Prototype"
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -140
	ver.offset_top = -28
	ver.offset_right = -12
	ver.offset_bottom = -8
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	add_child(ver)


func _play_btn(text: String, parent: Node, callback: Callable, col: Color) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", col.lightened(0.4))
	btn.add_theme_color_override("font_pressed_color", col.lightened(0.6))
	btn.pressed.connect(callback)
	parent.add_child(btn)


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/PuzzleSelect.tscn")


func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/Editor.tscn")


func _on_help() -> void:
	_show_help_overlay()


func _on_quit() -> void:
	get_tree().quit()


# ── Help Overlay ───────────────────────────────────────────────────────────────

func _show_help_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.004, 0.004, 0.01, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(520, 400)
	center.add_child(vbox)

	var heading := Label.new()
	heading.text = "How to Play"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(heading)

	var lines := [
		"◆  Click a tool in the toolbelt (bottom), then click the grid to place it.",
		"◆  Left-click a placed tool to toggle its orientation.",
		"◆  Right-click to remove a tool.  Press [R] to rotate.",
		"◆  Route light from the source to every colored target.",
		"◆  Prisms split white light into red, green, and blue.",
		"◆  Filters extract a single color from white light.",
		"◆  Splitters duplicate a beam at half intensity.",
		"◆  Lenses focus (strengthen) or spread (weaken) a beam.",
		"◆  Shadow blocks need a strong beam to destroy them.",
		"◆  Chromatic shades block all colors except their weakness.",
		"◆  Null emitters cancel all light in a 3×3 area.",
		"",
		"◆  [1]-[5] select tools    [M] mute    [Enter] advance",
	]
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
		vbox.add_child(l)

	var btn := Button.new()
	btn.text = "← Back"
	btn.custom_minimum_size = Vector2(200, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", ACCENT_CYAN)
	btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(btn)
