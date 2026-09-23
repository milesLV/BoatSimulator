class_name ShipRepairDutyController
extends RefCounted

enum RepairRole {
	NONE,
	BAILER,
	REPAIRER
}

enum RepairPlanReason {
	NONE,
	REPAIR_HOLE,
	ENTRY_BAIL,
	SAFETY_BAIL,
	NO_ROUTE,
	NO_SAFE_HOLE,
	DONE
}

var ship
var action_points: ShipActionPointContainer
var action_planner: ShipActionPlanner
var help_forecaster: ShipRepairHelpForecaster
var crew_task_controller: ShipCrewTaskController

var active_crewmates: Array[Crewmate] = []
var roles: Dictionary = {}
var hole_by_crewmate: Dictionary = {}
var crewmate_by_hole: Dictionary = {}
var help_requested: Dictionary = {}


func _init(
	new_ship,
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	ship = new_ship
	action_points = new_action_points
	action_planner = new_action_planner
	help_forecaster = ShipRepairHelpForecaster.new(ship, action_planner)


func assign_crewmate(crewmate: Crewmate) -> bool:

	if crewmate == null or action_planner == null:
		return false

	crew_task_controller.prepare_for_repair_duty(crewmate)

	if not active_crewmates.has(crewmate):
		active_crewmates.append(crewmate)

	Crewmate.set_queue_finished_listener(crewmate, _on_crewmate_queue_finished, true)

	ShipDebugLog.write(&"repair",
		"%s: repair duty assigned."
		% crewmate.name
	)

	release_hole_for(crewmate)

	return queue_next_action(crewmate, true)


func clear_crewmate(crewmate: Crewmate, reason := "unspecified") -> bool:
	if crewmate == null:
		return false

	var was_active = active_crewmates.has(crewmate)

	if was_active:
		ShipDebugLog.write(&"repair",
			"%s: repair duty cleared (%s)."
			% [
				crewmate.name,
				reason
			]
		)

	active_crewmates.erase(crewmate)
	roles.erase(crewmate)
	help_requested.erase(crewmate)
	Crewmate.set_queue_finished_listener(crewmate, _on_crewmate_queue_finished, false)
	release_hole_for(crewmate)

	return was_active


func clear_all() -> void:

	for crewmate in active_crewmates.duplicate():
		clear_crewmate(crewmate, "clear all")


func queue_next_action(crewmate: Crewmate, replace_current := false) -> bool:
	if crewmate == null or action_planner == null:
		return false

	if not active_crewmates.has(crewmate):
		return false

	_cleanup_reservations()
	release_hole_for(crewmate)

	var plan = plan_next_repair_step(crewmate)

	_log_plan_decision(crewmate, plan)

	var reason: int = plan["reason"]
	var actions: Array = plan["actions"]

	if reason == RepairPlanReason.DONE:
		clear_crewmate(crewmate, "repair duty done")
		return false

	if actions.is_empty():
		_print_blocked_plan_warning(crewmate, plan)
		return false

	crew_task_controller.queue_repair_actions(crewmate, actions, replace_current)

	return true


func plan_next_repair_step(crewmate: Crewmate) -> Dictionary:

	if crewmate == null or not active_crewmates.has(crewmate):
		return _build_plan_result(RepairPlanReason.NONE)

	if _has_damaged_holes():
		return _build_next_damage_control_plan(crewmate)

	roles[crewmate] = RepairRole.BAILER

	var bail_actions = action_planner.build_bail_water(crewmate, true)

	if not bail_actions.is_empty():
		return _build_plan_result(
			RepairPlanReason.SAFETY_BAIL,
			bail_actions,
			"draining remaining water"
		)

	if not _has_repair_or_bail_work_remaining():
		return _build_plan_result(RepairPlanReason.DONE, [], "all repair work is complete")

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		"remaining water exists but no bail route could be built"
	)


func reserve_hole_for(crewmate: Crewmate, hole: ShipHolePoint) -> bool:
	if crewmate == null or hole == null or hole.grade <= ShipHolePoint.MIN_GRADE:
		return false

	var reserving_crewmate = crewmate_by_hole.get(hole)

	if reserving_crewmate != null and reserving_crewmate != crewmate:
		return false

	release_hole_for(crewmate)

	hole_by_crewmate[crewmate] = hole
	crewmate_by_hole[hole] = crewmate

	return true


func is_repair_duty_crewmate(crewmate: Crewmate) -> bool:

	return active_crewmates.has(crewmate)


func _build_next_damage_control_plan(crewmate: Crewmate) -> Dictionary:

	if crewmate.bucket_amount > 0.0:
		var carried_repair_plan = _build_repair_hole_plan(crewmate)

		if carried_repair_plan["reason"] == RepairPlanReason.REPAIR_HOLE:
			carried_repair_plan["details"]["label"] = "repairing before emptying carried bucket"

			return carried_repair_plan

		roles[crewmate] = RepairRole.BAILER

		var carried_bucket_actions = action_planner.build_bail_water(crewmate, true)

		if not carried_bucket_actions.is_empty():
			_print_doomed_bailing_help_request(crewmate)

			return _build_plan_result(
				RepairPlanReason.SAFETY_BAIL,
				carried_bucket_actions,
				"emptying a carried bucket before resuming repairs"
			)

		return _build_plan_result(
			RepairPlanReason.NO_ROUTE,
			[],
			"carried bucket could not be routed to a repair-safe bail cycle"
		)

	var bailing_outmatched = help_forecaster.is_bailing_outmatched(crewmate, active_crewmates, roles, crewmate)
	var repair_plan = _build_repair_hole_plan(crewmate)

	if repair_plan["reason"] == RepairPlanReason.REPAIR_HOLE:
		if bailing_outmatched:
			var bail_rate = help_forecaster.get_crewmate_bail_rate(crewmate)
			var flood_rate = help_forecaster.get_effective_flood_rate(active_crewmates, roles, crewmate)

			repair_plan["details"]["label"] = "repairing because flood rate outmatches bailing"
			repair_plan["details"]["flood_rate"] = "%.2f" % flood_rate
			repair_plan["details"]["bail_rate"] = "%.2f" % bail_rate

		return repair_plan

	var entry_candidates = _get_sorted_repair_targets(crewmate, false)

	if not entry_candidates.is_empty():
		var flooded_entry_target: ShipHolePoint = entry_candidates[0]

		var flooded_entry_actions = action_planner.build_flooded_mid_deck_entry_bail(
			crewmate,
			flooded_entry_target
		)

		if not flooded_entry_actions.is_empty():
			roles[crewmate] = RepairRole.BAILER

			_print_doomed_bailing_help_request(crewmate)

			return _build_plan_result(
				RepairPlanReason.ENTRY_BAIL,
				flooded_entry_actions,
				"",
				{
					"hole": String(flooded_entry_target.name),
					"deck": DeckGraph.get_deck_name(flooded_entry_target.deck)
				}
			)

	if (
		not _has_damaged_holes(true)
		and ship.health_system.water_level <= 0.0
		and ship.health_system.get_flood_rate() <= 0.0
	):
		return _build_plan_result(
			RepairPlanReason.DONE,
			[],
			"no unreserved repair work or water remains"
		)

	_print_doomed_bailing_help_request(crewmate)

	roles[crewmate] = RepairRole.BAILER

	var safety_bail_actions = action_planner.build_bail_water(crewmate, true)

	if not safety_bail_actions.is_empty():
		return _build_plan_result(
			RepairPlanReason.SAFETY_BAIL,
			safety_bail_actions,
			"bailing to create a safe repair window"
		)

	if repair_plan["reason"] != RepairPlanReason.NONE:
		return repair_plan

	if _has_damaged_holes():
		return _build_plan_result(
			RepairPlanReason.NO_SAFE_HOLE,
			[],
			"damage remains but no safe repair or bail route is available"
		)

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		"repair work remains but no follow-up route could be built"
	)


func _build_repair_hole_plan(crewmate: Crewmate) -> Dictionary:

	var candidate_holes = _get_sorted_repair_targets(crewmate, true)
	var failed_holes: Array[String] = []

	if candidate_holes.is_empty():
		if _has_damaged_holes(true):
			return _build_plan_result(
				RepairPlanReason.NO_SAFE_HOLE,
				[],
				"unreserved holes exist, but none are safe yet"
			)

		return _build_plan_result(RepairPlanReason.NONE)

	for hole in candidate_holes:
		if not reserve_hole_for(crewmate, hole):
			failed_holes.append("%s reserved elsewhere" % hole.name)
			continue

		var actions = action_planner.build_repair_hole(crewmate, hole)

		if not actions.is_empty():
			roles[crewmate] = RepairRole.REPAIRER

			return _build_plan_result(
				RepairPlanReason.REPAIR_HOLE,
				actions,
				"",
				{
					"hole": String(hole.name),
					"deck": DeckGraph.get_deck_name(hole.deck)
				}
			)

		release_hole_for(crewmate)
		failed_holes.append("%s route build failed" % hole.name)

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		"safe repair holes were found, but none produced a valid route",
		{
			"failed_holes": failed_holes
		}
	)


func _get_sorted_repair_targets(crewmate: Crewmate, require_safe: bool) -> Array[ShipHolePoint]:
	var result: Array[ShipHolePoint] = []

	if crewmate == null or action_points == null or action_planner == null:
		return result

	result.assign(ShipRepairTargetRanker.get_repair_targets_by_priority(
		action_points,
		action_planner,
		crewmate,
		crewmate_by_hole.keys(),
		help_forecaster.get_effective_flood_rate(active_crewmates, roles, crewmate),
		require_safe
	))

	return result


func _print_doomed_bailing_help_request(crewmate: Crewmate) -> void:

	help_forecaster.print_doomed_bailing_help_request_if_needed(
		crewmate,
		active_crewmates,
		roles,
		help_requested
	)


func _has_damaged_holes(unreserved_only := false) -> bool:

	if action_points == null:
		return false

	return action_points.hull_holes.any(
		func(hole):
			return (
				hole.grade > ShipHolePoint.MIN_GRADE
				and not (unreserved_only and crewmate_by_hole.has(hole))
			)
	)


func _has_repair_or_bail_work_remaining() -> bool:

	return (
		_has_damaged_holes()
		or ship.health_system.water_level > 0.0
		or ship.health_system.get_flood_rate() > 0.0
	)


func _cleanup_reservations() -> void:

	for crewmate in hole_by_crewmate.keys():
		var hole: ShipHolePoint = hole_by_crewmate[crewmate]

		if (
			crewmate == null
			or not active_crewmates.has(crewmate)
			or hole == null
			or hole.grade <= ShipHolePoint.MIN_GRADE
		):
			release_hole_for(crewmate)


func release_hole_for(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	var hole = hole_by_crewmate.get(crewmate)

	if hole != null:
		crewmate_by_hole.erase(hole)

	hole_by_crewmate.erase(crewmate)


func _on_crewmate_queue_finished(crewmate: Crewmate) -> void:

	if crewmate == null or not active_crewmates.has(crewmate):
		return

	if crewmate.action_executor != null and crewmate.action_executor.has_actions():
		return

	queue_next_action(crewmate)


func _build_plan_result(
	reason: int,
	actions: Array[ActionDefinition] = [],
	label := "",
	details: Dictionary = {}
) -> Dictionary:

	var plan_details = details.duplicate()

	if not label.is_empty():
		plan_details["label"] = label

	return {
		"reason": reason,
		"actions": actions,
		"details": plan_details
	}


func _log_plan_decision(crewmate: Crewmate, plan) -> void:
	if crewmate == null:
		return

	ShipDebugLog.write(&"repair",
		"%s: repair duty next step reason=%s actions=%s%s"
		% [
			crewmate.name,
			_get_plan_reason_name(plan["reason"]),
			plan["actions"].size(),
			_get_plan_detail_text(plan["details"])
		]
	)


func _print_blocked_plan_warning(crewmate: Crewmate, plan) -> void:
	if crewmate == null or not _has_repair_or_bail_work_remaining():
		return

	ShipDebugLog.write(&"repair",
		"%s: repair duty is blocked; keeping assignment active. reason=%s Holes=%s UnreservedHoles=%s Water=%.2f Flood=%.2f%s"
		% [
			crewmate.name,
			_get_plan_reason_name(plan["reason"]),
			_has_damaged_holes(),
			_has_damaged_holes(true),
			ship.health_system.water_level,
			ship.health_system.get_flood_rate(),
			_get_plan_detail_text(plan["details"])
		]
	)


func _get_plan_detail_text(details: Dictionary) -> String:

	return " " + ShipDebugLog.join_details(details) if not details.is_empty() else ""


func _get_plan_reason_name(reason: int) -> String:

	return String(RepairPlanReason.keys()[reason]).to_lower()
