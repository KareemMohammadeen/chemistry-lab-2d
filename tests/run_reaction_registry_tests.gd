extends SceneTree
## Headless coverage for the reaction registry contract.

var _content: ContentDatabase
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_content = ContentDatabase.new()
	_content.load_all()
	_check(_content.errors.is_empty(), "content loads without errors: %s" % str(_content.errors))
	_check(_content.reaction_registry != null, "reaction registry loads")
	_check(_content.reaction_registry.has_reaction("dissolve_sodium_chloride"), "sodium chloride dissolution is registered")
	_check(_content.reaction_registry.is_enabled("dissolve_sodium_chloride"), "sodium chloride dissolution is enabled")
	_check(_content.reaction_registry.has_reaction("boil_water"), "boiling is registered")
	_check(_content.reaction_registry.is_enabled("boil_water"), "boiling is enabled")
	_check(_content.reaction_registry.has_reaction("magnesium_combustion_virtual_demo"), "magnesium demo remains explicitly registered")
	_check(not _content.reaction_registry.is_enabled("magnesium_combustion_virtual_demo"), "magnesium demo stays disabled")

	var dissolution := _content.find_dissolution("sodium_chloride")
	_check(dissolution != null and dissolution.id == "dissolve_sodium_chloride", "dissolution lookup resolves the sodium chloride handler")

	var boiling := _content.first_enabled_reaction_of_type("boiling")
	_check(boiling != null and boiling.id == "boil_water", "boiling lookup resolves the boiling handler")

	var neutralisation := _content.first_enabled_reaction_of_type("neutralisation")
	_check(neutralisation != null and neutralisation.id == "neutralisation_strong_acid_strong_base", "neutralisation lookup resolves the neutralisation handler")

	var first_dissolution := _content.first_enabled_reaction_of_type("dissolution")
	_check(first_dissolution != null and first_dissolution.type == "dissolution", "the registry exposes an enabled dissolution reaction")

	print("\n%d check(s), %d failure(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error(label)
