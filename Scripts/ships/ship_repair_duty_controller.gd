class_name ShipRepairDutyController
extends RefCounted

enum RepairRole {
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
var crew_task_controller: ShipCrewTaskController

var active_crewmates: Array[Crewmate] = []
var roles: Dictionary = {}
var hole_by_crewmate: Dictionary = {}
var help_requested: Dictionary = {}
## crewmate -> the decks they patch; missing or empty is every deck.
var deck_filter: Dictionary = {}


func _init(
	new_ship,
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	ship = new_ship
	action_points = new_action_points
	action_planner = new_action_planner


func assign_crewmate(crewmate: Crewmate, decks: Array = []) -> bool:

	crew_task_controller.prepare_for_repair_duty(crewmate)
	deck_filter[crewmate] = decks

	if not active_crewmates.has(crewmate):
		active_crewmates.append(crewmate)

	Crewmate.set_queue_finished_listener(crewmate, _on_crewmate_queue_finished, true)

	ShipDebugLog.write(&"repair", "%s: repair duty assigned." % crewmate.name)

	return queue_next_action(crewmate, true)


func clear_crewmate(crewmate: Crewmate, reason := "unspecified") -> bool:

	var was_active = active_crewmates.has(crewmate)

	if was_active:
		ShipDebugLog.write(&"repair", "%s: repair duty cleared (%s)." % [crewmate.name, reason])

	active_crewmates.erase(crewmate)
	roles.erase(crewmate)
	help_requested.erase(crewmate)
	deck_filter.erase(crewmate)
	Crewmate.set_queue_finished_listener(crewmate, _on_crewmate_queue_finished, false)
	release_hole_for(crewmate)

	return was_active


func clear_all() -> void:

	for crewmate in active_crewmates.duplicate():
		clear_crewmate(crewmate, "clear all")


func queue_next_action(crewmate: Crewmate, replace_current := false) -> bool:
	if not active_crewmates.has(crewmate):
		return false

	_cleanup_reservations()
	release_hole_for(crewmate)

	var plan = plan_next_repair_step(crewmate)
	var reason_name = String(RepairPlanReason.keys()[plan["reason"]]).to_lower()

	ShipDebugLog.write(&"repair", "%s: repair duty next step reason=%s actions=%s %s"
		% [crewmate.name, reason_name, plan["actions"].size(), plan["note"]])

	if plan["reason"] == RepairPlanReason.DONE:
		clear_crewmate(crewmate, "repair duty done")
		return false

	if plan["actions"].is_empty():
		if _has_repair_or_bail_work_remaining():
			ShipDebugLog.write(&"repair",
				"%s: repair duty is blocked; keeping assignment active. reason=%s Holes=%s UnreservedHoles=%s Water=%.2f Flood=%.2f %s"
				% [crewmate.name, reason_name, _has_damaged_holes(), _has_damaged_holes(true),
					ship.health_system.water_level, ship.health_system.get_flood_rate(), plan["note"]]
			)

		return false

	crew_task_controller.queue_repair_actions(crewmate, plan["actions"], replace_current)

	return true


func plan_next_repair_step(crewmate: Crewmate) -> Dictionary:

	if _has_damaged_holes():
		return _build_next_damage_control_plan(crewmate)

	roles[crewmate] = RepairRole.BAILER

	var bail_actions = action_planner.build_bail_water(crewmate, true)

	if not bail_actions.is_empty():
		return _plan(RepairPlanReason.SAFETY_BAIL, bail_actions, "draining remaining water")

	if not _has_repair_or_bail_work_remaining():
		return _plan(RepairPlanReason.DONE, [], "all repair work is complete")

	return _plan(RepairPlanReason.NO_ROUTE, [], "remaining water exists but no bail route could be built")


func is_repair_duty_crewmate(crewmate: Crewmate) -> bool:

	return active_crewmates.has(crewmate)


func _build_next_damage_control_plan(crewmate: Crewmate) -> Dictionary:

	if crewmate.bucket_amount > 0.0:
		var carried_repair_plan = _build_repair_hole_plan(crewmate)

		if carried_repair_plan["reason"] == RepairPlanReason.REPAIR_HOLE:
			carried_repair_plan["note"] += " repairing before emptying carried bucket"

			return carried_repair_plan

		roles[crewmate] = RepairRole.BAILER

		var carried_bucket_actions = action_planner.build_bail_water(crewmate, true)

		if not carried_bucket_actions.is_empty():
			_print_doomed_bailing_help_request(crewmate)

			return _plan(
				RepairPlanReason.SAFETY_BAIL, carried_bucket_actions, "emptying a carried bucket before resuming repairs"
			)

		return _plan(RepairPlanReason.NO_ROUTE, [], "carried bucket could not be routed to a repair-safe bail cycle")

	var repair_plan = _build_repair_hole_plan(crewmate)

	if repair_plan["reason"] == RepairPlanReason.REPAIR_HOLE:
		var bail_rate = _get_bail_rate(crewmate)
		var flood_rate = _get_flood_rate_without(crewmate)

		if bail_rate <= 0.0 or flood_rate > bail_rate:
			repair_plan["note"] += " repairing because flood rate %.2f outmatches bailing %.2f" % [flood_rate, bail_rate]

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

			return _plan(RepairPlanReason.ENTRY_BAIL, flooded_entry_actions, "hole=%s deck=%s"
				% [flooded_entry_target.name, DeckGraph.get_deck_name(flooded_entry_target.deck)])

	if (
		not _has_damaged_holes(true)
		and ship.health_system.water_level <= 0.0
		and ship.health_system.get_flood_rate() <= 0.0
	):
		return _plan(RepairPlanReason.DONE, [], "no unreserved repair work or water remains")

	_print_doomed_bailing_help_request(crewmate)

	roles[crewmate] = RepairRole.BAILER

	var safety_bail_actions = action_planner.build_bail_water(crewmate, true)

	if not safety_bail_actions.is_empty():
		return _plan(RepairPlanReason.SAFETY_BAIL, safety_bail_actions, "bailing to create a safe repair window")

	if repair_plan["reason"] != RepairPlanReason.NONE:
		return repair_plan

	return _plan(RepairPlanReason.NO_SAFE_HOLE, [], "damage remains but no safe repair or bail route is available")


## Candidates are already open and unreserved, so the first one with a route is taken.
func _build_repair_hole_plan(crewmate: Crewmate) -> Dictionary:

	var candidate_holes = _get_sorted_repair_targets(crewmate, true)

	if candidate_holes.is_empty():
		if _has_damaged_holes(true):
			return _plan(RepairPlanReason.NO_SAFE_HOLE, [], "unreserved holes exist, but none are safe yet")

		return _plan(RepairPlanReason.NONE)

	for hole in candidate_holes:
		var actions = action_planner.build_repair_hole(crewmate, hole)

		if not actions.is_empty():
			hole_by_crewmate[crewmate] = hole
			roles[crewmate] = RepairRole.REPAIRER

			return _plan(RepairPlanReason.REPAIR_HOLE, actions, "hole=%s deck=%s"
				% [hole.name, DeckGraph.get_deck_name(hole.deck)])

	return _plan(RepairPlanReason.NO_ROUTE, [], "safe repair holes were found, but none produced a valid route")


## Unreserved holes [param crewmate] can reach, quickest trip first; the name breaks ties so
## the order is stable. [param require_safe] also drops trips the ship would not survive.
func _get_sorted_repair_targets(crewmate: Crewmate, require_safe: bool) -> Array:

	var flood_rate = _get_flood_rate_without(crewmate)
	var reserved = hole_by_crewmate.values()
	var decks: Array = deck_filter.get(crewmate, [])
	var trip_times := {}

	for hole in action_points.hull_holes:
		if hole.grade <= ShipHolePoint.MIN_GRADE or reserved.has(hole):
			continue

		if not decks.is_empty() and not hole.deck in decks:
			continue

		var repair_trip = action_planner.estimate_repair_trip(crewmate, hole)

		if repair_trip["total_time"] == INF:
			continue

		if require_safe and not action_planner.is_repair_trip_safe(crewmate, hole, repair_trip, flood_rate):
			continue

		trip_times[hole] = repair_trip["total_time"]

	var holes = trip_times.keys()
	holes.sort_custom(func(a, b): return (
		trip_times[a] < trip_times[b] if trip_times[a] != trip_times[b]
		else String(a.name) < String(b.name)
	))

	return holes


func _get_bail_rate(crewmate: Crewmate) -> float:

	# no bail route estimates INF, so a rate of 0
	return Crewmate.MAX_BUCKET_AMOUNT / action_planner.estimate_repair_bail_cycle_duration(crewmate)


## The flooding left once every other bailer on duty, and busy at it, takes their share.
func _get_flood_rate_without(crewmate: Crewmate) -> float:

	var flood_rate = ship.health_system.get_flood_rate()

	for other in active_crewmates:
		if other != crewmate and roles.get(other) == RepairRole.BAILER and other.action_executor.has_actions():
			flood_rate = maxf(flood_rate - _get_bail_rate(other), 0.0)

	return flood_rate


## Once per stretch of it: [param crewmate] is bailing but the water still gains.
func _print_doomed_bailing_help_request(crewmate: Crewmate) -> void:

	var own_bail_rate = _get_bail_rate(crewmate)

	if own_bail_rate <= 0.0:
		return

	if _get_flood_rate_without(crewmate) <= own_bail_rate:
		help_requested.erase(crewmate)
		return

	if help_requested.has(crewmate):
		return

	help_requested[crewmate] = true
	ShipDebugLog.write(&"repair", "%s: I need help! I can slow the flooding, but we are still sinking." % crewmate.name)


func _has_damaged_holes(unreserved_only := false) -> bool:

	return action_points.hull_holes.any(
		func(hole):
			return (
				hole.grade > ShipHolePoint.MIN_GRADE
				and not (unreserved_only and hole_by_crewmate.values().has(hole))
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
		if not active_crewmates.has(crewmate) or hole_by_crewmate[crewmate].grade <= ShipHolePoint.MIN_GRADE:
			release_hole_for(crewmate)


func release_hole_for(crewmate: Crewmate) -> void:

	hole_by_crewmate.erase(crewmate)


func _on_crewmate_queue_finished(crewmate: Crewmate) -> void:

	if not active_crewmates.has(crewmate) or crewmate.action_executor.has_actions():
		return

	queue_next_action(crewmate)


func _plan(reason: int, actions: Array[ActionDefinition] = [], note := "") -> Dictionary:

	return {"reason": reason, "actions": actions, "note": note}
