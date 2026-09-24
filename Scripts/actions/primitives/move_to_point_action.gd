extends ActionDefinition
class_name MoveToPointAction

const MOVE_SPEED := Crewmate.RUN_SPEED
const FLOODED_LOWER_DECK_SPEED_SCALE := 0.7
const RUNTIME_START_POSITION := &"start_position"
const RUNTIME_TARGET_POSITION := &"target_position"
const RUNTIME_START_DECK := &"start_deck"

var point: ShipActionPoint


func _init(new_point: ShipActionPoint) -> void:

	point = new_point
	progress_policy = ProgressPolicy.CONTINUOUS
	action_id = "go_to_%s" % point.name


func get_duration(actor, _context := {}) -> float:

	return get_travel_duration_to_point(actor, point)


func on_start(actor, instance) -> void:

	instance.runtime_state.merge({
		RUNTIME_START_POSITION: actor.position,
		RUNTIME_TARGET_POSITION: point.get_position_for_actor(actor, actor.position),
		RUNTIME_START_DECK: actor.location,
	}, true)

	if _is_deck_transition(instance):
		actor.begin_deck_transition(actor.location, point.deck)


func on_tick(actor, instance, _delta: float) -> void:

	var progress = minf(instance.elapsed / instance.duration, 1.0) if instance.duration > 0.0 else 1.0

	actor.position = instance.runtime_state[RUNTIME_START_POSITION].lerp(
		instance.runtime_state[RUNTIME_TARGET_POSITION], progress
	)

	if not _is_deck_transition(instance):
		actor.set_location(point.deck)


func on_complete(actor, instance) -> void:

	actor.position = instance.runtime_state[RUNTIME_TARGET_POSITION]

	if _is_deck_transition(instance):
		actor.complete_deck_transition()
	else:
		actor.set_location(point.deck)


func on_interrupt(actor, _instance) -> void:

	actor.clear_deck_transition()


## An actor not yet placed on any deck just appears on the target's.
func _is_deck_transition(instance) -> bool:

	var start_deck = instance.runtime_state[RUNTIME_START_DECK]

	return DeckGraph.is_valid_deck(start_deck) and start_deck != point.deck


static func get_travel_duration_to_point(
	actor,
	target_point: ShipActionPoint,
	start_position = null,
	start_deck = null
) -> float:

	var origin = resolve_start_position(actor, start_position)
	var target_position = target_point.get_position_for_actor(actor, origin)
	var origin_deck = resolve_start_deck(actor, start_deck)

	return _get_segment_travel_duration(
		actor,
		origin,
		target_position,
		origin_deck,
		target_point.deck
	)


static func get_travel_duration_for_points(
	actor,
	route_points: Array,
	start_position = null,
	start_deck = null
) -> float:

	return get_route_segments(
		actor,
		route_points,
		get_route_positions_for_points(actor, route_points, start_position),
		start_deck
	).reduce(func(total, segment): return total + segment["duration"], 0.0)


## One entry per leg of the route: its travel time and the decks it spans.
static func get_route_segments(
	actor,
	route_points: Array,
	route_positions: Array,
	start_deck = null
) -> Array[Dictionary]:

	var segments: Array[Dictionary] = []
	var current_deck = resolve_start_deck(actor, start_deck)

	for i in range(route_positions.size() - 1):
		var target_deck = route_points[i].deck

		segments.append({
			"duration": _get_segment_travel_duration(
				actor,
				route_positions[i],
				route_positions[i + 1],
				current_deck,
				target_deck
			),
			"from_deck": current_deck,
			"to_deck": target_deck
		})
		current_deck = target_deck

	return segments


static func get_route_positions_for_points(
	actor,
	route_points: Array,
	start_position = null
) -> Array:

	var positions: Array = [resolve_start_position(actor, start_position)]

	for route_point in route_points:
		positions.append(route_point.get_position_for_actor(actor, positions.back()))

	return positions


static func resolve_start_position(actor, start_position) -> Vector2:
	return start_position if start_position is Vector2 else actor.position


static func resolve_start_deck(actor, start_deck) -> int:
	return start_deck if start_deck is int else actor.location


static func get_effective_run_speed(actor, from_deck: int, to_deck: int) -> float:
	if not _is_water_at_or_above(actor, ShipHealthSystem.LOWER_DECK_FLOODED):
		return MOVE_SPEED

	var wading = (
		from_deck == DeckGraph.DECKS.LOWER
		or (
			from_deck == DeckGraph.DECKS.MID
			and to_deck == DeckGraph.DECKS.LOWER
			and _is_water_at_or_above(actor, ShipHealthSystem.MID_DECK_WATER_LEVEL)
		)
	)

	return MOVE_SPEED * (FLOODED_LOWER_DECK_SPEED_SCALE if wading else 1.0)


static func _get_segment_travel_duration(
	actor,
	from_position: Vector2,
	to_position: Vector2,
	from_deck: int,
	to_deck: int
) -> float:

	return from_position.distance_to(to_position) / get_effective_run_speed(actor, from_deck, to_deck)


static func _is_water_at_or_above(actor, threshold: float) -> bool:

	# a test actor times a throw before it is given a ship
	return actor.ship != null and actor.ship.health_system.water_level >= threshold
