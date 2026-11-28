# Material Thermodynamics (Phase 1)

How the simulator models heating, cooling, melting, freezing, boiling, evaporation, condensation and the fusing of
solids. Code: `scripts/chemistry/thermal_profile.gd`, `melt_equilibrium.gd`, `binary_melt_system.gd`,
`scripts/simulation/phase_change_system.gd`, called from `HeatSystem`.

> **Verification status.** The model was checked with an independent Python reference (`tests/test_phase_model.py`)
> and the data validator. The GDScript implementation and `tests/run_phase_change_tests.tscn` have **not** been run
> in Godot 4.7.2. See "Verification" at the end.

## 1. Data: one thermal profile per material family
A chemical gets a `thermal` block (see `docs/CHEMICAL_DATABASE.md`). Materials that are phases of one substance
(water / ice / water_vapor) share one *family*: the root entry lists `phases`, members say `"family": "<root>"`.
Every numeric field carries `value`, `unit`, `status`, `source`. Nothing is guessed: a missing value stays absent
and the model refuses the behaviour that needs it (for example no boiling without a heat of vaporisation).

| Field | Use |
|-------|-----|
| melting / boiling point | phase-change temperatures (1 atm) |
| enthalpy_fusion_j_per_g, enthalpy_vaporization_j_per_g | latent heats |
| specific_heat_solid / liquid / gas | heat capacity per phase |
| density_solid / liquid | volume bookkeeping |
| antoine (water) | vapour pressure in a sealed vessel |

## 2. Energy model (enthalpy method)
For a vessel the conserved quantity is H = C·T + Σ m_k·f_k, where C is the heat capacity of the contents and
f_k the latent-heat state of material k. Heat input changes H; the temperature is recovered by inverting the monotone
function T → H, which has plateaus (latent heat absorbed at constant T) and jumps. Consequences:
- a melting solid holds its melting point until all of it is liquid, then warms; freezing mirrors this;
- no energy is created or lost by a phase change (tested on 4,000 random states in the Python model);
- several materials melt in order of their melting points, each with its own plateau.
C is held constant within one step (see limitations).

## 3. Pure substances and mixtures
Pure substances melt and freeze at one temperature. Two different solids put in one vessel stay a **physical
mixture** and each melts on its own. They become a single material only if the pair is listed in
`data/materials/binary_systems.json` **and** both were liquid together; this is recorded in `vessel.fused_systems`
and shown by the inspector ("one fused solid material"). Unlisted pairs never fuse.

### Tin–bismuth (the only binary system so far)
Simple eutectic. Eutectic 138.8 °C at 56.97 mass % Bi (NIST calculated Bi–Sn diagram). The liquid appears at the
eutectic temperature, then the liquid fraction follows the lever rule up to the liquidus. Fusion heats mix ideally;
terminal solid solubility (21 % Bi in Sn) and heat of mixing are neglected. **The liquidus is a straight line
between the sourced endpoints; real liquidus curves are curved**, so temperatures between 138.8 °C and the melting
points are approximate. Only the eutectic temperature and the pure melting points are sourced data.

## 4. Boiling, evaporation, condensation
- **Open vessel:** heat beyond the boiling point vaporises liquid (latent heat removed from the vessel); vapour vents.
  Slow evaporation below the boiling point uses a mass-transfer constant
  (`evaporation_mass_transfer_g_per_s_per_kpa`, status `placeholder`) and only occurs while the liquid is warmer
  than ambient, so it cools the liquid.
- **Closed vessel:** vapour–liquid equilibrium is solved by bisection with latent-heat coupling; vapour pressure from
  Antoine (water, NIST/Stull) or Clausius–Clapeyron from boiling point and heat of vaporisation; pressure is capped by
  `max_virtual_pressure_kpa`. Cooling condenses vapour back to liquid.
- Solutions (liquids with dissolved solute) are not frozen or boiled by this system: freezing-point depression
  and boiling-point elevation are not modelled, and the older aqueous boil clamp still applies to them.

## 5. Equipment
Hot plate unchanged. The **cold plate** (`cold_plate_basic`) reuses the heater mechanism with
`min_surface_temperature_c` as its setpoint lower bound. Library allowlists were widened to include ice, tin,
bismuth, carbon dioxide and the cold plate; these are one-line constants in `library_panel.gd`,
`spawn_object_command.gd`, `add_reagent_command.gd`.

## 6. Undo/redo and save/load
`fused_systems` is part of `VesselState.to_dictionary`/`from_dictionary`, so snapshot undo/redo and sessions carry it.
Sessions without it load with an empty dictionary. `SessionStore` accepts molten/frozen phases per profile and derives
the gas-amount limit from the pressure limit.

## 7. Data sources (fetched 2026-11-28)
Wikipedia "Properties of water"; element infoboxes (values citing the CRC Handbook) for Sn, Bi, Zn, Mg; NIST Chemistry
WebBook for ethanol, glycerol and water Antoine constants; Wikipedia data pages for ethanol, glycerol, sodium chloride;
NIST metallurgy Bi–Sn diagram and PMC5578286. Status tags: `reference` (quoted), `derived` (e.g. kJ/mol ÷ molar mass).
Wikipedia is a secondary source; each value should be re-checked against the primary handbook when available.

## 8. Not found / omitted
GHS classifications; liquid heat capacity of metals (falls back to the solid value and is flagged); glycerol heat of
vaporisation at the boiling point; NaCl liquid heat capacity and a consistent boiling point; Sn–Bi liquidus at
intermediate compositions.

## 9. Known limitations
- No freezing-point depression, boiling-point elevation, solid solutions, sublimation or supercooling.
- Only the eutectic kind of binary system is implemented; `kind` is reserved for others.
- Linear Sn–Bi liquidus (see above). Evaporation rate constant is a placeholder.
- Constant heat capacity per step; error shrinks with the step size.
- Vapour from open vessels disappears; dissolved solutes do not crystallise when water boils away.
- Only 10 materials (water, ice, water vapour, ethanol, glycerol, NaCl, Zn, Mg, Sn, Bi) have thermal profiles; the rest keep the legacy behaviour.
- Most metals' melting points exceed the hot plate's 300 °C maximum.
- Cold plate visuals and the new `phase_change` observation kind in the UI are untested.

## 10. Verification
| Level | What |
|-------|------|
| Run | `python3 tests/test_phase_model.py` (21 checks), `python3 tests/validate_project.py` (includes thermal data checks, mutation-tested) |
| Inferred from code only | all GDScript in this phase |
| Needs manual / Godot run | `res://tests/run_phase_change_tests.tscn`, `run_simulation_tests.tscn`, `ui_probe.tscn`, then play: heat ice, tin+bismuth on the hot plate, cold plate with water, save/load and undo during a melt |
