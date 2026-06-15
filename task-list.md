# Task List — Prisms & Color Splitting

## Goal
Implement prisms and color splitting — the next Phase I milestone per the GDD roadmap.
Phase I calls for: "Implement mirrors, prisms, and color splitting."

## Design Decisions (stated assumptions)

The GDD describes prisms as splitting white light into RGB at "a fixed angular
separation." Our grid uses cardinal directions only (up/down/left/right), so
"angular separation" maps to 90-degree turns. The design:

1. **Prism on white beam**: splits into 3 colored beams.
   - GREEN continues straight
   - RED turns 90° left (counterclockwise)
   - BLUE turns 90° right (clockwise)
   - Orientation 1 swaps red/blue sides.
2. **Colored beam on prism**: passes through unaffected (no split).
3. **Targets**: a target is only "hit" when beam color matches target color.
   A wrong-color beam is absorbed but does not activate the target.
4. **Tool selection**: keyboard-based (1 = mirror, 2 = prism) for the prototype.
   A proper toolbelt UI is a future task.

## Steps

1. Update BeamSimulator: add color constants, prism tool handling, beam-split
   via work queue → verify: white beam through prism produces 3 RGB segments
2. Update Grid: add prism placement/drawing, tool selection, budgets
   → verify: can place prisms, switch between mirror/prism via keys
3. Update Main: add prism_budget to levels, add Chapter II puzzles, tool selection
   status → verify: new puzzles are solvable
4. Run project end-to-end → verify: all puzzles playable and winnable

## Status
- [x] Commit existing prototype
- [x] BeamSimulator prism support
- [x] Grid prism support
- [x] Main prism levels
- [x] End-to-end test
