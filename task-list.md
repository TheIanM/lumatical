# Task List — Roguelike Puzzle Generator

## Goal
Solution-first puzzle generator with difficulty scaling, for the
procedural roguelike mode described in the GDD.

## Design (from GDD §09)
The generator never needs to *solve* a puzzle — it *constructs* one from
a known solution:
1. Place a source at a random position/direction
2. Place N random tools to route the beam (the solution)
3. Run BeamSimulator to trace beam paths
4. Place targets at beam endpoints (with matching colors)
5. Strip solution tools, set budget = solution tool count
6. Optionally add enemies/blockers for difficulty

Guaranteed solvable by construction.

## Difficulty Tiers
- **Easy** (floors 1-5): 1-2 tools, 1 target, mirrors only
- **Normal** (floors 6-15): 2-3 tools, 1-2 targets, + prisms/filters
- **Hard** (floors 16-30): 3-4 tools, 2-3 targets, + splitters/lenses
- **Brutal** (floors 31+): 4-5 tools, 2-3 targets, + enemies

## Steps
1. PuzzleGenerator core — place solution, simulate, extract targets
   → verify: generated puzzles are solvable
2. Difficulty scaling — parameters per floor
3. Roguelike scene — floor counter, score, next-floor flow
4. Run modifiers (stretch goal)

## Status
- [x] PuzzleGenerator core
- [x] Difficulty scaling
- [x] Roguelike scene
- [x] End-to-end test
