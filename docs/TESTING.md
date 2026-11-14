# Testing

## 1. Static validator (no engine needed)
```
python3 tests/validate_project.py
```
Checks `res://` references, snake_case names, scene resource/NodePath consistency, that every node-typed `@export`
is assigned in its scene, tab indentation, bracket balance, unique `class_name`, autoload conflicts, unknown class
names, risky `:=` inference from Variant values, JSON validity and data cross-references (equipment interactions,
setups, reactions, profile ordering, interaction points). Expected: 0 errors; one informational warning about
placeholder data. Run it before ending every session.

## 2. Headless scenario tests (needs Godot 4.3+)
```
godot --headless --path . --import
godot --headless --path . -s tests/run_simulation_tests.gd
```
Drives the real commands: setup, refused actions and their reasons, the water + copper sulfate demo (blue solution,
observations, inspector content), undo/redo, neutralisation (pH, heat), heating with the hot plate and thermometer,
conservation of dissolved salt when pouring, and session save/load including invalid-file refusal and log restoration.
Exit code 0 means all checks passed.

## 3. In-engine checklist (not yet performed)
- [ ] Project opens with no script errors in Output / Debugger (reload once if class names are unknown).
- [ ] F5 shows wall, two shelves with 5 bottles and glassware, the bench with the hot plate, top bar and Inspector.
- [ ] Hover highlights objects; click selects with corner brackets and fills the Inspector.
- [ ] Drag feedback eases the object upward with a slight scale/lean change and leaves a soft shadow on the surface below.
- [ ] While dragging, valid drop targets/surfaces glow green and refused targets glow red; the preview changes as the pointer moves.
- [ ] Drag the beaker to the bench; dropping outside the shelves/bench shows a reason and the beaker returns.
- [ ] Drag the Water bottle onto the beaker: tilt, stream, level rises smoothly; Inspector shows 50 mL (default amount).
- [ ] Drag the CuSO4 bottle onto the beaker: grains fall, crystals dissolve, water turns blue, a toast and the Inspector explain it.
- [ ] Change the amount in the Inspector and pour again; pour more than fits and read the message.
- [ ] Drag the beaker onto the hot plate, select the plate, Switch on; temperature rises; "HOT" label appears above 60 degC.
- [ ] Put the thermometer into the beaker (drop it on the beaker); it follows the beaker when moved and reads its temperature.
- [ ] Pour acid and base into the flask: pH about 7 and a small warming.
- [ ] Ctrl+Z / Ctrl+Y and the buttons; Reset bench; Space pauses; 2x and 4x speed.
- [ ] Resize the window (16:9 and 4:3): the scene letterboxes and the Inspector stays readable.
- [ ] Open **Session**: Save an experiment, change the bench, then reopen the saved file; check positions, contents, temperatures and observations are restored.
- [ ] Open **Experiment Log**: confirm accepted and refused commands plus chemistry observations appear in time order.
- [ ] Toggle **Sound effects** off and on; confirm no sounds play while muted and actions still work.
Record results in CHANGELOG.md.


## 4. Curriculum and element reference data
Run:
```
python3 tests/validate_curriculum.py
```
Checks the five requested grade profiles, source references, Senior 1 Integrated Science status,
Senior 2 pathway uncertainty, and all 118 element reference records. This does not validate
chemical reactions or imply that periodic-table entries are usable reagents.

## 5. Teacher demo data validation
Run:
```
python3 tests/validate_teacher_demo.py
```
Checks that all five grade profiles have an evidence-labelled preview, that teacher preview materials and equipment IDs
are known, that the classroom demo setup only contains water and sodium chloride, and that the learning guide references
the expected scientific/safety and Ministry source catalogue.

## 6. Curriculum source review status
- Prep 1–3: current grade books must be checked individually before importing unit-level topics.
- Senior 1: Integrated Science is confirmed by the Ministry statement dated 2026-09-01.
- Senior 2: do not infer one chemistry map without selecting General Secondary or the Egyptian Baccalaureate pathway.
- The application currently labels the selected grade and evidence status; lesson-level mapping remains pending until the exact official books are reviewed.
