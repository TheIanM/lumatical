extends Node2D

## Editor grid renderer — draws the grid, all placed elements, solution tools,
## validation feedback, and hover highlight for the level editor.
##
## This node reads state directly from the parent editor script.

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var editor = get_parent()
	var cs: float = editor.CELL_SIZE
	var gw: int = editor.GRID_W
	var gh: int = editor.GRID_H

	# Grid lines
	var total_w := gw * cs
	var total_h := gh * cs
	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.02, 0.02, 0.05, 0.5), true)
	var breath := 0.6 + sin(_time * 0.8) * 0.15
	var grid_col := Color(0.06, 0.06, 0.12, 0.6 * breath)
	for x in range(gw + 1):
		var xp := x * cs
		draw_line(Vector2(xp, 0), Vector2(xp, total_h), grid_col, 1.0)
	for y in range(gh + 1):
		var yp := y * cs
		draw_line(Vector2(0, yp), Vector2(total_w, yp), grid_col, 1.0)
	draw_rect(Rect2(0, 0, total_w, total_h), Color(0.1, 0.1, 0.21, 0.9), false, 2.0)

	# Null emitter fields
	for pos in editor._null_emitters:
		var cx: float = (pos.x - 0.5) * cs
		var cy: float = (pos.y - 0.5) * cs
		var pulse := 0.7 + sin(_time * 1.5) * 0.15
		draw_rect(Rect2(cx, cy, cs * 3.0, cs * 3.0), Color(0.02, 0.0, 0.04, 0.35 * pulse), true)

	# Blockers
	for pos in editor._blockers:
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.6
		draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), Color(0.18, 0.18, 0.22), true)

	# Shadow blocks
	for sb in editor._shadow_blocks:
		var pos: Vector2i = sb["pos"]
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.32
		var pts := PackedVector2Array()
		for i in range(6):
			var angle := TAU * i / 6.0 - PI / 2.0
			pts.append(c + Vector2(cos(angle), sin(angle)) * s)
		draw_colored_polygon(pts, Color(0.12, 0.05, 0.15, 0.7))
		for i in range(6):
			draw_line(pts[i], pts[(i + 1) % 6], Color(0.5, 0.2, 0.6, 0.8), 2.0)

	# Chromatic shades
	for cs_entry in editor._chromatic_shades:
		var pos: Vector2i = cs_entry["pos"]
		var col: Color = cs_entry["color"]
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var r := cs * 0.3
		var pulse := 0.6 + sin(_time * 1.8) * 0.15
		draw_circle(c, r * 1.3, Color(col.r, col.g, col.b, 0.04 * pulse))
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.12 * pulse))
		draw_arc(c, r, 0, TAU, 24, Color(col.r, col.g, col.b, 0.5), 2.0)

	# Null emitters
	for pos in editor._null_emitters:
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var r := cs * 0.22
		var pulse := 0.7 + sin(_time * 2.0) * 0.15
		draw_circle(c, r * pulse, Color(0.08, 0.0, 0.12))

	# Targets
	for pos in editor._targets:
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var r := cs * 0.3
		var base_col: Color = editor._targets[pos]["color"]
		var hit: bool = editor._sim_result != null and pos in editor._sim_result.hit_targets
		if hit:
			var hp := 1.0 + sin(_time * 4.0) * 0.15
			draw_circle(c, r * 2.0 * hp, Color(base_col.r, base_col.g, base_col.b, 0.08))
			draw_arc(c, r * hp, 0, TAU, 36, base_col, 3.0)
			draw_circle(c, r * 0.55 * hp, base_col)
		else:
			draw_circle(c, r, Color(base_col.r, base_col.g, base_col.b, 0.12))
			draw_arc(c, r, 0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.7), 2.5)
			draw_circle(c, r * 0.35, Color(base_col.r, base_col.g, base_col.b, 0.5))

	# Solution tools (drawn with dashed style to distinguish from real tools)
	_draw_sol_mirrors(editor, cs)
	_draw_sol_prisms(editor, cs)
	_draw_sol_filters(editor, cs)
	_draw_sol_splitters(editor, cs)
	_draw_sol_lenses(editor, cs)

	# Sources
	for src in editor._sources:
		var c := Vector2((src["pos"].x + 0.5) * cs, (src["pos"].y + 0.5) * cs)
		var r := cs * 0.22
		var pulse := 1.0 + sin(_time * 2.5) * 0.12
		draw_circle(c, r * 2.5 * pulse, Color(0.91, 0.91, 1.0, 0.06))
		draw_circle(c, r * 1.8, Color(0.91, 0.91, 1.0, 0.15))
		draw_circle(c, r * pulse, Color(0.91, 0.91, 1.0))
		var d := Vector2(src["direction"])
		var tip := c + d * cs * 0.42
		draw_line(c + d * r * 0.8, tip, Color(0.91, 0.91, 1.0), 3.0)
		var perp := Vector2(-d.y, d.x)
		draw_line(tip, tip - d * 8 + perp * 6, Color(0.91, 0.91, 1.0), 2.5)
		draw_line(tip, tip - d * 8 - perp * 6, Color(0.91, 0.91, 1.0), 2.5)

	# Hover highlight
	if editor._hovered_cell.x >= 0:
		var gp: Vector2i = editor._hovered_cell
		if gp.x >= 0 and gp.x < gw and gp.y >= 0 and gp.y < gh:
			var c := Vector2((gp.x + 0.5) * cs, (gp.y + 0.5) * cs)
			var s := cs * 0.92
			draw_rect(Rect2(c.x - s / 2.0, c.y - s / 2.0, s, s), Color(1, 1, 1, 0.08), true)


func _draw_sol_mirrors(editor, cs: float) -> void:
	for pos in editor._sol_mirrors:
		var orient: int = int(editor._sol_mirrors[pos])
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var h := cs * 0.35
		var col := Color(0.0, 0.94, 1.0, 0.5)
		if orient == 0:
			draw_line(c + Vector2(-h, h), c + Vector2(h, -h), col, 3.0)
		else:
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), col, 3.0)


func _draw_sol_prisms(editor, cs: float) -> void:
	for pos in editor._sol_prisms:
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.3
		var col := Color(1.0, 0.0, 0.9, 0.4)
		var pts := PackedVector2Array([
			c + Vector2(0, -s), c + Vector2(-s, s), c + Vector2(s, s),
		])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.15))
		for i in range(3):
			draw_line(pts[i], pts[(i + 1) % 3], col, 2.0)


func _draw_sol_filters(editor, cs: float) -> void:
	for pos in editor._sol_filters:
		var color_idx: int = int(editor._sol_filters[pos])
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.35
		var col: Color = Grid.FILTER_COLORS[color_idx]
		var fcol := Color(col.r, col.g, col.b, 0.3)
		draw_rect(Rect2(c.x - s * 0.35, c.y - s, s * 0.7, s * 2.0), fcol, true)
		draw_rect(Rect2(c.x - s * 0.35, c.y - s, s * 0.7, s * 2.0), Color(col.r, col.g, col.b, 0.6), false, 2.0)


func _draw_sol_splitters(editor, cs: float) -> void:
	for pos in editor._sol_splitters:
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.3
		var col := Color(1.0, 0.53, 0.0, 0.4)
		var pts := PackedVector2Array([
			c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0),
		])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.15))
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], col, 2.0)


func _draw_sol_lenses(editor, cs: float) -> void:
	for pos in editor._sol_lenses:
		var orient: int = int(editor._sol_lenses[pos])
		var c := Vector2((pos.x + 0.5) * cs, (pos.y + 0.5) * cs)
		var s := cs * 0.3
		var col := Color(0.67, 0.4, 1.0, 0.4)
		if orient == 0:
			draw_arc(c + Vector2(-s * 0.3, 0), s * 0.7, -PI / 2, PI / 2, 16, col, 2.5)
			draw_arc(c + Vector2(s * 0.3, 0), s * 0.7, PI / 2, PI * 1.5, 16, col, 2.5)
		else:
			draw_arc(c + Vector2(0, -s * 0.3), s * 0.7, 0, PI, 16, col, 2.5)
			draw_arc(c + Vector2(0, s * 0.3), s * 0.7, PI, TAU, 16, col, 2.5)
