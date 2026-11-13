#!/usr/bin/env python3
"""Validate the safe classroom demo and evidence-labelled teacher previews."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAFE_PLAYABLE = {"water", "sodium_chloride"}
SAFE_REFERENCE = {"glucose", "sucrose", "starch"}


def read_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    guide = read_json(ROOT / "data/learning/learning_guide.json")
    preview_file = read_json(ROOT / "data/learning/teacher_previews.json")
    curriculum = read_json(ROOT / "data/curricula/egypt_2026_2027.json")
    setup = read_json(ROOT / "data/setups/classroom_demo.json")

    profiles = {item["id"] for item in curriculum["profiles"]}
    previews = preview_file.get("grade_previews", [])
    preview_ids = [item.get("profile_id") for item in previews]
    assert set(preview_ids) == profiles, "Each curriculum profile must have one teacher preview"
    assert len(preview_ids) == len(set(preview_ids)), "Duplicate teacher preview profile"

    equipment_files = {path.stem for path in (ROOT / "data/equipment").glob("*.json")}
    material_ids = {item.get("id") for item in guide.get("materials", [])}
    allowed_materials = SAFE_PLAYABLE | SAFE_REFERENCE
    assert SAFE_PLAYABLE.issubset(material_ids), "Classroom materials missing from learning guide"

    for preview in previews:
        assert preview.get("curriculum_alignment_status") in {
            "suggested_not_verified_against_official_textbook",
            "pathway_and_official_textbook_review_required",
        }, f"Preview must not claim verified curriculum mapping: {preview.get('profile_id')}"
        assert preview.get("title") and preview.get("focus")
        assert preview.get("virtual_flow"), "Teacher flow must describe software use"
        assert set(preview.get("material_ids", [])) <= allowed_materials, (
            f"Non-classroom material exposed in {preview.get('profile_id')}"
        )
        missing_equipment = set(preview.get("equipment_ids", [])) - equipment_files
        assert not missing_equipment, f"Missing equipment in {preview.get('profile_id')}: {missing_equipment}"

    for obj in setup.get("objects", []):
        contents = obj.get("contents", {})
        for kind in ("liquids", "solids"):
            ids = set(contents.get(kind, {}).keys())
            assert ids <= SAFE_PLAYABLE, f"Classroom demo setup contains an unapproved reagent: {ids}"

    source_ids = {item.get("id") for item in guide.get("sources", [])}
    required_sources = {
        "openstax_dissolution",
        "openstax_phase_transitions",
        "acs_secondary_safety",
        "moe_prep_books",
        "moe_secondary_books",
    }
    assert required_sources.issubset(source_ids), "A required learning or official curriculum source is missing"

    print("PASS: five teacher previews, safe demo materials, equipment references and source catalogue.")
    print("NOTE: grade-by-grade official unit alignment remains pending textbook/pathway verification.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
