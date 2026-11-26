#!/usr/bin/env python3
"""Lightweight project validator for Chemistry Lab.

The CI uses this script to catch broken JSON data files without blocking on
older rules that no longer match the current engine/data layout.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_JSON = {ROOT / "data/learning/safe_experiments_more9.json"}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_json(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def check_input_bindings() -> list[str]:
    """Every InputActions constant needs a binding, and every binding needs a constant."""
    source = (ROOT / "scripts/core/input_actions.gd").read_text(encoding="utf-8")
    constants = set(re.findall(r'const\s+\w+\s*:=\s*&"([a-z_]+)"', source))
    bound = set(load_json("data/input/default_bindings.json")["actions"])
    errors = [f"input action '{name}' has no binding" for name in sorted(constants - bound)]
    errors += [f"binding '{name}' has no InputActions constant" for name in sorted(bound - constants)]
    return errors


def check_speed_presets() -> list[str]:
    values = load_json("data/simulation/simulation_constants.json")["values"]
    speeds = values.get("speeds", [])
    errors: list[str] = []
    if 1 not in speeds and 1.0 not in speeds:
        errors.append("simulation speeds must include the normal 1x speed")
    if not any(isinstance(v, (int, float)) and 0 < v < 1 for v in speeds):
        errors.append("simulation speeds must include at least one slow-motion preset below 1x")
    if any(not isinstance(v, (int, float)) or v <= 0 for v in speeds):
        errors.append("simulation speeds must all be positive numbers")
    if speeds != sorted(speeds):
        errors.append("simulation speeds must be listed slowest to fastest")
    return errors


def check_setups() -> list[str]:
    """Setups may only place equipment that exists in data/equipment."""
    known = {p.stem for p in (ROOT / "data/equipment").glob("*.json")}
    errors: list[str] = []
    for path in sorted((ROOT / "data/setups").glob("*.json")):
        for item in json.loads(path.read_text(encoding="utf-8")).get("objects", []):
            if item.get("equipment") not in known:
                errors.append(f"{rel(path)}: unknown equipment '{item.get('equipment')}'")
    return errors


def check_resource_paths() -> list[str]:
    """Every preload/load of a res:// path in scripts must point at an existing file."""
    errors: list[str] = []
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        for match in re.findall(r'(?:preload|load)\("res://([^"]+)"\)', path.read_text(encoding="utf-8")):
            if not (ROOT / match).exists():
                errors.append(f"{rel(path)}: missing resource res://{match}")
    return errors


def check_workspace_layering() -> list[str]:
    """The workspace lives inside the UI tree, so its z values must be ordered and in range.

    Equipment must stay above the backdrop (z 0) however far from the origin it is, drag and
    effects above equipment, and everything inside Godot's +-4096 z limit.
    """
    source = (ROOT / "scripts/ui/lab_workspace.gd").read_text(encoding="utf-8")
    z = {n: int(v) for n, v in re.findall(r"^const (\w*Z\w*|VIEW_Z_SPAN) := (-?\d+)", source, re.M)}
    errors: list[str] = []
    needed = ["VIEW_Z_BASE", "VIEW_Z_SPAN", "SPECIMEN_Z", "SPECIMEN_DRAG_Z", "DRAG_Z"]
    missing = [n for n in needed if n not in z]
    if missing:
        return [f"lab_workspace.gd is missing z constants: {missing}"]
    if z["VIEW_Z_BASE"] - z["VIEW_Z_SPAN"] <= 0:
        errors.append("equipment z range must stay above the backdrop (z 0)")
    if not z["VIEW_Z_BASE"] + z["VIEW_Z_SPAN"] + 2 < z["SPECIMEN_Z"] < z["SPECIMEN_DRAG_Z"] < z["DRAG_Z"] < 2000:
        errors.append("z order must be equipment < specimens < dragged specimen < dragged equipment < effects (2000)")
    scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
    if re.search(r'instance=ExtResource\("2"\)\]\s*\nz_index = -', scene):
        errors.append("main.tscn must not give the workspace a negative z_index (it hides the bench behind the stage frame)")
    return errors


def check_ghost_interaction_guards() -> list[str]:
    """Structural guards against objects that are drawn (or hit-tested) for state that no longer exists."""
    workspace = (ROOT / "scripts/ui/lab_workspace.gd").read_text(encoding="utf-8")
    controller = (ROOT / "scripts/interaction/interaction_controller.gd").read_text(encoding="utf-8")
    view = (ROOT / "scripts/ui/equipment_view.gd").read_text(encoding="utf-8")
    main = (ROOT / "scripts/core/main.gd").read_text(encoding="utf-8")
    errors: list[str] = []
    if "bound_equipment_id" not in view or "view.bound_equipment_id != item.equipment_id" not in workspace:
        errors.append("lab_workspace.gd must rebuild a view whose object id now holds different equipment")
    if "state_restored.connect(_on_state_restored)" not in workspace:
        errors.append("lab_workspace.gd must reconcile its views on LabSimulation.state_restored")
    if "state_restored.connect(_on_state_restored)" not in controller:
        errors.append("interaction_controller.gd must reconcile remembered object ids on state_restored")
    body = re.search(r"func object_id_at\(.*?\n\n\n", workspace, re.S)
    if body is None or "is_point_on_stage(point)" not in body.group(0):
        errors.append("object_id_at must refuse points outside the visible stage")
    if "_stage_rect.has_point" in workspace:
        errors.append("lab_workspace.gd must gate pointer input with is_screen_point_on_stage, not the pushed stage copy")
    if "clear_reference_samples" not in controller or "on_lab_replaced" not in main:
        errors.append("Reset and Open experiment must clear reference samples (on_lab_replaced)")
    if re.search(r"(?<!_samples_root\.)add_child\(specimen\)", workspace):
        errors.append("reference samples must be added to the ReferenceSamples node so they can be cleared")
    return errors


def check_reactions() -> list[str]:
    """Static consistency of reaction definitions, the V3 registry and chemical data."""
    errors: list[str] = []
    registry = load_json("data/reaction_registry_v3.json")
    handlers = registry.get("handlers", {})
    entries = {entry["id"]: entry for entry in registry.get("reactions", [])}
    chemicals = {p.stem: load_json(rel(p)) for p in sorted((ROOT / "data/chemicals").glob("*.json"))}
    compounds = {}
    for path in sorted((ROOT / "data/compounds").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        compounds[data.get("id", path.stem)] = data
    definitions = {}
    for path in sorted((ROOT / "data/reactions").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "reactions" in data or data.get("id") is None:
            continue  # the legacy index file lists reactions; it is not a definition
        definitions[data["id"]] = data
        if path.stem != data["id"]:
            errors.append(f"{rel(path)}: file name does not match id '{data['id']}'")
    supported_conditions = {"temperature", "pressure", "ph", "closed_system", "catalyst"}
    for reaction_id, data in definitions.items():
        entry = entries.get(reaction_id)
        if entry is None:
            errors.append(f"reaction '{reaction_id}' is not in the V3 registry")
            continue
        handler = handlers.get(entry.get("handler_id"))
        if handler is None:
            errors.append(f"reaction '{reaction_id}' uses unknown handler '{entry.get('handler_id')}'")
        elif handler.get("reaction_type") != data.get("type"):
            errors.append(f"reaction '{reaction_id}' has type '{data.get('type')}' but its handler expects '{handler.get('reaction_type')}'")
        enabled = bool(entry.get("enabled", False))
        if not enabled and not entry.get("disabled_reason"):
            errors.append(f"reaction '{reaction_id}' is disabled without a disabled_reason")
        if data.get("type") == "visual_demo":
            continue
        participants = list(data.get("reactants", [])) + list(data.get("products", []))
        for key in ("solute", "substance"):
            if data.get(key):
                participants.append({"chemical_id": data[key], "phase": "solid" if key == "solute" else "liquid"})
        for participant in participants:
            chemical = chemicals.get(participant.get("chemical_id"))
            if chemical is None:
                errors.append(f"reaction '{reaction_id}' refers to unknown chemical '{participant.get('chemical_id')}'")
                continue
            if enabled and data.get("reactants") and participant.get("phase") != "gas":
                # Mirrors ReactionEngineFinal._moles_per_ledger_unit: a prepared solution needs its
                # concentration, anything else needs a molar mass on the chemical or its compound record.
                has_mass = "molar_mass_g_mol" in chemical or "molar_mass_g_mol" in compounds.get(participant["chemical_id"], {})
                is_solution = participant.get("phase") == "liquid" and "concentration_mol_per_l" in chemical
                if not (has_mass or is_solution):
                    errors.append(f"enabled reaction '{reaction_id}': '{participant['chemical_id']}' has no molar mass or solution concentration for mole conversion")
        if enabled:
            for condition in data.get("conditions", []):
                if not isinstance(condition, dict) or condition.get("type") not in supported_conditions:
                    errors.append(f"enabled reaction '{reaction_id}' has an unsupported condition {condition}")
    for reaction_id in entries:
        if reaction_id not in definitions:
            errors.append(f"registry entry '{reaction_id}' has no definition file")
    return errors


def main() -> int:
    errors: list[str] = []

    for path in sorted(ROOT.rglob("*.json")):
        if path in SKIP_JSON:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{rel(path)}: invalid JSON ({exc})")

    errors.extend(check_input_bindings())
    errors.extend(check_speed_presets())
    errors.extend(check_setups())
    errors.extend(check_resource_paths())
    errors.extend(check_workspace_layering())
    errors.extend(check_ghost_interaction_guards())
    errors.extend(check_reactions())

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        print(f"{len(errors)} JSON error(s) detected")
        return 1

    print("Validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
