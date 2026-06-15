class_name Background
extends Node2D

## Animated background for Lumatical.
##
## Layered atmospheric depth behind the grid:
## 1. Breathing radial gradients (cyan/magenta void glow).
## 2. Large slowly-rotating wireframe polygons deep in the void.
## 3. Drifting dust-mote particles in neon colors.
## 4. Constellation lines connecting nearby particles — a living network.
## 5. Periodic energy ripples that sweep outward and fade.
##
## Everything is kept faint and slow to stay hypnotic, not distracting.

const PARTICLE_COUNT := 90
const CONSTELLATION_DIST := 110.0
const RIPPE_INTERVAL := 4.0

var _time: float = 0.0
var _particles: Array = []
var _ripples: Array = []
var _viewport_size: Vector2
var _ripple_timer: float = 0.0


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_spawn_particles()


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

	# Spawn ripples periodically
	_ripple_timer += delta
	if _ripple_timer >= RIPPE_INTERVAL:
		_ripple_timer = 0.0
		_spawn_ripple()

	# Update ripples
	var survivors: Array = []
	for r in _ripples:
		r["age"] += delta
		if r["age"] < r["life"]:
			survivors.append(r)
	_ripples = survivors

	queue_redraw()


func _draw() -> void:
	_draw_breathing_void()
	_draw_wireframes()
	_draw_ripples()
	_draw_constellations()
	_draw_particles()


# ── Breathing Void ────────────────────────────────────────────────────────────

func _draw_breathing_void() -> void:
	var breath := 0.5 + sin(_time * 0.3) * 0.5

	var center1 := Vector2(
		_viewport_size.x * (0.25 + sin(_time * 0.07) * 0.08),
		_viewport_size.y * (0.35 + cos(_time * 0.05) * 0.06),
	)
	var center2 := Vector2(
		_viewport_size.x * (0.75 + cos(_time * 0.06) * 0.08),
		_viewport_size.y * (0.65 + sin(_time * 0.08) * 0.06),
	)

	var r1 := _viewport_size.length() * (0.3 + breath * 0.05)
	var r2 := _viewport_size.length() * (0.25 + (1.0 - breath) * 0.05)

	_draw_radial_gradient(center1, r1, Color(0.0, 0.12, 0.16, 1.0))
	_draw_radial_gradient(center2, r2, Color(0.12, 0.0, 0.12, 1.0))


func _draw_radial_gradient(center: Vector2, radius: float, col: Color) -> void:
	var steps := 12
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var r := radius * (1.0 - t * 0.85)
		var alpha := col.a * (1.0 - t) * 0.5
		draw_circle(center, r, Color(col.r, col.g, col.b, alpha))


# ── Wireframe Polygons ──────────────────────────────────────────────────────────
# Large geometric shapes deep in the background that slowly rotate and breathe.
# Evokes the "something moving in the deep" feeling from the GDD.

func _draw_wireframes() -> void:
	var shapes := [
		{"center": Vector2(_viewport_size.x * 0.15, _viewport_size.y * 0.2), "radius": 180.0, "sides": 6, "speed": 0.06, "color": Color(0.0, 0.94, 1.0)},
		{"center": Vector2(_viewport_size.x * 0.85, _viewport_size.y * 0.75), "radius": 220.0, "sides": 5, "speed": -0.04, "color": Color(1.0, 0.0, 0.9)},
		{"center": Vector2(_viewport_size.x * 0.7, _viewport_size.y * 0.15), "radius": 140.0, "sides": 3, "speed": 0.08, "color": Color(0.0, 1.0, 0.53)},
	]

	for shape in shapes:
		var rot: float = _time * shape["speed"]
		var breath := 1.0 + sin(_time * 0.5 + shape["center"].x * 0.01) * 0.06
		var r: float = float(shape["radius"]) * breath
		var col: Color = shape["color"]
		var pts := PackedVector2Array()
		for i in range(shape["sides"]):
			var angle := rot + TAU * i / float(shape["sides"])
			pts.append(shape["center"] + Vector2(cos(angle), sin(angle)) * r)
		# Faint filled body
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.04))
		# Outline — two passes for a soft glow
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(col.r, col.g, col.b, 0.05), 5.0)
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(col.r, col.g, col.b, 0.12), 1.5)


# ── Energy Ripples ──────────────────────────────────────────────────────────────
# Periodic expanding rings that sweep outward from random points and fade.
# Adds a sense of energy and life to the void.

func _spawn_ripple() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ripple_%d" % randi())
	_ripples.append({
		"center": Vector2(
			rng.randf() * _viewport_size.x,
			rng.randf() * _viewport_size.y,
		),
		"age": 0.0,
		"life": rng.randf_range(3.0, 5.0),
		"max_r": rng.randf_range(200.0, 400.0),
		"color": [Color(0.0, 0.94, 1.0), Color(1.0, 0.0, 0.9), Color(0.91, 0.91, 1.0)][rng.randi() % 3],
	})


func _draw_ripples() -> void:
	for r in _ripples:
		var progress: float = float(r["age"]) / float(r["life"])
		var radius: float = float(r["max_r"]) * progress
		var col: Color = r["color"]
		# Fade out as it expands
		var alpha := (1.0 - progress) * 0.15
		draw_arc(r["center"], radius, 0, TAU, 64, Color(col.r, col.g, col.b, alpha), 2.0)
		# Inner echo
		var alpha2 := (1.0 - progress) * 0.08
		draw_arc(r["center"], radius * 0.8, 0, TAU, 64, Color(col.r, col.g, col.b, alpha2), 1.0)


# ── Constellations ─────────────────────────────────────────────────────────────
# Faint lines between nearby particles — creates a living network effect.

func _draw_constellations() -> void:
	for i in range(_particles.size()):
		var p1: Vector2 = _particles[i]["pos"]
		for j in range(i + 1, _particles.size()):
			var p2: Vector2 = _particles[j]["pos"]
			var d := p1.distance_to(p2)
			if d < CONSTELLATION_DIST:
				var t := 1.0 - d / CONSTELLATION_DIST
				var col1: Color = _particles[i]["color"]
				var col2: Color = _particles[j]["color"]
				var col := Color(
					(col1.r + col2.r) * 0.5,
					(col1.g + col2.g) * 0.5,
					(col1.b + col2.b) * 0.5,
					t * 0.08
				)
				draw_line(p1, p2, col, 1.0)


# ── Particles ──────────────────────────────────────────────────────────────────

func _draw_particles() -> void:
	for p in _particles:
		var phase := sin(_time * p["flicker_speed"] + p["flicker_offset"])
		var brightness := 0.5 + phase * 0.5
		var col: Color = p["color"]
		var a: float = float(p["base_alpha"]) * brightness

		draw_circle(p["pos"], p["size"] * 2.5, Color(col.r, col.g, col.b, a * 0.15))
		draw_circle(p["pos"], p["size"], Color(col.r, col.g, col.b, a))


func _spawn_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lumatical_bg")

	var palette := [
		Color(0.0, 0.94, 1.0),   # Cyan
		Color(1.0, 0.0, 0.9),    # Magenta
		Color(0.91, 0.91, 1.0),  # White
		Color(0.0, 1.0, 0.53),   # Green
		Color(1.0, 0.9, 0.0),    # Yellow
	]

	for i in range(PARTICLE_COUNT):
		_particles.append({
			"pos": Vector2(
				rng.randf() * _viewport_size.x,
				rng.randf() * _viewport_size.y,
			),
			"vel": Vector2(
				rng.randf_range(-8.0, 8.0),
				rng.randf_range(-6.0, 6.0),
			),
			"size": rng.randf_range(1.0, 2.5),
			"color": palette[rng.randi() % palette.size()],
			"base_alpha": rng.randf_range(0.15, 0.35),
			"flicker_speed": rng.randf_range(0.5, 2.0),
			"flicker_offset": rng.randf() * TAU,
		})
