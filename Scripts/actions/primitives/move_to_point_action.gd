extends ActionDefinition
class_name MoveToPointAction

const MOVE_SPEED := Crewmate.RUN_SPEED
const FLOODED_LOWER_DECK_SPEED_SCALE := 0.7

var point: ShipActionPoint
var route_points: Array = []


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:

	point = new_point
	route_points = new_route_points.duplicate()

	if route_points.is_empty() or route_points.back() != point:
		route_points.append(point)

	progress_policy = ProgressPolicy.CONTINUOUS
	action_id = "go_to_%s" % point.name


func get_duration(actor) -> float:

	return get_travel_duration_for_points(actor, route_points)


func on_start(actor, instance) -> void:

	var route_positions = get_route_positions_for_points(actor, route_points)

	instance.runtime_state.merge({
		&"route_positions": route_positions,
		&"segments": get_route_segments(actor, route_points, route_positions),
	}, true)


func on_tick(actor, instance, _delta: float) -> void:

	var positions: Array = instance.runtime_state[&"route_positions"]
	var time_left: float = instance.elapsed

	for i in positions.size() - 1:
		var segment: Dictionary = instance.runtime_state[&"segments"][i]

		if time_left < segment["duration"]:
			actor.position = positions[i].lerp(positions[i + 1], time_left / segment["duration"])

			# on the stairs they still show on the deck they left; one not yet on any deck appears on the target's
			actor.set_location(segment["from_deck"] if DeckGraph.is_valid_deck(segment["from_deck"]) else segment["to_deck"])
			return

		time_left -= segment["duration"]

	actor.position = positions.back()
	actor.set_location(point.deck)


func on_complete(actor, instance) -> void:

	actor.position = instance.runtime_state[&"route_positions"].back()
	actor.set_location(point.deck)


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
			"duration": route_positions[i].distance_to(route_positions[i + 1])
				/ get_effective_run_speed(actor, current_deck, target_deck),
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


static func _is_water_at_or_above(actor, threshold: float) -> bool:

	# a test actor times a throw before it is given a ship
	return actor.ship != null and actor.ship.health_system.water_level >= threshold
