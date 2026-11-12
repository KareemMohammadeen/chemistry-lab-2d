class_name CurriculumCatalog
extends RefCounted
## Loads evidence-aware school-year profiles. This is curriculum metadata only: it does not
## unlock chemical reagents or change simulation rules.

const DATA_PATH := "res://data/curricula/egypt_2026_2027.json"

var profiles: Array = []
var profiles_by_id: Dictionary = {}
var sources_by_id: Dictionary = {}
var errors: PackedStringArray = []


func load_profiles() -> void:
	profiles.clear()
	profiles_by_id.clear()
	sources_by_id.clear()
	errors.clear()
	var data := JsonDataLoader.load_dictionary(DATA_PATH)
	if data.is_empty():
		errors.append("Could not load curriculum data: %s" % DATA_PATH)
		return
	for source_value in data.get("sources", []):
		if typeof(source_value) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = source_value
		var source_id := str(source.get("id", ""))
		if source_id.is_empty() or sources_by_id.has(source_id):
			errors.append("Curriculum data contains an empty or duplicate source id.")
			continue
		sources_by_id[source_id] = source.duplicate(true)
	for profile_value in data.get("profiles", []):
		if typeof(profile_value) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_value
		var profile_id := str(profile.get("id", ""))
		if profile_id.is_empty() or profiles_by_id.has(profile_id):
			errors.append("Curriculum data contains an empty or duplicate profile id.")
			continue
		var missing_sources: Array[String] = []
		for source_id_value in profile.get("source_ids", []):
			var source_id := str(source_id_value)
			if not sources_by_id.has(source_id):
				missing_sources.append(source_id)
		if not missing_sources.is_empty():
			errors.append("Curriculum profile '%s' references unknown sources: %s" % [profile_id, str(missing_sources)])
			continue
		profiles.append(profile.duplicate(true))
		profiles_by_id[profile_id] = profile.duplicate(true)
	if profiles.is_empty():
		errors.append("Curriculum data contains no grade profiles.")


func get_profile(profile_id: String) -> Dictionary:
	if not profiles_by_id.has(profile_id):
		return {}
	var profile: Dictionary = profiles_by_id[profile_id]
	return profile.duplicate(true)


func get_source(source_id: String) -> Dictionary:
	if not sources_by_id.has(source_id):
		return {}
	var source: Dictionary = sources_by_id[source_id]
	return source.duplicate(true)
