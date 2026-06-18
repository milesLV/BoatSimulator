class_name ShipHealthSystem
extends RefCounted

signal sunk

const MAX_WATER_LEVEL := 500.0
const LOWER_DECK_FLOODED := 140.0
const MID_DECK_WATER_LEVEL := 232.0
const MOVING_LOWER_HOLE_EFFICIENCY := 0.9
const MOVING_MID_HOLE_EFFICIENCY := 0.333
const STILL_LOWER_HOLE_EFFICIENCY := 1.0
const STILL_MID_HOLE_EFFICIENCY := 0.166

var ship
var action_points: ShipActionPointContainer
var water_level := 0.0
var sunk_state := false
var lower_deck_flood_rate_cache := 0.0
var mid_deck_flood_rate_cache := 0.0


func _init(
	new_ship,
	new_action_points: ShipActionPointContainer
) -> void:

	ship = new_ship
	action_points = new_action_points
	_rebuild_flood_rate_cache()


func physics_process(delta: float) -> void:

	if sunk_state:
		return

	_add_flooding_for_delta(delta)

	if water_level >= MAX_WATER_LEVEL:
		_sink()


func get_projected_water_level(seconds: float) -> float:

	return _project_water_level(
		water_level,
		seconds,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)


func _add_flooding_for_delta(delta: float) -> void:

	water_level = _project_water_level(
		water_level,
		delta,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)


func remove_water(amount: float) -> float:

	if amount <= 0.0:
		return 0.0

	var removed = min(
		amount,
		water_level
	)

	water_level -= removed

	return removed


func apply_cannonball_hit(
	hit_position: Vector2,
	hole_damage: int
) -> bool:

	if action_points == null:
		return false

	var hole = action_points.get_closest_hole(hit_position)

	if hole == null:
		return false

	hole.add_grade(hole_damage)

	return true


func get_water_level() -> float:

	return water_level


func get_flood_rate() -> float:

	return _get_flood_rate_for_water_level(
		water_level,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)


func get_time_until_full(flood_rate_offset := 0.0) -> float:

	return _get_time_until_full(
		water_level,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache,
		flood_rate_offset
	)


func is_sunk() -> bool:

	return sunk_state


func can_survive_repair_trip(
	hole: ShipHolePoint,
	effective_flood_rate: float,
	repair_complete_time: float,
	total_time: float,
	safety_leeway: float
) -> bool:

	var flood_rate_offset = effective_flood_rate - get_flood_rate()
	var water_after_repair = _project_water_level(
		water_level,
		repair_complete_time,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache,
		flood_rate_offset
	)

	if water_after_repair >= MAX_WATER_LEVEL:
		return false

	var lower_rate = lower_deck_flood_rate_cache
	var mid_rate = mid_deck_flood_rate_cache

	if hole != null:
		match hole.deck:
			DeckGraph.DECKS.LOWER:
				lower_rate = max(lower_rate - float(hole.grade), 0.0)
			DeckGraph.DECKS.MID:
				mid_rate = max(mid_rate - float(hole.grade), 0.0)

	var projected_water_after_trip = _project_water_level(
		water_after_repair,
		max(total_time + safety_leeway - repair_complete_time, 0.0),
		lower_rate,
		mid_rate,
		flood_rate_offset
	)

	return projected_water_after_trip < MAX_WATER_LEVEL


func _get_raw_flood_rates() -> Vector2:

	if action_points == null:
		return Vector2.ZERO

	var flood_rates := Vector2.ZERO

	for hole in action_points.get_holes_ref():
		match hole.deck:
			DeckGraph.DECKS.LOWER:
				flood_rates.x += hole.grade
			DeckGraph.DECKS.MID:
				flood_rates.y += hole.grade

	return flood_rates


func _get_flood_rate_for_water_level(
	projected_water_level: float,
	lower_rate: float,
	mid_rate: float,
	flood_rate_offset := 0.0
) -> float:

	return max(
		lower_rate * _get_lower_deck_efficiency()
		+ mid_rate * _get_mid_deck_efficiency(projected_water_level)
		+ flood_rate_offset,
		0.0
	)


func _project_water_level(
	start_water_level: float,
	seconds: float,
	lower_rate: float,
	mid_rate: float,
	flood_rate_offset := 0.0
) -> float:

	if seconds <= 0.0:
		return min(start_water_level, MAX_WATER_LEVEL)

	var rate = _get_flood_rate_for_water_level(
		start_water_level,
		lower_rate,
		mid_rate,
		flood_rate_offset
	)

	if start_water_level < MID_DECK_WATER_LEVEL and rate > 0.0:
		var time_to_mid_deck = (
			(MID_DECK_WATER_LEVEL - start_water_level)
			/ rate
		)

		if time_to_mid_deck < seconds:
			return min(
				MID_DECK_WATER_LEVEL
				+ _get_flood_rate_for_water_level(
					MID_DECK_WATER_LEVEL,
					lower_rate,
					mid_rate,
					flood_rate_offset
				) * (seconds - time_to_mid_deck),
				MAX_WATER_LEVEL
			)

	return min(
		start_water_level + rate * seconds,
		MAX_WATER_LEVEL
	)


func _get_time_until_full(
	start_water_level: float,
	lower_rate: float,
	mid_rate: float,
	flood_rate_offset := 0.0
) -> float:

	if start_water_level >= MAX_WATER_LEVEL:
		return 0.0

	var rate = _get_flood_rate_for_water_level(
		start_water_level,
		lower_rate,
		mid_rate,
		flood_rate_offset
	)

	if rate <= 0.0:
		return INF

	if start_water_level >= MID_DECK_WATER_LEVEL:
		return (MAX_WATER_LEVEL - start_water_level) / rate

	var time_to_mid_deck = (
		(MID_DECK_WATER_LEVEL - start_water_level)
		/ rate
	)
	var mid_rate_after_threshold = _get_flood_rate_for_water_level(
		MID_DECK_WATER_LEVEL,
		lower_rate,
		mid_rate,
		flood_rate_offset
	)

	if mid_rate_after_threshold <= 0.0:
		return INF

	return (
		time_to_mid_deck
		+ (MAX_WATER_LEVEL - MID_DECK_WATER_LEVEL) / mid_rate_after_threshold
	)


func _get_lower_deck_efficiency() -> float:

	if _is_ship_moving():
		return MOVING_LOWER_HOLE_EFFICIENCY

	return STILL_LOWER_HOLE_EFFICIENCY


func _get_mid_deck_efficiency(projected_water_level: float) -> float:

	if projected_water_level >= MID_DECK_WATER_LEVEL:
		return _get_lower_deck_efficiency()

	if _is_ship_moving():
		return MOVING_MID_HOLE_EFFICIENCY

	return STILL_MID_HOLE_EFFICIENCY


func _is_ship_moving() -> bool:

	return ship != null and ship.velocity.length() > 0.01


func _rebuild_flood_rate_cache() -> void:

	var flood_rates = _get_raw_flood_rates()
	lower_deck_flood_rate_cache = flood_rates.x
	mid_deck_flood_rate_cache = flood_rates.y

	if action_points == null:
		return

	var handler = Callable(
		self,
		"_on_hole_grade_changed"
	)

	for hole in action_points.get_holes_ref():
		if not hole.grade_changed.is_connected(
			handler
		):
			hole.grade_changed.connect(handler)


func _on_hole_grade_changed(
	hole: ShipHolePoint,
	old_grade: int,
	new_grade: int
) -> void:

	if (
		hole == null
	):
		return

	var grade_delta = float(new_grade - old_grade)

	match hole.deck:
		DeckGraph.DECKS.LOWER:
			lower_deck_flood_rate_cache = max(
				lower_deck_flood_rate_cache + grade_delta,
				0.0
			)
		DeckGraph.DECKS.MID:
			mid_deck_flood_rate_cache = max(
				mid_deck_flood_rate_cache + grade_delta,
				0.0
			)


func _sink() -> void:

	if sunk_state:
		return

	sunk_state = true
	water_level = MAX_WATER_LEVEL

	ShipDebugLog.repair(
		"%s has sunk."
		% ship.name
	)

	if (
		ship != null
		and ship.has_method("on_sunk")
	):
		ship.on_sunk()

	sunk.emit()
