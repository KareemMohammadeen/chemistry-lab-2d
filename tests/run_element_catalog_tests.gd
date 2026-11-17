extends SceneTree
## Headless checks for the normalized element catalog.
## Run:
##   godot --headless --path . -s tests/run_element_catalog_tests.gd
## Exit code is 0 when every check passes.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var content := ContentDatabase.new()
	content.load_all()
	_check(content.errors.is_empty(), "content loads without errors: %s" % str(content.errors))
	_check(content.elements.size() > 0, "element reference data loaded")

	var catalog := ElementCatalog.build_index(content.elements_by_number)
	var by_symbol: Dictionary = catalog.get("by_symbol", {})
	var by_number: Dictionary = catalog.get("by_number", {})
	var cards: Array = catalog.get("list", [])

	_check(by_number.size() == content.elements_by_number.size(),
		"catalog covers every element by atomic number (%d cards for %d elements)" % [by_number.size(), content.elements_by_number.size()])
	_check(cards.size() == content.elements_by_number.size(),
		"catalog list includes every element (%d cards)" % cards.size())
	_check(by_symbol.has("Hg"), "mercury card exists")
	_check(by_symbol.has("Br"), "bromine card exists")
	_check(by_symbol.has("H"), "hydrogen card exists")

	var mercury: Dictionary = by_symbol.get("Hg", {})
	_check(str(mercury.get("state_at_stp", "")) == "liquid", "mercury is marked liquid")
	_check(str(mercury.get("display_form", "")) == "liquid sample", "mercury display form is liquid sample")
	_check(not str(mercury.get("summary", "")).is_empty(), "mercury has a summary")

	var bromine: Dictionary = by_symbol.get("Br", {})
	_check(str(bromine.get("state_at_stp", "")) == "liquid", "bromine is marked liquid")

	var hydrogen: Dictionary = by_symbol.get("H", {})
	_check(str(hydrogen.get("state_at_stp", "")) == "gas", "hydrogen is marked gas")
	_check(str(hydrogen.get("display_form", "")) == "gas sample", "hydrogen display form is gas sample")

	for card in cards:
		_check(int(card.get("atomic_number", 0)) > 0, "card has a valid atomic number")
		_check(not str(card.get("id", "")).is_empty(), "card has an element id")
		_check(not str(card.get("name", "")).is_empty(), "card has a display name")
		_check(not str(card.get("summary", "")).is_empty(), "card has a summary")

	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("OK: %s" % message)
		return
	_failures += 1
	push_error("FAIL: %s" % message)
