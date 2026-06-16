# Task List — New Tools & Puzzles

## Goal
Add 2 new tools from the GDD's open question list, then puzzles using them.
Keeping it to 2 tools to stay focused — pick the most impactful, least punishing.

## Tools Selected
1. **Refractor Cube** — Bends a beam 90° clockwise regardless of entry angle.
   Simpler than a mirror but less flexible. Great for teaching routing basics
   and creating "one way" puzzle constraints.
2. **Teleporter** — Beam enters one portal, exits the other at same direction.
   Opens spatial puzzles across the grid. Two linked portals placed as a pair.

## Tools Deferred
- Color Mixer — requires two converging beams, complex for prototype
- Timer Gate — adds timing element, user wants non-punishing

## Steps
1. BeamSimulator: add refractor + teleporter handling
   → verify: unit trace through each tool type
2. Grid: add drawing + input for both tools (KEY_6, KEY_7)
   → verify: can place/remove/rotate
3. Main: add toolbelt entries, tools dict, new puzzles
   → verify: puzzles solvable
4. Run end-to-end

## Status
- [ ] Refractor Cube (simulator + grid + main)
- [ ] Teleporter (simulator + grid + main)
- [ ] New puzzles (41-50)
- [ ] End-to-end test
