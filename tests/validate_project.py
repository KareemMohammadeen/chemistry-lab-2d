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

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        print(f"{len(errors)} JSON error(s) detected")
        return 1

    print("Validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
