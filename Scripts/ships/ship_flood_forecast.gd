class_name ShipFloodForecast
extends RefCounted


static func projected_water_level(
	water_level: float,
	flood_rate: float,
	seconds: float,
	max_water_level: float
) -> float:

	return min(
		water_level + max(flood_rate, 0.0) * max(seconds, 0.0),
		max_water_level
	)


static func time_until_full(
	water_level: float,
	flood_rate: float,
	max_water_level: float
) -> float:

	if flood_rate <= 0.0:
		return INF

	return max((max_water_level - water_level) / flood_rate, 0.0)


static func bail_rate(bucket_amount: float, bail_cycle_duration: float) -> float:
	if bail_cycle_duration <= 0.0 or bail_cycle_duration == INF:
		return 0.0

	return bucket_amount / bail_cycle_duration


static func flood_rate_after_bailing(
	flood_rate: float,
	bucket_amount: float,
	bail_cycle_duration: float
) -> float:

	return max(flood_rate - bail_rate(bucket_amount, bail_cycle_duration), 0.0)


static func can_survive_repair_trip(
	water_level: float,
	max_water_level: float,
	flood_rate: float,
	repaired_hole_flood_rate: float,
	repair_complete_time: float,
	total_time: float,
	safety_leeway: float
) -> bool:

	var safe_total_time = total_time + safety_leeway
	var water_after_repair = projected_water_level(
		water_level,
		flood_rate,
		repair_complete_time,
		max_water_level
	)

	if water_after_repair >= max_water_level:
		return false

	var remaining_time = max(safe_total_time - repair_complete_time, 0.0)
	var post_repair_flood_rate = max(
		flood_rate - repaired_hole_flood_rate,
		0.0
	)
	var projected_water_after_trip = projected_water_level(
		water_after_repair,
		post_repair_flood_rate,
		remaining_time,
		max_water_level
	)

	return projected_water_after_trip < max_water_level
