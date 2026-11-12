#!/usr/bin/env python3
"""Validate the curriculum metadata and 118-element reference catalogue.

Run from the repository root:
    python3 tests/validate_curriculum.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "curricula" / "egypt_2026_2027.json"
ELEMENTS = ROOT / "data" / "elements" / "elements.json"

def read_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

def main() -> int:
    curriculum = read_json(DATA)
    element_data = read_json(ELEMENTS)

    expected = ["prep1", "prep2", "prep3", "senior1", "senior2"]
    profiles = curriculum.get("profiles", [])
    ids = [item.get("id") for item in profiles]
    assert ids == expected, f"Unexpected grade order/IDs: {ids}"
    assert len(ids) == len(set(ids)), "Duplicate grade profile IDs"

    sources = {item.get("id"): item for item in curriculum.get("sources", [])}
    assert len(sources) == len(curriculum.get("sources", [])), "Duplicate source IDs"
    for profile in profiles:
        assert profile.get("label") and profile.get("subject"), f"Incomplete profile: {profile}"
        for source_id in profile.get("source_ids", []):
            assert source_id in sources, f"{profile['id']} references missing source {source_id}"
        assert profile.get("topic_mapping_status"), f"{profile['id']} has no topic mapping status"

    assert "senior1_integrated_science_statement" in sources
    senior1 = next(item for item in profiles if item["id"] == "senior1")
    assert senior1["subject"] == "Integrated Science"
    assert senior1["subject_status"] == "confirmed_by_ministry_statement"

    senior2 = next(item for item in profiles if item["id"] == "senior2")
    assert senior2["subject_status"] == "requires_pathway_confirmation"

    elements = element_data.get("elements", [])
    numbers = [int(item["atomic_number"]) for item in elements]
    symbols = [item["symbol"] for item in elements]
    assert numbers == list(range(1, 119)), "Element atomic numbers must cover 1..118 in order"
    assert len(set(symbols)) == 118, "Element symbols must be unique"

    # Curriculum metadata must not define reagent recipes or enable elemental reactions.
    forbidden_keys = {"reaction", "reactions", "recipe", "procedure", "mixing_steps"}
    for profile in profiles:
        assert not forbidden_keys.intersection(profile.keys()), "Curriculum profile must remain metadata-only"

    print("PASS: 5 grade profiles, source references, and all 118 element reference records.")
    print("NOTE: topic-by-topic syllabus mapping is intentionally pending official textbook review.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
