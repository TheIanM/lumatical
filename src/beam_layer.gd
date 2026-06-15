class_name BeamLayer
extends Node2D

## Renders beam segments produced by BeamSimulator.
##
## Uses additive blending with five concentric glow layers to approximate
## the neon bloom aesthetic: a wide faint halo, progressively brighter and
## narrower mid-glow layers, and a hot bright core. Additive blending makes
## overlapping beams naturally create bright hotspots at intersections.

var _segments: Array = []
var _time: float = 0.0


func set_segments(segments: Array) -> void:
	_segments = segments
	queue_redraw()


func _process(_delta: float) -> void:
	_time += _delta
	queue_redraw()


func _draw() -> void:
	for seg in _segments:
		_draw_beam_segment(seg)

	# Draw radial glow at every segment endpoint — these are where beams
	# interact with tools (mirrors, prisms, targets) and should feel "hot"
	for seg in _segments:
		_draw_endpoint_glow(seg.end, seg.color, seg.intensity)


func _draw_beam_segment(seg) -> void:
	var col: Color = seg.color
	var i: float = seg.intensity

	# Subtle pulse — beams breathe slightly like living light
	var pulse := 1.0 + sin(_time * 3.0 + seg.start.x * 0.01) * 0.06
	var i_p := i * pulse

	# Layer 1: Ultra-wide halo — very faint, creates ambient light spill
	draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.03 * i_p), 28.0)

	# Layer 2: Wide glow
	draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.07 * i_p), 18.0)

	# Layer 3: Mid glow — the main bloom body
	draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.15 * i_p), 10.0)

	# Layer 4: Bright inner glow
	draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.4 * i_p), 5.0)

	# Layer 5: Hot core — near-white at center for intensity > 0.5
	var core_col := col.lerp(Color.WHITE, 0.4 * i_p)
	draw_line(seg.start, seg.end, core_col, 2.0)


func _draw_endpoint_glow(pos: Vector2, col: Color, intensity: float) -> void:
	var pulse := 1.0 + sin(_time * 4.0) * 0.15
	var r := 14.0 * intensity * pulse

	# Soft radial glow at beam endpoints
	draw_circle(pos, r * 2.5, Color(col.r, col.g, col.b, 0.02 * intensity))
	draw_circle(pos, r * 1.5, Color(col.r, col.g, col.b, 0.06 * intensity))
	draw_circle(pos, r, Color(col.r, col.g, col.b, 0.12 * intensity))
