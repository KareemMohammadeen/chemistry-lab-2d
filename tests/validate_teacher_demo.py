#!/usr/bin/env python3
"""Validate the safe classroom demo and evidence-labelled teacher previews."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAFE_PLAYABLE = {"water", "sodium_chloride"}
SAFE_REFERENCE = {"glucose", "sucrose", "starch"}
SAFE_VIRTUAL_GASES = {"carbon_dioxide"}


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
    allowed_materials = SAFE_PLAYABLE | SAFE_REFERENCE | SAFE_VIRTUAL_GASES
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
        selected_equipment = set(preview.get("equipment_ids", []))
        missing_equipment = selected_equipment - equipment_files
        assert not missing_equipment, f"Missing equipment in {preview.get('profile_id')}: {missing_equipment}"
        classroom_equipment = {
            "beaker_250ml", "test_tube_20ml", "thermometer_general",
            "dropper_3ml", "hot_plate_basic",
        }
        assert selected_equipment <= classroom_equipment, (
            f"Non-classroom equipment exposed in {preview.get('profile_id')}: {selected_equipment - classroom_equipment}"
        )
        assert selected_equipment, f"No classroom equipment mapped to {preview.get('profile_id')}"

    for obj in setup.get("objects", []):
        contents = obj.get("contents", {})
        for kind in ("liquids", "solids"):
            ids = set(contents.get(kind, {}).keys())
            assert ids <= SAFE_PLAYABLE, f"Classroom demo setup contains an unapproved reagent: {ids}"

    # Gas support is opt-in and remains separate from the original classroom water/salt setup.
    co2 = read_json(ROOT / "data/chemicals/carbon_dioxide.json")
    assert co2.get("state") == "gas" and co2.get("simulation", {}).get("enabled") is True
    assert co2.get("simulation", {}).get("role") == "virtual_gas"

    experiment_pack = read_json(ROOT / "data/learning/expanded_safe_experiments.json")
    prep2 = next(item for item in experiment_pack["grades"] if item["grade_id"] == "prep2")
    magnesium_demo = next(item for item in prep2["experiments"] if item["id"] == "prep2_magnesium_combustion_observation")
    assert magnesium_demo.get("visual_demo_id") == "magnesium_combustion_virtual_demo"
    assert magnesium_demo.get("curriculum_alignment_status") == "suggested_not_verified_against_official_textbook"
    assert not magnesium_demo.get("steps"), "The magnesium activity must remain observational, not procedural."

    grade_pack = read_json(ROOT / "data/curricula/egypt_2026_2027_safe_experiments.json")
    mapped_prep2 = next(item for item in grade_pack["grade_experiments"] if item["grade_id"] == "prep2")
    assert magnesium_demo["id"] in mapped_prep2["experiment_ids"], "Prep 2 experiment bank mapping missing magnesium demo."

    # Guided activities are restricted to a small, virtual-only classroom command set.
    guided = read_json(ROOT / "data/learning/guided_experiments.json")
    assert guided.get("safety_scope") == "virtual_only_classroom_model"
    allowed_commands = {"pour", "add_solid", "mix"}
    allowed_materials = {"water", "sodium_chloride", "sucrose"}
    allowed_vessels = {"beaker_250ml", "erlenmeyer_flask_250ml", "test_tube_20ml"}
    assert guided.get("experiments"), "Guided experiment list must not be empty"
    for activity in guided["experiments"]:
        assert activity.get("enabled") is True
        assert activity.get("safety_scope") == "virtual_only_classroom_model"
        assert activity.get("alignment_status") == "suggested_not_verified_against_official_textbook"
        for step in activity.get("steps", []):
            if step.get("type") == "action":
                assert step.get("command") in allowed_commands
                assert step.get("interaction_id") in allowed_commands
                source_id = step.get("source_contains_chemical_id", "")
                target_id = step.get("target_contains_chemical_id", "")
                if source_id:
                    assert source_id in allowed_materials
                if target_id:
                    assert target_id in allowed_materials
                assert step.get("target_equipment_id", "beaker_250ml") in allowed_vessels
            elif step.get("type") == "condition":
                assert step.get("condition") == "minimum_dissolved_g"
                assert step.get("chemical_id") in allowed_materials
            else:
                raise AssertionError("Unsupported guided activity step type")

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
