class_name UnitFormat
extends RefCounted
## Formats quantities for display. Every readout in the interface goes through here so
## units and decimal places stay consistent.


## "0.25x", "1x", "8x". GDScript's % operator has no %g, so the number is formatted by String.num.
static func speed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%dx" % int(roundf(value))
	return "%sx" % String.num(value)


static func volume_ml(value: float) -> String:
	if value >= 100.0:
		return "%.0f mL" % value
	if value >= 10.0:
		return "%.1f mL" % value
	return "%.2f mL" % value


static func mass_g(value: float) -> String:
	if value >= 100.0:
		return "%.0f g" % value
	return "%.2f g" % value


static func temperature_c(value: float) -> String:
	return "%.1f °C" % value


@warning_ignore("integer_division")
static func time_mmss(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]
