# Next Session

1. Open branch `codex/infinite-workbench-equipment-spawn` in Godot 4.3+ and reload the project once if class names are unknown.
2. Verify Library drag-and-drop: spawn extra beakers / flasks / instruments; add water and sodium chloride directly to vessels; create stock bottles by dropping a reagent onto open space.
3. Verify the Inspector Mix action starts stirring and accelerates the documented dissolution simulation.
4. Exercise the infinite workbench: middle-mouse pan, wheel zoom around the cursor, zoom buttons, Center / Home, and object placement far beyond the original canvas bounds.
5. Run `python3 tests/validate_project.py`, `python3 tests/validate_curriculum.py`, `python3 tests/validate_teacher_demo.py`, and `godot --headless --path . -s tests/run_simulation_tests.gd`.
6. Confirm undo/redo, session save/load, pouring, heating, reference-only periodic-table tokens, and the existing safety boundary still behave as expected.

Key entry points: `scripts/interaction/interaction_controller.gd`, `scripts/ui/lab_workspace.gd`, `scripts/ui/library_card.gd`, `scripts/simulation/commands/spawn_object_command.gd`, `scripts/simulation/commands/add_reagent_command.gd`.

**Important:** the new controls and scenes have not yet been opened or tested in the Godot engine.