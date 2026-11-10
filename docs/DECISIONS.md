# Decision Log

Format: ID - decision - reason - alternatives considered.

**D-001 (2026-11-07) snake_case file names, `docs/` folder.** Owner's final convention; overrides PascalCase and `documentation/` examples.

**D-002 Audio under `assets/audio/`.** The owner's latest layout nests audio with assets; keeps imported media together. Alternative: top-level `audio/` (earlier brief) - rejected for consistency with the latest layout.

**D-003 Interaction types are data, identified by `StringName` ids.** New interaction types need no code or enum change (extensibility rule). Alternative: a GDScript enum - rejected because every new type would modify shared code.

**D-004 Interaction is component-based (`Interactable` as a child node).** Composition over inheritance; any physics body can become interactable. Alternative: base class `InteractableBody` - rejected (forces inheritance on all equipment).

**D-005 `InteractionManager` is per actor, not an autoload.** Keeps it replaceable and supports multiple actors later (e.g. observer modes). Autoloads are reserved for truly global services.

**D-006 Controls are data (JSON -> `InputMap` at startup).** Satisfies "no hardcoded controls", enables rebinding and new devices without editing project.godot. Alternative: static InputMap entries in project.godot - rejected as harder to extend and edit programmatically.

**D-007 JSON for early data files.** Simple, diff-friendly, trivial to validate. Chemicals may move to Godot Resources in Milestone 4/8 if editor tooling is wanted; `JsonDataLoader` keeps loading in one place.

**D-008 Deferred systems.** Save, inventory, tools, experiments, tutorials and the educational database are not scaffolded in Milestone 1: empty stubs would violate the no-placeholder rule. They arrive with the milestones that need them (see TODO.md).

**D-009 No `class_name` on autoloads.** Godot reports an error when a global class hides an autoload singleton.

**D-010 Static validator instead of an in-repo Godot dependency.** No engine was available in the build environment; `tests/validate_project.py` catches broken references, scene-tree and NodePath errors, indentation and naming problems. It does not replace running the project.

**D-011 `supported_interactions` typed as `Array[StringName]`.** Zero parse risk and fully data-compatible; trade-off is no inspector dropdown. Revisit in TODO.

**D-012 (2026-11-07) Chemistry data foundation precedes liquid simulation.** Viscosity, density and phase points are needed from Milestone 4 onward, so the substance schema, `ChemicalDatabase` loader and periodic table are built as the first step of Milestone 4 (not earlier: Milestone 3 equipment must not depend on substances; it exposes a generic container interface). Alternative: a separate milestone - rejected to keep the agreed 12-milestone order.

**D-013 Data provenance and uncertainty.** Every element/compound value records its source and whether it is measured, predicted or unknown (many superheavy-element properties are only predicted). Missing values are `null`, never guessed. Scientific accuracy has priority, and the 118-element table will be built from a vetted reference rather than written from memory.

**D-014 Single phase-resolution function.** Substance + temperature + pressure -> state of matter lives in one place (heat/state logic), used by heating, cooling, liquids and the reaction engine. Initial fidelity: pure substances at fixed pressure; solutions (freezing-point depression, boiling-point elevation), supercooling and pressure effects are documented extensions.

**D-015 Equipment is data-defined where possible.** Glassware shares one container component; capacity, graduations, openings and material come from data. Equipment-specific behavior (burette tap, centrifuge spin, condenser flow) is a separate small component, never a copy of container logic. Milestone 3 is delivered in sub-phases (see MILESTONES.md).

**D-016 Education levels are tags, not code paths.** `education_levels` on substances, equipment and experiments; UI shows simple or advanced readouts via a setting. The simulation never forks per level.

**D-017 (2026-11-07, PROPOSED) Direction change to a 2D teacher-controlled demonstration simulator.** Owner statement supersedes the earlier 3D/first-person presentation. Full analysis and proposed changes (presentation-agnostic core, pointer interaction, interaction context, drop zones, command layer, simulation clock, state-driven animation) in `docs/DIRECTION_REVIEW.md`. Not accepted until the owner answers its open questions; nothing was implemented or deleted.

**D-014 (2026-11-08) Strictly 2D.** Accepted (supersedes the 3D scenes of the first prototype, see DIRECTION_REVIEW.md as D-017). A fixed front view with pointer interaction; 3D, first-person and VR are out of scope.

**D-015 Simulation core is presentation-independent.** `RefCounted` classes, no nodes; one `SimulationHost` node drives it. Makes headless tests, replay and reports possible and keeps views replaceable.

**D-016 Undo by full-state snapshots.** Chemistry is not reversible by inverse operations (dissolution progress, heat released). The state is small, so snapshots are cheap and exactly correct. Alternative: inverse commands, rejected.

**D-018 Views draw with `_draw()` instead of sprites.** No art assets exist yet; a vessel profile drives outline, liquid level (integrated w squared) and graduations from data. Sprites can replace views later without touching the simulation.

**D-019 Commands carry an `InteractionContext`.** (source, target, interaction_id, pointer, payload, time) is the single input to every command and is logged, which prepares replay, undo and lab reports.

**D-020 Aspect `keep`, reference 1920x1080.** Fixed-size front-view art and layout data in pixels; letterboxing is predictable. Revisit for tablets.

**D-021 Reaction results come only from data plus the engine.** Dissolution, neutralisation and boiling are defined in `data/reactions`; equipment and UI contain no chemical rules.

**D-022 Provenance on values.** Numeric content carries a status. The validator reports how many `placeholder` values remain.
