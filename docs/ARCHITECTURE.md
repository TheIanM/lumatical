# Lumatical — Internal Documentation

## Architecture Overview

```
MainMenu.tscn → Play → PuzzleSelect → Main.tscn (gameplay)
                → Roguelike → Roguelike.tscn (procedural)
                → Level Editor → Editor.tscn
```

All three game scenes (Main, Roguelike, Editor) share the same building blocks:
- `BeamSimulator` — pure logic, no Node dependencies
- `Grid` — cell state + rendering + input
- `BeamLayer` — beam segment rendering with glow
- `AudioManager` — generative interaction audio
- `Background` — animated particles and atmosphere

---

## Core Module: BeamSimulator (`src/beam_simulator.gd`)

The heart of the game. Traces beams through a grid of optical tools.

### Input Format

```gdscript
BeamSimulator.simulate(grid_size, tools, sources, cell_size)
```

**tools** — Dictionary mapping `Vector2i` cell positions to tool dicts:
```
{"type": "mirror", "orientation": 0|1}        # 0="/", 1="\"
{"type": "prism", "orientation": 0|1}         # splits white → RGB
{"type": "filter", "color": Color}            # passes matching color only
{"type": "splitter", "orientation": 0|1}      # duplicates beam at 0.5i
{"type": "lens", "orientation": 0|1}          # 0=convex ×1.5i, 1=concave ×0.5i
{"type": "refractor", "orientation": 0|1}     # 90° turn regardless of entry
{"type": "teleporter", "pair": Vector2i}      # beam exits at paired portal
{"type": "target", "color": Color}            # absorbs beam, records hit
{"type": "blocker"}                            # absorbs everything
{"type": "shadow_block", "threshold": float}  # destroyed if intensity ≥ threshold
{"type": "chromatic_shade", "color": Color}   # destroyed by matching color
{"type": "null_emitter"}                       # creates 3×3 dead zone
```

**sources** — Array of:
```
{"pos": Vector2i, "direction": Vector2i, "color": Color, "intensity": float}
```

### Output Format

```gdscript
class SimResult:
    var segments: Array       # Array of BeamSegment {start, end, color, intensity}
    var hit_targets: Array    # Array of Vector2i positions
    var destroyed_enemies: Dictionary  # pos → true
```

### Key Rules

- **Colors**: WHITE `(0.91, 0.91, 1.0)` is the full spectrum. RED/GREEN/BLUE are
  split components. Color matching uses `is_equal_approx`.
- **Intensity**: Starts at source (usually 1.0). Splitters halve it. Lenses
  multiply by 1.5 or 0.5. Beams below `MIN_INTENSITY` (0.05) are dropped.
- **Direction**: Cardinal only — `Vector2i(1,0)`, `(-1,0)`, `(0,1)`, `(0,-1)`.
- **Work queue**: Beam-splitting tools (prism, splitter) spawn new beams that
  are traced independently via a queue in `simulate()`.
- **Mirror reflection**: Depends on direction AND orientation.
  - "/" mirror: RIGHT→UP, UP→RIGHT, LEFT→DOWN, DOWN→LEFT
  - "\" mirror: RIGHT→DOWN, DOWN→RIGHT, LEFT→UP, UP→LEFT
- **Teleporter**: `pair` field points to the OTHER portal's position. The beam
  continues in the same direction from the paired cell.
- **Null emitter dead zones**: Precomputed as a 3×3 area around each emitter.
  Any beam entering a dead zone cell is cancelled.

### Solvability Validation (used by Editor and Generator)

To validate that a puzzle is solvable, run `BeamSimulator.simulate()` with the
solution tools + all fixed elements (targets, blockers, enemies), then check
that every target position appears in `result.hit_targets`.

```gdscript
var result = BeamSimulator.simulate(grid_size, tools_with_solution, sources, cell_size)
var all_hit = true
for pos in targets:
    if not pos in result.hit_targets:
        all_hit = false  # This target was NOT reached
```

This is the pattern used by:
- **Editor** (`editor.gd:_run_validation()`) — validates designer solutions
- **Generator** (`puzzle_generator.gd`) — validates generated puzzles (Step 7)

---

## Grid Tool Index Reference

| Index | Tool          | Key | Color Constant    |
|-------|---------------|-----|-------------------|
| 0     | Mirror        | 1   | C_MIRROR (cyan)   |
| 1     | Prism         | 2   | C_PRISM (magenta) |
| 2     | Filter        | 3   | C_FILTER (yellow) |
| 3     | Splitter      | 4   | C_SPLITTER (orange)|
| 4     | Lens          | 5   | C_LENS (violet)   |
| 5     | Refractor     | 6   | C_REFRACTOR (teal)|
| 6     | Teleporter    | 7   | C_TELEPORTER (pink)|

Filter sub-colors are indexed by int in `Grid.FILTER_COLORS`:
- 0 = RED, 1 = GREEN, 2 = BLUE
- These reference `BeamSimulator.RED/GREEN/BLUE` directly to prevent drift.

---

## Level Format

Levels are dictionaries with these keys:

```gdscript
{
    "name": String,
    "sources": [{"pos": Vector2i, "direction": Vector2i, "color": Color, "intensity": float}],
    "targets": {Vector2i: {"color": Color, "intensity": float (optional)}},
    "blockers": [Vector2i, ...],
    "shadow_blocks": [{"pos": Vector2i, "threshold": float}],      # optional
    "chromatic_shades": [{"pos": Vector2i, "color": Color}],       # optional
    "null_emitters": [Vector2i, ...],                               # optional
    "mirror_budget": int,
    "prism_budget": int,        # optional, defaults to 0
    "filter_budget": int,       # optional
    "splitter_budget": int,     # optional
    "lens_budget": int,         # optional
    "refractor_budget": int,    # optional
    "teleporter_budget": int,   # optional
}
```

### How Tools Dict is Built (Main/Roguelike)

`_build_tools_dict()` in both `main.gd` and `roguelike.gd` merges:
1. Targets (with optional intensity)
2. Blockers
3. Enemies (shadow blocks, chromatic shades, null emitters)
4. Player-placed tools (mirrors, prisms, filters, splitters, lenses, refractors)
5. Teleporters (with `pair` pointing to the other portal)

**Critical**: The tools dict must include ALL fixed elements AND all
player-placed tools. Missing any will cause simulation bugs.

---

## Puzzle Generator (`src/puzzle_generator.gd`)

Solution-first generation — never needs to solve a puzzle.

### Pipeline

1. **Place source** at random edge cell, facing inward
2. **Place N solution tools** at random positions
3. **Simulate** the beam paths through solution tools
4. **Extract targets** by walking along beam segments, collecting all cells
   the beam passes through (excluding source and tool cells)
5. **Build puzzle** with stripped tools, budgets derived from solution
6. **Add obstacles/enemies** for difficulty
7. **Validate**: re-simulate with solution tools + targets + obstacles to
   confirm all targets are still reachable. If not, regenerate.

### Difficulty Tiers

| Tier | Floors | Tools | Targets | Pool |
|------|--------|-------|---------|------|
| Easy | 1-5 | 1-2 | 1 | Mirrors |
| Normal | 6-15 | 2-3 | 1-2 | + Prism, Filter |
| Hard | 16-30 | 3-4 | 2-3 | + Splitter, Lens, weak sources |
| Brutal | 31+ | 4-5 | 2-3 | All tools + enemies |

### Validation (Step 7)

After building the puzzle, we verify solvability by:
1. Re-adding the solution tools to the tools dict
2. Running BeamSimulator
3. Checking all targets are hit
4. If any miss (e.g., a blocker was placed on a solution path), regenerate

This is the same pattern as the level editor's `_run_validation()`.

---

## Known Gotchas

1. **`erase()` returns void in Godot 4** — can't use `if dict.erase(key)`.
   Use `if dict.has(key): dict.erase(key); changed = true`.

2. **GDScript type inference with Dictionary access** — `var x := dict["key"]`
   fails because Dictionary values are untyped. Use explicit types:
   `var x: int = dict["key"]` or `var x: float = float(dict["key"])`.

3. **`class_name` scripts need editor import** — new scripts with
   `class_name` won't be recognized until Godot's editor imports them
   (generates `.uid` files). Launch the editor briefly after creating
   new scripts.

4. **Vector2i as Dictionary keys** — works natively in GDScript, but JSON
   serialization needs string conversion (`"x,y"`). See `PuzzleSerializer`.

5. **FILTER_COLORS must match BeamSimulator colors** — always reference
   `BeamSimulator.RED/GREEN/BLUE` directly, never hardcode color values.
   (This caused the puzzle 6 bug where blue filters didn't match targets.)

6. **BeamSimulator direction is always cardinal** — no diagonal movement.
   Mirrors and refractors only produce cardinal outputs from cardinal inputs.

7. **Teleporter budget is always 2** — portals come in pairs. The first
   placed is index 0, the second is index 1. They link to each other.
