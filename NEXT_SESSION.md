# Next Session

1. Open branch feature/chemistry-engine-v2 in Godot 4.3+ and import the project.
2. Verify the 118 sample tokens: Fe/Cu cubes with symbols, sulfur/phosphorus powder forms, magnesium ribbon, liquid drops, sealed gas display cylinders, and conceptual unknown-state atoms. Confirm they pan/zoom with the infinite workbench and remain non-reactive.
3. Drag the virtual carbon-dioxide Library card onto a vessel; verify automatic stopper, retained gas, pressure row and gas content in the Inspector.
4. Verify that liquid/solid additions and pouring are refused while closed; use Return to open system, then retry. Check Undo/Redo for gas add and open/close state.
5. Save a closed vessel session, change the scene, and reopen it; check gas amount, trapped air, closed state and pressure are restored. Verify invalid gas ledgers are rejected without replacing the live session.
6. Open Safe experiment bank and select each of Prep 1, Prep 2, Prep 3, Senior 1 and Senior 2. Verify evidence-status labels. Select a vessel and run the magnesium observation-only model; check white flash, white MgO illustration, Experiment Log and Undo.
7. Run all validators and Godot headless scenarios from docs/TESTING.md.
8. Check the normal water + salt, copper sulfate dissolution, neutralisation, heating, pouring and session regression flows.

Key entry points: scripts/simulation/vessel_state.gd, scripts/chemistry/reaction_engine.gd, scripts/simulation/session_store.gd, scripts/ui/element_visual.gd, scripts/ui/lab_workspace.gd, scripts/ui/experiment_catalog.gd.

Important: static checks and the GitHub Godot workflow must pass before considering the implementation verified. In-engine drag/pan/zoom, the stopper/flash visuals, and UI layout still require manual inspection.
