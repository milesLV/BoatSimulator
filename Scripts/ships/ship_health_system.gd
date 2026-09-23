class_name ShipHealthSystem
extends RefCounted

const MAX_WATER_LEVEL := 500.0
const LOWER_DECK_FLOODED := 140.0
const MID_DECK_WATER_LEVEL := 232.0
const MOVING_LOWER_HOLE_EFFICIENCY := 0.9
const MOVING_MID_HOLE_EFFICIENCY := 0.333
const STILL_LOWER_HOLE_EFFICIENCY := 1.0
const STILL_MID_HOLE_EFFICIENCY := 0.166
const MAST_RADIUS := 8.0
const MAST_HOLE_DAMAGE := 2

var ship
var action_points: ShipActionPointContainer
var water_level := 0.0
var sunk_state := false
var lower_deck_flood_rate_cache := 0.0
var mid_deck_flood_rate_cache := 0.0


func _init(new_ship, new_action_points: ShipActionPointContainer) -> void:
	ship = new_ship
	action_points = new_action_points

	if action_points == null:
		return

	for hole in action_points.hull_holes:
		_add_flood_rate(hole.deck, float(hole.grade))
		hole.grade_changed.connect(_on_hole_grade_changed)


func physics_process(delta: float) -> void:

	if sunk_state:
		return

	water_level = _project_water_level(
		water_level,
		delta,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)

	if water_level >= MAX_WATER_LEVEL:
		_sink()


func get_projected_water_level(seconds: float, water_removals: Array = []) -> float:
	var projected_water = water_level
	var elapsed := 0.0
	var removals = water_removals.duplicate()
	removals.sort_custom(
		func(a, b): return float(a.get("time", 0.0)) < float(b.get("time", 0.0))
	)

	for removal in removals:
		var time = float(removal.get("time", 0.0))
		var removal_time = clamp(time, elapsed, seconds)
		projected_water = _project_water_level(
			projected_water,
			removal_time - elapsed,
			lower_deck_flood_rate_cache,
			mid_deck_flood_rate_cache
		)
		elapsed = removal_time

		if time <= seconds:
			projected_water = max(projected_water - float(removal.get("amount", 0.0)), 0.0)

	return _project_water_level(
		projected_water,
		seconds - elapsed,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)


func remove_water(amount: float) -> float:

	if amount <= 0.0:
		return 0.0

	var removed = min(amount, water_level)

	water_level -= removed

	return removed


## Where the ball struck decides which hole it opened - the gunner may have picked a hole the
## far end of the hull, and grading it there is the ball phasing through. Returns the hole that
## took the damage, or null. A hole already at its cap absorbs nothing: set_grade clamps, and
## the damage does not spill onto the next hole along.
func apply_cannonball_hit(hit_position: Vector2, hole_damage: int) -> ShipHolePoint:

	if action_points == null:
		return null

	var hole = _closest_facing_hole(hit_position)

	if hole != null:
		hole.set_grade(hole.grade + hole_damage)

	return hole


## A ball that missed the hull but crossed the mast on its way past. [param from] and
## [param to] are the ends of the flight it has left. Opens one fresh mast hole - they cap at
## grade 2 - and does nothing once all three are open.
func apply_mast_hit(from: Vector2, to: Vector2) -> bool:

	if action_points == null or action_points.mast_holes.is_empty():
		return false

	var mast = action_points.mast_holes.front().global_position

	if Geometry2D.get_closest_point_to_segment(mast, from, to).distance_to(mast) > MAST_RADIUS:
		return false

	for hole in action_points.mast_holes:
		if hole.grade < hole.max_grade:
			hole.set_grade(hole.grade + MAST_HOLE_DAMAGE)
			return true

	return false


## The hole whose footprint is nearest the impact, out of those cut into plating facing the same
## way as the plating the ball went through. Both points are on the hull: the hole nodes sit
## 10 to 70px inside it, so measuring an impact against a node compares two different things and
## hands the hit to whichever hole happens to be buried deepest.
func _closest_facing_hole(hit_position: Vector2) -> ShipHolePoint:

	var struck = AimForHoles.outward_normal(ship.to_local(hit_position))
	var footprint := func(hole): return ship.to_global(
		AimForHoles.hull_footprint(ship.to_local(hole.global_position))
	)

	var facing = action_points.hull_holes.filter(func(hole): return (
		AimForHoles.outward_normal(ship.to_local(hole.global_position)).dot(struck) > 0.0
	))

	if facing.is_empty():
		return action_points.get_closest_hole(hit_position)

	return facing.reduce(func(closest, hole): return (
		hole
		if footprint.call(hole).distance_to(hit_position)
		< footprint.call(closest).distance_to(hit_position)
		else closest
	))


## How much water a grade point on [param deck] actually lets in right now.
func get_deck_efficiency(deck: int) -> float:

	if deck == DeckGraph.DECKS.LOWER:
		return _get_lower_deck_efficiency()

	if deck == DeckGraph.DECKS.MID:
		return _get_mid_deck_efficiency(water_level)

	return 0.0


func get_flood_rate() -> float:

	return _get_flood_rate_for_water_level(
		water_level,
		lower_deck_flood_rate_cache,
		mid_deck_flood_rate_cache
	)


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

	return min(start_water_level + rate * seconds, MAX_WATER_LEVEL)


func _get_lower_deck_efficiency() -> float:

	return MOVING_LOWER_HOLE_EFFICIENCY if _is_ship_moving() else STILL_LOWER_HOLE_EFFICIENCY


func _get_mid_deck_efficiency(projected_water_level: float) -> float:

	if projected_water_level >= MID_DECK_WATER_LEVEL:
		return _get_lower_deck_efficiency()

	return MOVING_MID_HOLE_EFFICIENCY if _is_ship_moving() else STILL_MID_HOLE_EFFICIENCY


func _is_ship_moving() -> bool:

	return ship != null and ship.velocity.length() > 0.01


func _on_hole_grade_changed(hole: ShipHolePoint, old_grade: int, new_grade: int) -> void:
	_add_flood_rate(hole.deck, float(new_grade - old_grade))


func _add_flood_rate(deck: int, grade_delta: float) -> void:

	if deck == DeckGraph.DECKS.LOWER:
		lower_deck_flood_rate_cache = max(lower_deck_flood_rate_cache + grade_delta, 0.0)
	elif deck == DeckGraph.DECKS.MID:
		mid_deck_flood_rate_cache = max(mid_deck_flood_rate_cache + grade_delta, 0.0)


func _sink() -> void:

	if sunk_state:
		return

	sunk_state = true
	water_level = MAX_WATER_LEVEL

	ShipDebugLog.write(&"repair",
		"%s has sunk."
		% ship.name
	)

	ship.on_sunk()
