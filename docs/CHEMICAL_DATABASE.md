# Chemical Reference Database

Two reference sets sit beside the playable chemicals in `data/chemicals/`:

| Set | Location | Loaded as | Count |
|-----|----------|-----------|-------|
| Elements | `data/elements/elements.json` | `ElementDefinition` via `ContentDatabase.get_element(symbol)` / `get_element_by_number(z)` | 118 |
| Compounds | `data/compounds/<id>.json` | `CompoundDefinition` via `ContentDatabase.get_compound(id)` | 38 |

The simulation only uses `data/chemicals/`. A compound whose `simulation.chemical_id` is set is linked to a playable chemical;
the rest are reference data until the reaction engine learns them.

## Provenance rules
- Nothing is verified. Numeric values carry `status`: `unverified_reference` (copied or recalled, not checked against a primary
  source), `derived` (computed by rule or formula), `display` (colour hints). Unknown values are `null` (NAN in code), never guessed.
- Elements 1-103: melting point, boiling point, density, electronegativity and state come from an automatically extracted
  table (Engineering ToolBox) that contains typing errors. Corrections are applied only where certain and recorded per element in
  `corrections` (Os, Cd, Ge, Xe, He, and Dy/Ho, whose values were withheld because the source repeated neighbouring rows).
- Elements 104-118: only identity, structure, mass number and a predicted electron configuration. Bulk properties are unknown.
- Atomic masses are abridged standard weights recalled from memory and cross-checked against the source (all within 0.1 u).
  Radioactive elements carry the mass number of a long-lived isotope; for the heaviest elements sources differ.
- Group, period, block, category and electron configuration are derived. Configurations use the Madelung rule with the known
  exceptions, and the build script verifies that the electrons per shell match the source for all 103 elements.
- Compound values are recalled general-chemistry values. Molar masses are derived from the element table. Hazard text is plain-language
  guidance, not an SDS.

## Rebuilding
```
python3 tools/build_elements.py     # elements.json from tools/element_source_data.txt plus rules
python3 tools/build_compounds.py    # data/compounds/*.json
python3 tests/validate_project.py   # cross-checks (118 elements, molar masses, links)
```

## Still missing
Oxidation states only for common teaching elements; appearance and hazard text only for the common ones; compound reaction
data is descriptive, not yet executable by the ReactionEngine.
