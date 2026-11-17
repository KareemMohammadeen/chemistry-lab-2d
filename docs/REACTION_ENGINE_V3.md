# Reaction Engine V3

Reaction Engine V3 is the repository's explicit allowlist and dispatch layer for the classroom chemistry model.
It exists to keep ambient chemistry deterministic, data-driven, and reviewable.

## What it does

- loads the reaction registry from `data/reaction_registry_v3.json`
- checks whether a reaction is registered and enabled
- routes enabled reactions to the matching handler type
- keeps visual demonstrations separate from ambient chemistry
- returns structured `ReactionResult` data for the UI, logs, and tests

## Current handler scope

Enabled handler types:

- `dissolution` — continuous, temperature-aware dissolution of the supported classroom salts
- `neutralisation` — continuous strong-acid / strong-base neutralisation
- `boiling` — observation-only boiling of water in the virtual model

Disabled / reference-only entries remain in the registry so the data stays explicit, but they do not execute until a reviewed handler is enabled.

## Core contracts

- `ReactionRegistryV3` is the allowlist source of truth.
- `ReactionMatcher` is read-only; it checks readiness and never mutates vessel state.
- `ReactionResult` is the structured envelope shared by the matcher and executor.
- `ReactionEngine` performs the state mutation for enabled reactions and produces observations, consumed/produced ledgers, effects, warnings, and errors.

## Safety boundary

The system is intentionally limited to the virtual classroom model.
Reference-only elements, compounds, and disabled reaction entries cannot become executable just because they exist in JSON.

## Verification

Headless tests in `tests/run_reaction_registry_tests.gd` and `tests/run_reaction_executor_tests.gd` cover the allowlist, enabled reactions, and the generic executor path.
