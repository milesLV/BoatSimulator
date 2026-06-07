extends ActionDefinition
class_name MoveToPointAction

const MOVE_SPEED := Crewmate.RUN_SPEED

var point: ShipActionPoint
var _start_position: Vector2
var _target_position: Vector2


func _init(new_point: ShipActionPoint) -> void:

	point = new_point
	action_point = point
	progress_policy = ProgressPolicy.CONTINUOUS

	if point == null:
		action_id = "go_to_missing_point"
		action_location = ""
		return

	action_id = "go_to_%s" % point.name
	action_location = String(point.name)


func get_duration(actor, _context := {}) -> float:

	if point == null:
		return 0.0

	return get_travel_duration_to_point(
		actor,
		point
	)


func on_start(actor, _instance) -> void:

	if point == null:
		push_error("MoveToPointAction has no action point.")

		return

	_start_position = actor.position
	_target_position = point.get_position_for_actor(actor)


func on_tick(actor, instance, _delta: float) -> void:

	var progress = instance.get_progress()

	actor.position = _start_position.lerp(
		_target_position,
		progress
	)

	_update_actor_location(actor)


func on_complete(actor, _instance) -> void:

	actor.position = _target_position

	_update_actor_location(actor)

	super.on_complete(
		actor,
		_instance
	)


func _update_actor_location(actor) -> void:

	if point == null:
		return

	actor.set_location(point.deck)


static func get_travel_duration_to_point(
	actor,
	target_point: ShipActionPoint,
	start_position = null
) -> float:

	if (
		actor == null
		or target_point == null
	):
		return 0.0

	var origin = _resolve_start_position(
		actor,
		start_position
	)
	var target_position = target_point.get_position_for_actor(actor)

	return origin.distance_to(
		target_position
	) / MOVE_SPEED


static func get_travel_duration_for_points(
	actor,
	route_points: Array,
	start_position = null
) -> float:

	return get_travel_distance_for_points(
		actor,
		route_points,
		start_position
	) / MOVE_SPEED


static func get_travel_distance_for_points(
	actor,
	route_points: Array,
	start_position = null
) -> float:

	var route_positions = get_route_positions_for_points(
		actor,
		route_points,
		start_position
	)

	if route_positions.size() <= 1:
		return 0.0

	var distance := 0.0

	for i in range(
		route_positions.size() - 1
	):
		distance += route_positions[i].distance_to(route_positions[i + 1])

	return distance


static func get_route_positions_for_points(
	actor,
	route_points: Array,
	start_position = null
) -> Array:

	var positions: Array = []

	if actor == null:
		return positions

	positions.append(
		_resolve_start_position(
			actor,
			start_position
		)
	)

	for route_point in route_points:
		if route_point == null:
			continue

		positions.append(route_point.get_position_for_actor(actor))

	return positions


static func _resolve_start_position(
	actor,
	start_position
) -> Vector2:

	if start_position is Vector2:
		return start_position

	return actor.position
