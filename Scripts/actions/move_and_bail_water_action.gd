class_name MoveAndBailWaterAction
extends MoveToPointAction

## Scooping (or throwing) winds up this long before arrival.
const SCOOP_DURATION := 1.0
const PICKUP_TOLERANCE := 1.0

var route_points: Array = []


func _init(new_point: ShipActionPoint, new_route_points: Array = []) -> void:
	super(new_point)

	action_id = "move_and_bail_water"
	fills_bucket = true
	route_points = build_route_points(new_point, new_route_points)


func get_duration(actor, _context := {}) -> float:
	return max(MoveToPointAction.get_travel_duration_for_points(actor, route_points), SCOOP_DURATION)


func on_start(actor, instance) -> void:
	var route_positions = MoveToPointAction.get_route_positions_for_points(actor, route_points)

	instance.runtime_state.merge({
		RUNTIME_TARGET_POSITION: route_positions.back(),
		&"route_positions": route_positions,
		&"segments": MoveToPointAction.get_route_segments(actor, route_points, route_positions),
	}, true)


## Walks the route leg by leg at each leg's own speed, on the stairs while a leg changes deck.
func on_tick(actor, instance, _delta: float) -> void:
	# announced as the actor reaches the point; a throw does its work in on_complete
	if (
		fills_bucket
		and not instance.runtime_state.has(&"announced")
		and instance.elapsed >= instance.duration - SCOOP_DURATION
	):
		instance.runtime_state[&"announced"] = true
		ShipDebugLog.write(&"bail", "%s started bailing at %s." % [actor.name, point.name])

	var positions: Array = instance.runtime_state[&"route_positions"]
	var time_left: float = instance.elapsed

	for i in positions.size() - 1:
		var segment: Dictionary = instance.runtime_state[&"segments"][i]

		if time_left < segment["duration"]:
			actor.position = positions[i].lerp(positions[i + 1], time_left / segment["duration"])

			if segment["from_deck"] == segment["to_deck"]:
				actor.set_location(segment["to_deck"])
			else:
				actor.begin_deck_transition(segment["from_deck"], segment["to_deck"])

			return

		time_left -= segment["duration"]

	actor.position = positions.back()
	actor.set_location(point.deck)


func on_complete(actor, instance) -> void:
	actor.position = instance.runtime_state[RUNTIME_TARGET_POSITION]
	actor.set_location(point.deck)

	if fills_bucket:
		_collect_water(actor)
	else:
		MoveAndThrowBucketWaterAction.throw_water(actor, point)


func _collect_water(actor) -> void:
	var health_system = actor.ship.health_system

	if actor.bucket_amount > 0.0:
		return

	if not point.contains_actor(actor, PICKUP_TOLERANCE):
		ShipDebugLog.write(&"bail",
			"Bail missed: %s was not at %s when the scoop finished." % [actor.name, point.name]
		)
		return

	if point.deck == DeckGraph.DECKS.MID and health_system.water_level < ShipHealthSystem.MID_DECK_WATER_LEVEL:
		return

	actor.bucket_amount += health_system.remove_water(Crewmate.MAX_BUCKET_AMOUNT)

	ShipDebugLog.write(&"bail",
		"Ship water level after bail: %.1f/%.1f"
		% [health_system.water_level, health_system.MAX_WATER_LEVEL]
	)


## [param new_route_points] with [param target_point] appended when it is not already last.
static func build_route_points(target_point: ShipActionPoint, new_route_points: Array) -> Array:
	var result := new_route_points.duplicate()

	if result.is_empty() or result.back() != target_point:
		result.append(target_point)

	return result
