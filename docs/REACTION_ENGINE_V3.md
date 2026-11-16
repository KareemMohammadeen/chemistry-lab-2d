# Reaction Engine V3 — Foundation

This document describes the first three V3 components: the registry, the read-only matcher and the shared result model. It does **not** describe a finished generic reaction executor.

## 1. Registry

- Runtime source: `data/reaction_registry_v3.json`
- Loader: `ReactionRegistryV3`
- Owner: `ContentDatabase`

Every reaction definition in `data/reactions/*.json` must have exactly one registry entry. The registry verifies its schema version, unique IDs, safety scope, handler ID and reaction-type compatibility.

Only known handlers compiled into the application are accepted. A reaction is enabled only when its handler is enabled and belongs to the explicit executable-handler allowlist. Observation-only entries (currently boiling metadata and the magnesium visual demo) remain disabled for generic matching.

The V3 registry is deliberately stored outside `data/reactions/`: that directory is reserved for `ReactionDefinition` files and is loaded as such by the existing content database. The loader also ignores the short-lived legacy `data/reactions/reaction_registry.json` file if present on a base branch.

## 2. Matcher

- Script: `scripts/chemistry/reaction_matcher.gd`
- API: `ReactionMatcher.match_reaction(reaction_id, vessel)`

The matcher is a read-only readiness check. It verifies:

1. The reaction exists and is enabled in the registry.
2. The reaction has structured reactant requirements.
3. Every reactant names a known, explicitly virtual-enabled chemical.
4. The required phase exists in the vessel ledger (`liquid`, `solid`, `dissolved` or `gas`).
5. The required model quantity is present.
   - Threshold units must match the phase ledger: liquid uses `mL`, solid/dissolved use `g`, and gas uses `mol`. Missing or mismatched units are invalid definitions.
6. Any supported condition is satisfied.

The first supported condition is a numeric `temperature_c` comparison (`gte`, `lte` or `eq`). Unknown conditions are rejected instead of being silently ignored. Reference-element participants are rejected: periodic-table specimens remain visual references, not reagents.

A successful match means only that the required virtual participants and supported conditions are present. It does not calculate a limiting reagent, consume a reactant, make a product, conserve mass/charge by execution, or run a reaction.

## 3. Result model

- Script: `scripts/chemistry/reaction_result.gd`

The result envelope has explicit statuses: `invalid`, `rejected`, `not_matched`, `matched` and `executed`. It carries the reaction identity, matched and missing participants, message, observations, consumed/produced ledgers, energy and temperature fields, warnings and errors.

`to_dictionary()` returns deep copies of collection fields, so callers cannot mutate the original result through the serialized snapshot. The matcher leaves `consumed` and `produced` empty by design.

## Current allowlist

| Reaction | Handler | V3 state |
|---|---|---|
| Sodium chloride dissolution | `dissolution_v1` | Enabled; existing continuous handler |
| Copper sulfate pentahydrate dissolution | `dissolution_v1` | Enabled; existing continuous handler |
| Strong acid/base neutralisation | `neutralisation_v1` | Enabled; existing continuous handler |
| Water boiling | `boiling_observation_v1` | Disabled; no dedicated V3 handler |
| Magnesium visual demonstration | `visual_demo_observation_v1` | Disabled for generic execution; separate observation-only flow |

The participant metadata on the enabled reactions describes the virtual materials and phases required for matching. The current legacy handlers still own their existing continuous state changes; V3 does not replace them yet.

## Tests

- Static registry/schema and safe-material validation: `python tests/validate_project.py`
- Headless matcher scenarios: `godot --headless --path . -s tests/run_simulation_tests.gd`

The headless tests verify successful matching, missing participants, neutralisation participants, disabled visual demos, unknown IDs, result serialization and the fact that matching does not mutate simulation state.

## Next implementation boundary

The next V3 component is the executor. It must be introduced only after a reaction type has explicit quantity units, stoichiometric limits, phase-aware consumption/products, mass and charge validation, observation output, and deterministic undo/redo/save-load tests. New or reference-only substances must not become executable merely because they appear in JSON.
