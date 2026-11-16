class_name LabReport
extends RefCounted
## Builds a concise Markdown lab report from the current simulation and command history.
## The report is software-generated and mirrors the same simplified classroom model used in-app.


static func report_path(session_path: String) -> String:
	var base := session_path.get_basename()
	if base.is_empty():
		base = "chemistry_lab_session"
	return "%s.report.md" % base


static func save_to_path(sim: LabSimulation, commands: CommandStack, session_path: String) -> Dictionary:
	var report := build_markdown(sim, commands)
	var path := report_path(session_path)
	var directory := path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"message": "Could not write the lab report.",
			"path": path,
		}
	file.store_string(report)
	return {
		"ok": true,
		"message": "Lab report exported to %s" % path,
		"path": path,
	}


static func build_markdown(sim: LabSimulation, commands: CommandStack) -> String:
	var lines := PackedStringArray()
	lines.append("# Chemistry Lab Report")
	lines.append("")
	lines.append("Generated from the current simulation state and command log.")
	lines.append("")
	lines.append("## Snapshot")
	lines.append("- Simulation time: %s" % UnitFormat.time_mmss(sim.state.time_s))
	lines.append("- Objects on the bench: %d" % sim.state.objects.size())
	lines.append("- Logged actions: %d" % commands.history.size())
	lines.append("")
	lines.append("## Objects")
	for object_id in sim.state.objects.keys():
		var item: LabObject = sim.state.objects[object_id]
		if item == null:
			continue
		lines.append("### %s" % _object_label(sim, item))
		lines.append("- Equipment: %s" % str(item.equipment_id))
		lines.append("- Position: %.1f, %.1f" % [item.position.x, item.position.y])
		if item.vessel == null:
			lines.append("- Vessel: none")
		else:
			lines.append("- Vessel: %s" % ("closed system" if item.vessel.is_closed_system else "open system"))
			lines.append("- Contents: %s" % _summarise_vessel(sim, item.vessel))
			if not item.vessel.observations.is_empty():
				lines.append("- Observations:")
				for observation in item.vessel.observations:
					if typeof(observation) != TYPE_DICTIONARY:
						continue
					lines.append("  - %s: %s" % [UnitFormat.time_mmss(float(observation.get("time_s", 0.0))), str(observation.get("text", ""))])
		lines.append("")
	lines.append("## Actions")
	if commands.history.is_empty():
		lines.append("No actions have been recorded yet.")
	else:
		for entry in commands.history:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var successful := bool(entry.get("ok", false))
			var description := str(entry.get("description", ""))
			if description.is_empty():
				description = str(entry.get("command", ""))
			if not successful:
				var reason := str(entry.get("reason", ""))
				if not reason.is_empty():
					description = "%s — %s" % [description, reason]
			lines.append("- %s  %s  %s" % [
				UnitFormat.time_mmss(float(entry.get("sim_time_s", 0.0))),
				"OK" if successful else "BLOCKED",
				description,
			])
	lines.append("")
	lines.append("## Report note")
	lines.append("This report mirrors the simplified classroom simulation model. It is not a substitute for a real laboratory record or a real safety assessment.")
	return "\n".join(lines)


static func _object_label(sim: LabSimulation, item: LabObject) -> String:
	if sim.has_method("object_label"):
		return str(sim.object_label(item))
	return str(item.equipment_id)


static func _summarise_vessel(sim: LabSimulation, vessel: VesselState) -> String:
	var parts: Array[String] = []
	if not vessel.liquids.is_empty():
		parts.append("liquids: %s" % _format_amounts(sim, vessel.liquids, true))
	if not vessel.solids.is_empty():
		parts.append("solids: %s" % _format_amounts(sim, vessel.solids, false))
	if not vessel.dissolved.is_empty():
		parts.append("dissolved: %s" % _format_amounts(sim, vessel.dissolved, false))
	if not vessel.gases.is_empty():
		parts.append("gases: %s" % _format_gases(sim, vessel.gases))
	if vessel.is_closed_system:
		parts.append("pressure %.1f kPa" % vessel.pressure_kpa(sim.database.constant("ambient_pressure_kpa", 101.325)))
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "empty"


static func _format_amounts(sim: LabSimulation, ledger: Dictionary, use_volume: bool) -> String:
	var parts: Array[String] = []
	for chemical_id in ledger.keys():
		var amount := float(ledger[chemical_id])
		var label := str(chemical_id)
		var chemical := sim.database.get_chemical(str(chemical_id))
		if chemical != null:
			label = chemical.display_name
		parts.append("%s %s" % [label, UnitFormat.volume_ml(amount) if use_volume else UnitFormat.mass_g(amount)])
	return ", ".join(PackedStringArray(parts))


static func _format_gases(sim: LabSimulation, ledger: Dictionary) -> String:
	var parts: Array[String] = []
	for chemical_id in ledger.keys():
		var amount := float(ledger[chemical_id])
		var label := str(chemical_id)
		var chemical := sim.database.get_chemical(str(chemical_id))
		if chemical != null:
			label = chemical.display_name
		parts.append("%s %.4f mol" % [label, amount])
	return ", ".join(PackedStringArray(parts))
