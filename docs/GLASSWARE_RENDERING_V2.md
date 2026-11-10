# Glassware Rendering V2

## Scope

This is a presentation-only redesign of the 2D glassware. The simulation, chemistry engine, vessel ledger, equipment behaviour, interaction points, commands and drag/drop behaviour are intentionally unchanged. Four equipment visual profiles have refined shape control points only.

## Rendering approach

- `EquipmentView` continues to use each equipment JSON visual profile as the source of the vessel's shape.
- Glass tint, wall edges, opening rims and base glints are kept subtle so the contents remain readable against the laboratory backdrop.
- Side reflections are generated from `VesselGeometry.half_width_at()` at multiple heights. Each ribbon and line is inset from the local wall width rather than using a fixed X coordinate. If a profile section is too narrow for the requested stroke, that reflection is skipped.
- Liquid remains a profile slice. The meniscus and side refractions are drawn from the local liquid height and vessel width.
- Boiling bubbles clamp their horizontal centre by the current vessel width and their radius.
- Solid beds remain display-only projections of `VesselState.solids`. Per-substance grains use the chemical colour and deterministic positions constrained by the current profile.
- Library vessel thumbnails use the same profile points to build a filled liquid slice, so tapered flasks and test tubes no longer show rectangular liquid bands.

## Explicit non-goals

- No new physical refraction shader or real optical simulation is included.
- No scientific properties, material data, phase changes or chemical rules are changed.
- Four equipment visual profiles have new shape control points; nominal capacities, heights, openings, pour points and interaction rules are unchanged.
- No chemistry state is inferred from a visual effect.
- The visual profiles are refined only for silhouette: a softly rolled beaker lip/base, a rounder test-tube tip, a smoother Erlenmeyer shoulder and a gentler reagent-bottle shoulder.

## Manual verification

Open `codex/glassware-rendering-v2` in Godot 4.3+ and follow Section 4 of `docs/TESTING.md`. In particular, check the empty/filled states of the beaker, test tube and Erlenmeyer flask, plus the reagent bottle and dropper. Verify reflections, liquid surfaces, boiling bubbles and crystal grains never escape the vessel silhouette.

## Verification status

The branch was reviewed against the existing profile geometry and state/view interfaces. It has **not** been opened or run in the Godot editor in this environment. Static validator and headless simulation tests have not been run here either; this PR must remain unmerged until the documented checks are performed.
