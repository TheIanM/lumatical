# LUMATICAL

**Light is your instrument.**

A physics-based puzzle game where you bend, split, and direct beams of light through mirrors, prisms, and lenses to solve increasingly mind-bending challenges. No narrative. Pure luminescence. Pure logic.

Built in **Godot 4.6** with GDScript. All assets are vector/programmatic — no texture files, scales to any resolution.

---

## Features

### Core Gameplay
- **8 optical tools** — Mirror, Prism, Color Filter, Beam Splitter, Lens, Refractor Cube, Teleporter, and Blocker
- **3 enemy types** — Shadow Blocks (intensity-gated), Chromatic Shades (color-matched), Null Emitters (dead zones)
- **50 handcrafted puzzles** across 7 chapters of escalating complexity
- **Real-time beam simulation** — see exactly where your light goes as you place tools

### Roguelike Mode
- **Procedurally generated puzzles** via solution-first generation (guaranteed solvable by construction)
- **Persistent tool inventory** — tools are consumed on use, earned between floors
- **Run-end condition** — run out of tools, run ends
- **Reward screen** — pick 1 of 3 random tools after each floor
- **4 difficulty tiers** — Easy → Normal → Hard → Brutal
- **Daily seeded runs** — same puzzles for everyone, changes each day
- **Share codes** — 6-character codes to challenge friends with the same seed
- **Local leaderboard** — top 10 runs with mode, floor, score, and share code

### Level Editor
- **Full GUI editor** with palette for every element type
- **Solution-first validation** — place your solution, validate it, export
- **JSON puzzle format** — serializable, diffable, shareable
- **Real-time beam preview** while editing

### Presentation
- **Neon bloom aesthetic** — 5-layer additive glow on all beams, no post-processing needed
- **Animated background** — drifting particles, constellation networks, wireframe shapes, energy ripples, breathing radial gradients
- **Generative audio** — interaction-based notes on 3 harmonic pentatonic scales (always consonant)
- **Beam-rendered title** — "LUMATICAL" spelled out in light beams with mirrors at each corner and a prism splitting the T
- **Vector UI icons** — every tool has a programmatically drawn icon

---

## Tools

| Tool | What it does |
|------|-------------|
| **Mirror** | Reflects beams at angle of incidence. Two orientations: `/` and `\` |
| **Prism** | Splits white light into red, green, and blue beams |
| **Color Filter** | Passes only one color, absorbs the rest |
| **Beam Splitter** | Duplicates a beam into two copies at half intensity each |
| **Lens** | Convex focuses (×1.5 intensity), concave spreads (×0.5) |
| **Refractor Cube** | Bends beam 90° regardless of entry angle |
| **Teleporter** | Linked portal pair — beam warps between them |
| **Blocker** | Fixed obstacle that absorbs all beams |

---

## Enemies

| Enemy | Behavior |
|-------|----------|
| **Shadow Block** | Absorbs beams below its intensity threshold. Destroyed by a focused beam |
| **Chromatic Shade** | Absorbs all colors except its weakness. Destroyed by matching color |
| **Null Emitter** | Creates a 3×3 dead zone that cancels all light entering it |

---

## Getting Started

### Requirements
- [Godot 4.6+](https://godotengine.org/download/) (stable)

### Run the project
```bash
git clone https://github.com/yourusername/lumatical.git
```
Open the project in Godot 4.6 and press F5 (or the play button).

### Controls

| Input | Action |
|-------|--------|
| **[1]–[7]** | Select tool |
| **Left-click** | Place tool / toggle orientation |
| **Right-click** | Remove tool |
| **[R]** | Rotate / cycle tool |
| **[M]** | Mute audio |
| **[Enter]** | Advance to next puzzle / floor |

---

## Project Structure

```
lumatical/
├── scenes/
│   ├── MainMenu.tscn       # Title screen with beam-drawn logo
│   ├── PuzzleSelect.tscn   # Puzzle browser
│   ├── Main.tscn            # Core puzzle gameplay
│   ├── Roguelike.tscn       # Procedural roguelike mode
│   └── Editor.tscn          # Level editor
├── src/
│   ├── main.gd              # Game controller — 50 handcrafted puzzles
│   ├── main_menu.gd         # Title screen, navigation, beam text renderer
│   ├── puzzle_select.gd     # Puzzle selection screen
│   ├── roguelike.gd         # Roguelike mode with persistent inventory
│   ├── editor.gd            # Level editor controller
│   ├── editor_grid.gd       # Editor grid rendering
│   ├── grid.gd              # Grid state, rendering, and input
│   ├── beam_simulator.gd    # Core beam tracing engine (pure logic)
│   ├── beam_layer.gd        # Beam segment rendering with glow
│   ├── background.gd        # Animated background system
│   ├── audio_manager.gd     # Generative interaction audio
│   ├── puzzle_generator.gd  # Solution-first procedural generator
│   ├── puzzle_serializer.gd # JSON puzzle save/load
│   ├── run_manager.gd       # Leaderboards, seeds, share codes
│   └── tool_icons.gd        # Vector UI icon generator
├── docs/
│   └── ARCHITECTURE.md      # Internal docs for contributors
├── puzzles/                  # Exported puzzle JSON files
└── project.godot
```

---

## Architecture

The game follows the GDD's architectural principles:

- **BeamSimulator is pure logic** — no Node dependencies, shared by gameplay, editor, and generator
- **Solution-first generation** — puzzles are constructed from known solutions, never solved by AI
- **Programmatic assets** — all visuals are code-drawn (lines, circles, polygons), no texture files
- **Consistent tool format** — a single Dictionary format describes every game element, used everywhere

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full internal reference.

---

## Development Status

| Phase | Status |
|-------|--------|
| **Phase I — Foundation** (sim, grid, tools, 20 puzzles) | ✅ Complete |
| **Phase II — Depth** (enemies, editor, audio, polish) | ✅ Complete |
| **Phase III — Infinity** (roguelike, leaderboards, sharing) | ✅ Complete |
| **Phase IV — Polish** (accessibility, mobile, localization) | 🔲 Not started |

### Stats
- **15 GDScript files** (~5,500 lines)
- **5 scenes**
- **50 handcrafted puzzles**
- **8 tools, 3 enemy types**
- **0 external assets** (everything is programmatic)

---

## License

MIT

---

*Lumatical — Game Design Document v0.1*
