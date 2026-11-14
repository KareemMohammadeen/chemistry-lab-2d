# TODO

## Blocking
- [ ] Verify drag/drop visual polish and infinite-workbench pan/zoom in Godot: lift/scale/lean, ground shadow, valid/invalid target colours, surface previews and an inserted thermometer moving with its vessel.
- [ ] Open in Godot 4.3+, run `scenes/main.tscn`, work through the checklist in `docs/TESTING.md`, fix what it finds.
- [ ] Run `tests/run_simulation_tests.gd` headless and fix failures.
- [ ] Review every `placeholder` / `unverified_reference` value (CuSO4 solubility conversion, time constants, heater rates, glass mass).

## Database follow-ups
- [ ] Verify element values against a primary source (NIST/IUPAC); replace the Engineering ToolBox extraction.
- [ ] Oxidation states, appearance and hazards for every element; subshell-level checks for 104-118.
- [ ] Make more compounds playable (colour, solubility curve, reactions) and an in-app periodic table / compound browser.
- [ ] Audit and expand executable reaction data (precipitation, acid-carbonate, displacement) only after checking balanced equations, conditions, equilibrium/stoichiometry and safety/provenance; do not activate the 118 visual-only element tokens.

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
