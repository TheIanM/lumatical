class_name BeamLayer
extends Node2D

## Renders beam segments produced by BeamSimulator.
##
## Draws each segment three times (wide-dim, mid-glow, bright-core) to
## approximate the neon bloom aesthetic described in the GDD. Positioned
## as a sibling of Grid at the same offset, so both share the same
## local coordinate system.

var _segments: Array = []


func set_segments(segments: Array) -> void:
	_segments = segments
	queue_redraw()


func _draw() -> void:
	for seg in _segments:
		var col: Color = seg.color
		# Outer glow — wide and very faint
		draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.06), 18.0)
		# Mid glow
		draw_line(seg.start, seg.end, Color(col.r, col.g, col.b, 0.18), 9.0)
		# Core beam — thin and bright
		draw_line(seg.start, seg.end, col, 3.0)
