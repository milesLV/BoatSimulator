class_name ShipRepairDutyController
extends RefCounted

enum RepairRole {
	NONE,
	BAILER,
	REPAIRER
}

enum RepairStage {
	NONE,
	NEEDS_ENTRY_BAIL,
	INSIDE_FLOODED_ZONE,
	SAFETY_BAILING,
	REPAIRING
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
var repair_stage_by_crewmate: Dictionary = {}
var queue_finished_handlers: Dictionary = {}


func _init(
	new_ship,
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	ship = new_ship
	action_points = new_action_points
	action_planner = new_action_planner
	help_forecaster = ShipRepairHelpForecaster.new(
		ship,
		action_points,
		action_planner
	)


func set_task_controller(new_crew_task_controller: ShipCrewTaskController) -> void:

	crew_task_controller = new_crew_task_controller


func assign_crewmate(crewmate: Crewmate) -> bool:

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	if crew_task_controller != null:
		crew_task_controller.prepare_for_repair_duty(crewmate)

	if not active_crewmates.has(
		crewmate
	):
		active_crewmates.append(crewmate)

	_connect_queue_finished_listener(crewmate)
	_set_repair_stage(
		crewmate,
		RepairStage.NEEDS_ENTRY_BAIL
	)

	ShipDebugLog.repair(
		"%s: repair duty assigned."
		% crewmate.name
	)

	_release_crewmate_reservation(crewmate)

	return queue_next_action(
		crewmate,
		true
	)


func clear_crewmate(
	crewmate: Crewmate,
	reason := "unspecified"
) -> bool:

	if crewmate == null:
		return false

	var was_active = active_crewmates.has(crewmate)

	if was_active:
		ShipDebugLog.repair(
			"%s: repair duty cleared (%s)."
			% [
				crewmate.name,
				reason
			]
		)

	active_crewmates.erase(crewmate)
	roles.erase(crewmate)
	help_requested.erase(crewmate)
	repair_stage_by_crewmate.erase(crewmate)
	_disconnect_queue_finished_listener(crewmate)
	_release_crewmate_reservation(crewmate)

	return was_active


func clear_all() -> void:

	for crewmate in active_crewmates.duplicate():
		clear_crewmate(
			crewmate,
			"clear all"
		)


func queue_next_action(
	crewmate: Crewmate,
	replace_current := false
) -> bool:

	if (
		crewmate == null
		or action_planner == null
	):
		return false

	if not active_crewmates.has(
		crewmate
	):
		return false

	_cleanup_reservations()
	_release_crewmate_reservation(crewmate)

	var plan = plan_next_repair_step(crewmate)

	_log_plan_decision(
		crewmate,
		plan
	)

	var reason: int = plan.get(
		"reason",
		RepairPlanReason.NONE
	)
	var actions: Array = plan.get(
		"actions",
		[]
	)

	if reason == RepairPlanReason.DONE:
		clear_crewmate(
			crewmate,
			"repair duty done"
		)
		return false

	if actions.is_empty():
		_print_blocked_plan_warning(
			crewmate,
			plan
		)
		return false

	_queue_actions(
		crewmate,
		actions,
		replace_current
	)

	return true


func plan_next_repair_step(crewmate: Crewmate) -> Dictionary:

	if (
		crewmate == null
		or not active_crewmates.has(crewmate)
	):
		return _build_plan_result(
			RepairPlanReason.NONE
		)

	if _has_damaged_holes():
		return _build_next_damage_control_plan(
			crewmate
		)

	roles[crewmate] = RepairRole.BAILER

	var bail_actions = action_planner.build_bail_water(
		crewmate,
		true
	)

	if not bail_actions.is_empty():
		_set_repair_stage(
			crewmate,
			RepairStage.SAFETY_BAILING
		)

		return _build_plan_result(
			RepairPlanReason.SAFETY_BAIL,
			bail_actions,
			{
				"label": "draining remaining water"
			}
		)

	if not _has_repair_or_bail_work_remaining():
		return _build_plan_result(
			RepairPlanReason.DONE,
			[],
			{
				"label": "all repair work is complete"
			}
		)

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		{
			"label": "remaining water exists but no bail route could be built"
		}
	)


func reserve_hole_for(
	crewmate: Crewmate,
	hole: ShipHolePoint
) -> bool:

	if (
		crewmate == null
		or hole == null
		or hole.grade <= ShipHolePoint.MIN_GRADE
	):
		return false

	var reserving_crewmate = crewmate_by_hole.get(hole)

	if (
		reserving_crewmate != null
		and reserving_crewmate != crewmate
	):
		return false

	_release_crewmate_reservation(crewmate)

	hole_by_crewmate[crewmate] = hole
	crewmate_by_hole[hole] = crewmate

	return true


func release_hole_for(crewmate: Crewmate) -> void:

	_release_crewmate_reservation(crewmate)


func mark_repair_completed(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	_set_repair_stage(
		crewmate,
		RepairStage.NONE
	)
	_release_crewmate_reservation(crewmate)


func is_repair_duty_crewmate(crewmate: Crewmate) -> bool:

	return active_crewmates.has(
		crewmate
	)


func _build_next_damage_control_plan(crewmate: Crewmate) -> Dictionary:

	if crewmate.bucket_amount > 0.0:
		var repair_plan = _build_repair_hole_plan(crewmate)

		if repair_plan.get(
			"reason",
			RepairPlanReason.NONE
		) == RepairPlanReason.REPAIR_HOLE:
			var details: Dictionary = repair_plan.get(
				"details",
				{}
			)

			details["label"] = "repairing before emptying carried bucket"
			repair_plan["details"] = details

			return repair_plan

		roles[crewmate] = RepairRole.BAILER
		_set_repair_stage(
			crewmate,
			RepairStage.SAFETY_BAILING
		)

		var carried_bucket_actions = action_planner.build_repair_safety_bail_cycle(crewmate)

		if not carried_bucket_actions.is_empty():
			_print_doomed_bailing_help_request_if_needed(
				crewmate,
				true
			)

			return _build_plan_result(
				RepairPlanReason.SAFETY_BAIL,
				carried_bucket_actions,
				{
					"label": "emptying a carried bucket before resuming repairs"
				}
			)

		return _build_plan_result(
			RepairPlanReason.NO_ROUTE,
			[],
			{
				"label": "carried bucket could not be routed to a repair-safe bail cycle"
			}
		)

	var bailing_outmatched = _is_bailing_outmatched(crewmate)
	var repair_plan = _build_repair_hole_plan(crewmate)

	if repair_plan.get(
		"reason",
		RepairPlanReason.NONE
	) == RepairPlanReason.REPAIR_HOLE:
		if bailing_outmatched:
			var details: Dictionary = repair_plan.get(
				"details",
				{}
			)
			var bail_rate = _get_crewmate_bail_rate(crewmate)
			var flood_rate = _get_effective_flood_rate(crewmate)

			details["label"] = "repairing because flood rate outmatches bailing"
			details["flood_rate"] = "%.2f" % flood_rate
			details["bail_rate"] = "%.2f" % bail_rate
			repair_plan["details"] = details

		return repair_plan

	var flooded_entry_target = _get_best_flooded_entry_target(crewmate)

	if flooded_entry_target != null:
		var flooded_entry_actions = action_planner.build_flooded_mid_deck_entry_bail(
			crewmate,
			flooded_entry_target
		)

		if not flooded_entry_actions.is_empty():
			roles[crewmate] = RepairRole.BAILER
			_set_repair_stage(
				crewmate,
				_get_entry_bail_stage(crewmate)
			)

			_print_doomed_bailing_help_request_if_needed(
				crewmate,
				true
			)

			return _build_plan_result(
				RepairPlanReason.ENTRY_BAIL,
				flooded_entry_actions,
				{
					"hole": String(
						flooded_entry_target.name
					),
					"deck": DeckGraph.get_deck_name(flooded_entry_target.deck)
				}
			)

	if (
		not _has_unreserved_damaged_holes()
		and _get_water_level() <= 0.0
		and _get_flood_rate() <= 0.0
	):
		return _build_plan_result(
			RepairPlanReason.DONE,
			[],
			{
				"label": "no unreserved repair work or water remains"
			}
		)

	_print_doomed_bailing_help_request_if_needed(
		crewmate,
		true
	)

	roles[crewmate] = RepairRole.BAILER
	_set_repair_stage(
		crewmate,
		RepairStage.SAFETY_BAILING
	)

	var safety_bail_actions = action_planner.build_repair_safety_bail_cycle(crewmate)

	if not safety_bail_actions.is_empty():
		return _build_plan_result(
			RepairPlanReason.SAFETY_BAIL,
			safety_bail_actions,
			{
				"label": "bailing to create a safe repair window"
			}
		)

	var repair_reason: int = repair_plan.get(
		"reason",
		RepairPlanReason.NONE
	)

	if repair_reason != RepairPlanReason.NONE:
		return repair_plan

	if _has_damaged_holes():
		return _build_plan_result(
			RepairPlanReason.NO_SAFE_HOLE,
			[],
			{
				"label": "damage remains but no safe repair or bail route is available"
			}
		)

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		{
			"label": "repair work remains but no follow-up route could be built"
		}
	)


func _build_repair_hole_plan(crewmate: Crewmate) -> Dictionary:

	var candidate_holes = _get_sorted_repair_targets(
		crewmate,
		true
	)
	var failed_holes: Array[String] = []

	if candidate_holes.is_empty():
		if _has_unreserved_damaged_holes():
			return _build_plan_result(
				RepairPlanReason.NO_SAFE_HOLE,
				[],
				{
					"label": "unreserved holes exist, but none are safe yet"
				}
			)

		return _build_plan_result(
			RepairPlanReason.NONE
		)

	for hole in candidate_holes:
		if not reserve_hole_for(
			crewmate,
			hole
		):
			failed_holes.append(
				"%s reserved elsewhere"
				% hole.name
			)
			continue

		var actions = action_planner.build_repair_hole(
			crewmate,
			hole
		)

		if not actions.is_empty():
			roles[crewmate] = RepairRole.REPAIRER
			_set_repair_stage(
				crewmate,
				RepairStage.REPAIRING
			)

			return _build_plan_result(
				RepairPlanReason.REPAIR_HOLE,
				actions,
				{
					"hole": String(
						hole.name
					),
					"deck": DeckGraph.get_deck_name(hole.deck)
				}
			)

		release_hole_for(crewmate)
		failed_holes.append(
			"%s route build failed"
			% hole.name
		)

	return _build_plan_result(
		RepairPlanReason.NO_ROUTE,
		[],
		{
			"label": "safe repair holes were found, but none produced a valid route",
			"failed_holes": failed_holes
		}
	)


func _get_best_flooded_entry_target(crewmate: Crewmate) -> ShipHolePoint:

	var candidate_holes = _get_sorted_repair_targets(
		crewmate,
		false
	)

	if candidate_holes.is_empty():
		return null

	return candidate_holes[0]


func _get_sorted_repair_targets(
	crewmate: Crewmate,
	require_safe: bool
) -> Array[ShipHolePoint]:

	var result: Array[ShipHolePoint] = []

	if (
		crewmate == null
		or action_points == null
		or action_planner == null
	):
		return result

	var excluded_holes = crewmate_by_hole.keys()
	var effective_flood_rate = _get_effective_flood_rate(crewmate)
	var targets = ShipRepairTargetRanker.get_repair_targets_by_priority(
		action_points,
		action_planner,
		crewmate,
		excluded_holes,
		effective_flood_rate,
		require_safe
	)

	for target in targets:
		result.append(target)

	return result


func _is_bailing_outmatched(crewmate: Crewmate) -> bool:

	if help_forecaster == null:
		return true

	return help_forecaster.is_bailing_outmatched(
		crewmate,
		active_crewmates,
		roles,
		crewmate,
		RepairRole.BAILER
	)


func _get_crewmate_bail_rate(crewmate: Crewmate) -> float:

	if help_forecaster == null:
		return 0.0

	return help_forecaster.get_crewmate_bail_rate(
		crewmate
	)


func _print_doomed_bailing_help_request_if_needed(
	crewmate: Crewmate,
	force_if_bailing_loses := false
) -> void:

	if help_forecaster == null:
		return

	help_forecaster.print_doomed_bailing_help_request_if_needed(
		crewmate,
		active_crewmates,
		roles,
		help_requested,
		force_if_bailing_loses,
		RepairRole.BAILER
	)


func _get_effective_flood_rate(repairing_crewmate: Crewmate) -> float:

	if help_forecaster == null:
		return 0.0

	return help_forecaster.get_effective_flood_rate(
		active_crewmates,
		roles,
		repairing_crewmate,
		RepairRole.BAILER
	)


func _is_active_bailer_support(crewmate: Crewmate) -> bool:

	return (
		crewmate != null
		and roles.get(
			crewmate,
			RepairRole.NONE
		) == RepairRole.BAILER
		and crewmate.action_executor != null
		and crewmate.action_executor.has_actions()
	)


func _has_damaged_holes() -> bool:

	if action_points == null:
		return false

	for hole in action_points.get_holes_ref():
		if hole.grade > ShipHolePoint.MIN_GRADE:
			return true

	return false


func _has_unreserved_damaged_holes() -> bool:

	if action_points == null:
		return false

	var reserved_holes = crewmate_by_hole.keys()

	for hole in action_points.get_holes_ref():
		if (
			hole.grade > ShipHolePoint.MIN_GRADE
			and not reserved_holes.has(hole)
		):
			return true

	return false


func _get_water_level() -> float:

	if (
		ship == null
		or ship.health_system == null
	):
		return 0.0

	return ship.health_system.get_water_level()


func _get_flood_rate() -> float:

	if (
		ship == null
		or ship.health_system == null
	):
		return 0.0

	return ship.health_system.get_flood_rate()


func _has_repair_or_bail_work_remaining() -> bool:

	return (
		_has_damaged_holes()
		or _get_water_level() > 0.0
		or _get_flood_rate() > 0.0
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
			_release_crewmate_reservation(crewmate)


func _release_crewmate_reservation(crewmate: Crewmate) -> void:

	if crewmate == null:
		return

	var hole = hole_by_crewmate.get(crewmate)

	if hole != null:
		crewmate_by_hole.erase(hole)

	hole_by_crewmate.erase(crewmate)


func _queue_actions(
	crewmate: Crewmate,
	actions: Array,
	replace_current: bool
) -> void:

	if (
		crewmate == null
		or crewmate.action_executor == null
	):
		return

	if replace_current:
		if crew_task_controller != null:
			crew_task_controller.cancel_plan_and_clear_station_request(
				crewmate,
				true
			)
		else:
			crewmate.action_executor.cancel_plan()
			crewmate.requested_station = null
	elif crew_task_controller != null:
		crew_task_controller.clear_requested_station(crewmate)
	else:
		crewmate.requested_station = null

	crewmate.action_executor.queue_actions(actions)


func _connect_queue_finished_listener(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or crewmate.action_executor == null
	):
		return

	var handler: Callable

	if queue_finished_handlers.has(
		crewmate
	):
		handler = queue_finished_handlers[crewmate]
	else:
		handler = Callable(
			self,
			"_on_crewmate_queue_finished"
		).bind(crewmate)
		queue_finished_handlers[crewmate] = handler

	if not crewmate.action_executor.queue_finished.is_connected(
		handler
	):
		crewmate.action_executor.queue_finished.connect(handler)


func _disconnect_queue_finished_listener(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or crewmate.action_executor == null
		or not queue_finished_handlers.has(crewmate)
	):
		return

	var handler: Callable = queue_finished_handlers[
		crewmate
	]

	if crewmate.action_executor.queue_finished.is_connected(
		handler
	):
		crewmate.action_executor.queue_finished.disconnect(handler)

	queue_finished_handlers.erase(crewmate)


func _on_crewmate_queue_finished(crewmate: Crewmate) -> void:

	if (
		crewmate == null
		or not active_crewmates.has(crewmate)
	):
		return

	if (
		crewmate.action_executor != null
		and crewmate.action_executor.has_actions()
	):
		return

	queue_next_action(crewmate)


func _get_entry_bail_stage(crewmate: Crewmate) -> int:

	if crewmate == null:
		return RepairStage.NEEDS_ENTRY_BAIL

	if (
		crewmate.location == DeckGraph.DECKS.MID
		or crewmate.location == DeckGraph.DECKS.LOWER
	):
		return RepairStage.INSIDE_FLOODED_ZONE

	return RepairStage.NEEDS_ENTRY_BAIL


func _set_repair_stage(
	crewmate: Crewmate,
	stage: int
) -> void:

	if crewmate == null:
		return

	repair_stage_by_crewmate[crewmate] = stage


func _get_repair_stage(crewmate: Crewmate) -> int:

	if crewmate == null:
		return RepairStage.NONE

	return repair_stage_by_crewmate.get(
		crewmate,
		RepairStage.NONE
	)


func _build_plan_result(
	reason: int,
	actions: Array[ActionDefinition] = [],
	details: Dictionary = {}
) -> Dictionary:

	return {
		"reason": reason,
		"actions": actions,
		"details": details
	}


func _log_plan_decision(
	crewmate: Crewmate,
	plan: Dictionary
) -> void:

	if crewmate == null:
		return

	var reason: int = plan.get(
		"reason",
		RepairPlanReason.NONE
	)
	var actions: Array = plan.get(
		"actions",
		[]
	)
	var details: Dictionary = plan.get(
		"details",
		{}
	)
	var detail_text = _get_plan_detail_text(details)

	ShipDebugLog.repair(
		"%s: repair duty next step reason=%s stage=%s actions=%s%s"
		% [
			crewmate.name,
			_get_plan_reason_name(
				reason
			),
			_get_repair_stage_name(
				_get_repair_stage(crewmate)
			),
			actions.size(),
			detail_text
		]
	)


func _print_blocked_plan_warning(
	crewmate: Crewmate,
	plan: Dictionary
) -> void:

	if (
		crewmate == null
		or not _has_repair_or_bail_work_remaining()
	):
		return

	var reason: int = plan.get(
		"reason",
		RepairPlanReason.NONE
	)
	var detail_text = _get_plan_detail_text(
		plan.get(
			"details",
			{}
		)
	)

	ShipDebugLog.repair(
		"%s: repair duty is blocked; keeping assignment active. reason=%s stage=%s Holes=%s UnreservedHoles=%s Water=%.2f Flood=%.2f%s"
		% [
			crewmate.name,
			_get_plan_reason_name(
				reason
			),
			_get_repair_stage_name(
				_get_repair_stage(crewmate)
			),
			_has_damaged_holes(),
			_has_unreserved_damaged_holes(),
			_get_water_level(),
			_get_flood_rate(),
			detail_text
		]
	)


func _get_plan_detail_text(details: Dictionary) -> String:

	if details.is_empty():
		return ""

	var text := ""

	for key in details.keys():
		if text != "":
			text += " "

		text += "%s=%s" % [
			String(
				key
			),
			String(details[key])
		]

	if text == "":
		return ""

	return " " + text


func _get_repair_stage_name(stage: int) -> String:

	return String(
		RepairStage.keys()[
			stage
		]
	).to_lower()


func _get_plan_reason_name(reason: int) -> String:

	return String(
		RepairPlanReason.keys()[
			reason
		]
	).to_lower()
