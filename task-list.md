# Task List — Visual Polish (Waves-inspired aesthetic)

## Goal
Transform the flat prototype look into the neon-drenched, glow-heavy aesthetic
described in the GDD and inspired by Waves: deep void, additive light bloom,
drifting particles, and elements that feel alive.

## Key Constraints
- Renderer is `gl_compatibility` (no WorldEnvironment bloom/Glow post-process).
- All glow must be faked via multi-pass additive drawing.
- Must stay calm/atmospheric per GDD, not chaotic like Waves.

## Steps

1. **BeamLayer: additive glow overhaul**
   → CanvasItemMaterial with BLEND_MODE_ADD
   → 5-layer glow (ultra-wide halo → bright core) with round caps
   → Radial glow at segment endpoints (beam intersections feel hot)
   → verify: overlapping beams create bright hotspots

2. **Background system (new file)**
   → Slowly drifting ambient particles (dust motes)
   → Subtle animated radial gradient (breathing void)
   → verify: background has depth and motion, never distracting

3. **Grid: living elements**
   → _process-driven animation (pulsing source glow, breathing grid)
   → Source orb with pulsing aura
   → verify: grid feels alive when idle

4. **Hit-point flares**
   → Radial burst where beams hit mirrors/prisms/targets
   → verify: tool interactions have visual punch

5. **Color & contrast pass**
   → Deepen background, saturate beam colors
   → verify: beams pop against the void

## Status
- [x] BeamLayer additive glow
- [x] Background particle system
- [x] Grid animation
- [x] Hit-point flares
- [x] Color/contrast pass
