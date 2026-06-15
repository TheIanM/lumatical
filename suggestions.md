# Suggestions

Ideas noticed during development, not implemented to keep changes surgical.

## Done
- ~~Toolbelt UI~~ ✅
- ~~clear_mirrors rename~~ ✅
- ~~Solve overlay color~~ ✅

## Visual polish (future iterations)
- **Screen-space bloom via shader**: Currently faking bloom with multi-pass
  additive drawing. A custom post-process shader (even in gl_compatibility
  using a back-buffer copy) would give smoother, more natural glow falloff.
- **Chromatic aberration on beam edges**: The GDD calls for subtle RGB channel
  offset at beam split points and during the solve animation. Could be done
  by drawing R/G/B channels at slight offsets for wide glow layers.
- **Solve animation cascade**: The GDD describes a "cascading bloom wave across
  the entire grid" on puzzle completion. Currently just shows an overlay.
  Could animate beams brightening sequentially from source to targets.
- **Particle light-up on beam proximity**: Background particles currently
  flicker independently. The GDD envisions them lighting up when beams pass
  through them — like dust motes in a flashlight. Would need beam-particle
  collision checks.
- **Beam trail/afterimage**: Waves leaves luminous trails on moving elements.
  Beams could have a brief afterimage fade when they change (tool moved).
- **Audio**: The entire generative audio system is unbuilt. This is a major
  part of the GDD's atmosphere — the ambient drone, beam tones, solve chord.
- **Mobile touch**: No touch input yet, only mouse. The GDD targets iOS/Android
  as secondary platforms with drag-and-drop tool placement.
