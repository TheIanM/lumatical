# Task List — Leaderboards, Seeded Runs, and Share Codes

## Goal
Add daily seeded runs, local leaderboard persistence, and share codes
that encode the run seed.

## Design
- **Seed**: integer that drives PuzzleGenerator deterministically.
  Daily run seed = hash of today's date. Share code = seed encoded as
  6-character base36 string.
- **RunManager**: singleton that persists scores to user://leaderboard.json,
  generates daily seeds, and encodes/decodes share codes.
- **Roguelike modes**: endless (random), daily (seeded), shared (from code).
- **Leaderboard**: top 10 scores with mode, floor, date. Shown on menu.

## Steps
1. PuzzleGenerator: accept seed param
2. RunManager: score persistence + share codes + daily seeds
3. Roguelike: accept mode + seed, track and submit score
4. Menu: daily run + share code entry + leaderboard screen
5. Test

## Status
- [x] PuzzleGenerator seeded generation
- [x] RunManager
- [x] Roguelike mode support
- [x] Menu UI
- [x] Test
