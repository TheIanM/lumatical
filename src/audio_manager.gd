class_name AudioManager
extends Node

## Generative audio system for Lumatical.
##
## Each beam produces a sustained tone — pitch from its vertical grid
## position, timbre from its color. The result is an ethereal soundscape
## that resolves into a soft chord when solved.
##
## Waveforms use triangle waves (soft, mystical) rather than sine stacks.
## Tones only start/stop when the beam set actually changes — no stutter.

const PENTATONIC_MAJOR := [0, 2, 4, 7, 9]

const MIDI_ROOT_RED := 48      # C3
const MIDI_ROOT_GREEN := 60    # C4
const MIDI_ROOT_BLUE := 72     # C5
const MIDI_ROOT_WHITE := 55    # G3

const SAMPLE_RATE := 44100.0
const TONE_DURATION := 3.0     # Longer loop = less obvious repetition

var _tone_players: Array = []
var _drone_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _master_bus := "Master"
var _muted := false

var _tone_cache: Dictionary = {}

# Track active tones by a composite key (color+pitch) so we don't
# stop/restart tones that are already playing.
var _active_tones: Dictionary = {}  # key -> AudioStreamPlayer


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

	for i in range(16):
		var p := AudioStreamPlayer.new()
		p.bus = _master_bus
		p.volume_db = -24.0
		add_child(p)
		_tone_players.append({"player": p, "busy": false})


# ── Ambient Drone ──────────────────────────────────────────────────────────────

func _generate_ambient_drone() -> void:
	var samples := int(SAMPLE_RATE * 6.0)  # 6-second loop for less repetition
	var data := PackedVector2Array()

	var freq1 := _midi_to_freq(36)  # C2
	var freq2 := _midi_to_freq(43)  # G2
	var freq3 := _midi_to_freq(48)  # C3 — subtle octave

	for i in range(samples):
		var t := i / SAMPLE_RATE
		# Triangle waves — softer than sine stacks
		var s1 := _triangle(freq1 * t) * 0.05
		var s2 := _triangle(freq2 * t) * 0.03
		var s3 := sin(freq3 * TAU * t) * 0.015  # subtle sine layer
		# Slow vibrato for a breathing, mystical feel
		var lfo := sin(0.12 * TAU * t) * 0.015
		# Stereo width: slightly different phase per channel
		var sample_l := s1 + s2 + s3 + lfo
		var sample_r := s1 + _triangle(freq2 * t + 0.3) * 0.03 + s3 + lfo
		data.append(Vector2(sample_l, sample_r))

	_drone_player.stream = _pack_wav(data, SAMPLE_RATE, true)
	_drone_player.volume_db = -16.0
	_drone_player.play()


# ── Beam Tones ─────────────────────────────────────────────────────────────────

func update_beam_tones(beams: Array) -> void:
	if _muted:
		return

	# Build the set of tones that SHOULD be playing.
	# Key = color_key + pitch_index, so same color at different positions
	# produces different tones.
	var desired: Dictionary = {}
	for beam in beams:
		var col: Color = beam["color"]
		var y_pos: int = beam.get("y_pos", 4)
		var intensity: float = beam.get("intensity", 1.0)
		var key := "%s_%d" % [_color_key(col), y_pos]
		if not desired.has(key):
			desired[key] = {"color": col, "y_pos": y_pos, "intensity": intensity}

	# Stop tones that are no longer needed
	var to_stop: Array = []
	for key in _active_tones:
		if not desired.has(key):
			to_stop.append(key)
	for key in to_stop:
		var p: AudioStreamPlayer = _active_tones[key]
		p.stop()
		_active_tones.erase(key)

	# Start new tones — leave existing ones alone (no stutter)
	for key in desired:
		if _active_tones.has(key):
			continue
		var info: Dictionary = desired[key]
		var player := _get_free_tone_player()
		if player == null:
			continue
		var stream := _get_or_create_tone(info["color"])
		player.stream = stream
		player.pitch_scale = _pitch_from_position(info["color"], info["y_pos"])
		player.volume_db = _intensity_to_db(info["intensity"])
		player.play()
		_active_tones[key] = player


func _pitch_from_position(col: Color, y_pos: int) -> float:
	var root := _color_root(col)
	var scale_index := clampi(7 - y_pos, 0, 7)
	var octave_offset: int = (scale_index / PENTATONIC_MAJOR.size()) * 12
	var note_index: int = PENTATONIC_MAJOR[scale_index % PENTATONIC_MAJOR.size()]
	var midi_note := root + note_index + octave_offset
	return _midi_to_freq(midi_note) / _midi_to_freq(root)


func _color_root(col: Color) -> int:
	if _is_red(col):   return MIDI_ROOT_RED
	if _is_green(col): return MIDI_ROOT_GREEN
	if _is_blue(col):  return MIDI_ROOT_BLUE
	return MIDI_ROOT_WHITE


func _get_or_create_tone(col: Color) -> AudioStream:
	var key := _color_key(col)
	if _tone_cache.has(key):
		return _tone_cache[key]
	var wav := _generate_tone_waveform(col)
	_tone_cache[key] = wav
	return wav


func _generate_tone_waveform(col: Color) -> AudioStream:
	var samples := int(SAMPLE_RATE * TONE_DURATION)
	var data := PackedVector2Array()

	var base_freq: float = _midi_to_freq(_color_root(col))
	var vibrato_rate := 0.6   # Hz — very slow drift
	var vibrato_depth := 0.5  # Hz — subtle pitch wobble

	if _is_red(col):
		# Warm low — soft triangle, barely any harmonics
		base_freq = _midi_to_freq(MIDI_ROOT_RED)
		vibrato_rate = 0.4
	elif _is_green(col):
		# Clean mid — pure triangle, ethereal
		base_freq = _midi_to_freq(MIDI_ROOT_GREEN)
		vibrato_rate = 0.7
	elif _is_blue(col):
		# Crystalline high — bright triangle, glassy
		base_freq = _midi_to_freq(MIDI_ROOT_BLUE)
		vibrato_rate = 0.9
	else:
		# White — rich but soft, slight detune for chorus effect
		base_freq = _midi_to_freq(MIDI_ROOT_WHITE)
		vibrato_rate = 0.5

	for i in range(samples):
		var t := i / SAMPLE_RATE
		# Vibrato — slow pitch modulation for a living, mystical tone
		var vibrato := sin(vibrato_rate * TAU * t) * vibrato_depth
		var freq := base_freq + vibrato

		# Triangle wave — soft and ethereal, no harsh edges
		var sample := _triangle(freq * t) * 0.18

		# Subtle octave shimmer for green/blue
		if _is_green(col) or _is_blue(col):
			sample += _triangle(freq * 2.0 * t) * 0.03

		# Stereo detune — slight pitch offset between channels for width
		var sample_r := _triangle((freq + 0.3) * t) * 0.18
		if _is_green(col) or _is_blue(col):
			sample_r += _triangle((freq + 0.3) * 2.0 * t) * 0.03

		# Envelope: long fade in/out for seamless, breathy loop
		var env := 1.0
		var fade := int(SAMPLE_RATE * 0.3)  # 300ms fade
		if i < fade:
			env = float(i) / fade
		elif i > samples - fade:
			env = float(samples - i) / fade
		sample *= env
		sample_r *= env
		data.append(Vector2(sample, sample_r))

	return _pack_wav(data, SAMPLE_RATE, true)


# ── Interaction SFX ─────────────────────────────────────────────────────────────

func play_mirror_ping() -> void:
	if _muted: return
	_play_sfx(_generate_ping(660.0, 0.4))


func play_prism_shatter() -> void:
	if _muted: return
	_play_sfx(_generate_shatter())


func play_target_hit() -> void:
	if _muted: return
	_play_sfx(_generate_confirmation())


func play_solve_chord() -> void:
	if _muted: return
	_play_sfx(_generate_solve_chord())


func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()


func _generate_ping(freq: float, duration: float) -> AudioStream:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedVector2Array()
	for i in range(samples):
		var t := i / SAMPLE_RATE
		# Soft triangle with slow decay — gentle, not piercing
		var env := exp(-t * 4.0)
		var sample := _triangle(freq * t) * env * 0.12
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_shatter() -> AudioStream:
	# Descending triangle tones — like soft chimes, not glass breaking
	var samples := int(SAMPLE_RATE * 0.6)
	var data := PackedVector2Array()
	var freqs := [880.0, 660.0, 990.0, 740.0]
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var sample := 0.0
		for fi in range(freqs.size()):
			var f: float = freqs[fi]
			var delay: float = fi * 0.04
			if t > delay:
				var lt := t - delay
				var env := exp(-lt * 5.0)
				sample += _triangle(f * lt) * env * 0.06
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_confirmation() -> AudioStream:
	var samples := int(SAMPLE_RATE * 0.6)
	var data := PackedVector2Array()
	var freq := _midi_to_freq(72)
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var env := exp(-t * 4.0) * (1.0 - exp(-t * 20.0))
		var sample := _triangle(freq * t) * env * 0.15
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_solve_chord() -> AudioStream:
	# Soft major chord with triangle waves — ethereal, not triumphant.
	# Shorter: 1.5s with gentle attack and release.
	var samples := int(SAMPLE_RATE * 1.5)
	var data := PackedVector2Array()
	var chord := [60, 64, 67, 72]  # C major
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var attack := minf(t / 0.2, 1.0)
		var release := 1.0
		if t > 0.9:
			release = maxf(1.0 - (t - 0.9) / 0.6, 0.0)
		var env := attack * release
		var sample := 0.0
		var sample_r := 0.0
		for ni in range(chord.size()):
			var f := _midi_to_freq(chord[ni])
			# Slight stereo detune per note for width
			sample += _triangle(f * t) * 0.08
			sample_r += _triangle((f + 0.4) * t) * 0.08
		sample *= env
		sample_r *= env
		data.append(Vector2(sample, sample_r))
	return _pack_wav(data, SAMPLE_RATE, false)


# ── Controls ────────────────────────────────────────────────────────────────────

func toggle_mute() -> void:
	_muted = not _muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(_master_bus), _muted)


func is_muted() -> bool:
	return _muted


func stop_all_tones() -> void:
	for key in _active_tones:
		var p: AudioStreamPlayer = _active_tones[key]
		p.stop()
	_active_tones.clear()


# ── Helpers ─────────────────────────────────────────────────────────────────────

## Triangle wave oscillator. Softer and more ethereal than sine stacks.
## Uses the arcsin approach for a clean triangle shape.
func _triangle(phase: float) -> float:
	return (2.0 / PI) * asin(sin(TAU * phase))


func _get_free_tone_player() -> AudioStreamPlayer:
	for entry in _tone_players:
		if not entry["busy"] or not entry["player"].playing:
			entry["busy"] = true
			return entry["player"]
	return _tone_players[0]["player"]


func _color_key(col: Color) -> String:
	return "%.3f%.3f%.3f" % [col.r, col.g, col.b]


func _is_red(col: Color) -> bool:
	return col.r > 0.8 and col.g < 0.5 and col.b < 0.5


func _is_green(col: Color) -> bool:
	return col.g > 0.8 and col.r < 0.3


func _is_blue(col: Color) -> bool:
	return col.b > 0.8 and col.r < 0.5


func _intensity_to_db(intensity: float) -> float:
	var i := clampf(intensity, 0.1, 1.0)
	return lerp(-36.0, -12.0, i)


func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _pack_wav(data: PackedVector2Array, rate: float, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	var frames := data.size()
	var buf := PackedByteArray()
	buf.resize(frames * 4)
	for i in range(frames):
		var l := clampi(int(data[i].x * 32767), -32768, 32767)
		var r := clampi(int(data[i].y * 32767), -32768, 32767)
		buf.encode_s16(i * 4, l)
		buf.encode_s16(i * 4 + 2, r)
	stream.data = buf
	stream.mix_rate = int(rate)
	stream.stereo = true
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream
