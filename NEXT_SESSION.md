# Next Session

1. Open the project in Godot 4.3+. If class names are unknown, reload the project once.
2. Run the main scene and the in-engine checklist in `docs/TESTING.md`; note every error and visual problem.
3. Run `godot --headless --path . -s tests/run_simulation_tests.gd` and fix failing checks.
4. Likely first problems (I could not run Godot): type-inference errors on `:=` from Variant values, a scene
   property typo, drag/drop target feel (support zone sizes in `data/equipment/hot_plate_basic.json`),
   Inspector layout at 1280x720.
5. Then pick from `TODO.md` (Milestone 2 candidates).

Key entry points: `scripts/core/main.gd` (composition), `scripts/simulation/simulation_host.gd`,
`scripts/interaction/interaction_controller.gd`, `scripts/chemistry/reaction_engine.gd`.
