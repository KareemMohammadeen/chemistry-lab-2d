# Conventions

## Naming
- All file and folder names: `snake_case` (`beaker_controller.gd`, `lab_bench.tscn`). Descriptive; no abbreviations;
  never `temp`, `new_script`, `manager2`, `final`.
- Exceptions: the five root status docs (`README.md`, ...), `docs/*.md` (UPPER_SNAKE_CASE), and Godot-required names
  (`project.godot`, `icon.svg`).
- Classes: `PascalCase` via `class_name` (except autoloads). Functions / variables: `snake_case`. Constants: `UPPER_SNAKE_CASE`.
  Private members: leading underscore. Signals: past-tense or event-style names (`focus_changed`).
- Scene node names: `PascalCase`, meaningful.

## Folders

| Folder | Content |
|--------|---------|
| `scenes/{lab,equipment,ui}` | `main.tscn` plus one scene per view responsibility |
| `scripts/simulation` | State, commands, clock, heat: the truth. No nodes except `SimulationHost` |
| `scripts/chemistry` | Reaction engine, acid/base, solution appearance, thermal properties |
| `scripts/interaction` | Pointer to context to command; results and definitions |
| `scripts/ui` | Views, workspace, inspector, interface |
| `scripts/core`, `managers`, `utilities` | Event bus, colour tokens, input actions, data helpers |
| `data/{chemicals,reactions,equipment,lab,setups,simulation,interaction,input}` | JSON content with provenance status |
| `assets/{sprites,effects,audio}` | Imported media (empty for now) |
| `docs/`, `tests/` | Documentation; validator and headless scenario test |

Empty reserved folders contain `.gitkeep`.

## GDScript
- Tabs for indentation (`.editorconfig`). Static typing wherever practical.
- Doc comments (`##`) on every class; comments elsewhere only where reasoning is not obvious.
- No magic numbers: shared constants in `scripts/core/`, tunables as `@export`, content in `data/`.
- Node references via `@export` (assigned in the scene) rather than hard-coded `get_node` paths.
- Communicate across systems with `EventBus` or component signals; do not reach into unrelated systems.
- Audio only through `AudioManager`; input only through `InputActions` constants and data bindings.

## Scenes
- One responsibility per scene; compose with instances. Never build the whole lab in one scene.
- Shared materials live in `assets/materials`; prefer sharing over per-object copies.

## Documentation duties
Update CHANGELOG for every change, TODO for remaining work, PROJECT_CONTEXT when state or architecture
changes, DECISIONS for design choices, and rewrite NEXT_SESSION at the end of every session.
