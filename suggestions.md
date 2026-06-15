# Suggestions

Ideas noticed during development, not implemented to keep changes surgical.

## From prism/color work
- **Toolbelt UI**: The GDD describes a toolbelt at the bottom of the screen for
  drag-and-drop tool selection. Currently tool selection is keyboard-only (1/2).
  A proper toolbelt with clickable icons and budget counters would match the GDD
  vision and be more intuitive, especially for mobile.
- **`clear_mirrors()` is now a misnomer**: `Grid.clear_mirrors()` only clears
  mirrors, not prisms. It's currently unused (dead code). If needed later, rename
  to `clear_tools()` and clear both dictionaries.
- **Solve overlay color**: The overlay title is hardcoded green. Could use the
  dominant target color of the solved puzzle for a more thematic effect.
