# TODO

## Blocking
- [ ] Verify Glassware Rendering V2 in Godot for the beaker, test tube, Erlenmeyer flask, reagent bottle and dropper; check empty/filled/solid states and confirm no reflection or material grain escapes the glass profile.
- [ ] Verify drag/drop visual polish in Godot: lift/scale/lean, ground shadow, valid/invalid target colours, surface previews and an inserted thermometer moving with its vessel.
- [ ] Open in Godot 4.3+, run `scenes/main.tscn`, work through the checklist in `docs/TESTING.md`, fix what it finds.
- [ ] Run `tests/run_simulation_tests.gd` headless and fix failures.
- [ ] Review every `placeholder` / `unverified_reference` value (CuSO4 solubility conversion, time constants, heater rates, glass mass).

## Database follow-ups
- [ ] Verify element values against a primary source (NIST/IUPAC); replace the Engineering ToolBox extraction.
- [ ] Oxidation states, appearance and hazards for every element; subshell-level checks for 104-118.
- [ ] Make more compounds playable (colour, solubility curve, reactions) and an in-app periodic table / compound browser.
- [ ] Executable reaction data (precipitation, acid-carbonate, displacement) for the ReactionEngine.

## Milestone 2 candidates
- [ ] Graduated pipette/dropper behaviour (drop-wise addition), stirring rod, spatula and balance.
- [ ] Remaining apparatus: graduated cylinder, burette, funnel, filter; pH indicator and pH meter.
- [ ] Right-click context menu and double-click actions; touch gestures (long press).
- [ ] Save/load experiments (the state is already serialisable) and a lab report from the command history.
- [ ] Replay from the command history.
- [ ] Sound effects (`assets/audio`), glass sprites or shaders (`assets/sprites`, `assets/effects`).
- [ ] Teacher/student modes and guided experiments.
