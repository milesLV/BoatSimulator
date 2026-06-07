class_name ShipRepairTargetRanker
extends RefCounted


static func get_repair_targets_by_priority(
	action_points: ShipActionPointContainer,
	action_planner: ShipActionPlanner,
	crewmate: Crewmate,
	excluded_holes: Array,
	effective_flood_rate: float,
	require_safe: bool
) -> Array:

	if action_points == null or action_planner == null:
		return []

	var ranked_targets: Array = []

	for hole in action_points.get_holes_ref():
		if hole.grade <= ShipHolePoint.MIN_GRADE:
			continue

		if excluded_holes.has(hole):
			continue

		var repair_trip = action_planner.estimate_repair_trip(crewmate, hole)

		if repair_trip["total_time"] == INF:
			continue

		var can_repair_safely = action_planner.is_repair_trip_safe(
			crewmate,
			hole,
			repair_trip,
			effective_flood_rate
		)

		if require_safe and not can_repair_safely:
			continue

		ranked_targets.append(
			{
				"hole": hole,
				"repair_trip_duration": repair_trip["total_time"],
				"is_flooding_hole": _is_flooding_hole(hole)
			}
		)

	ranked_targets.sort_custom(func(a, b): return _compare_targets(a, b))

	var result: Array = []

	for target in ranked_targets:
		result.append(target["hole"])

	return result


static func _compare_targets(a: Dictionary, b: Dictionary) -> bool:
	if a["repair_trip_duration"] != b["repair_trip_duration"]:
		return a["repair_trip_duration"] < b["repair_trip_duration"]

	if a["is_flooding_hole"] != b["is_flooding_hole"]:
		return a["is_flooding_hole"] and not b["is_flooding_hole"]

	return String(a["hole"].name) < String(b["hole"].name)


static func _is_flooding_hole(hole: ShipHolePoint) -> bool:
	return (
		hole != null
		and (
			hole.deck == DeckGraph.DECKS.MID
			or hole.deck == DeckGraph.DECKS.LOWER
		)
	)
