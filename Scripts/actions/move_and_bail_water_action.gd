class_name MoveAndBailWaterAction
extends MoveToPointAction

var route_points: Array = []

var _route_positions: Array = []
var _segment_lengths: Array = []
var _total_distance := 0.0
var _travel_duration := 0.0
var _windup_started := false


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

	_route_positions = MoveToPointAction.get_route_positions_for_points(
		actor,
		route_points
	)
	_rebuild_segment_lengths()
	_travel_duration = _total_distance / MOVE_SPEED

	if not _route_positions.is_empty():
		_start_position = _route_positions[0]
		_target_position = _route_positions[
			_route_positions.size() - 1
		]

	_windup_started = false
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

	var distance_along_route = _get_distance_along_route(instance.elapsed)

	actor.position = _get_position_at_distance(distance_along_route)
	_update_actor_location_at_distance(
		actor,
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

	actor.position = _target_position
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

	if _windup_started:
		return

	var windup_start_time = max(
		_travel_duration - BailWaterAction.DURATION,
		0.0
	)

	if instance.elapsed < windup_start_time:
		return

	_windup_started = true
	BailWaterAction.print_bail_started(
		actor,
		point
	)


func _get_distance_along_route(elapsed: float) -> float:

	if _travel_duration <= 0.0:
		return _total_distance

	return min(
		elapsed * MOVE_SPEED,
		_total_distance
	)


func _rebuild_segment_lengths() -> void:

	_segment_lengths.clear()
	_total_distance = 0.0

	if _route_positions.size() <= 1:
		return

	for i in range(
		_route_positions.size() - 1
	):
		var segment_length = _route_positions[i].distance_to(_route_positions[i + 1])

		_segment_lengths.append(segment_length)
		_total_distance += segment_length


func _get_position_at_distance(distance_along_route: float) -> Vector2:

	if _route_positions.is_empty():
		return _target_position

	if (
		_total_distance <= 0.0
		or _route_positions.size() == 1
	):
		return _route_positions[
			_route_positions.size() - 1
		]

	var remaining_distance = clamp(
		distance_along_route,
		0.0,
		_total_distance
	)

	for i in range(
		_segment_lengths.size()
	):
		var segment_length = _segment_lengths[i]

		if segment_length <= 0.0:
			continue

		if remaining_distance <= segment_length:
			return _route_positions[i].lerp(
				_route_positions[i + 1],
				remaining_distance / segment_length
			)

		remaining_distance -= segment_length

	return _route_positions[
		_route_positions.size() - 1
	]


func _update_actor_location_at_distance(
	actor,
	distance_along_route: float
) -> void:

	if route_points.is_empty():
		return

	var remaining_distance = clamp(
		distance_along_route,
		0.0,
		_total_distance
	)

	for i in range(
		_segment_lengths.size()
	):
		var segment_length = _segment_lengths[i]

		if (
			remaining_distance <= segment_length
			or i == _segment_lengths.size() - 1
		):
			actor.set_location(route_points[i].deck)
			return

		remaining_distance -= segment_length


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


func _get_actor_name(actor) -> String:

	if actor == null:
		return "Unknown actor"

	return String(
		actor.name
	)


func _get_point_name() -> String:

	if point == null:
		return "unknown point"

	return String(
		point.name
	)
