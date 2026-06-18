class_name MoveAndBailWaterAction
extends MoveToPointAction

const RUNTIME_ROUTE_POSITIONS := &"route_positions"
const RUNTIME_SEGMENT_LENGTHS := &"segment_lengths"
const RUNTIME_SEGMENT_DURATIONS := &"segment_durations"
const RUNTIME_SEGMENT_FROM_DECKS := &"segment_from_decks"
const RUNTIME_SEGMENT_TO_DECKS := &"segment_to_decks"
const RUNTIME_TOTAL_DISTANCE := &"total_distance"
const RUNTIME_WINDUP_STARTED := &"windup_started"

var route_points: Array = []


func _init(
	new_point: ShipActionPoint,
	new_route_points: Array = []
) -> void:

	super(new_point)

	action_id = "move_and_bail_water"
	route_points = _build_route_points(
		new_point,
		new_route_points
	)


func get_duration(
	actor,
	_context := {}
) -> float:

	return max(
		MoveToPointAction.get_travel_duration_for_points(
			actor,
			route_points
		),
		BailWaterAction.DURATION
	)


func on_start(
	actor,
	instance
) -> void:

	var route_positions = MoveToPointAction.get_route_positions_for_points(
		actor,
		route_points
	)
	var start_deck = actor.location
	var target_deck = start_deck

	if point != null:
		target_deck = point.deck

	_set_runtime(
		instance,
		RUNTIME_ROUTE_POSITIONS,
		route_positions
	)
	_set_runtime(
		instance,
		RUNTIME_START_DECK,
		start_deck
	)
	_set_runtime(
		instance,
		RUNTIME_TARGET_DECK,
		target_deck
	)

	_rebuild_route_segments(
		actor,
		instance
	)

	if not route_positions.is_empty():
		_set_runtime(
			instance,
			RUNTIME_START_POSITION,
			route_positions[0]
		)
		_set_runtime(
			instance,
			RUNTIME_TARGET_POSITION,
			route_positions[
				route_positions.size() - 1
			]
		)

	_set_runtime(
		instance,
		RUNTIME_WINDUP_STARTED,
		false
	)
	_start_windup_if_ready(
		actor,
		instance
	)


func on_tick(
	actor,
	instance,
	_delta: float
) -> void:

	_start_windup_if_ready(
		actor,
		instance
	)

	var distance_along_route = _get_distance_along_route(
		instance,
		instance.elapsed
	)

	actor.position = _get_position_at_distance(
		instance,
		distance_along_route
	)
	_update_actor_location_at_distance(
		actor,
		instance,
		distance_along_route
	)


func on_complete(
	actor,
	instance
) -> void:

	_start_windup_if_ready(
		actor,
		instance
	)

	actor.position = _get_runtime_vector2(
		instance,
		RUNTIME_TARGET_POSITION,
		actor.position
	)
	_update_actor_location(actor)

	BailWaterAction.collect_water(
		actor,
		point
	)

	completed.emit(
		_build_context(
			actor,
			instance
		)
	)


func _start_windup_if_ready(
	actor,
	instance
) -> void:

	if bool(
		_get_runtime(
			instance,
			RUNTIME_WINDUP_STARTED,
			false
		)
	):
		return

	var travel_duration = _get_runtime_float(
		instance,
		RUNTIME_TRAVEL_DURATION
	)
	var windup_start_time = max(
		travel_duration - BailWaterAction.DURATION,
		0.0
	)

	if instance.elapsed < windup_start_time:
		return

	_set_runtime(
		instance,
		RUNTIME_WINDUP_STARTED,
		true
	)
	BailWaterAction.print_bail_started(
		actor,
		point
	)


func _get_distance_along_route(
	instance,
	elapsed: float
) -> float:

	var travel_duration = _get_runtime_float(
		instance,
		RUNTIME_TRAVEL_DURATION
	)
	var total_distance = _get_runtime_float(
		instance,
		RUNTIME_TOTAL_DISTANCE
	)

	if travel_duration <= 0.0:
		return total_distance

	var remaining_time = clamp(
		elapsed,
		0.0,
		travel_duration
	)
	var distance := 0.0
	var segment_lengths = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_LENGTHS
	)
	var segment_durations = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_DURATIONS
	)

	for i in range(segment_lengths.size()):
		var segment_duration = segment_durations[i]
		var segment_length = segment_lengths[i]

		if segment_duration <= 0.0:
			distance += segment_length
			continue

		if remaining_time <= segment_duration:
			return (
				distance
				+ segment_length * (remaining_time / segment_duration)
			)

		distance += segment_length
		remaining_time -= segment_duration

	return total_distance


func _rebuild_route_segments(
	actor,
	instance
) -> void:

	var route_positions = _get_runtime_array(
		instance,
		RUNTIME_ROUTE_POSITIONS
	)
	var segment_lengths: Array = []
	var segment_durations: Array = []
	var segment_from_decks: Array[int] = []
	var segment_to_decks: Array[int] = []
	var total_distance := 0.0
	var travel_duration := 0.0

	if route_positions.size() <= 1:
		_store_route_segments(
			instance,
			segment_lengths,
			segment_durations,
			segment_from_decks,
			segment_to_decks,
			total_distance,
			travel_duration
		)
		return

	var current_deck = actor.location

	for i in range(route_positions.size() - 1):
		var segment_length = route_positions[i].distance_to(route_positions[i + 1])
		var target_point: ShipActionPoint = null
		var target_deck = current_deck

		if i < route_points.size():
			target_point = route_points[i]

			if target_point != null:
				target_deck = target_point.deck

		var segment_duration = MoveToPointAction.get_travel_duration_to_point(
			actor,
			target_point,
			route_positions[i],
			current_deck
		)

		segment_lengths.append(segment_length)
		segment_durations.append(segment_duration)
		segment_from_decks.append(current_deck)
		segment_to_decks.append(target_deck)
		total_distance += segment_length
		travel_duration += segment_duration
		current_deck = target_deck

	_store_route_segments(
		instance,
		segment_lengths,
		segment_durations,
		segment_from_decks,
		segment_to_decks,
		total_distance,
		travel_duration
	)


func _store_route_segments(
	instance,
	segment_lengths: Array,
	segment_durations: Array,
	segment_from_decks: Array,
	segment_to_decks: Array,
	total_distance: float,
	travel_duration: float
) -> void:

	_set_runtime(
		instance,
		RUNTIME_SEGMENT_LENGTHS,
		segment_lengths
	)
	_set_runtime(
		instance,
		RUNTIME_SEGMENT_DURATIONS,
		segment_durations
	)
	_set_runtime(
		instance,
		RUNTIME_SEGMENT_FROM_DECKS,
		segment_from_decks
	)
	_set_runtime(
		instance,
		RUNTIME_SEGMENT_TO_DECKS,
		segment_to_decks
	)
	_set_runtime(
		instance,
		RUNTIME_TOTAL_DISTANCE,
		total_distance
	)
	_set_runtime(
		instance,
		RUNTIME_TRAVEL_DURATION,
		travel_duration
	)


func _get_position_at_distance(
	instance,
	distance_along_route: float
) -> Vector2:

	var route_positions = _get_runtime_array(
		instance,
		RUNTIME_ROUTE_POSITIONS
	)
	var target_position = _get_runtime_vector2(
		instance,
		RUNTIME_TARGET_POSITION,
		Vector2.ZERO
	)
	var total_distance = _get_runtime_float(
		instance,
		RUNTIME_TOTAL_DISTANCE
	)

	if route_positions.is_empty():
		return target_position

	if (
		total_distance <= 0.0
		or route_positions.size() == 1
	):
		return route_positions[
			route_positions.size() - 1
		]

	var remaining_distance = clamp(
		distance_along_route,
		0.0,
		total_distance
	)
	var segment_lengths = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_LENGTHS
	)

	for i in range(
		segment_lengths.size()
	):
		var segment_length = segment_lengths[i]

		if segment_length <= 0.0:
			continue

		if remaining_distance <= segment_length:
			return route_positions[i].lerp(
				route_positions[i + 1],
				remaining_distance / segment_length
			)

		remaining_distance -= segment_length

	return route_positions[
		route_positions.size() - 1
	]


func _update_actor_location_at_distance(
	actor,
	instance,
	distance_along_route: float
) -> void:

	if route_points.is_empty():
		return

	var remaining_distance = clamp(
		distance_along_route,
		0.0,
		_get_runtime_float(
			instance,
			RUNTIME_TOTAL_DISTANCE
		)
	)
	var segment_lengths = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_LENGTHS
	)
	var segment_from_decks = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_FROM_DECKS
	)
	var segment_to_decks = _get_runtime_array(
		instance,
		RUNTIME_SEGMENT_TO_DECKS
	)

	for i in range(segment_lengths.size()):
		var segment_length = segment_lengths[i]
		var from_deck: int = segment_from_decks[i]
		var to_deck: int = segment_to_decks[i]

		if (
			segment_length <= 0.0
			or remaining_distance >= segment_length
		):
			_clear_actor_deck_transition(actor)
			actor.set_location(to_deck)
			remaining_distance -= segment_length
			continue

		if from_deck != to_deck:
			_begin_actor_deck_transition(
				actor,
				from_deck,
				to_deck
			)
		else:
			_clear_actor_deck_transition(actor)
			actor.set_location(to_deck)

		return

	if not route_points.is_empty():
		_clear_actor_deck_transition(actor)
		actor.set_location(route_points[route_points.size() - 1].deck)


func _get_runtime_array(
	instance,
	key
) -> Array:

	var value = _get_runtime(
		instance,
		key,
		[]
	)

	if value is Array:
		return value

	return []


func _build_route_points(
	target_point: ShipActionPoint,
	new_route_points: Array
) -> Array:

	var result: Array = []

	for route_point in new_route_points:
		if route_point == null:
			continue

		result.append(route_point)

	if (
		target_point != null
		and (
			result.is_empty()
			or result[
				result.size() - 1
			] != target_point
		)
	):
		result.append(target_point)

	return result
