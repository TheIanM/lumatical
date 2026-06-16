# Task List — Persistent Tool Inventory for Roguelike

## Goal
Replace per-puzzle budgets with a persistent tool inventory across the
entire run. Running out of tools = run ends.

## Design
- Player starts with a small inventory (e.g., 4 mirrors, 1 prism)
- Each floor generates a puzzle solvable with tools from the inventory
- After solving, pick 1 of 3 random tool rewards
- If generated puzzle requires tools the player doesn't have → regenerate
- If puzzle is unsolvable with remaining inventory → run over

## Flow
1. Start run → inventory = {mirror: 4, prism: 1}
2. Generate floor → puzzle needs ≤ inventory
3. Player places tools from inventory (spent tools are consumed on solve)
4. Solve → reward screen (pick 1 of 3)
5. Next floor with updated inventory
6. If can't generate a solvable puzzle → "Run Over" screen

## Steps
1. Add inventory to Roguelike + pass to Grid
2. Update PuzzleGenerator to respect inventory constraints
3. Add reward screen between floors
4. Add run-end condition
5. Test

## Status
- [ ] Inventory system
- [ ] Generator constraints
- [ ] Reward screen
- [ ] Run-end condition
- [ ] Test
