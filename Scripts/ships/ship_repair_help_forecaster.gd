class_name ShipRepairHelpForecaster
extends RefCounted

var ship
var action_planner: ShipActionPlanner


func _init(new_ship, new_action_planner: ShipActionPlanner) -> void:
	ship = new_ship
	action_planner = new_action_planner


func get_crewmate_bail_rate(crewmate: Crewmate) -> float:
	if crewmate == null or action_planner == null:
		return 0.0

	var bail_cycle_duration = action_planner.estimate_repair_bail_cycle_duration(crewmate)

	if bail_cycle_duration <= 0.0 or bail_cycle_duration == INF:
		return 0.0

	return Crewmate.MAX_BUCKET_AMOUNT / bail_cycle_duration


func is_bailing_outmatched(
	crewmate: Crewmate,
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	repairing_crewmate: Crewmate
) -> bool:

	var bail_rate = get_crewmate_bail_rate(crewmate)

	if bail_rate <= 0.0:
		return true

	return get_effective_flood_rate(active_crewmates, roles, repairing_crewmate) > bail_rate


func get_effective_flood_rate(
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	repairing_crewmate: Crewmate
) -> float:

	if ship == null or ship.health_system == null:
		return 0.0

	var flood_rate = ship.health_system.get_flood_rate()

	for crewmate in active_crewmates:
		if (
			crewmate == null
			or crewmate == repairing_crewmate
			or not _is_active_bailer_support(crewmate, roles)
		):
			continue

		flood_rate = max(flood_rate - get_crewmate_bail_rate(crewmate), 0.0)

	return flood_rate


func print_doomed_bailing_help_request_if_needed(
	crewmate: Crewmate,
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	help_requested: Dictionary
) -> void:

	if (
		crewmate == null
		or ship == null
		or ship.health_system == null
		or action_planner == null
	):
		return

	var own_bail_rate = get_crewmate_bail_rate(crewmate)

	if own_bail_rate <= 0.0:
		return

	var flood_after_own_bail = max(
		get_effective_flood_rate(active_crewmates, roles, crewmate) - own_bail_rate,
		0.0
	)

	if flood_after_own_bail <= 0.0:
		help_requested.erase(crewmate)
		return

	if help_requested.get(crewmate, false):
		return

	help_requested[crewmate] = true
	ShipDebugLog.write(
		&"repair",
		"%s: I need help! I can slow the flooding, but we are still sinking." % crewmate.name
	)


func _is_active_bailer_support(crewmate: Crewmate, roles: Dictionary) -> bool:
	return (
		roles.get(crewmate, -1) == ShipRepairDutyController.RepairRole.BAILER
		and crewmate.action_executor != null
		and crewmate.action_executor.has_actions()
	)
