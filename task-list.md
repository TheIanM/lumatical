# Task List — Generative Audio System

## Goal
Implement the GDD's generative audio: each beam produces a sustained tone
based on color and grid position, interactions have percussive sounds, and
solving a puzzle produces a convergent chord.

## Design (from GDD)
- Pitch: determined by beam's vertical position (top=high, bottom=low)
- Volume: determined by beam intensity
- Timbre: white=rich fundamental, red=warm low, green=clean mid, blue=crystalline high
- Mirror reflection: percussive ping
- Prism split: crystalline shatter
- Target hit: resonant confirmation tone
- Solve: all tones converge into a sustained chord, fades over 3s
- Ambient drone: low evolving pad beneath everything

## Technical Approach
Godot's AudioStreamGenerator lets us synthesize audio in real-time by
filling PCM buffers. We'll create one generator for the ambient drone
and use AudioStreamPlayer nodes for discrete SFX (pings, shatters).

For sustained beam tones, we use a pool of AudioStreamPlayer nodes with
generated AudioStreamWAV resources (simple sine + harmonics), pitched
per beam. This is simpler than raw PCM and sufficient for the prototype.

## Steps
1. AudioManager: singleton-style node, manages all audio
   → ambient drone via AudioStreamGenerator
   → beam tone generation (pitch from position, timbre from color)
2. Wire beam tone updates into the simulation loop
   → tones start/stop as beams appear/disappear
3. Interaction SFX: mirror ping, prism shatter, target hit
4. Solve chord: convergent chord on puzzle completion
5. Settings: mute toggle

## Status
- [x] AudioManager core + ambient drone
- [x] Beam tones (pitch + timbre by color)
- [x] Interaction SFX
- [x] Solve chord
- [x] Mute toggle
