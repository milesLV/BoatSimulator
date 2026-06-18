extends ActionDefinition
class_name MoveToPointAction

const MOVE_SPEED := Crewmate.RUN_SPEED
const FLOODED_LOWER_DECK_SPEED_SCALE := 0.7
const RUNTIME_START_POSITION := &"start_position"
const RUNTIME_TARGET_POSITION := &"target_position"
const RUNTIME_TRAVEL_DURATION := &"travel_duration"
const RUNTIME_START_DECK := &"start_deck"
const RUNTIME_TARGET_DECK := &"target_deck"

var point: ShipActionPoint


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


func on_start(actor, instance) -> void:

	if point == null:
		push_error("MoveToPointAction has no action point.")

		return

	var start_position = actor.position
	var target_position = point.get_position_for_actor(actor)
	var start_deck = actor.location
	var target_deck = point.deck
	var travel_duration = get_travel_duration_to_point(
		actor,
		point,
		start_position,
		start_deck
	)

	_set_runtime(
		instance,
		RUNTIME_START_POSITION,
		start_position
	)
	_set_runtime(
		instance,
		RUNTIME_TARGET_POSITION,
		target_position
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
	_set_runtime(
		instance,
		RUNTIME_TRAVEL_DURATION,
		travel_duration
	)

	if _is_deck_transition(instance):
		_begin_actor_deck_transition(
			actor,
			start_deck,
			target_deck
		)


func on_tick(actor, instance, _delta: float) -> void:

	var progress = 1.0

	var travel_duration = _get_runtime_float(
		instance,
		RUNTIME_TRAVEL_DURATION
	)

	if travel_duration > 0.0:
		progress = min(
			instance.elapsed / travel_duration,
			1.0
		)

	actor.position = _get_runtime_vector2(
		instance,
		RUNTIME_START_POSITION,
		actor.position
	).lerp(
		_get_runtime_vector2(
			instance,
			RUNTIME_TARGET_POSITION,
			actor.position
		),
		progress
	)

	if not _is_deck_transition(instance):
		_update_actor_location(actor)


func on_complete(actor, instance) -> void:

	actor.position = _get_runtime_vector2(
		instance,
		RUNTIME_TARGET_POSITION,
		actor.position
	)

	if _is_deck_transition(instance):
		_complete_actor_deck_transition(actor)
	else:
		_update_actor_location(actor)

	super.on_complete(
		actor,
		instance
	)


func on_interrupt(actor, _instance) -> void:

	_clear_actor_deck_transition(actor)


func _update_actor_location(actor) -> void:

	if point == null:
		return

	actor.set_location(point.deck)


func _is_deck_transition(instance) -> bool:

	var start_deck = _get_runtime_int(
		instance,
		RUNTIME_START_DECK,
		-1
	)
	var target_deck = _get_runtime_int(
		instance,
		RUNTIME_TARGET_DECK,
		-1
	)

	return (
		DeckGraph.is_valid_deck(start_deck)
		and DeckGraph.is_valid_deck(target_deck)
		and start_deck != target_deck
	)


func _begin_actor_deck_transition(
	actor,
	from_deck: int,
	to_deck: int
) -> void:

	if (
		actor != null
		and actor.has_method("begin_deck_transition")
	):
		actor.begin_deck_transition(
			from_deck,
			to_deck
		)


func _complete_actor_deck_transition(actor) -> void:

	if (
		actor != null
		and actor.has_method("complete_deck_transition")
	):
		actor.complete_deck_transition()
		return

	_update_actor_location(actor)


func _clear_actor_deck_transition(actor) -> void:

	if (
		actor != null
		and actor.has_method("clear_deck_transition")
	):
		actor.clear_deck_transition()


func _get_runtime_vector2(
	instance,
	key,
	default_value := Vector2.ZERO
) -> Vector2:

	var value = _get_runtime(
		instance,
		key,
		default_value
	)

	if value is Vector2:
		return value

	return default_value


func _get_runtime_float(
	instance,
	key,
	default_value := 0.0
) -> float:

	var value = _get_runtime(
		instance,
		key,
		default_value
	)

	if (
		value is float
		or value is int
	):
		return float(value)

	return default_value


func _get_runtime_int(
	instance,
	key,
	default_value := -1
) -> int:

	var value = _get_runtime(
		instance,
		key,
		default_value
	)

	if value is int:
		return value

	return default_value


static func get_travel_duration_to_point(
	actor,
	target_point: ShipActionPoint,
	start_position = null,
	start_deck = null
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
	var origin_deck = _resolve_start_deck(
		actor,
		start_deck
	)

	return _get_segment_travel_duration(
		actor,
		origin,
		target_position,
		origin_deck,
		target_point.deck,
		target_point
	)


static func get_travel_duration_for_points(
	actor,
	route_points: Array,
	start_position = null,
	start_deck = null
) -> float:

	var route_positions = get_route_positions_for_points(
		actor,
		route_points,
		start_position
	)

	if route_positions.size() <= 1:
		return 0.0

	var duration := 0.0
	var current_deck = _resolve_start_deck(
		actor,
		start_deck
	)

	for i in range(route_positions.size() - 1):
		var target_point: ShipActionPoint = null
		var target_deck = current_deck

		if i < route_points.size():
			target_point = route_points[i]

			if target_point != null:
				target_deck = target_point.deck

		duration += _get_segment_travel_duration(
			actor,
			route_positions[i],
			route_positions[i + 1],
			current_deck,
			target_deck,
			target_point
		)
		current_deck = target_deck

	return duration


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


static func _resolve_start_deck(
	actor,
	start_deck
) -> int:

	if start_deck is int:
		return start_deck

	if actor != null:
		return actor.location

	return -1


static func get_effective_run_speed(
	actor,
	from_deck: int,
	to_deck: int,
	_target_point: ShipActionPoint = null
) -> float:

	if not _is_water_at_or_above(actor, ShipHealthSystem.LOWER_DECK_FLOODED):
		return MOVE_SPEED

	if from_deck == DeckGraph.DECKS.LOWER:
		return MOVE_SPEED * FLOODED_LOWER_DECK_SPEED_SCALE

	if (
		from_deck == DeckGraph.DECKS.MID
		and to_deck == DeckGraph.DECKS.LOWER
		and _is_water_at_or_above(actor, ShipHealthSystem.MID_DECK_WATER_LEVEL)
	):
		return MOVE_SPEED * FLOODED_LOWER_DECK_SPEED_SCALE

	return MOVE_SPEED


static func _get_segment_travel_duration(
	actor,
	from_position: Vector2,
	to_position: Vector2,
	from_deck: int,
	to_deck: int,
	target_point: ShipActionPoint = null
) -> float:

	var speed = get_effective_run_speed(
		actor,
		from_deck,
		to_deck,
		target_point
	)

	if speed <= 0.0:
		return INF

	return from_position.distance_to(to_position) / speed


static func _is_water_at_or_above(actor, threshold: float) -> bool:

	return (
		actor != null
		and actor.ship != null
		and actor.ship.health_system != null
		and actor.ship.health_system.get_water_level() >= threshold
	)
