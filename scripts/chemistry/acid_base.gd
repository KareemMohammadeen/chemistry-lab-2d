class_name AcidBase
extends RefCounted
## Acid-base bookkeeping for aqueous vessels. Strong acids and bases are treated as fully
## dissociated, and pH is calculated at 25 °C (pH + pOH = 14). These are documented
## simplifications of the Milestone 1 model.

const PH_NEUTRAL := 7.0
## pH + pOH at 25 °C.
const PH_PLUS_POH := 14.0
## Net concentration (mol/L) below which a solution is reported as neutral.
const NEUTRAL_CONCENTRATION_MOL_PER_L := 1.0e-7


## Total volume (mL) of liquids that act as an aqueous solvent.
static func aqueous_volume_ml(vessel: VesselState, db: ContentDatabase) -> float:
	var total := 0.0
	for chemical_id in vessel.liquids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		if chemical != null and chemical.is_aqueous_solvent:
			total += float(vessel.liquids[chemical_id])
	return total


## Amounts of hydrogen ions and hydroxide ions (mol) added to the vessel, as {"acid", "base"}.
static func moles(vessel: VesselState, db: ContentDatabase) -> Dictionary:
	var acid := 0.0
	var base := 0.0
	for chemical_id in vessel.liquids.keys():
		var chemical := db.get_chemical(str(chemical_id))
		if chemical == null:
			continue
		var litres := float(vessel.liquids[chemical_id]) / 1000.0
		acid += litres * chemical.h_plus_mol_per_l
		base += litres * chemical.oh_minus_mol_per_l
	return {"acid": acid, "base": base}


## Calculated pH of the vessel contents, or NAN when there is no aqueous liquid.
static func compute_ph(vessel: VesselState, db: ContentDatabase) -> float:
	var litres := aqueous_volume_ml(vessel, db) / 1000.0
	if litres <= 0.0:
		return NAN
	var amounts := moles(vessel, db)
	var net_concentration := (float(amounts["acid"]) - float(amounts["base"])) / litres
	if absf(net_concentration) < NEUTRAL_CONCENTRATION_MOL_PER_L:
		return PH_NEUTRAL
	if net_concentration > 0.0:
		return -log(net_concentration) / log(10.0)
	var poh := -log(-net_concentration) / log(10.0)
	return PH_PLUS_POH - poh
