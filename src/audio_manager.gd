class_name AudioManager
extends Node

## Generative audio system for Lumatical.
##
## Each beam produces a sustained tone — pitch from its vertical grid
## position, timbre from its color. This makes every puzzle a unique
## soundscape that resolves into a chord when solved.
##
## Architecture:
## - Ambient drone: synthesized AudioStreamGenerator, always playing.
## - Beam tones: pool of AudioStreamPlayer nodes with generated WAV data.
##   We generate short looping tones per color and pitch-shift them.
## - Interaction SFX: one-shot AudioStreamPlayer for discrete events.

# ── Note frequencies (pentatonic scale for pleasant consonance) ───────────────
# The GDD's "soft constraint" option: grid positions map to a pentatonic
# scale so any combination of beams sounds harmonious.
const PENTATONIC_MAJOR := [0, 2, 4, 7, 9]  # Scale degrees (semitones from root)

# Base notes per color — different octaves for each beam color
# Red is warm/low, Green is clean/mid, Blue is crystalline/high, White is rich
const MIDI_ROOT_RED := 48      # C3 — warm low
const MIDI_ROOT_GREEN := 60    # C4 — clean mid
const MIDI_ROOT_BLUE := 72     # C5 — crystalline high
const MIDI_ROOT_WHITE := 55    # G3 — rich fundamental

const SAMPLE_RATE := 44100.0
const TONE_DURATION := 2.0     # Seconds — looping tone segments

# Tone player pool
var _tone_players: Array = []
var _drone_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _master_bus := "Master"
var _muted := false

# Pre-generated tone waveforms, keyed by color hex
var _tone_cache: Dictionary = {}

# Track active beams to manage tone lifecycle
var _active_tones: Dictionary = {}  # color_hex -> AudioStreamPlayer


func _ready() -> void:
	# Ensure the audio bus exists
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

	# Create a pool of tone players
	for i in range(16):
		var p := AudioStreamPlayer.new()
		p.bus = _master_bus
		add_child(p)
		_tone_players.append({"player": p, "busy": false})


# ── Ambient Drone ──────────────────────────────────────────────────────────────

func _generate_ambient_drone() -> void:
	# Two low sine waves a fifth apart, very quiet, slowly evolving
	var samples := int(SAMPLE_RATE * 4.0)  # 4-second loop
	var data := PackedVector2Array()

	var freq1 := _midi_to_freq(36)  # C2 — deep drone
	var freq2 := _midi_to_freq(43)  # G2 — fifth

	for i in range(samples):
		var t := i / SAMPLE_RATE
		var s1 := sin(freq1 * TAU * t) * 0.08
		var s2 := sin(freq2 * TAU * t) * 0.05
		# Slow LFO for breathing
		var lfo := sin(0.15 * TAU * t) * 0.02
		var sample := s1 + s2 + lfo
		data.append(Vector2(sample, sample))

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 4.0

	# Use a WAV stream for looping
	var wav := _pack_wav(data, SAMPLE_RATE, true)
	_drone_player.stream = wav
	_drone_player.volume_db = -12.0
	_drone_player.play()


# ── Beam Tones ─────────────────────────────────────────────────────────────────

## Update beam tones based on current simulation result.
## [param beams] — Array of {color, intensity, y_pos (0=top)} for each beam.
func update_beam_tones(beams: Array) -> void:
	if _muted:
		return

	# Stop all currently playing tones
	for key in _active_tones:
		var p: AudioStreamPlayer = _active_tones[key]
		p.stop()
	_active_tones.clear()

	# Generate a tone for each unique beam color present
	var seen_colors: Dictionary = {}
	for beam in beams:
		var col: Color = beam["color"]
		var key := _color_key(col)
		if seen_colors.has(key):
			continue
		seen_colors[key] = true

		var y_pos: int = beam.get("y_pos", 4)
		var intensity: float = beam.get("intensity", 1.0)
		_play_beam_tone(col, y_pos, intensity)


func _play_beam_tone(col: Color, y_pos: int, intensity: float) -> void:
	var key := _color_key(col)
	var player := _get_free_tone_player()
	if player == null:
		return

	# Generate or get cached tone
	var stream := _get_or_create_tone(col)
	player.stream = stream
	player.pitch_scale = _pitch_from_position(col, y_pos)
	player.volume_db = _intensity_to_db(intensity)
	player.play()
	_active_tones[key] = player


func _pitch_from_position(col: Color, y_pos: int) -> float:
	# Map grid row (0=top=high pitch) to pentatonic scale
	# y_pos 0 = highest note, y_pos 7 = lowest note
	var root: int
	if _is_red(col):
		root = MIDI_ROOT_RED
	elif _is_green(col):
		root = MIDI_ROOT_GREEN
	elif _is_blue(col):
		root = MIDI_ROOT_BLUE
	else:
		root = MIDI_ROOT_WHITE

	# Flip y so top=high, bottom=low, then map to pentatonic
	var scale_index := clampi(7 - y_pos, 0, 7)
	var octave_offset := (scale_index / PENTATONIC_MAJOR.size()) * 12
	var note_index: int = PENTATONIC_MAJOR[scale_index % PENTATONIC_MAJOR.size()]
	var midi_note := root + note_index + octave_offset

	# Pitch scale relative to the tone's base frequency
	var base_note: int
	if _is_red(col):
		base_note = MIDI_ROOT_RED
	elif _is_green(col):
		base_note = MIDI_ROOT_GREEN
	elif _is_blue(col):
		base_note = MIDI_ROOT_BLUE
	else:
		base_note = MIDI_ROOT_WHITE

	return _midi_to_freq(midi_note) / _midi_to_freq(base_note)


func _get_or_create_tone(col: Color) -> AudioStream:
	var key := _color_key(col)
	if _tone_cache.has(key):
		return _tone_cache[key]

	var wav := _generate_tone_waveform(col)
	_tone_cache[key] = wav
	return wav


func _generate_tone_waveform(col: Color) -> AudioStream:
	# Generate a looping tone with harmonics appropriate to the color
	var samples := int(SAMPLE_RATE * TONE_DURATION)
	var data := PackedVector2Array()

	var base_freq: float
	var harmonics: Array  # [{multiplier, amplitude}]

	if _is_red(col):
		# Warm low — fundamental + 2nd harmonic (like a cello)
		base_freq = _midi_to_freq(MIDI_ROOT_RED)
		harmonics = [{m = 1.0, a = 0.5}, {m = 2.0, a = 0.15}]
	elif _is_green(col):
		# Clean mid — bell-like, bright harmonics
		base_freq = _midi_to_freq(MIDI_ROOT_GREEN)
		harmonics = [{m = 1.0, a = 0.35}, {m = 3.0, a = 0.1}, {m = 5.0, a = 0.05}]
	elif _is_blue(col):
		# Crystalline high — glassy, odd harmonics
		base_freq = _midi_to_freq(MIDI_ROOT_BLUE)
		harmonics = [{m = 1.0, a = 0.3}, {m = 2.0, a = 0.08}, {m = 4.0, a = 0.04}]
	else:
		# White — rich fundamental, all harmonics
		base_freq = _midi_to_freq(MIDI_ROOT_WHITE)
		harmonics = [{m = 1.0, a = 0.3}, {m = 2.0, a = 0.1}, {m = 3.0, a = 0.05}]

	for i in range(samples):
		var t := i / SAMPLE_RATE
		var sample := 0.0
		for h in harmonics:
			sample += sin(base_freq * h.m * TAU * t) * h.a
		# Envelope: fade in/out for seamless loop
		var env := 1.0
		var fade := int(SAMPLE_RATE * 0.05)
		if i < fade:
			env = float(i) / fade
		elif i > samples - fade:
			env = float(samples - i) / fade
		sample *= env * 0.3
		data.append(Vector2(sample, sample))

	return _pack_wav(data, SAMPLE_RATE, true)


# ── Interaction SFX ─────────────────────────────────────────────────────────────

func play_mirror_ping() -> void:
	if _muted:
		return
	_play_sfx(_generate_ping(880.0, 0.15))


func play_prism_shatter() -> void:
	if _muted:
		return
	_play_sfx(_generate_shatter())


func play_target_hit() -> void:
	if _muted:
		return
	_play_sfx(_generate_confirmation())


func play_solve_chord() -> void:
	if _muted:
		return
	_play_sfx(_generate_solve_chord())


func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()


func _generate_ping(freq: float, duration: float) -> AudioStream:
	var samples := int(SAMPLE_RATE * duration)
	var data := PackedVector2Array()
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var env := exp(-t * 15.0)
		var sample := sin(freq * TAU * t) * env * 0.3
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_shatter() -> AudioStream:
	# Quick descending arpeggio of crystal-like tones
	var samples := int(SAMPLE_RATE * 0.5)
	var data := PackedVector2Array()
	var freqs := [1320.0, 1760.0, 2200.0, 2640.0]
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var sample := 0.0
		for f in freqs:
			var delay := (freqs.find(f)) * 0.03
			if t > delay:
				var lt := t - delay
				var env := exp(-lt * 8.0)
				sample += sin(f * TAU * lt) * env * 0.1
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_confirmation() -> AudioStream:
	var samples := int(SAMPLE_RATE * 0.8)
	var data := PackedVector2Array()
	var freq := _midi_to_freq(72)  # C5
	for i in range(samples):
		var t := i / SAMPLE_RATE
		var env := exp(-t * 3.0) * (1.0 - exp(-t * 30.0))
		var sample := (sin(freq * TAU * t) * 0.3 + sin(freq * 2 * TAU * t) * 0.1) * env
		data.append(Vector2(sample, sample))
	return _pack_wav(data, SAMPLE_RATE, false)


func _generate_solve_chord() -> AudioStream:
	# Consonant major chord (C-E-G-C) that sustains and fades over 3 seconds
	var samples := int(SAMPLE_RATE * 3.0)
	var data := PackedVector2Array()
	var chord := [60, 64, 67, 72]  # C major: C4, E4, G4, C5
	for i in range(samples):
		var t := i / SAMPLE_RATE
		# Slow attack, long release
		var attack := minf(t / 0.3, 1.0)
		var release := 1.0
		if t > 2.0:
			release = maxf(1.0 - (t - 2.0) / 1.0, 0.0)
		var env := attack * release
		var sample := 0.0
		for note in chord:
			var f := _midi_to_freq(note)
			sample += sin(f * TAU * t) * 0.12
		sample *= env * 0.5
		data.append(Vector2(sample, sample))
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

func _get_free_tone_player() -> AudioStreamPlayer:
	for entry in _tone_players:
		if not entry["busy"] or not entry["player"].playing:
			entry["busy"] = true
			return entry["player"]
	# All busy — reuse the first one
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
	# Map 0-1 intensity to -30dB to -6dB
	var i := clampf(intensity, 0.1, 1.0)
	return lerp(-30.0, -6.0, i)


func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _pack_wav(data: PackedVector2Array, rate: float, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	# Interleave stereo: L R L R ...
	var frames := data.size()
	var buf := PackedByteArray()
	buf.resize(frames * 4)  # 2 bytes per sample, 2 channels
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
