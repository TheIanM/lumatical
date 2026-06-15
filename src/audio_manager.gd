class_name AudioManager
extends Node

## Generative audio system for Lumatical.
##
## No sustained tones. A single note plays when a beam hits an object
## (mirror, prism, filter, splitter, lens, target). All notes come from
## 3 harmonically related pentatonic scales derived from the C major
## diatonic set, so any combination is always consonant.
##
## Scale 1 (I):  C major pentatonic  — C D E G A    (red beams)
## Scale 2 (IV): F major pentatonic  — F G A C D    (green beams)
## Scale 3 (V):  G major pentatonic  — G A B D E    (blue beams)
## White uses Scale 1 at a lower octave.
##
## Grid Y position maps to note index within the scale.

const SAMPLE_RATE := 44100.0

# 3 harmonic pentatonic scales — all notes are from C major diatonic,
# so any combination across scales is always consonant.
const SCALE_I := [0, 2, 4, 7, 9]       # C:  C D E G A
const SCALE_IV := [5, 7, 9, 12, 14]    # F:  F G A C D
const SCALE_V := [7, 9, 11, 14, 16]    # G:  G A B D E

# Root MIDI notes per color (which scale + starting octave)
const ROOT_RED := 48       # C3 + Scale I
const ROOT_GREEN := 53     # F3 + Scale IV
const ROOT_BLUE := 59      # B3 + Scale V
const ROOT_WHITE := 43     # G2 + Scale I (lower, grounding)

var _drone_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _master_bus := "Master"
var _muted := false


func _ready() -> void:
	if AudioServer.get_bus_count() == 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(0, "Master")

	_drone_player = AudioStreamPlayer.new()
	_drone_player.bus = _master_bus
	add_child(_drone_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = _master_bus
	add_child(_sfx_player)

	_generate_ambient_drone()


# ── Ambient Drone ──────────────────────────────────────────────────────────────

func _generate_ambient_drone() -> void:
	var samples := int(SAMPLE_RATE * 6.0)
	var data := PackedVector2Array()

	var freq1 := _midi_to_freq(36)  # C2
	var freq2 := _midi_to_freq(43)  # G2

	for i in range(samples):
		var t := i / SAMPLE_RATE
		var s1 := _triangle(freq1 * t) * 0.04
		var s2 := _triangle(freq2 * t) * 0.025
		var lfo := sin(0.1 * TAU * t) * 0.01
		var l := s1 + s2 + lfo
		var r := _triangle(freq1 * t + 0.2) * 0.04 + _triangle(freq2 * t + 0.2) * 0.025 + lfo
		data.append(Vector2(l, r))

	_drone_player.stream = _pack_wav(data, SAMPLE_RATE, true)
	_drone_player.volume_db = -18.0
	_drone_player.play()


# ── Interaction Notes ───────────────────────────────────────────────────────────
## Plays a single note for each beam-tool interaction. Called once per
## simulation pass (i.e. when the player places/moves/removes a tool).
##
## [param hits] — Array of {color, y_pos, tool_type} for each interaction.

func play_interaction_notes(hits: Array) -> void:
	if _muted or hits.is_empty():
		return

	# All notes are pre-mixed into one buffer so they play as a single
	# consonant chord with a soft attack.
	var max_duration := 1.2
	var samples := int(SAMPLE_RATE * max_duration)
	var mix_l := PackedFloat32Array()
	var mix_r := PackedFloat32Array()
	mix_l.resize(samples)
	mix_r.resize(samples)

	for hit in hits:
		var col: Color = hit["color"]
		var y_pos: int = hit["y_pos"]
		var midi := _note_for(col, y_pos)
		var freq := _midi_to_freq(midi)

		# Slight random detune for organic feel
		var detune: float = (randf() - 0.5) * 0.8

		for i in range(samples):
			var t := i / SAMPLE_RATE
			var env := exp(-t * 2.5) * (1.0 - exp(-t * 15.0))
			var w := _triangle((freq + detune) * t) * 0.06 * env
			mix_l[i] += w
			mix_r[i] += _triangle((freq + detune + 0.3) * t) * 0.06 * env

	# Normalize to prevent clipping
	var peak := 0.001
	for i in range(samples):
		peak = maxf(peak, absf(mix_l[i]))
		peak = maxf(peak, absf(mix_r[i]))
	var norm := 0.8 / peak

	var data := PackedVector2Array()
	for i in range(samples):
		data.append(Vector2(mix_l[i] * norm, mix_r[i] * norm))

	_play_sfx(_pack_wav(data, SAMPLE_RATE, false))


## Returns the MIDI note for a beam color at a given grid Y position.
func _note_for(col: Color, y_pos: int) -> int:
	var root: int
	var scale: Array

	if _is_red(col):
		root = ROOT_RED
		scale = SCALE_I
	elif _is_green(col):
		root = ROOT_GREEN
		scale = SCALE_IV
	elif _is_blue(col):
		root = ROOT_BLUE
		scale = SCALE_V
	else:
		root = ROOT_WHITE
		scale = SCALE_I

	# Map Y position (0=top=high pitch, 7=bottom=low) to scale notes.
	# Higher grid rows = lower pitch. Wrap across octaves.
	var index := clampi(7 - y_pos, 0, 7)
	var octave: int = index / scale.size()
	var degree: int = scale[index % scale.size()]
	return root + degree + octave * 12


# ── One-shot SFX ────────────────────────────────────────────────────────────────

func play_solve_chord() -> void:
	if _muted: return

	var samples := int(SAMPLE_RATE * 1.5)
	var data := PackedVector2Array()
	var chord := [48, 52, 55, 60, 64]  # C major spread — C3 E3 G3 C4 E4

	for i in range(samples):
		var t := i / SAMPLE_RATE
		var attack := minf(t / 0.15, 1.0)
		var release := 1.0
		if t > 0.9:
			release = maxf(1.0 - (t - 0.9) / 0.6, 0.0)
		var env := attack * release
		var l := 0.0
		var r := 0.0
		for note in chord:
			var f := _midi_to_freq(note)
			l += _triangle(f * t) * 0.06
			r += _triangle((f + 0.4) * t) * 0.06
		data.append(Vector2(l * env, r * env))
	_play_sfx(_pack_wav(data, SAMPLE_RATE, false))


func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()


# ── Controls ────────────────────────────────────────────────────────────────────

func toggle_mute() -> void:
	_muted = not _muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(_master_bus), _muted)


func is_muted() -> bool:
	return _muted


func stop_all_tones() -> void:
	pass  # No sustained tones to stop


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _triangle(phase: float) -> float:
	return (2.0 / PI) * asin(sin(TAU * phase))


func _is_red(col: Color) -> bool:
	return col.r > 0.8 and col.g < 0.5 and col.b < 0.5


func _is_green(col: Color) -> bool:
	return col.g > 0.8 and col.r < 0.3


func _is_blue(col: Color) -> bool:
	return col.b > 0.8 and col.r < 0.5


func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _pack_wav(data: PackedVector2Array, rate: float, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var frames := data.size()
	var buf := PackedByteArray()
	buf.resize(frames * 4)
	for i in range(frames):
		buf.encode_s16(i * 4, clampi(int(data[i].x * 32767), -32768, 32767))
		buf.encode_s16(i * 4 + 2, clampi(int(data[i].y * 32767), -32768, 32767))
	stream.data = buf
	stream.mix_rate = int(rate)
	stream.stereo = true
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream
