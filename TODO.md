# TODO

## Blocking
- [ ] Verify drag/drop visual polish and infinite-workbench pan/zoom in Godot: lift/scale/lean, ground shadow, valid/invalid target colours, surface previews and an inserted thermometer moving with its vessel.
- [ ] Open in Godot 4.3+, run `scenes/main.tscn`, work through the checklist in `docs/TESTING.md`, fix what it finds.
- [ ] Run `tests/run_simulation_tests.gd` headless and fix failures.
- [ ] Review every `placeholder` / `unverified_reference` value (CuSO4 solubility conversion, time constants, heater rates, glass mass).
- [ ] Add an explicit specimen model for materials so elements become lab samples instead of cards only: Fe cube, Cu cube, Mg ribbon, powders, liquids, gas cylinders, etc.
- [ ] Add open/closed vessel state transitions for gases: automatic gas detection, stopper/cap handling, pressure tracking, and gas collection without leakage.
- [ ] Make the reaction engine fully generic and data-driven so new reactions can be added from data files without writing new GDScript each time.
- [ ] Add the remaining supported apparatus: graduated pipette/dropper, stirring rod, spatula, analytical balance, graduated cylinder, burette, funnel, filter setup, pH meter, thermometer, watch glass, crucible and related accessories.
- [ ] Add guided experiments that walk the user step-by-step through school lab activities instead of leaving everything as free sandbox only.
- [ ] Add replay from command history so a finished experiment can be played back like a timeline.
- [ ] Add experiment report export (at least Markdown; PDF later if needed) with materials, steps, observations, equation and conclusion.
- [ ] Add teacher/student/sandbox modes and restrictions so the project can be used safely in class.
- [ ] Finish the higher-quality visual effects pass: glass highlights, glow, bubbles, smoke, precipitation, flame, flashes, and better liquid motion.
- [ ] Add right-click actions, double-click shortcuts, and touch gestures (long press / tap-and-drag).

## Database follow-ups
- [ ] Verify element values against a primary source (NIST/IUPAC); replace the Engineering ToolBox extraction.
- [ ] Oxidation states, appearance and hazards for every element; subshell-level checks for 104-118.
- [ ] Make more compounds playable (colour, solubility curve, reactions) and an in-app periodic table / compound browser.
- [ ] Audit and expand executable reaction data (precipitation, acid-carbonate, displacement) only after checking balanced equations, conditions, equilibrium/stoichiometry and safety/provenance; do not activate the 118 visual-only element tokens.
- [ ] Add curriculum-linked experiments for Prep 1, Prep 2, Prep 3, Senior 1 and Senior 2 with references to the school book / approved teaching source.
- [ ] Add the magnesium ribbon combustion demo with the bright white flash and white MgO product.
- [ ] Keep dangerous or non-school-safe reactions blocked unless there is a safe, explicit educational simulation design.

## Milestone 2 candidates
- [x] Drag equipment from the Library to create additional movable vessels and instruments.
- [x] Infinite pan-and-zoom workbench with free placement across the world plane.
- [x] Drag classroom water / sodium chloride cards onto a vessel to add measured virtual quantities.
- [ ] Graduated pipette/dropper behaviour (drop-wise addition), stirring rod, spatula and balance.
- [ ] Remaining apparatus: graduated cylinder, burette, funnel, filter; pH indicator and pH meter.
- [ ] Right-click context menu and double-click actions; touch gestures (long press).
- [x] Save/load validated experiment sessions (equipment state, vessel contents, temperatures, observations and action history).
- [x] In-app Experiment Log for accepted/refused actions and recorded observations.
- [ ] Replay from the command history.
- [x] Optional, muteable procedural feedback sounds for actions and observations.
- [ ] Glass sprites or shaders (`assets/sprites`, `assets/effects`).
- [ ] Teacher/student modes and guided experiments.
