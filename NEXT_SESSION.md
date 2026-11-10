# Next Session

1. Open branch `codex/drag-drop-visual-polish` in Godot 4.3+. If class names are unknown, reload the project once.
2. Run `scenes/main.tscn` and verify the drag lift, scale, lean, detached shadow, green/red target previews and active shelf/bench drop-zone feedback.
3. Drag a vessel containing a thermometer; confirm the thermometer remains visually attached while the vessel is lifted and moved.
4. Work through the rest of the in-engine checklist in `docs/TESTING.md`; note every error or visual problem.
5. Run `python3 tests/validate_project.py` and `godot --headless --path . -s tests/run_simulation_tests.gd`; fix any failures.
6. Confirm the project still preserves the existing refusal messages, command validation, pour stream and undo/redo behaviour.

Key entry points: `scripts/interaction/interaction_controller.gd`, `scripts/ui/lab_workspace.gd`, `scripts/ui/equipment_view.gd`, `scripts/chemistry/reaction_engine.gd`.

**Important:** the drag/drop visual changes have not yet been opened or tested in the Godot engine.
