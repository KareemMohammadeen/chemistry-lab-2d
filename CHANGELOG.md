# Changelog

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
