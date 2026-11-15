## Chemistry Engine v2 foundations (2026-11-15) - awaiting Godot verification
- Reworked vessel state to keep an explicit virtual-gas ledger, closed/open-system flag and trapped-air amount; pressure is estimated with a simplified ideal-gas model using the remaining headspace.
- Added a pressure guard at both command validation and the ReactionEngine gas-product entry point. Gas addition to an open vessel automatically seals it; liquid/solid additions and pours are rejected while sealed; a reversible Inspector action returns the model to open and clears retained gas.
- Added session serialization and validation for gas amounts, closed-state consistency, trapped air and calculated pressure. Legacy sessions remain readable through safe defaults.
- Reworked the 118 periodic-table tokens as compact movable sample figures on the infinite workbench: labelled metal cubes, selected powder/crystal forms, magnesium ribbon, liquid-drop and sealed gas-cylinder illustrations. The 118 remain visual-only and non-reactive.
- Added a separate opt-in virtual carbon-dioxide Library item; it is not a real gas-handling feature.
- Added a qualitative, observation-only magnesium visual model with a brief white flash and an illustrative white MgO product. It is not a procedure and does not calculate a real yield.
- Added a Safe Experiment Bank window for all five grade profiles; the magnesium observation is suggested for Prep 2 but is not verified against the exact official textbook.
- Added headless regression coverage for gas auto-sealing, pressure, vent/undo/redo, session round-trip and the magnesium visual-demo state. Godot 4.3 CI/runtime results are pending.

# Changelog

## Infinite workbench and Library drag/drop (2026-11-14) - awaiting Godot verification
- Added an infinite, lab-styled work surface with a world-space grid, middle-mouse panning, cursor-anchored wheel zoom, zoom buttons, Center and Home reset.
- Library equipment cards can be dragged onto the stage to spawn additional movable glassware and instruments.
- Water and table-salt cards can be dragged onto a vessel to add classroom quantities directly, or onto open space to create a refillable virtual reagent bottle.
- Added validated, undoable spawn and reagent-add commands; existing Mix, pour, heating, reaction and session systems remain the simulation authority.
- Infinite placement accepts finite coordinates throughout the supported world range; reference-only periodic-table specimens remain non-reactive.
- Added headless scenarios for spawning, far-world placement, direct reagent additions, mixing, and undo/redo. Godot runtime verification is still required.

## Session persistence, experiment log and optional audio (2026-11-14) - awaiting Godot verification
- Added versioned JSON session save/load for the complete serialisable simulation state: simulation time, equipment locations, vessel contents, temperatures, observations and command history.
- Validate session format, version, object/equipment references, quantities, capacities and relationships before replacing the live simulation; invalid files leave the current lab state unchanged.
- Added a top-bar Session menu with Save experiment, Open experiment, Experiment log and a Sound effects toggle.
- Added a chronological Experiment Log for accepted/refused commands and vessel observations.
- Added short procedural, low-volume feedback tones for actions and observations; sound is optional and can be muted.
- Added headless round-trip and invalid-session regression checks; Godot 4.3 runtime/editor testing is still required.
- Periodic-table tokens remain visual-only and are not stored as chemical reagents. Existing reaction models remain limited to their documented data.

## Teacher presentation flow and classroom previews (2026-11-13) - awaiting Godot verification
- Added a polished welcome screen with separate Classroom Demo and Teacher Mode entry actions.
- Added grade-specific teacher preview cards for Prep 1, Prep 2, Prep 3, Senior 1 and Senior 2; each preview is explicitly labelled as suggested rather than verified against exact official unit order.
- Connected Teacher Mode to the selected grade, guide window, learning goals, virtual lesson flow and teacher discussion prompt.
- Added collapsible Inspector sections for properties, contents, observations and safety without changing simulation state or chemistry rules.
- Updated README to use the water + table-salt classroom scenario and point to the teacher presentation.
- Added a static teacher-demo validator and GitHub Actions static validation workflow.
- Added docs/TEACHER_PRESENTATION.md; final in-app screenshots still need to be captured after running the project in Godot.
- Godot runtime and visual checks have not been performed in this environment.


## Periodic table reference and curriculum selector (2026-11-12) - awaiting in-engine verification
- Exposed all 118 already-loaded elements in a read-only periodic-table reference grid.
- Element cards show only basic reference facts (atomic number, category, position, block and electron configuration); they do not create reagents or enable reactions.
- Added a data-driven Egyptian 2026-2027 grade selector for Prep 1, Prep 2, Prep 3, Senior 1 and Senior 2.
- Senior 1 is labelled Integrated Science based on the Ministry statement dated 2026-09-01.
- Senior 2 remains pathway-dependent until the applicable General Secondary or Egyptian Baccalaureate pathway is confirmed.
- Unit-level curriculum mapping remains explicitly pending review of each matching official textbook.
- Added a standalone validator for the five profiles and the 118-element reference records.
- Not run in Godot yet.

## Drag & drop visual polish (2026-11-10) - awaiting in-engine verification
- Dragged equipment now eases upward, scales slightly and leans subtly with horizontal pointer movement.
- Added a detached, soft contact shadow so the object visibly lifts from the bench or shelf.
- Drop surfaces show a restrained active-zone treatment; the hovered surface or equipment target previews green when its command validates and red when it is refused.
- Equipment inserted into a dragged vessel inherits the vessel's lift so it stays visually attached.
- Preview feedback calls command validation only; it does not execute commands or change simulation state.
- Not run in Godot yet; verify the visual states and existing drag/drop interactions in-engine.

## UI redesign, part 1 (2026-11-10) - unreleased
- Layout: three docked areas - Library (left), laboratory stage (centre), Inspector (right) - under a grouped top bar
  (library toggle, brand and experiment title, lab-time chip, undo/redo group, reset, pause + 1x/2x/4x group). All built with
  containers; panel widths follow the window width, the Library starts hidden on narrow windows and has a toggle.
- Stage: the laboratory is scaled and centred into the space between the panels (`LabWorkspace.fit_to_rect`); the 1920x1080 cabinet
  area is gone. Canvas is now 1240x900, a compact reagent rack, a glassware shelf and a deeper bench; the backdrop extends past the
  canvas so any window shape is filled. Stretch aspect is `expand`; `Main` raises the content scale so text never drops below 0.75.
- Library: playable reagents (the 5 loaded chemicals only, grouped by category, formula, state, stock) and equipment (grouped,
  with capacity, availability). Clicking a card selects the matching object. Reference elements/compounds are not listed.
- Inspector: header, empty state with tips, cards for actions, properties, contents, observations and safety, scrolling content.
- Design system: dark slate palette with teal/cyan accents and amber heat; `LabTheme` type variations (SidePanel, CardPanel,
  GroupPill, ToolButton, AccentButton, Title/Heading/Caption labels). Paper labels on bottles now fit their text (shrink, then wrap).
- Fixes: pointer position and hit-testing use laboratory-local coordinates (needed because the stage is scaled); the panel
  blocking test uses the screen position.
- Not run in the Godot engine.

## Polish and database pass (2026-11-08/09) - unreleased
- UI: shared theme (button hover/pressed/disabled/focus states, inputs, scrollbars, tooltips), SVG toolbar icons, pause/resume
  state, Inspector fade-in, minimum window size.
- Graphics: shaded glass with rims and highlights, liquid gradients and meniscus, convection and steam when hot, crystal speckles,
  bottle caps and label bands, rounded hot plate with knob and glow, shaded shelves/bench/cabinet, curved pour stream with ripples.
- Data: removed placeholder wording (safety text written per chemical, notes reworded); provenance statuses kept.
- Reference database: 118 elements and 38 compounds (see docs/CHEMICAL_DATABASE.md), `ElementDefinition`, `CompoundDefinition`,
  loaders in `ContentDatabase`, validator and headless-test checks, build scripts in `tools/`.
- Still not run in the Godot engine.

## Milestone 1 (2D prototype) - unreleased
- New 2D project (replaces the 3D first-person Milestone 1; the old ZIP is untouched).
- Simulation core: lab state, vessel ledger (liquids, solids, dissolved), fixed-step clock, heat system,
  command stack with snapshot undo/redo, seven commands (pick up, place, pour, add solid, mix, heat, insert via place).
- Chemistry: data-driven reaction engine (dissolution, strong acid/base neutralisation, boiling clamp),
  derived pH and solution colour, observations with explanations.
- Content: 5 chemicals, 7 equipment items, 4 reactions, shelf/bench layout, first-demo setup.
- Interaction: pointer controller (select, drag, drop, armed pour), reasons for every refusal.
- UI: `_draw()` equipment views, pour animation, Inspector panel, top bar, toasts.
- Tests: static validator (adapted), headless scenario test (`tests/run_simulation_tests.gd`).
- Not run in the Godot engine yet (no binary was available while building).
