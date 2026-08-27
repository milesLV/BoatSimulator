class_name MoveAndBailWaterAction
extends MoveToPointAction

const RUNTIME_ROUTE_POSITIONS := &"route_positions"
const RUNTIME_SEGMENT_LENGTHS := &"segment_lengths"
const RUNTIME_SEGMENT_DURATIONS := &"segment_durations"
const RUNTIME_SEGMENT_FROM_DECKS := &"segment_from_decks"
const RUNTIME_SEGMENT_TO_DECKS := &"segment_to_decks"
const RUNTIME_TOTAL_DISTANCE := &"total_distance"
const RUNTIME_ROUTE_CURVE := &"route_curve"
const RUNTIME_WINDUP_STARTED := &"windup_started"

var route_points: Array = []


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:
	super(new_point)

	action_id = "move_and_bail_water"
	fills_bucket = true
	route_points = build_route_points(new_point, new_route_points)


func get_duration(actor, _context := {}) -> float:
	return max(
		MoveToPointAction.get_travel_duration_for_points(actor, route_points),
		BailWaterAction.DURATION
	)


func on_start(actor, instance) -> void:
	var route_positions = MoveToPointAction.get_route_positions_for_points(actor, route_points)
	var start_deck = actor.location
	var target_deck = start_deck

	if point != null:
		target_deck = point.deck

	instance.set_runtime_value(RUNTIME_ROUTE_POSITIONS, route_positions)
	instance.set_runtime_value(RUNTIME_START_DECK, start_deck)
	instance.set_runtime_value(RUNTIME_TARGET_DECK, target_deck)

	_rebuild_route_segments(actor, instance)

	if not route_positions.is_empty():
		instance.set_runtime_value(RUNTIME_START_POSITION, route_positions[0])
		instance.set_runtime_value(RUNTIME_TARGET_POSITION, route_positions.back())

	instance.set_runtime_value(RUNTIME_WINDUP_STARTED, false)
	_start_windup_if_ready(actor, instance)


func on_tick(actor, instance, _delta: float) -> void:
	_start_windup_if_ready(actor, instance)

	var distance_along_route = _get_distance_along_route(instance, instance.elapsed)

	actor.position = _get_position_at_distance(instance, distance_along_route)
	_update_actor_location_at_distance(actor, instance, distance_along_route)


func on_complete(actor, instance) -> void:
	_start_windup_if_ready(actor, instance)

	actor.position = instance.get_runtime_value(RUNTIME_TARGET_POSITION, actor.position)
	_update_actor_location(actor)

	BailWaterAction.collect_water(actor, point)


func _start_windup_if_ready(actor, instance) -> void:
	if bool(instance.get_runtime_value(RUNTIME_WINDUP_STARTED, false)):
		return

	var travel_duration = instance.get_runtime_value(RUNTIME_TRAVEL_DURATION, 0.0)
	var windup_start_time = max(travel_duration - BailWaterAction.DURATION, 0.0)

	if instance.elapsed < windup_start_time:
		return

	instance.set_runtime_value(RUNTIME_WINDUP_STARTED, true)
	_on_windup_started(actor)


## Announced as the actor reaches the point; a throw does its work in on_complete.
func _on_windup_started(actor) -> void:

	BailWaterAction.print_bail_started(actor, point)


func _get_distance_along_route(instance, elapsed: float) -> float:
	var travel_duration = instance.get_runtime_value(RUNTIME_TRAVEL_DURATION, 0.0)
	var total_distance = instance.get_runtime_value(RUNTIME_TOTAL_DISTANCE, 0.0)

	if travel_duration <= 0.0:
		return total_distance

	var remaining_time = clamp(elapsed, 0.0, travel_duration)
	var distance := 0.0
	var segment_lengths = instance.get_runtime_value(RUNTIME_SEGMENT_LENGTHS, [])
	var segment_durations = instance.get_runtime_value(RUNTIME_SEGMENT_DURATIONS, [])

	for i in range(segment_lengths.size()):
		var segment_duration = segment_durations[i]
		var segment_length = segment_lengths[i]

		if segment_duration <= 0.0:
			distance += segment_length
			continue

		if remaining_time <= segment_duration:
			return distance + segment_length * (remaining_time / segment_duration)

		distance += segment_length
		remaining_time -= segment_duration

	return total_distance


func _rebuild_route_segments(actor, instance) -> void:
	var route_positions = instance.get_runtime_value(RUNTIME_ROUTE_POSITIONS, [])
	var segments = MoveToPointAction.get_route_segments(
		actor,
		route_points,
		route_positions,
		actor.location
	)
	var field := func(key): return segments.map(func(segment): return segment[key])
	var total := func(key): return field.call(key).reduce(func(a, b): return a + b, 0.0)

	instance.set_runtime_value(RUNTIME_SEGMENT_LENGTHS, field.call("length"))
	instance.set_runtime_value(RUNTIME_SEGMENT_DURATIONS, field.call("duration"))
	instance.set_runtime_value(RUNTIME_SEGMENT_FROM_DECKS, field.call("from_deck"))
	instance.set_runtime_value(RUNTIME_SEGMENT_TO_DECKS, field.call("to_deck"))
	instance.set_runtime_value(RUNTIME_TOTAL_DISTANCE, total.call("length"))
	instance.set_runtime_value(RUNTIME_TRAVEL_DURATION, total.call("duration"))

	var curve := Curve2D.new()

	for position in route_positions:
		curve.add_point(position)

	instance.set_runtime_value(RUNTIME_ROUTE_CURVE, curve)


func _get_position_at_distance(instance, distance_along_route: float) -> Vector2:
	var curve = instance.get_runtime_value(RUNTIME_ROUTE_CURVE)

	if not curve is Curve2D or curve.point_count == 0:
		return instance.get_runtime_value(RUNTIME_TARGET_POSITION, Vector2.ZERO)

	# sample_baked needs real length; a degenerate route just parks on its last point.
	if curve.get_baked_length() <= 0.0:
		return curve.get_point_position(curve.point_count - 1)

	return curve.sample_baked(distance_along_route)


func _update_actor_location_at_distance(actor, instance, distance_along_route: float) -> void:
	if route_points.is_empty():
		return

	var remaining_distance = clamp(
		distance_along_route,
		0.0,
		instance.get_runtime_value(RUNTIME_TOTAL_DISTANCE, 0.0)
	)
	var segment_lengths = instance.get_runtime_value(RUNTIME_SEGMENT_LENGTHS, [])
	var segment_from_decks = instance.get_runtime_value(RUNTIME_SEGMENT_FROM_DECKS, [])
	var segment_to_decks = instance.get_runtime_value(RUNTIME_SEGMENT_TO_DECKS, [])

	for i in range(segment_lengths.size()):
		var segment_length = segment_lengths[i]
		var from_deck: int = segment_from_decks[i]
		var to_deck: int = segment_to_decks[i]

		if segment_length <= 0.0 or remaining_distance >= segment_length:
			actor.clear_deck_transition()
			actor.set_location(to_deck)
			remaining_distance -= segment_length
			continue

		if from_deck != to_deck:
			actor.begin_deck_transition(from_deck, to_deck)
		else:
			actor.clear_deck_transition()
			actor.set_location(to_deck)

		return

	actor.clear_deck_transition()
	actor.set_location(route_points.back().deck)


## [param new_route_points] with [param target_point] appended when it is not already last.
static func build_route_points(target_point: ShipActionPoint, new_route_points: Array) -> Array:
	var result: Array = new_route_points.filter(func(p): return p != null)

	if (
		target_point != null
		and (
			result.is_empty()
			or result.back() != target_point
		)
	):
		result.append(target_point)

	return result
