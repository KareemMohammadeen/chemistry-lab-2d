#!/usr/bin/env python3
"""Builds data/elements/elements.json (118 elements) from tools/element_source_data.txt plus rules.

Provenance policy: nothing here is presented as verified. Values copied from the source table are
"unverified_reference"; values computed by rule are "derived"; values that were not available stay null.
Run from the project root:  python3 tools/build_elements.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_URL = "https://www.engineeringtoolbox.com/elements-periodic-table-atomic-weight-melting-boiling-points-density-electronegativity-electron-affinity-configuration-d_999.html"
SOURCE = "Engineering ToolBox element table (elements 1-103), extracted automatically on 2026-11-08; older data set with some known typing errors"

SYMBOLS = ("H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo "
           "Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb "
           "Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og").split()
NAMES = ("Hydrogen Helium Lithium Beryllium Boron Carbon Nitrogen Oxygen Fluorine Neon Sodium Magnesium Aluminium Silicon Phosphorus "
         "Sulfur Chlorine Argon Potassium Calcium Scandium Titanium Vanadium Chromium Manganese Iron Cobalt Nickel Copper Zinc Gallium "
         "Germanium Arsenic Selenium Bromine Krypton Rubidium Strontium Yttrium Zirconium Niobium Molybdenum Technetium Ruthenium "
         "Rhodium Palladium Silver Cadmium Indium Tin Antimony Tellurium Iodine Xenon Caesium Barium Lanthanum Cerium Praseodymium "
         "Neodymium Promethium Samarium Europium Gadolinium Terbium Dysprosium Holmium Erbium Thulium Ytterbium Lutetium Hafnium "
         "Tantalum Tungsten Rhenium Osmium Iridium Platinum Gold Mercury Thallium Lead Bismuth Polonium Astatine Radon Francium Radium "
         "Actinium Thorium Protactinium Uranium Neptunium Plutonium Americium Curium Berkelium Californium Einsteinium Fermium "
         "Mendelevium Nobelium Lawrencium Rutherfordium Dubnium Seaborgium Bohrium Hassium Meitnerium Darmstadtium Roentgenium "
         "Copernicium Nihonium Flerovium Moscovium Livermorium Tennessine Oganesson").split()
assert len(SYMBOLS) == 118 and len(NAMES) == 118

# Standard atomic weights, abridged (IUPAC), recalled from memory; cross-checked against the source table below.
# Radioactive elements without a standard weight carry the mass number of a long-lived isotope (marked is_mass_number).
MASS = {1:1.008,2:4.0026,3:6.94,4:9.0122,5:10.81,6:12.011,7:14.007,8:15.999,9:18.998,10:20.180,11:22.990,12:24.305,13:26.982,
 14:28.085,15:30.974,16:32.06,17:35.45,18:39.95,19:39.098,20:40.078,21:44.956,22:47.867,23:50.942,24:51.996,25:54.938,26:55.845,
 27:58.933,28:58.693,29:63.546,30:65.38,31:69.723,32:72.630,33:74.922,34:78.971,35:79.904,36:83.798,37:85.468,38:87.62,39:88.906,
 40:91.224,41:92.906,42:95.95,44:101.07,45:102.91,46:106.42,47:107.87,48:112.41,49:114.82,50:118.71,51:121.76,52:127.60,53:126.90,
 54:131.29,55:132.91,56:137.33,57:138.91,58:140.12,59:140.91,60:144.24,62:150.36,63:151.96,64:157.25,65:158.93,66:162.50,67:164.93,
 68:167.26,69:168.93,70:173.05,71:174.97,72:178.49,73:180.95,74:183.84,75:186.21,76:190.23,77:192.22,78:195.08,79:196.97,80:200.59,
 81:204.38,82:207.2,83:208.98,90:232.04,91:231.04,92:238.03}
MASS_NUMBER = {43:98,61:145,84:209,85:210,86:222,87:223,88:226,89:227,93:237,94:244,95:243,96:247,97:247,98:251,99:252,100:257,
 101:258,102:259,103:266,104:267,105:268,106:269,107:270,108:277,109:278,110:281,111:282,112:285,113:286,114:289,115:290,116:293,
 117:294,118:294}

# Corrections to the source table, each applied only where the error is certain. Documented in the output.
CORRECTIONS = {
 2:  {"melting_c": (None, "Helium does not freeze at normal pressure; the source printed -273 degC.")},
 32: {"density_g_cm3": (5.323, "Source listed 5.23; the commonly quoted value is 5.323.")},
 48: {"melting_c": (321, "Source listed 21; cadmium melts at 321 degC.")},
 54: {"density_g_cm3": (0.0059, "Source printed '0,0059' (decimal comma).")},
 66: {"melting_c": (None, "Source repeated terbium's values for dysprosium."),
      "boiling_c": (None, "Source repeated terbium's values for dysprosium."),
      "density_g_cm3": (None, "Source repeated terbium's values for dysprosium.")},
 67: {"melting_c": (None, "Source repeated lutetium's values for holmium."),
      "boiling_c": (None, "Source repeated lutetium's values for holmium."),
      "density_g_cm3": (None, "Source repeated lutetium's values for holmium.")},
 76: {"melting_c": (3033, "Source listed 303; osmium melts at about 3033 degC.")},
}
# Bulk state at 0 degC and 1 atm is only listed where it is established; At, Fr and Z>=100 were never made in bulk.
STATE_UNKNOWN = {85, 87} | set(range(100, 119))

NOBLE = [2, 10, 18, 36, 54, 86, 118]
ORDER = [(1,0),(2,0),(2,1),(3,0),(3,1),(4,0),(3,2),(4,1),(5,0),(4,2),(5,1),(6,0),(4,3),(5,2),(6,1),(7,0),(5,3),(6,2),(7,1)]
CAP = {0: 2, 1: 6, 2: 10, 3: 14}
OVERRIDES = {  # ground-state exceptions to the Madelung filling rule
 24:{(4,0):1,(3,2):5}, 29:{(4,0):1,(3,2):10}, 41:{(5,0):1,(4,2):4}, 42:{(5,0):1,(4,2):5}, 44:{(5,0):1,(4,2):7},
 45:{(5,0):1,(4,2):8}, 46:{(5,0):0,(4,2):10}, 47:{(5,0):1,(4,2):10}, 57:{(4,3):0,(5,2):1}, 58:{(4,3):1,(5,2):1},
 64:{(4,3):7,(5,2):1}, 78:{(6,0):1,(5,2):9}, 79:{(6,0):1,(5,2):10}, 89:{(5,3):0,(6,2):1}, 90:{(5,3):0,(6,2):2},
 91:{(5,3):2,(6,2):1}, 92:{(5,3):3,(6,2):1}, 93:{(5,3):4,(6,2):1}, 96:{(5,3):7,(6,2):1}, 103:{(5,3):14,(6,2):0,(7,1):1},
}
L = "spdf"


def fill(z):
    counts, left = {}, z
    for n, l in ORDER:
        put = min(CAP[l], left)
        counts[(n, l)] = put
        left -= put
    return counts


def configuration(z):
    counts = fill(z)
    for key, value in OVERRIDES.get(z, {}).items():
        counts[key] = value
    assert sum(counts.values()) == z, (z, counts)
    core = max([n for n in NOBLE if n < z], default=0)
    core_counts = fill(core) if core else {}
    parts = []
    for (n, l) in sorted(counts, key=lambda k: (k[0], k[1])):
        remainder = counts[(n, l)] - core_counts.get((n, l), 0)
        if remainder > 0:
            parts.append(f"{n}{L[l]}{remainder}")
    shells = {}
    for (n, l), c in counts.items():
        shells[n] = shells.get(n, 0) + c
    shell_list = [shells[n] for n in sorted(shells) if shells[n] > 0]
    prefix = f"[{SYMBOLS[core-1]}] " if core else ""
    return prefix + " ".join(parts), shell_list


def period_group_block(z):
    period = next(i + 1 for i, n in enumerate(NOBLE) if z <= n)
    if z in (1,): return 1, 1, "s"
    if z == 2: return 1, 18, "s"
    start = {2: 2, 3: 10, 4: 18, 5: 36, 6: 54, 7: 86}[period]
    k = z - start                      # 1-based position within the period
    if period in (2, 3):
        return period, (k if k <= 2 else k + 10), ("s" if k <= 2 else "p")
    if period in (4, 5):
        return period, k, ("s" if k <= 2 else "d" if k <= 12 else "p")
    # periods 6 and 7 have the f block in the middle
    f_first, f_last = (57, 70) if period == 6 else (89, 102)
    if k <= 2: return period, k, "s"
    if f_first <= z <= f_last: return period, None, "f"
    if z > f_last:
        g = z - f_last + 2             # Lu/Lr -> 3
        return period, g, ("d" if g <= 12 else "p")
    raise ValueError(z)


def category(z, group):
    if 57 <= z <= 71: return "lanthanoid"
    if 89 <= z <= 103: return "actinoid"
    if z == 1: return "nonmetal"
    if z >= 113: return "unknown chemical properties"
    if z in (5, 14, 32, 33, 51, 52): return "metalloid"
    if group == 1: return "alkali metal"
    if group == 2: return "alkaline earth metal"
    if group == 17: return "halogen"
    if group == 18: return "noble gas"
    if z in (6, 7, 8, 15, 16, 34): return "nonmetal"
    if group is not None and 3 <= group <= 12: return "transition metal" if z <= 112 else "transition metal (predicted)"
    if z in (13, 31, 49, 50, 81, 82, 83, 84): return "post-transition metal"
    return "unknown chemical properties"


def status(value, note=None, source=SOURCE, state="unverified_reference"):
    out = {"value": value, "status": state, "source": source}
    if note:
        out["note"] = note
    return out


APPEARANCE = {
 1:"Colourless, odourless gas.",2:"Colourless, odourless gas.",3:"Soft, silvery-white metal that tarnishes quickly in air.",
 6:"Graphite is a soft grey-black solid; diamond is a hard, transparent crystal.",7:"Colourless, odourless gas.",
 8:"Colourless, odourless gas; liquid oxygen is pale blue.",9:"Pale yellow gas.",10:"Colourless gas that glows red-orange in a discharge tube.",
 11:"Soft, silvery metal that tarnishes quickly in air.",12:"Shiny grey-white metal.",13:"Silvery-white, lightweight metal.",
 14:"Hard, shiny blue-grey crystalline solid.",15:"White phosphorus is a waxy, pale solid; red phosphorus is a dark red powder.",
 16:"Bright yellow crystalline solid.",17:"Pale yellow-green gas with a sharp smell.",18:"Colourless, odourless gas.",
 19:"Soft, silvery metal that tarnishes quickly in air.",20:"Silvery-grey metal.",26:"Lustrous grey metal.",29:"Reddish-orange metal.",
 30:"Bluish-silver metal.",35:"Dark red-brown liquid giving off orange-brown vapour.",47:"Bright, white-grey metal.",
 50:"Silvery-white metal.",53:"Shiny grey-violet solid that gives off violet vapour.",79:"Soft, bright yellow metal.",
 80:"Heavy, silvery liquid metal.",82:"Soft, dull blue-grey metal.",
}
DESCRIPTION = {
 1:"The lightest and most abundant element in the universe. It burns in oxygen to form water.",
 2:"A chemically inert noble gas used to fill balloons and cool equipment.",
 6:"The basis of organic chemistry; it forms the backbone of living molecules.",
 7:"Makes up about four-fifths of air and is chemically unreactive as N2.",
 8:"Needed for combustion and respiration; it makes up about one fifth of air.",
 11:"A very reactive metal that reacts vigorously with water, so it is stored under oil.",
 17:"A reactive halogen used to disinfect water; it forms table salt with sodium.",
 19:"A very reactive metal that reacts violently with water; essential to living cells.",
 20:"A reactive metal found in limestone, chalk and bones.",
 26:"The most widely used metal. It rusts when exposed to damp air.",
 29:"A good conductor of heat and electricity; its salts such as copper sulfate are blue.",
 47:"A precious metal with the highest electrical conductivity of any element.",
 79:"A dense, soft, unreactive precious metal.",
 80:"The only common metal that is liquid at room temperature. Its vapour is poisonous.",
}
HAZARD = {
 3:"Reacts with water; keep away from moisture. Corrosive.",11:"Reacts violently with water and can ignite. Corrosive; store under oil.",
 19:"Reacts violently with water and can ignite. Corrosive; store under oil.",9:"Extremely reactive, toxic and corrosive gas.",
 17:"Toxic gas; irritates the eyes and lungs.",35:"Toxic and corrosive; the vapour burns the airways and skin.",
 53:"Harmful vapour; stains and irritates skin.",80:"Toxic, especially as vapour; spills need special clean-up.",
 82:"Toxic by ingestion and inhalation of dust or fumes.",48:"Toxic and a suspected carcinogen.",33:"Toxic; compounds are poisons.",
 4:"Dust and fumes are toxic when inhaled.",15:"White phosphorus ignites in air and is poisonous.",
 1:"Highly flammable gas; forms explosive mixtures with air.",
}
OXIDATION = {1:[-1,1],3:[1],4:[2],5:[3],6:[-4,2,4],7:[-3,3,5],8:[-2],9:[-1],11:[1],12:[2],13:[3],14:[4],15:[-3,3,5],16:[-2,4,6],
 17:[-1,1,3,5,7],19:[1],20:[2],24:[2,3,6],25:[2,4,7],26:[2,3],27:[2,3],28:[2],29:[1,2],30:[2],33:[-3,3,5],34:[-2,4,6],
 35:[-1,1,5],47:[1],48:[2],50:[2,4],53:[-1,1,5,7],55:[1],56:[2],79:[1,3],80:[1,2],82:[2,4],2:[0],10:[0],18:[0]}


def parse(value, cast=float):
    value = value.strip()
    if value == "EMPTY":
        return None
    return cast(value.replace(",", ".", 1) if value.count(",") == 1 and "." not in value else value)


def main():
    rows = [line.strip().split("|") for line in (ROOT / "tools/element_source_data.txt").read_text().splitlines()[1:]]
    source = {int(r[0]): r for r in rows}
    elements, problems = [], []
    for z in range(1, 119):
        symbol, name = SYMBOLS[z - 1], NAMES[z - 1]
        period, group, block = period_group_block(z)
        config, shell_list = configuration(z)
        entry = {"atomic_number": z, "symbol": symbol, "name": name,
                 "period": period, "group": group, "block": block, "category": category(z, group)}
        entry["structure_source"] = "derived from atomic number by the standard periodic-table layout (f block = La-Yb and Ac-No, group 3 = Sc, Y, Lu, Lr)"
        if z in MASS or z in MASS_NUMBER:
            if z in MASS:
                entry["atomic_mass_u"] = status(MASS[z], "abridged standard atomic weight recalled from memory, cross-checked against the source table",
                                                "IUPAC abridged standard atomic weights (recalled)")
            else:
                entry["atomic_mass_u"] = status(float(MASS_NUMBER[z]), "mass number of a long-lived isotope; no standard atomic weight exists. Sources differ for the heaviest elements.",
                                                "conventional mass number (recalled)")
                entry["atomic_mass_is_mass_number"] = True
        row = source.get(z)
        corrections = []
        if row:
            source_mass = row[3].strip("()")
            if z in MASS and abs(float(source_mass) - MASS[z]) > 0.1:
                problems.append(f"mass mismatch Z={z}: recalled {MASS[z]} vs source {source_mass}")
            if z in MASS_NUMBER and z <= 103 and int(float(source_mass)) != MASS_NUMBER[z] and z != 103:
                problems.append(f"mass number mismatch Z={z}: {MASS_NUMBER[z]} vs {source_mass}")
            props = {"melting_c": parse(row[5]), "boiling_c": parse(row[6]), "density_g_cm3": parse(row[7]),
                     "electronegativity_pauling": parse(row[8])}
            for key, (value, why) in CORRECTIONS.get(z, {}).items():
                corrections.append({"field": key, "source_value": props[key], "used": value, "reason": why})
                props[key] = value
            unit = {"melting_c": "degC", "boiling_c": "degC", "density_g_cm3": "g/cm3 (gases at 0 degC, 1 atm)", "electronegativity_pauling": "Pauling scale"}
            for key, value in props.items():
                if value is None:
                    entry[key] = None
                else:
                    entry[key] = status(value)
                    entry[key]["unit"] = unit[key]
                    if any(c["field"] == key for c in corrections):
                        entry[key]["status"] = "unverified_reference"
                        entry[key]["note"] = "corrected from the source table, see corrections"
            state = row[4].strip().lower()
            entry["state_at_stp"] = None if z in STATE_UNKNOWN else status(state, "state at 0 degC and 1 atm")
            if sum(int(x) for x in row[9].split(",")) != z:
                problems.append(f"shell sum mismatch Z={z}")
            if [int(x) for x in row[9].split(",")] != shell_list:
                problems.append(f"shell mismatch Z={z}: source {row[9]} vs derived {shell_list}")
        else:
            for key in ("melting_c", "boiling_c", "density_g_cm3", "electronegativity_pauling", "state_at_stp"):
                entry[key] = None
            entry["unknown_note"] = "Only a few atoms have ever been made; bulk properties are unknown or predicted."
        if z == 33:
            entry["boiling_c"]["note"] = "Sublimation point at 1 atm; the listed melting point applies only under about 28 atm."
        entry["electron_configuration"] = status(config, "ground state by the Madelung rule with known exceptions; checked against the source's shell occupancy"
                                                 if z <= 103 else "predicted (Madelung rule); not measured",
                                                 "derived", "derived")
        entry["electrons_per_shell"] = shell_list
        entry["oxidation_states_common"] = (status(OXIDATION[z], "common oxidation states from general-chemistry teaching, recalled",
                                                    "recalled") if z in OXIDATION else None)
        entry["appearance"] = APPEARANCE.get(z)
        entry["radioactive"] = z in (43, 61) or z >= 84
        entry["hazards"] = HAZARD.get(z) or ("Radioactive: handle only under specialist supervision." if entry["radioactive"] else None)
        entry["description"] = DESCRIPTION.get(z) or f"{name} is element {z}, in period {period}" + \
            (f", group {group}" if group else ", the f block") + f" of the periodic table ({entry['category']})."
        if corrections:
            entry["corrections"] = corrections
        elements.append(entry)
    out = {"version": 1, "note": "Reference data. Every numeric value carries a status; nothing here is peer-reviewed. Unknown values are null, never guessed.",
           "sources": [SOURCE_URL], "elements": elements}
    path = ROOT / "data/elements/elements.json"
    path.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", path, len(elements), "elements")
    for p in problems:
        print("CHECK", p)


if __name__ == "__main__":
    main()
