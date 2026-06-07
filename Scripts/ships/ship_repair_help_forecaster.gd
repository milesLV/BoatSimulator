class_name ShipRepairHelpForecaster
extends RefCounted

var ship
var action_points: ShipActionPointContainer
var action_planner: ShipActionPlanner


func _init(
	new_ship,
	new_action_points: ShipActionPointContainer,
	new_action_planner: ShipActionPlanner
) -> void:

	ship = new_ship
	action_points = new_action_points
	action_planner = new_action_planner


func get_crewmate_bail_rate(crewmate: Crewmate) -> float:
	if crewmate == null or action_planner == null:
		return 0.0

	var bail_cycle_duration = action_planner.estimate_repair_bail_cycle_duration(crewmate)

	return ShipFloodForecast.bail_rate(
		Crewmate.MAX_BUCKET_AMOUNT,
		bail_cycle_duration
	)


func is_bailing_outmatched(
	crewmate: Crewmate,
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	repairing_crewmate: Crewmate,
	bailer_role: int
) -> bool:

	var bail_rate = get_crewmate_bail_rate(crewmate)

	if bail_rate <= 0.0:
		return true

	return get_effective_flood_rate(
		active_crewmates,
		roles,
		repairing_crewmate,
		bailer_role
	) > bail_rate


func get_effective_flood_rate(
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	repairing_crewmate: Crewmate,
	bailer_role: int
) -> float:

	if ship == null or ship.health_system == null:
		return 0.0

	var flood_rate = ship.health_system.get_flood_rate()

	for crewmate in active_crewmates:
		if (
			crewmate == null
			or crewmate == repairing_crewmate
			or not _is_active_bailer_support(crewmate, roles, bailer_role)
		):
			continue

		var bail_cycle_duration = action_planner.estimate_repair_bail_cycle_duration(crewmate)
		flood_rate = ShipFloodForecast.flood_rate_after_bailing(
			flood_rate,
			Crewmate.MAX_BUCKET_AMOUNT,
			bail_cycle_duration
		)

	return max(flood_rate, 0.0)


func print_doomed_bailing_help_request_if_needed(
	crewmate: Crewmate,
	active_crewmates: Array[Crewmate],
	roles: Dictionary,
	help_requested: Dictionary,
	force_if_bailing_loses: bool,
	bailer_role: int
) -> void:

	if (
		crewmate == null
		or ship == null
		or ship.health_system == null
		or action_planner == null
	):
		return

	var own_bail_duration = action_planner.estimate_repair_bail_cycle_duration(crewmate)

	if own_bail_duration <= 0.0 or own_bail_duration == INF:
		return

	var flood_after_own_bail = ShipFloodForecast.flood_rate_after_bailing(
		get_effective_flood_rate(
			active_crewmates,
			roles,
			crewmate,
			bailer_role
		),
		Crewmate.MAX_BUCKET_AMOUNT,
		own_bail_duration
	)

	if flood_after_own_bail <= 0.0:
		help_requested.erase(crewmate)
		return

	var time_until_full = ShipFloodForecast.time_until_full(
		ship.health_system.get_water_level(),
		flood_after_own_bail,
		ship.health_system.MAX_WATER_LEVEL
	)
	var nearest_help_time = _get_nearest_available_help_time(
		crewmate,
		active_crewmates
	)
	var needs_help = (
		force_if_bailing_loses
		or time_until_full <= (
			ShipActionPlanner.HELP_SINK_WINDOW
			+ nearest_help_time
		)
	)

	if needs_help:
		if help_requested.get(crewmate, false):
			return

		help_requested[crewmate] = true
		ShipDebugLog.repair(
			"%s: I need help! I can slow the flooding, but we are still sinking."
			% crewmate.name
		)
	else:
		help_requested.erase(crewmate)


func _get_nearest_available_help_time(
	requesting_crewmate: Crewmate,
	active_crewmates: Array[Crewmate]
) -> float:

	if ship == null or not ship.has_method("get_crewmates"):
		return 0.0

	var assist_point = _get_nearest_assist_point(requesting_crewmate)

	if assist_point == null:
		return 0.0

	var best_time := INF

	for crewmate in ship.get_crewmates():
		if (
			crewmate == null
			or crewmate == requesting_crewmate
			or active_crewmates.has(crewmate)
		):
			continue

		var travel_time = action_planner.estimate_travel_duration_to_point(
			crewmate,
			assist_point
		)

		if travel_time < best_time:
			best_time = travel_time

	return best_time


func _get_nearest_assist_point(crewmate: Crewmate) -> ShipHolePoint:
	if crewmate == null or action_points == null:
		return null

	var best_hole: ShipHolePoint = null
	var best_distance := INF

	for hole in action_points.get_holes_ref():
		if (
			hole.grade <= ShipHolePoint.MIN_GRADE
			or (
				hole.deck != DeckGraph.DECKS.MID
				and hole.deck != DeckGraph.DECKS.LOWER
			)
		):
			continue

		var distance = crewmate.global_position.distance_to(hole.global_position)

		if distance < best_distance:
			best_hole = hole
			best_distance = distance

	if best_hole != null:
		return best_hole

	for hole in action_points.get_holes_ref():
		if hole.grade <= ShipHolePoint.MIN_GRADE:
			continue

		var distance = crewmate.global_position.distance_to(hole.global_position)

		if distance < best_distance:
			best_hole = hole
			best_distance = distance

	return best_hole


func _is_active_bailer_support(
	crewmate: Crewmate,
	roles: Dictionary,
	bailer_role: int
) -> bool:

	if crewmate == null or roles.get(crewmate, -1) != bailer_role:
		return false

	return crewmate.action_executor != null and crewmate.action_executor.has_actions()
