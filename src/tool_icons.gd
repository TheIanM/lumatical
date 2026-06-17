class_name ToolIcons
extends RefCounted

## Vector-drawn tool icons for the UI.
##
## Each icon is drawn programmatically onto a small ImageTexture, so they
## scale crisply at any resolution. Used by the toolbelt buttons and editor
## palette to show a visual symbol alongside the tool name.

const ICON_SIZE := 32

## Generate an ImageTexture for the given tool type.
static func get_icon(tool_type: String, color: Color) -> ImageTexture:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center := Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	var s := ICON_SIZE * 0.32

	match tool_type:
		"mirror":
			_draw_line(img, center + Vector2(-s, s), center + Vector2(s, -s), color, 2.5)
		"prism":
			_draw_triangle(img, center, s, color)
		"filter":
			_draw_rect(img, center, s * 0.5, s * 1.6, color, true, 0.3)
			_draw_rect(img, center, s * 0.5, s * 1.6, color, false, 1.5)
		"splitter":
			_draw_diamond(img, center, s, color)
		"lens":
			_draw_lens(img, center, s, color)
		"refractor":
			_draw_refractor(img, center, s, color)
		"teleporter":
			_draw_teleporter(img, center, s, color)
		"source":
			_draw_circle_filled(img, center, s * 0.6, color)
		"target":
			_draw_circle_outline(img, center, s * 0.8, color, 2.0)
			_draw_circle_filled(img, center, s * 0.3, color)
		"blocker":
			_draw_square_filled(img, center, s * 1.2, Color(0.3, 0.3, 0.35))
		"shadow_block":
			_draw_hexagon(img, center, s, color)
		"chromatic_shade":
			_draw_circle_outline(img, center, s * 0.8, color, 2.0)
			_draw_circle_filled(img, center, s * 0.5, Color(color.r, color.g, color.b, 0.3))
		"null_emitter":
			_draw_circle_filled(img, center, s * 0.5, Color(0.1, 0.0, 0.15))
			_draw_circle_outline(img, center, s * 0.8, Color(0.3, 0.0, 0.4), 1.5)

	return ImageTexture.create_from_image(img)


# ── Drawing Primitives ─────────────────────────────────────────────────────────

static func _set_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < ICON_SIZE and y >= 0 and y < ICON_SIZE:
		img.set_pixel(x, y, col)


static func _blend_pixel(img: Image, x: float, y: float, col: Color, thickness: float) -> void:
	var r := thickness * 0.5
	for dx in range(-ceili(r), ceili(r) + 1):
		for dy in range(-ceili(r), ceili(r) + 1):
			if dx * dx + dy * dy <= r * r:
				var px := int(x) + dx
				var py := int(y) + dy
				if px >= 0 and px < ICON_SIZE and py >= 0 and py < ICON_SIZE:
					var existing: Color = img.get_pixel(px, py)
					var blended := Color(
						lerp(existing.r, col.r, col.a),
						lerp(existing.g, col.g, col.a),
						lerp(existing.b, col.b, col.a),
						maxf(existing.a, col.a)
					)
					img.set_pixel(px, py, blended)


static func _draw_line(img: Image, p1: Vector2, p2: Vector2, col: Color, thickness: float) -> void:
	var dx := p2.x - p1.x
	var dy := p2.y - p1.y
	var steps := maxi(ceili(abs(dx)), ceili(abs(dy))) * 2
	if steps == 0:
		_blend_pixel(img, p1.x, p1.y, col, thickness)
		return
	for i in range(steps + 1):
		var t := float(i) / steps
		var x := p1.x + dx * t
		var y := p1.y + dy * t
		_blend_pixel(img, x, y, col, thickness)


static func _draw_triangle(img: Image, center: Vector2, s: float, col: Color) -> void:
	var pts := [
		center + Vector2(0, -s),
		center + Vector2(-s * 0.85, s * 0.6),
		center + Vector2(s * 0.85, s * 0.6),
	]
	for i in range(3):
		_draw_line(img, pts[i], pts[(i + 1) % 3], col, 2.0)
	# Fill
	_fill_polygon(img, pts, Color(col.r, col.g, col.b, 0.25))


static func _draw_diamond(img: Image, center: Vector2, s: float, col: Color) -> void:
	var pts := [
		center + Vector2(0, -s),
		center + Vector2(s, 0),
		center + Vector2(0, s),
		center + Vector2(-s, 0),
	]
	for i in range(4):
		_draw_line(img, pts[i], pts[(i + 1) % 4], col, 2.0)
	_fill_polygon(img, pts, Color(col.r, col.g, col.b, 0.2))


static func _draw_lens(img: Image, center: Vector2, s: float, col: Color) -> void:
	# Two arcs approximated as circles offset horizontally
	var r := s * 0.9
	_draw_arc_pts(img, center + Vector2(-s * 0.2, 0), r, col, 2.0, -PI / 2, PI / 2)
	_draw_arc_pts(img, center + Vector2(s * 0.2, 0), r, col, 2.0, PI / 2, PI * 1.5)


static func _draw_refractor(img: Image, center: Vector2, s: float, col: Color) -> void:
	# Square outline with a curved arrow
	var pts := [
		center + Vector2(-s, -s), center + Vector2(s, -s),
		center + Vector2(s, s), center + Vector2(-s, s),
	]
	for i in range(4):
		_draw_line(img, pts[i], pts[(i + 1) % 4], col, 2.0)
	# CW arrow arc
	_draw_arc_pts(img, center, s * 0.4, col, 1.5, -PI / 2, PI)


static func _draw_teleporter(img: Image, center: Vector2, s: float, col: Color) -> void:
	_draw_circle_outline(img, center, s * 0.8, col, 2.0)
	_draw_circle_outline(img, center, s * 0.45, Color(col.r, col.g, col.b, 0.5), 1.5)


static func _draw_rect(img: Image, center: Vector2, hw: float, hh: float, col: Color, filled: bool, thickness: float) -> void:
	var p1 := center + Vector2(-hw, -hh)
	var p2 := center + Vector2(hw, -hh)
	var p3 := center + Vector2(hw, hh)
	var p4 := center + Vector2(-hw, hh)
	if filled:
		for y in range(int(p1.y), int(p3.y) + 1):
			for x in range(int(p1.x), int(p2.x) + 1):
				_blend_pixel(img, x, y, col, 1.0)
	else:
		_draw_line(img, p1, p2, col, thickness)
		_draw_line(img, p2, p3, col, thickness)
		_draw_line(img, p3, p4, col, thickness)
		_draw_line(img, p4, p1, col, thickness)


static func _draw_circle_filled(img: Image, center: Vector2, r: float, col: Color) -> void:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if dx * dx + dy * dy <= r * r:
				_blend_pixel(img, center.x + dx, center.y + dy, col, 1.0)


static func _draw_circle_outline(img: Image, center: Vector2, r: float, col: Color, thickness: float) -> void:
	_draw_arc_pts(img, center, r, col, thickness, 0, TAU)


static func _draw_arc_pts(img: Image, center: Vector2, r: float, col: Color, thickness: float, start: float, end: float) -> void:
	var steps := maxi(ceili(abs(end - start) * r), 8)
	for i in range(steps + 1):
		var t := float(i) / steps
		var angle := start + (end - start) * t
		var x := center.x + cos(angle) * r
		var y := center.y + sin(angle) * r
		_blend_pixel(img, x, y, col, thickness)


static func _draw_hexagon(img: Image, center: Vector2, s: float, col: Color) -> void:
	var pts: Array = []
	for i in range(6):
		var angle := TAU * i / 6.0 - PI / 2.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * s)
	for i in range(6):
		_draw_line(img, pts[i], pts[(i + 1) % 6], col, 2.0)
	_fill_polygon(img, pts, Color(col.r, col.g, col.b, 0.3))


static func _draw_square_filled(img: Image, center: Vector2, s: float, col: Color) -> void:
	var hx := s * 0.5
	var hy := s * 0.5
	for dy in range(int(-hy), int(hy) + 1):
		for dx in range(int(-hx), int(hx) + 1):
			_blend_pixel(img, center.x + dx, center.y + dy, col, 1.0)


static func _fill_polygon(img: Image, pts: Array, col: Color) -> void:
	# Scanline fill — find min/max Y
	var min_y := ICON_SIZE
	var max_y := 0
	for p in pts:
		min_y = mini(min_y, int(p.y))
		max_y = maxi(max_y, int(p.y))
	min_y = maxi(min_y, 0)
	max_y = mini(max_y, ICON_SIZE - 1)
	for y in range(min_y, max_y + 1):
		# Find intersections with polygon edges
		var xs: Array = []
		for i in range(pts.size()):
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[(i + 1) % pts.size()]
			if (p1.y <= y and p2.y > y) or (p2.y <= y and p1.y > y):
				var t := float(y - p1.y) / float(p2.y - p1.y)
				var x := p1.x + (p2.x - p1.x) * t
				xs.append(x)
		xs.sort()
		var i := 0
		while i + 1 < xs.size():
			var x1: float = xs[i]
			var x2: float = xs[i + 1]
			for x in range(maxi(int(x1), 0), mini(int(x2) + 1, ICON_SIZE)):
				_blend_pixel(img, x, y, col, 1.0)
			i += 2
