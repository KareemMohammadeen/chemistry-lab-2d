class_name ElementCatalog
extends RefCounted
## Builds a normalized, UI-friendly card for every element loaded from
## data/elements/elements.json. This keeps the reference file as the source of truth
## while giving the game a consistent, easy-to-read element view.

static func build_index(elements_by_number: Dictionary) -> Dictionary:
	var by_symbol: Dictionary = {}
	var by_number: Dictionary = {}
	var cards: Array = []

	var numbers: Array = elements_by_number.keys()
	numbers.sort()
	for atomic_number in numbers:
		var element: ElementDefinition = elements_by_number.get(atomic_number)
		if element == null:
			continue
		var card := build_card(element)
		cards.append(card)
		by_symbol[card["symbol"]] = card
		by_number[card["atomic_number"]] = card

	return {
		"by_symbol": by_symbol,
		"by_number": by_number,
		"list": cards,
	}


static func build_card(element: ElementDefinition) -> Dictionary:
	var display_name := _safe_text(element.display_name, element.id)
	var state := _safe_text(element.state_at_stp, "unknown")
	var category := _safe_text(element.category, "unknown")
	var group_text := "the f-block" if element.group <= 0 else "group %d" % element.group
	var summary := "%s (%s) is element %d, a %s in period %d, %s. At standard conditions it is a %s." % [
		display_name,
		element.id,
		element.atomic_number,
		category,
		element.period,
		group_text,
		state,
	]
	return {
		"id": element.id,
		"atomic_number": element.atomic_number,
		"symbol": element.id,
		"name": display_name,
		"display_name": display_name,
		"period": element.period,
		"group": element.group,
		"block": element.block,
		"category": category,
		"state_at_stp": state,
		"display_form": _display_form_for_state(state),
		"summary": summary,
		"search_terms": [display_name, element.id, category, state, str(element.atomic_number)],
		"appearance": null if element.appearance.is_empty() else element.appearance,
		"hazards": null if element.hazards.is_empty() else element.hazards,
		"radioactive": element.radioactive,
	}


static func _display_form_for_state(state: String) -> String:
	match state:
		"gas":
			return "gas sample"
		"liquid":
			return "liquid sample"
		"solid":
			return "solid sample"
		_:
			return "unknown sample"


static func _safe_text(value: String, fallback: String) -> String:
	if value == null:
		return fallback
	var cleaned := str(value).strip_edges()
	return cleaned if not cleaned.is_empty() else fallback