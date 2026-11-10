# Project Context

**What:** a strictly 2D educational chemistry laboratory (fixed front camera; mouse, touch, drag and drop).
Calm, minimal, premium, student-friendly. Windows first; the interaction layer is pointer-based so tablets and
interactive whiteboards need no redesign. 3D, first-person, walking and VR are permanently out of scope.

**Engine:** Godot 4.3, GDScript, GL Compatibility. Reference canvas 1920x1080, stretch `canvas_items`, aspect `keep`.

**Architecture rules (non-negotiable)**
1. The simulation controls truth (`scripts/simulation`, `scripts/chemistry`). Animation only shows state.
2. UI and views contain no chemistry logic; they display dictionaries and objects prepared by the simulation
   (`ObjectInspector`) and send requests upward.
3. Equipment never decides chemical results. The `ReactionEngine` does, from data in `data/reactions`.
4. Everything the user does is a `LabCommand` built from an `InteractionContext`
   (source, target, interaction_id, pointer, payload, time). Commands validate first and give a reason when refused.
5. Data-driven: chemicals, reactions, equipment, layout, setups, constants are JSON. Values carry a status
   (`reference`, `derived`, `unverified_reference`, `placeholder`, `display`).
6. Undo/redo restore full-state snapshots; the command history is the basis for replay and lab reports.

**Do not build yet:** plugins, localization, multiplayer, advanced particle chemistry, university-level simulation,
full accessibility, content packs, mobile optimisation.

**Design Bible:** the "Chemistry Lab Design Bible" (sections 1 to 60.6 so far) was written in chat and is not stored in
this repository. Colour tokens and layout follow it (`scripts/core/lab_colors.gd`, `data/lab/layout.json`).
