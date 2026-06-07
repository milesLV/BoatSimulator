class_name ShipHealthSystem
extends RefCounted

signal sunk

const MAX_WATER_LEVEL := 500.0

var ship
var action_points: ShipActionPointContainer
var water_level := 0.0
var sunk_state := false
var flood_rate_cache := 0.0


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

	return ShipFloodForecast.projected_water_level(
		water_level,
		flood_rate_cache,
		seconds,
		MAX_WATER_LEVEL
	)


func _add_flooding_for_delta(delta: float) -> void:

	water_level = ShipFloodForecast.projected_water_level(
		water_level,
		flood_rate_cache,
		delta,
		MAX_WATER_LEVEL
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

	return flood_rate_cache


func get_time_until_full() -> float:

	return ShipFloodForecast.time_until_full(
		water_level,
		flood_rate_cache,
		MAX_WATER_LEVEL
	)


func is_sunk() -> bool:

	return sunk_state


func _get_flood_rate() -> float:

	if action_points == null:
		return 0.0

	var flood_rate := 0.0

	for hole in action_points.get_holes_ref():
		if (
			hole.deck != DeckGraph.DECKS.MID
			and hole.deck != DeckGraph.DECKS.LOWER
		):
			continue

		flood_rate += hole.grade

	return flood_rate


func _rebuild_flood_rate_cache() -> void:

	flood_rate_cache = _get_flood_rate()

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
		or (
			hole.deck != DeckGraph.DECKS.MID
			and hole.deck != DeckGraph.DECKS.LOWER
		)
	):
		return

	flood_rate_cache = max(
		flood_rate_cache + float(new_grade - old_grade),
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
