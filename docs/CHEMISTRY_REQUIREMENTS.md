# Chemistry and Equipment Requirements

Source: owner brief "Advanced Chemistry Material System" (2026-11-07). Binding for Milestones 3-9.
Guiding principle: **scientific accuracy over feature count.** Every chemical, tool and experiment needs a real scientific purpose.
Audience: middle school, high school and university demonstrations; simple UI on top, advanced simulation underneath.

## 1. Substance database (data-driven)
Entries for elements, compounds, solutions, mixtures and laboratory chemicals, added without code changes.
Properties: name, formula, atomic number (elements), state, color, density, viscosity, melting / boiling / freezing point,
temperature range, transparency, reactivity, solubility, category, safety information, common laboratory uses.
These properties must drive behavior, not just display.

## 2. Periodic table
All 118 elements as data: symbol, atomic number, atomic mass, category, state at room temperature, melting point,
boiling point, density, other physical properties. Expandable and searchable.

## 3. Material behavior
- Liquids: viscosity (pour speed, flow, thickness), density (layering, mixing), surface behavior, mixing, temperature effects.
- Heating: more movement, expansion, boiling at boiling point. Cooling: slower movement, freezing at freezing point.
- Phase changes: melting (solid -> liquid) and freezing (liquid -> solid) at their points.
- Temperature affects state of matter, reaction speed, appearance and liquid behavior.

## 4. Temperature tools
Thermometers, digital temperature sensors/probes, temperature over time, heat transfer, cooling effects.

## 5. Equipment scope
- Glassware: beaker, Erlenmeyer flask, volumetric flask, test tube, graduated cylinder, pipette, burette, funnel, watch glass, Petri dish, condenser.
- Measurement: thermometer, digital temperature probe, pH meter, analytical balance, measuring cylinder.
- Heating: Bunsen burner, hot plate, heating mantle.
- Separation: filter setup, centrifuge, distillation equipment.
- Safety: gloves, goggles, lab coat, fume hood.

## 6. Educational levels
Content is tagged by level (`middle_school`, `high_school`, `university`). Simple vs. advanced presentation is a UI/settings
concern; the simulation core is always the same.

## Architectural implications (decisions in DECISIONS.md D-012 to D-016)
| Requirement | Consequence |
|-------------|-------------|
| Properties must influence simulation | One schema, loaded by a single `ChemicalDatabase`; liquid, heat and reaction systems read it, never copy values |
| 118 elements, scientifically accurate | Values must come from a vetted source and carry provenance; unknown/predicted values are explicit, never invented |
| Temperature-dependent state | A central phase-resolution function (substance + temperature + pressure -> state) shared by heating, cooling, liquids and reactions |
| Many equipment types | One container component + data-defined equipment (capacity, graduations, openings) instead of per-device scripts |
| Multiple education levels | `education_levels` tag on substances, equipment and experiments; level filtering lives outside the simulation |
