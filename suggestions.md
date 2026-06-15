# Suggestions

Ideas noticed during development, not implemented to keep changes surgical.

## From prism/color work
- ~~**Toolbelt UI**~~ ✅ Done — clickable toolbelt at the bottom of the screen
  with budget counters, color-coded buttons, active-tool highlighting, and
  keyboard shortcuts (1-4) retained as a power-user alternative.
- **`clear_mirrors()` is now a misnomer**: `Grid.clear_mirrors()` only clears
  mirrors, not prisms. It's currently unused (dead code). If needed later, rename
  to `clear_tools()` and clear all tool dictionaries.
- **Solve overlay color**: The overlay title is hardcoded green. Could use the
  dominant target color of the solved puzzle for a more thematic effect.
