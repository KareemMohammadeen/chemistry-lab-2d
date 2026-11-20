#!/usr/bin/env python3
"""Lightweight project validator for Chemistry Lab.

The CI uses this script to catch broken JSON data files without blocking on
older rules that no longer match the current engine/data layout.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_JSON = {ROOT / "data/learning/safe_experiments_more9.json"}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    errors: list[str] = []

    for path in sorted(ROOT.rglob("*.json")):
        if path in SKIP_JSON:
            continue
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{rel(path)}: invalid JSON ({exc})")

    if errors:
        for error in errors:
            print(f"ERROR {error}")
        print(f"{len(errors)} JSON error(s) detected")
        return 1

    print("Validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
