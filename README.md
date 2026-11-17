# Chemistry Lab

A calm, 2D educational chemistry laboratory with a pan-and-zoom infinite workbench. Drag glassware and classroom reagents,
pour, mix, heat, and read what happened in the Inspector.
Godot 4.3+, GDScript, Compatibility renderer. **Milestone 1: functional 2D laboratory prototype.**

## Open and run
1. Open the folder in Godot 4.3 or newer (`project.godot`). On first open Godot builds its class cache;
   if the Output panel reports unknown class names, choose **Project > Reload Current Project** once.
2. Press **F5**. The main scene is `scenes/main.tscn`.

## First demo: water + table salt (classroom-safe virtual scenario)
1. Choose **Start Classroom Demo** on the welcome screen.
2. Drag a fresh **Beaker 250 mL** card from the Library onto the workbench.
3. Drag **Water** onto the beaker to add 50 mL directly; drag **Sodium chloride** onto it to add 5 g.
4. Select the beaker and press **Mix** in the Inspector to start stirring and observe the dissolution model.
5. You can also drag a reagent card onto empty space to create a refillable virtual bottle, then pour from it.
6. Open **Teacher Guide** to see learning goals, suggested grade preview, model limitations and sources.

The application demo is a software-only educational model. It is not a set of instructions for real laboratory work.

## Screen layout
The rebuilt **Studio Workbench** uses a compact command header, a left materials dock, a central infinite workbench, and a contextual Inspector on the right. The dark resin finish and measurement grid continue as you pan across the work surface. Use the middle mouse button to pan, the wheel or − / + buttons to zoom, and Center or Home to return to the starting view. The Library can be collapsed on smaller windows.

## Controls
| Action | Input |
|--------|-------|
| Select / inspect | Click an object (right click also selects) |
| Pick up and move | Drag an object anywhere on the infinite workbench |
| Add equipment or reagents | Drag an equipment card to spawn it; drag water / table salt onto a vessel to add it |
| Pour with the Inspector | Select a vessel, press **Pour**, click the target vessel |
| Mix | Select a vessel containing liquid and press **Mix** in the Inspector |
| Pan / zoom | Middle-mouse drag / wheel; use −, +, Center or Home for view controls |
| Undo / redo | Ctrl+Z / Ctrl+Y or the top bar |
| Deselect / cancel | Esc |
| Pause simulated time | Space or the top bar (speeds 1x, 2x, 4x) |

Every refused action shows its reason at the bottom of the screen. Object creation and reagent additions are undoable commands. The classroom Library exposes only water and sodium chloride as playable materials; the 118 periodic-table entries remain visual references.

## Infinite workbench and Library drag/drop
The central work surface extends in every direction while keeping the laboratory's dark resin finish and measurement grid. Pan with the middle mouse button, zoom with the wheel or the − / + controls, and press Home or Center to return to the starting view. The Library can create additional movable glassware and instruments: drag an equipment card onto the workbench. Drag Water or Sodium chloride onto a vessel to add a classroom quantity directly; drag a reagent card onto open space to create a refillable virtual bottle. Select a vessel and press **Mix** in the Inspector to start stirring.

The 118 periodic-table entries remain read-only visual references, not reactive reagents. The new direct-add interaction is limited to the classroom water and table-salt materials.

## Session tools
The **Session** menu in the top bar can save the current virtual-lab state to a JSON session file, reopen a validated session, show the chronological Experiment Log, and toggle optional feedback sounds. Session files contain the simulation clock, equipment positions and contents, vessel temperatures, observations, and the command log. They do not include visual-only periodic-table specimen cards or pinned reference badges; those remain catalogue aids, not part of the chemistry simulation.

The Reaction Engine currently models the documented processes in `data/reactions`: dissolution of sodium chloride and copper sulfate pentahydrate, strong acid/base neutralisation, and water boiling. It does not simulate arbitrary element pairs. The 118 periodic-table specimens remain visual-only and cannot be mixed, heated or reacted.

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

The Periodic Table displays all 118 elements in an 18-column layout with search and a detail inspector. Every tile can be dragged onto the workbench to create a movable, procedurally drawn 2D specimen: solid metals appear as metallic blocks, solid non-metals/metalloids as crystal or mineral forms, gases as diatomic molecules or monatomic particles, and liquids as contained drop models. Elements whose bulk state is unknown or only predicted are shown as conceptual atom models rather than invented physical samples. Elements with recorded hazards or radioactivity receive a sealed virtual-display frame. **All 118 specimens are visual learning models only: none can be mixed, heated or reacted.** The guided classroom simulation remains limited to its approved classroom materials.

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

## Expanded safe curriculum content
Teacher Mode now includes a broader, safe learning guide covering matter, solutions, mixtures, state changes,
conservation reasoning, simple biology connections and model-evaluation prompts for Prep 1 through Senior 2.
These additions are classroom-only references and do not turn hazardous substances into executable real-world procedures.
