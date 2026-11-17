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
	_check(content.element_catalog.size() > 0, "element catalog built by ContentDatabase")
	_check(content.get_element_cards().size() == content.elements_by_number.size(),
		"catalog covers every loaded element")

	var mercury: Dictionary = content.get_element_card("Hg")
	var bromine: Dictionary = content.get_element_card("Br")
	var hydrogen: Dictionary = content.get_element_card("H")

	_check(not mercury.is_empty(), "mercury card exists")
	_check(not bromine.is_empty(), "bromine card exists")
	_check(not hydrogen.is_empty(), "hydrogen card exists")
	_check(str(mercury.get("state_at_stp", "")) == "liquid", "mercury is marked liquid")
	_check(str(mercury.get("display_form", "")) == "liquid sample", "mercury display form is liquid sample")
	_check(not str(mercury.get("summary", "")).is_empty(), "mercury has a summary")
	_check(str(bromine.get("state_at_stp", "")) == "liquid", "bromine is marked liquid")
	_check(str(hydrogen.get("state_at_stp", "")) == "gas", "hydrogen is marked gas")
	_check(str(hydrogen.get("display_form", "")) == "gas sample", "hydrogen display form is gas sample")

	for card in content.get_element_cards():
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
