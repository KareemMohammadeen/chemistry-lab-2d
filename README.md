# Chemistry Lab

A calm, 2D educational chemistry laboratory in a fixed front view. Drag bottles and glassware with the
mouse (touch-ready architecture), pour, mix, heat, and read what happened in the Inspector.
Godot 4.3+, GDScript, Compatibility renderer. **Milestone 1: functional 2D laboratory prototype.**

## Open and run
1. Open the folder in Godot 4.3 or newer (`project.godot`). On first open Godot builds its class cache;
   if the Output panel reports unknown class names, choose **Project > Reload Current Project** once.
2. Press **F5**. The main scene is `scenes/main.tscn`.

## First demo: water + copper sulfate
1. Click the beaker on the lower shelf, then drag it onto the bench.
2. Drag the **Water** bottle (upper shelf) onto the beaker: water is poured (set the amount in the Inspector first).
3. Drag the **CuSO4** bottle onto the beaker: crystals are added, dissolve over a few seconds, and the water turns blue.
4. Click the beaker: the Inspector lists contents, temperature, pH, and explains each observation.

Other things to try: drag a beaker onto the hot plate, select the plate and switch it on, put the thermometer
into the beaker; pour acid and base together and watch the temperature and pH; Ctrl+Z / Ctrl+Y undo and redo.

## Screen layout
Top bar (library toggle, title, lab time, undo/redo, reset, pause and speed) over three areas: **Library** on the left (the five
playable reagents and the equipment; click a card to select it), the **laboratory** in the centre (scaled to fit) and the
**Inspector** on the right. The Library hides itself on narrow windows; use the first toolbar button to show it.

## Controls
| Action | Input |
|--------|-------|
| Select / inspect | Click an object (right click also selects) |
| Pick up, move, place, pour | Drag an object; drop on a shelf, the bench, the hot plate, or on another vessel |
| Pour with the Inspector | Select a vessel, press **Pour**, click the target vessel |
| Undo / redo | Ctrl+Z / Ctrl+Y or the top bar |
| Deselect / cancel | Esc |
| Pause simulated time | Space or the top bar (speeds 1x, 2x, 4x) |

Every refused action shows its reason at the bottom of the screen.

## Tests
- Static (no engine): `python3 tests/validate_project.py`
- Simulation scenarios (needs Godot, headless):
  `godot --headless --path . --import` once, then `godot --headless --path . -s tests/run_simulation_tests.gd`
- See `docs/TESTING.md`.

## Reference data
`data/elements` (118 elements) and `data/compounds` (38 compounds) with provenance on every value: see `docs/CHEMICAL_DATABASE.md`.

## Where things are
`scripts/simulation` (truth: state, commands, heat), `scripts/chemistry` (engine, acid/base, appearance),
`scripts/interaction` (pointer to commands), `scripts/ui` (views, inspector), `data/` (all content as JSON),
`scenes/`, `docs/`. Start with `docs/ARCHITECTURE.md` and `PROJECT_CONTEXT.md`.

## Status
Written without access to a Godot binary: everything has been statically checked but **not yet run in the engine**.
See `NEXT_SESSION.md` for the in-engine checklist. Many numeric values are marked `placeholder` in the data and
must be reviewed before teaching use (`docs/CHEMISTRY_REQUIREMENTS.md`).
