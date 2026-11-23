# Chemistry Lab — Development Roadmap

This is the ordered project plan. It records what exists, what is still missing, and what must be verified before a feature is called complete.

Status:
- `[x]` Implemented in the current feature branch; CI/editor verification may still be pending.
- `[ ]` Not implemented or not yet verified.
- Safety boundary: periodic-table tokens stay visual-only unless a material receives a reviewed, explicit simulation definition. This project is a virtual classroom model, not real-lab operating guidance.

## P0 — Release blockers and verification

- [ ] Run the complete static validation suite on the latest branch and resolve every error.
- [ ] Run Godot 4.3+ headless import and `tests/run_simulation_tests.gd`; capture the final exit code and fix failures.
- [ ] Open `scenes/main.tscn` in the Godot editor and complete every applicable item in `docs/TESTING.md`.
- [ ] Verify drag/drop in the editor: lift, scale/lean, shadow, valid/invalid target feedback, surface previews, and inserted thermometer movement.
- [ ] Verify pan/zoom, reset/home, resizing, selection, Inspector refresh, save/load, Undo/Redo and sound toggles manually.
- [ ] Review all `placeholder`, `unverified_reference`, and `derived` values before presenting them as measured or authoritative (including CuSO4 solubility conversion, time constants, heater rates and glass mass).
- [ ] Add a reproducible release checklist and record actual test outcomes in CHANGELOG.md.

## P1 — Chemistry engine and scientific correctness

- [x] Define the V3 foundation: explicit registry, handler allowlist, read-only participant/condition matcher and shared result envelope.
- [ ] Make a new reaction executable only when its handler, balanced equation, participant identities, phases, units, conditions, conservation checks, safety status and sources all validate.
- [ ] Add reviewed virtual handlers in small increments (for example, selected precipitation or displacement models); do not treat descriptive JSON participants as executable chemistry.
- [ ] Add deterministic tests for limiting quantities, insufficient reactants, product ledgers, mass/mole accounting, invalid definitions, undo/redo and save/load.
- [ ] Keep reaction execution opt-in per chemical and per reaction. Never make the 118 visual reference tokens reactive by default.
- [ ] Verify chemical properties against primary or authoritative sources and retain source URLs, access dates, units and uncertainty/provenance labels.

## P2 — Apparatus and interaction capabilities

- [ ] Implement graduated dropper/pipette actions with bounded virtual aliquots and clear volume feedback.
- [ ] Add functional stirring rod, spatula and balance; define what each tool can and cannot transfer or measure.
- [ ] Add graduated cylinder, burette, funnel and filter-paper/filter assembly with validated interactions.
- [ ] Add pH indicator and pH meter readouts with clear model precision/limitations.
- [ ] Review the need for watch glass, crucible and other school-level accessories; add only with a defined safe educational use.
- [ ] Add right-click context actions and double-click shortcuts. (Touch pan/pinch and drag are implemented; long-press is not.)
- [ ] Ensure every apparatus has data-driven properties, supported interactions, an Inspector view and regression tests.

## P3 — Guided learning, classroom roles and assessment workflow

- [x] Add the first guided virtual activity: water + sodium chloride, ordered action tracking and a dissolved-mass observation condition (pending CI/editor verification).
- [ ] Expand guided activities only from reviewed school-level sources; store learning goals, prerequisites, step prompts, expected virtual state and evidence status in data files.
- [ ] Add optional hints and clear explanations when a step is refused or performed out of order.
- [ ] Persist guided-activity progress in the session format and restore it safely.
- [ ] Add Teacher Mode controls for choosing the activity, allowed materials/equipment, and classroom setup.
- [ ] Add Student Mode with teacher-selected restrictions and visible explanations when an action is unavailable.
- [ ] Keep Sandbox Mode separate, with a reviewed allowlist of virtual materials and actions.
- [ ] Do not add AI features or quizzes; they are outside this project's agreed scope.

## P4 — Replay and reporting

- [x] Export a Markdown lab report when saving a session; include the simulation snapshot, apparatus, contents, observations and action log.
- [ ] Implement true timeline replay from recorded command context and deterministic checkpoints; support play, pause, step-forward and seek.
- [ ] Make replay read-only and ensure it cannot mutate the saved experiment or bypass command validation.
- [ ] Add report sections for learning objective, method summary, observations, equation (only when verified), result, conclusion, source/evidence status and model limitations.
- [ ] Consider PDF export after the Markdown report format and content are stable.

## P5 — Visual quality, materials and performance

- [ ] Improve glass rendering with dedicated sprites/shaders, highlights, refraction-style effects and consistent scaling.
- [ ] Improve liquid motion: smooth level changes, pouring streams, mixing transitions and temperature-dependent visuals.
- [ ] Add constrained powder/crystal presentation, sediment and precipitation visuals where an enabled model supports them.
- [ ] Add polished, non-graphic particles for bubbles, vapour, colour change, crystals and safe virtual demonstrations.
- [ ] Add accessible transitions, focus states, keyboard navigation and reduced-motion considerations.
- [ ] Profile large workbenches and sessions; optimise rendering, history size, data loading and UI refresh.
- [x] Add optional, muteable procedural feedback sounds for supported actions and observations.

## P6 — Reference database and Egyptian curriculum coverage

- [ ] Verify all 118 element records against NIST/IUPAC or equivalent authoritative references; replace weak-source extraction and document unresolved values.
- [ ] Review electron configurations and subshell-level details, especially elements 104–118, and preserve unknown values as unknown.
- [ ] Add oxidation states, appearance and hazard summaries only with source-backed confidence labels; keep hazards informational, not operational instructions.
- [ ] Expand the compound browser and reference properties without making reference-only compounds playable automatically.
- [ ] Review Prep 1, Prep 2 and Prep 3 experiments against the exact 2026–2027 official books and cite page/unit references.
- [ ] Confirm Senior 1 Integrated Science topics against the official source.
- [ ] Keep Senior 2 mapping pathway-specific (General Secondary vs Egyptian Baccalaureate); do not merge incompatible syllabuses.
- [ ] For each curriculum activity, record grade, topic, source, page, confidence/alignment status, learning outcome and whether a virtual model exists.
- [ ] Add a regression check that no unverified curriculum item is labelled as officially confirmed.

## Implemented foundations in the current feature branch

- [x] Data-driven visual sample forms for all 118 elements (cube, powder, ribbon, crystal, liquid drop, gas cylinder or conceptual atom); specimens are explicitly read-only.
- [x] Infinite pan-and-zoom workbench and movable equipment.
- [x] Virtual gas ledger, automatic virtual sealing, trapped-air accounting, ideal-gas pressure estimate and software pressure guard.
- [x] Open/closed system rules, reversible vent action and gas-aware Undo/Redo and session persistence.
- [x] Qualitative observation-only magnesium model with a brief white flash and illustrative MgO product; not a physical-yield calculation or real procedure.
- [x] Safe experiment-bank catalogue for Prep 1, Prep 2, Prep 3, Senior 1 and Senior 2 with unverified mappings clearly labelled.
- [x] Session save/load with validation, experiment log and Markdown report export.
- [x] Static validators and Godot headless scenario coverage added for core simulation paths; latest headless scenario result must still be confirmed.

