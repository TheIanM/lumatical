# Task List — Enemies & Obstacles

## Goal
Implement the three GDD enemy types as puzzle elements, then add puzzles
that use them. This is Phase II content from the roadmap.

## Enemy Designs (from GDD)

### Shadow Block
- Occupies a cell, absorbs any beam below its intensity threshold
- Destroyed by a beam with intensity >= threshold (default 0.75)
- Teaches the intensity dimension — split beams (0.5i) need a convex lens
- Visual: dark hexagon with pulsing glow

### Chromatic Shade
- Has a color (e.g., RED). Absorbs non-matching colors
- Destroyed by matching color beam — then cell is clear for all beams
- Teaches color-based obstacle removal
- Visual: ghostly translucent shape in its vulnerability color

### Null Emitter
- Creates a 3x3 dead zone that cancels all beams entering it
- Cannot be destroyed (for now — GDD describes a timing cycle, deferred)
- Forces routing around its area of effect
- Visual: dark circle with radiating field

## Key Implementation Detail
Enemies are "destroyed" within a single simulation pass. The first beam
to reach an enemy with the right property (intensity/color) destroys it,
allowing subsequent beams to pass through. This is tracked in
SimResult.destroyed_enemies.

## Steps
1. BeamSimulator: add enemy types + null zone precomputation
2. Grid: add enemy state, drawing, destroyed feedback
3. Main: enemy data in levels, tools dict, 5 new puzzles (11-15)
4. Test end-to-end

## Status
- [x] BeamSimulator enemy handling
- [x] Grid enemy drawing
- [x] Main enemy levels
- [x] End-to-end test
