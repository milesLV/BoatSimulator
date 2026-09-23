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

	for hole in action_points.hull_holes:
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

		ranked_targets.append({
			"hole": hole,
			"repair_trip_duration": repair_trip["total_time"],
			"is_flooding_hole": hole.deck in DeckGraph.FLOODED_DECKS
		})

	ranked_targets.sort_custom(_compare_targets)

	return ranked_targets.map(func(target): return target["hole"])


static func _compare_targets(a: Dictionary, b: Dictionary) -> bool:
	if a["repair_trip_duration"] != b["repair_trip_duration"]:
		return a["repair_trip_duration"] < b["repair_trip_duration"]

	if a["is_flooding_hole"] != b["is_flooding_hole"]:
		return a["is_flooding_hole"] and not b["is_flooding_hole"]

	return String(a["hole"].name) < String(b["hole"].name)
