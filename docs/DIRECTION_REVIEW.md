# Direction Review: 2D Teacher-Controlled Demonstration Simulator

**Date:** 2026-11-07 - **Status:** ACCEPTED on 2026-11-08 (D-014). The 2D rebuild is Milestone 1; this review is kept for history.
**Trigger:** owner stated the project is a 2D teacher-controlled simulation, not a first-person game, built around
drag-and-drop laboratory demonstrations and realistic scientific animation.

**Important:** every brief received before this review describes a *3D* laboratory, and Milestone 1 was built that way
(first-person player, 3D room). No document describing the 2D direction has been provided. This review therefore treats
the owner's statement as the new requirement and the earlier "3D" wording as superseded for presentation only.

## Verdicts

| Question | Verdict today | Why |
|----------|---------------|-----|
| Is the project no longer designed as a first-person game? | **No** | The only gameplay-facing code is first-person: `PlayerController` (CharacterBody3D, captured mouse), `Interactor` (RayCast3D from a camera), 3D room and bench scenes, 3D collision layers, `main.tscn` as Node3D. |
| Does the architecture support drag-and-drop demonstrations? | **Not yet** | The interaction model is *focus + key press* ("look at object, press E"). Drag and drop is *pointer press, move, release over a drop target* with validation and previews. `drag`/`drop` exist only as names in `interaction_types.json` mapped to the `interact` key. |
| Can the chemistry/material system integrate with interaction? | **Yes, with one change** | The seam is right (interaction announces intent, systems decide outcomes; the planned reaction/phase systems are renderer-agnostic). But `Interactable.interaction_performed(interaction_id, actor)` has no *source / target / payload*. Pouring A into B, adding a chemical, placing a flask on a hot plate all need two parties. |
| Can the animation system support realistic demonstrations? | **No system exists** | Milestone 1 has no animation, time-control or state-to-visual layer. Nothing prevents one; it must be designed before liquids/heating so visuals are driven by simulation state. |

## Inventory: what survives a 2D direction

**Renderer-agnostic, keep as is:** `EventBus`, `GameManager`, `SettingsManager`, `InputManager` (data-driven bindings), `AudioManager`
(`play_sfx`; `play_sfx_3d` becomes unused), `JsonDataLoader`, `InteractionRegistry`, `InteractionDefinition`, `InteractionResult`,
`GameState`, `InputActions`, `HudController` (already 2D UI), all data files, the validator, all documentation rules,
and the whole planned chemistry/equipment *data* layer (substances, periodic table, phase resolution, reaction engine).

**Tied to 3D / first-person, to be replaced by 2D equivalents:** `PlayerController` + `player.tscn`, `Interactor` (RayCast3D),
`Interactable` (requires a `CollisionObject3D` parent), `InteractionHighlighter` (MeshInstance3D), `CollisionLayers` (3D layers),
`main_scene.gd` / `main.tscn`, every scene in `scenes/laboratory` and `scenes/environments`, the interaction test scene, `play_sfx_3d`.
`InteractionManager` is logic-agnostic but is typed to `Interactor`, so it needs an abstraction.

## Required architectural changes (proposed)

1. **Presentation-agnostic simulation core.** Chemistry, containers, temperature and reactions are plain data/logic objects
   (no nodes). Views (2D now, anything later) read them. This also keeps a 3D or VR view possible and makes the core testable
   without rendering.
2. **Pointer-driven interaction.** Replace the focus provider: a `PointerInteractor` (mouse, touch, pen, interactive whiteboard)
   emits the same `focus_changed` concept plus `drag_started / drag_moved / drag_released`. Introduce an interface-like base
   (`InteractionSource`) so `InteractionManager` does not depend on a specific detector.
3. **2D `Interactable`.** Target `CollisionObject2D` or `Control`; keep the dimension-specific part in a small adapter so the
   component API (supported interactions, enabled, reasons) stays unchanged.
4. **Interaction context object.** `InteractionContext { interaction_id, actor, source, target, pointer_position, payload }`
   replaces the `(id, actor)` signal arguments. Drag and drop is then `drop` with `source` and `target`; `can_interact`
   becomes `can_drop(source, target)` style validation returning a reason ("the flask does not fit on the stand").
5. **Interaction modes in data** (`instant`, `hold`, `toggle`, `drag`) in `interaction_types.json` (already planned for M2).
6. **Drop targets and snap zones as components** (`DropZone`): accepted equipment types, capacity, snap point, preview state,
   so stands, hot plates, balances and racks need no special code.
7. **Teacher control model.** There is no avatar. The *teacher* is the operator and the "actor" is a demonstration controller:
   - **Command layer:** every state change is a command (add substance, pour, place, set temperature) giving undo/redo,
     reset, replay and scripted demonstrations.
   - **Simulation clock:** a central clock with pause, step and speed scaling (slow motion, time-lapse for slow processes).
   - **Demonstration state:** save/restore a bench setup (links to the future save system).
   - **Presentation needs:** large readable UI, projector contrast, scalable UI (accessibility setting already exists),
     optional student view / second display later.
8. **Animation architecture.** Visuals are bound to simulation state, not scripted independently:
   - *Model -> view bindings:* liquid level and color, temperature glow, bubbling rate, vapor and condensation read the substance state.
   - *Tool kit (Godot 2D):* shaders for liquids and refraction, `GPUParticles2D` for bubbles/steam/smoke, `AnimationPlayer`/tweens for
     equipment motion (pouring tilt, burette tap, centrifuge spin), all timed by the simulation clock so slow motion and pause work.
   - *Data-driven effects:* effect ids in substance/reaction data map to reusable effect scenes (continues the existing effects rule).
9. **Input and audio.** Pointer/touch bindings added to the data-driven `InputManager`; the Escape/mouse-capture logic goes away.
   `AudioManager.play_sfx_3d` stays unused or becomes a positional-pan helper for 2D.
10. **Camera.** No first-person camera. A 2D bench view (optional zoom/pan, focus on an apparatus) replaces it.

## Impact on the milestone plan (proposal)

Insert **Milestone 1.5: 2D foundation migration** before Milestone 2:
convert main scene to a 2D bench; add `PointerInteractor`, 2D `Interactable`, `InteractionContext`, `DropZone`;
retire first-person code (mark deprecated, remove only after the new path is verified); add `SimulationClock` skeleton and the
command-layer interface; update validator and test scene. Milestone 2 then becomes "drag-and-drop interaction system".
Milestones 3-12 keep their order; Milestone 3 equipment becomes 2D scenes (sprites/vector art, drop zones, data-defined containers).
No files are deleted until the migration is verified.

## Open questions (need owner confirmation before implementation)
1. Is the presentation **pure 2D** (side-view bench with Godot 2D nodes), or 2D with some 3D-rendered elements?
2. Is the first-person 3D lab foundation to be **retired** (my recommendation, after the 2D path works)?
3. Which input devices must work for the teacher: mouse only, or also touch / interactive whiteboard?
