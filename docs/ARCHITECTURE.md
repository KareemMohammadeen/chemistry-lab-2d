# Architecture (2D)

```
            +----------------------------- scenes/main.tscn (Main: composition root) -----------------------------+
            |                                                                                                    |
 pointer -> InteractionController --builds--> InteractionContext --wrapped in--> LabCommand                      |
            | (scripts/interaction)           (source, target, interaction_id, pointer, payload, time)           |
            |                                                                  |                                 |
            |                                              SimulationHost.submit -> CommandStack                  |
            |                                                    validate -> execute -> log -> snapshots          |
            |                                                                  v                                 |
            |   LabSimulation (state: LabState, LabObject, VesselState) <- step(dt) <- SimulationClock           |
            |        |  ReactionEngine (data/reactions) + HeatSystem + AcidBase                                   |
            |        v                                                                                           |
            |   ObjectInspector (view-model dictionaries)        LabWorkspace + EquipmentView + StreamOverlay     |
            |        v                                                  (read state, draw, animate)              |
            |   InspectorPanel / LabInterface (display + signals only)                                           |
            +----------------------------------------------------------------------------------------------------+
```

## Layers and what each may do
| Layer | Folder | May | Must not |
|-------|--------|-----|----------|
| Simulation | `scripts/simulation` | own and change state, run commands, step time | reference nodes or UI |
| Chemistry | `scripts/chemistry` | decide reactions, pH, colour, heat of reaction from data | know about equipment views |
| Interaction | `scripts/interaction` | turn pointer input into commands | decide chemical outcomes |
| Views/UI | `scripts/ui` | read state, draw, animate, emit signals | change state, contain chemistry |
| Data | `data/` | describe content with provenance | contain code |

## Key objects
- `ContentDatabase`: loads chemicals, equipment, reaction definitions, the explicit V3 registry, constants and layout once; read-only afterwards.
- `ReactionRegistryV3`: checks unique reaction IDs, allowed handler/type mappings, enable flags and the virtual-only scope.
- `ReactionMatcher` / `ReactionResult`: read-only participant/condition matching and a structured result envelope; neither consumes nor creates materials.
- `LabState` / `LabObject` / `VesselState`: the serialisable truth. A vessel is a ledger: millilitres per liquid id,
  grams per solid id, grams dissolved per id. pH and colour are derived, never stored.
- `LabSimulation`: spawns objects from a setup, steps the world, snapshots/restores state, forwards observations.
- `SimulationHost` (Node): the only thing that advances time (fixed step 0.1 s, speed 1x/2x/4x, pause).
- `CommandStack`: executes `LabCommand`s; every attempt (also refused ones) is logged with a reason. Undo and redo
  restore full snapshots (chemistry is not reversible by inverse operations). The log is the base for replay and reports.
- `ReactionEngine`: existing per-step handlers remain authoritative for dissolution (first order toward the temperature-dependent solubility cap,
  stirring speeds it up), strong acid/base neutralisation (heat released once per mole), observations with explanations.
- `HeatSystem`: lumped-body model; hot plate ramps to its setpoint; vessels on it exchange heat without overshoot;
  boiling clamps at the water boiling point.
- `ObjectInspector`: builds the Inspector content as plain data (rows, contents, observations, safety, actions).
- Views: `LabWorkspace` (background, view per object, hit testing, drag), `EquipmentView` (`_draw()` per equipment style,
  smooth liquid level and colour), `StreamOverlay` (tilt and stream while pouring; display only).

## Commands (Milestone 1)
`pick_up` (not undoable), `place` (surface, support or insert modes), `pour`, `add_solid`, `mix`, `heat`.
Interaction ids and labels live in `data/interaction/interaction_types.json`.

## Drop resolution
Dropped on a hot plate zone and the item may stand there: `place` (support). Dropped on another object: a thermometer is
inserted; a vessel pours liquid (or adds solid if it holds only solid); otherwise a reason is shown. Dropped on a shelf or
the bench: `place` (surface). Anywhere else (or over the interface): refused with a reason, the object returns.

## Extending
New equipment: add `data/equipment/<id>.json` (profile, interaction points, interactions). New reaction definitions need a matching explicit entry in `data/reaction_registry_v3.json`; the V3 matcher is read-only until a validated executor is added. New chemical or reaction: add JSON. New action: add a command, an entry in `interaction_types.json`, an inspector action. No existing class should need to learn about the new item by name. See `docs/REACTION_ENGINE_V3.md` for the registry, matcher and result contract.
