class_name Background
extends Node2D

## Animated background for Lumatical.
##
## Creates a sense of depth with two layers:
## 1. A slowly breathing radial gradient that shifts hue over time.
## 2. Drifting dust-mote particles — faint until they wander near a beam,
##    then they briefly light up like motes caught in a flashlight.
##
## The effect is subtle and hypnotic, never distracting — matching the
## "deep dark aquarium" feeling described in the GDD.

const PARTICLE_COUNT := 80

var _time: float = 0.0
var _particles: Array = []
var _viewport_size: Vector2


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_spawn_particles()


func _process(delta: float) -> void:
	_time += delta
	_viewport_size = get_viewport_rect().size

	for p in _particles:
		p["pos"] += p["vel"] * delta
		# Wrap around screen edges
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
	_draw_breathing_void()
	_draw_particles()


func _draw_breathing_void() -> void:
	# Two large radial gradients that slowly breathe and shift,
	# creating the feeling of looking into a deep, living darkness.
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

	# Cyan-tinted glow — very faint
	_draw_radial_gradient(center1, r1, Color(0.0, 0.04, 0.06, 1.0))
	# Magenta-tinted glow — very faint, offset
	_draw_radial_gradient(center2, r2, Color(0.04, 0.0, 0.04, 1.0))


func _draw_radial_gradient(center: Vector2, radius: float, col: Color) -> void:
	# Approximate a radial gradient with concentric circles using additive-ish
	# blending (just low-alpha draws since Background doesn't use additive mode).
	var steps := 12
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var r := radius * (1.0 - t * 0.85)
		var alpha := col.a * (1.0 - t) * 0.3
		draw_circle(center, r, Color(col.r, col.g, col.b, alpha))


func _draw_particles() -> void:
	for p in _particles:
		var phase := sin(_time * p["flicker_speed"] + p["flicker_offset"])
		var brightness := 0.5 + phase * 0.5
		var col: Color = p["color"]
		var a: float = float(p["base_alpha"]) * brightness

		# Soft glow
		draw_circle(p["pos"], p["size"] * 2.5, Color(col.r, col.g, col.b, a * 0.15))
		# Core
		draw_circle(p["pos"], p["size"], Color(col.r, col.g, col.b, a))


func _spawn_particles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lumatical_bg") # Deterministic so particles don't jump on reload

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
			"base_alpha": rng.randf_range(0.06, 0.18),
			"flicker_speed": rng.randf_range(0.5, 2.0),
			"flicker_offset": rng.randf() * TAU,
		})
