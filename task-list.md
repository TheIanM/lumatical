# Task List — Level Editor

## Goal
Build a level editor with solution-first validation per the GDD.

## Design
The editor is a separate scene (Editor.tscn) that lets you:
1. Place fixed elements: sources, targets, blockers, enemies
2. Place "solution" tools to prove the puzzle is solvable
3. Hit Validate — runs BeamSimulator, confirms all targets are hit
4. Export — saves the puzzle as JSON (tools stripped, budgets derived from solution)
5. Play-test — toggle to game mode to try solving it yourself

## Steps
1. PuzzleSerializer: convert between LEVELS dict format and JSON files
   → verify: can save/load existing puzzles round-trip
2. Editor grid: place/edit all element types with a palette UI
   → verify: can build a puzzle from scratch
3. Validator: run sim on solution config, report which targets are hit
   → verify: green check when all hit, red X with details when not
4. Export: derive budgets from solution tools, save JSON
   → verify: exported puzzle loads and plays correctly
5. Scene switching: Main menu → Editor → Playtest
   → verify: full round-trip works

## Status
- [x] PuzzleSerializer (JSON save/load)
- [x] Editor scene + grid + palette
- [x] Validator (solution-first)
- [x] Export with budget derivation
- [x] Play-test toggle
- [x] Scene switching
