# Task List — Lens Tool & Intensity System

## Goal
Implement the Lens — the last of the 6 core GDD tools. Adds the intensity
dimension: convex lenses focus beams (stronger), concave spread them (weaker).
Targets can now require a minimum intensity to activate.

## Design Decision
In our cardinal-direction grid, "bending by a fixed angle" (the GDD's lens
description) doesn't add anything mirrors don't already cover. The interesting
and unique mechanic is intensity modification:
- Convex (orientation 0): beam passes through, intensity ×1.5
- Concave (orientation 1): beam passes through, intensity ×0.5
- Targets can optionally specify "intensity" (minimum needed to activate)

This creates puzzles where split beams (at 0.5 intensity) must be focused
through a convex lens to reach a target that requires full intensity.

## Steps
1. BeamSimulator: add lens handling + intensity-gated targets
   → verify: lens modifies intensity, targets check intensity threshold
2. Grid: add lens state, drawing, placement, input (KEY_5)
   → verify: can place/toggle/remove lenses
3. Main: add lens_budget, toolbelt entry, tool dict, new puzzles
   → verify: puzzles are solvable
4. Run project end-to-end → verify: all puzzles playable

## Status
- [x] BeamSimulator lens + intensity targets
- [x] Grid lens support
- [x] Main lens levels + toolbelt
- [x] End-to-end test
