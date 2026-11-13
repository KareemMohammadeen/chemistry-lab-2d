# Chemistry Lab

A calm, 2D educational chemistry laboratory in a fixed front view. Drag bottles and glassware with the
mouse (touch-ready architecture), pour, mix, heat, and read what happened in the Inspector.
Godot 4.3+, GDScript, Compatibility renderer. **Milestone 1: functional 2D laboratory prototype.**

## Open and run
1. Open the folder in Godot 4.3 or newer (`project.godot`). On first open Godot builds its class cache;
   if the Output panel reports unknown class names, choose **Project > Reload Current Project** once.
2. Press **F5**. The main scene is `scenes/main.tscn`.

## First demo: water + table salt (classroom-safe virtual scenario)
1. Choose **Start Classroom Demo** on the welcome screen.
2. Select the beaker on the lower shelf and move it onto the bench.
3. Drag the **Water** bottle onto the beaker to add the virtual solvent.
4. Drag the **Sodium chloride** bottle onto the beaker to observe the model's dissolution behaviour.
5. Select the beaker and read the Inspector observations and explanations.
6. Open **Teacher Guide** to see learning goals, suggested grade preview, model limitations and sources.

The application demo is a software-only educational model. It is not a set of instructions for real laboratory work.

## Screen layout
The rebuilt **Studio Workbench** uses a compact command header, a left materials dock, a large framed live workbench in the centre, and a contextual Inspector on the right. The header keeps grade selection, simulation time, undo/redo, reset, pause/speed and the Teacher Guide together. The Library can be collapsed on smaller windows.

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

## Teacher Mode and curriculum preview
The welcome screen offers a Classroom Demo and Teacher Mode. The teacher guide includes evidence-labelled previews for Prep 1,
Prep 2, Prep 3, Senior 1 and Senior 2. Prep 1–3 unit-level alignment is still pending direct review of the matching official
2026–2027 textbooks. Senior 1 is represented as Integrated Science; Senior 2 remains pathway-dependent. Preview activities
are suggestions for using the software, not claims about official lesson order.

The Periodic Table now displays all 118 elements in an 18-column layout with search and a detail inspector. Every tile supports drag-and-drop onto the central workbench, where it creates a movable visual element token. A small, explicitly marked subset is labelled as a visual display sample; all remaining elements are marked reference-only. **These tokens are not chemical reagents and cannot be mixed, heated or reacted.** Only water and table salt are available in the guided classroom simulation.

Teachers can also pin elements, compounds and other catalogue entries from the Reference Explorer onto the workbench as movable study notes. Those badges are visual references only and do not mutate the simulation.

A separate safe experiment pack lives in `data/learning/expanded_safe_experiments.json` with grade mappings in
`data/curricula/egypt_2026_2027_safe_experiments.json`. These files collect classroom-safe experiment concepts for Prep 1,
Prep 2, Prep 3, Senior 1 and Senior 2 without adding hazardous real-world procedures.

## Where things are
`scripts/simulation` (truth: state, commands, heat), `scripts/chemistry` (engine, acid/base, appearance),
`scripts/interaction` (pointer to commands), `scripts/ui` (views, inspector), `data/` (all content as JSON),
`scenes/`, `docs/`. Start with `docs/ARCHITECTURE.md` and `PROJECT_CONTEXT.md`.

## Teacher presentation
See [docs/TEACHER_PRESENTATION.md](docs/TEACHER_PRESENTATION.md) for a concise teacher-facing project overview,
demo flow, curriculum evidence status and scientific sources.

## Status
Written without access to a Godot binary: everything has been statically checked but **not yet run in the engine**.
See `NEXT_SESSION.md` for the in-engine checklist. Many numeric values are marked `placeholder` in the data and
must be reviewed before teaching use (`docs/CHEMISTRY_REQUIREMENTS.md`).
