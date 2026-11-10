class_name DataValue
extends RefCounted
## Reads data values that are either a plain number or an object
## {"value": ..., "unit": ..., "status": ..., "source": ...}.
## The status records provenance (see docs/CHEMISTRY_REQUIREMENTS.md, decision D-013).

## Statuses that need no review flag in the interface.
const TRUSTED_STATUSES: Array = ["reference", "display", "plain"]


static func number(data: Dictionary, key: String, fallback: float) -> float:
	if not data.has(key):
		return fallback
	var entry: Variant = data[key]
	if typeof(entry) == TYPE_DICTIONARY:
		var inner: Dictionary = entry
		if inner.get("value") == null:
			return fallback
		return float(inner["value"])
	if entry == null:
		return fallback
	return float(entry)


static func status(data: Dictionary, key: String) -> String:
	var entry: Variant = data.get(key)
	if typeof(entry) == TYPE_DICTIONARY:
		var inner: Dictionary = entry
		return str(inner.get("status", "unspecified"))
	return "plain"


static func is_trusted(data: Dictionary, key: String) -> bool:
	return TRUSTED_STATUSES.has(status(data, key))


## Parses [r, g, b] or [r, g, b, a] (0..1) into a Color.
static func color(value: Variant, fallback: Color) -> Color:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var parts: Array = value
	if parts.size() < 3:
		return fallback
	var alpha := 1.0 if parts.size() < 4 else float(parts[3])
	return Color(float(parts[0]), float(parts[1]), float(parts[2]), alpha)
