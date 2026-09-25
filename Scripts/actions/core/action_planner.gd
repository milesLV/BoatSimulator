extends RefCounted
class_name ShipActionPlanner

const LOW_WATER_LEVEL := 20.0
const REPAIR_SAFETY_LEEWAY := 0.5

var action_points
var route_planner
var lower_bucket_point: ShipActionPoint
## Doubles as a bucket point once the mid deck floods.
var mid_entry_point: ShipActionPoint
var anchor_point: ShipActionPoint
var throw_points: Array[ShipActionPoint] = []


func _init(new_action_points) -> void:

	action_points = new_action_points
	route_planner = ShipRoutePlanner.new(action_points)
	lower_bucket_point = action_points.get_point(&"BucketLD")
	mid_entry_point = action_points.get_point(&"Main2MidBottom")
	anchor_point = action_points.get_point(&"Anchor")
	throw_points.assign([&"WaterThrowSpot", &"AftBuckettingZone"].map(action_points.get_point))


func build_drop_anchor(actor) -> Array[ActionDefinition]:

	return build_at(actor, anchor_point, [RigAnchorAction.new(anchor_point), DropAnchorAction.new()]) if actor.ship.anchor_system.can_drop() else []


func build_raise_anchor(actor) -> Array[ActionDefinition]:

	return build_at(actor, anchor_point, [RaiseAnchorAction.new()]) if actor.ship.anchor_system.can_raise() else []


func build_raise_mast(actor) -> Array[ActionDefinition]:

	return _build_at_sail_lines(actor, RaiseMastAction.new()) if actor.ship.mast_system.can_raise() else []


func build_knock_mast_loose(actor) -> Array[ActionDefinition]:

	return _build_at_sail_lines(actor, KnockMastLooseAction.new())


## Holds the station afterwards so S works the mast again.
func _build_at_sail_lines(actor, action: ActionDefinition) -> Array[ActionDefinition]:

	var station = action_points.get_station(&"SailLengthStarb")

	return build_at(actor, station, [action, HoldStationAction.new(station)])


## A walk to [param point], one leg per stair, then [param on_arrival]; empty when there is no route.
func build_at(actor, point, on_arrival: Array, start_deck = null, start_position = null) -> Array[ActionDefinition]:

	var route = route_planner.find_route(actor, point, start_deck, start_position)
	var actions: Array[ActionDefinition] = []

	if not route.is_empty():
		actions.assign(route.map(func(route_point): return MoveToPointAction.new(route_point)) + on_arrival)

	return actions


func build_bail_water(actor, drain_to_zero := false) -> Array[ActionDefinition]:

	return _best_over_throw_points(actor, func(throw_point):
		var actions = _build_bail_candidate(actor, throw_point)
		var worth_it = (
			actions.is_empty()
			or actor.bucket_amount > 0.0
			or _should_queue_bail_cycle(actor, actions, drain_to_zero)
		)

		return actions if worth_it else []
	)


func build_repair_hole(actor, hole: ShipHolePoint, start_deck = null, start_position = null) -> Array[ActionDefinition]:

	return build_at(actor, hole, [RepairHoleAction.new(hole)], start_deck, start_position)


func build_flooded_mid_deck_entry_bail(
	actor,
	target_point: ShipActionPoint
) -> Array[ActionDefinition]:

	if (
		actor.bucket_amount > 0.0
		or not target_point.deck in DeckGraph.FLOODED_DECKS
		or not _is_mid_deck_flooded_by_arrival(actor, mid_entry_point)
	):
		return []

	return _best_over_throw_points(actor, func(throw_point): return _build_mid_deck_bail_cycle(actor, throw_point))


func _is_mid_deck_flooded_by_arrival(actor, point: ShipActionPoint) -> bool:

	var time_to_mid_deck = _estimate_move_and_bail_duration(actor, point)

	if time_to_mid_deck == INF:
		return false

	return (
		actor.ship.health_system.get_projected_water_level(
			time_to_mid_deck,
			_get_pending_bail_events(actor)
		)
		>= ShipHealthSystem.MID_DECK_WATER_LEVEL
	)


func estimate_repair_bail_cycle_duration(actor) -> float:

	var actions = build_bail_water(actor, true)

	if actions.is_empty():
		return INF

	if actor.bucket_amount > 0.0:
		return _get_bail_plan_score(actor, actions, actions.back().point)

	return route_planner.estimate_total_action_duration(actor, actions)


func _build_mid_deck_bail_cycle(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:

	var bucket_point = _get_bucket_point_for_deck(actor.location, throw_point)

	return _build_scoop_and_throw(actor, bucket_point, throw_point)


func _build_bail_candidate(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:

	if actor.bucket_amount > 0.0:
		return _build_throw_actions(actor, throw_point)

	var actions: Array[ActionDefinition] = []

	if _is_mid_deck_flooded_by_arrival(actor, _get_bucket_point_for_deck(actor.location, throw_point)):
		actions = _build_mid_deck_bail_cycle(actor, throw_point)

	if actions.is_empty():
		actions = _build_scoop_and_throw(actor, lower_bucket_point, throw_point)

	return actions


func _build_scoop_and_throw(actor, bucket_point: ShipActionPoint, throw_point: ShipActionPoint) -> Array[ActionDefinition]:

	var scoop_route = route_planner.find_route(actor, bucket_point)
	var throw_route = route_planner.find_route(
		actor, throw_point, bucket_point.deck, bucket_point.get_position_for_actor(actor)
	)

	if scoop_route.is_empty() or throw_route.is_empty():
		return []

	return [MoveAndBailWaterAction.new(bucket_point, scoop_route), MoveAndThrowBucketWaterAction.new(throw_point, throw_route)]


func _build_throw_actions(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:
	var throw_route = route_planner.find_route(actor, throw_point)

	if throw_route.is_empty():
		return []

	return [MoveAndThrowBucketWaterAction.new(throw_point, throw_route)]


func _best_over_throw_points(actor, builder: Callable) -> Array[ActionDefinition]:
	var best_actions: Array[ActionDefinition] = []
	var best_score := INF

	for throw_point in throw_points:
		var actions = builder.call(throw_point)

		if actions.is_empty():
			continue

		var score = _get_bail_plan_score(actor, actions, actions.back().point)

		if score < best_score:
			best_score = score
			best_actions.assign(actions)

	return best_actions


func _get_bail_plan_score(actor, actions: Array, throw_point: ShipActionPoint) -> float:
	var duration = route_planner.estimate_total_action_duration(actor, actions)

	if duration == INF:
		return INF

	var removals = _get_pending_bail_events(actor)
	var own_bail_time = route_planner.estimate_time_until_bail_complete(actor, actions)

	if own_bail_time != INF:
		removals.append({"time": own_bail_time, "amount": Crewmate.MAX_BUCKET_AMOUNT})

	return duration + _estimate_next_cycle_from_throw(actor, throw_point, duration, removals)


func _estimate_next_cycle_from_throw(
	actor,
	throw_point: ShipActionPoint,
	elapsed: float,
	removals: Array
) -> float:

	var projected_mid_water = actor.ship.health_system.get_projected_water_level(
		elapsed + MoveAndBailWaterAction.SCOOP_DURATION,
		removals
	)

	if projected_mid_water >= ShipHealthSystem.MID_DECK_WATER_LEVEL:
		return MoveAndBailWaterAction.SCOOP_DURATION + MoveAndThrowBucketWaterAction.THROW_DURATION

	var pickup_duration = _estimate_move_and_bail_duration(actor, lower_bucket_point, throw_point)
	return pickup_duration + _estimate_throw_duration_from_bucket(actor, lower_bucket_point)


func _get_pending_bail_events(actor) -> Array:

	var events: Array = []

	for crewmate in actor.ship.crewmates:
		if crewmate == actor or crewmate.action_executor == null:
			continue

		var executor = crewmate.action_executor
		var elapsed := 0.0

		for instance in ([executor.current_action] if executor.current_action != null else []) + executor.queued_actions:
			elapsed += instance.get_remaining_time(crewmate)

			if instance.definition.fills_bucket:
				events.append({"time": elapsed, "amount": Crewmate.MAX_BUCKET_AMOUNT})
				break

	return events


func _get_bucket_point_for_deck(deck, throw_point: ShipActionPoint) -> ShipActionPoint:

	match deck:
		DeckGraph.DECKS.UPPER, DeckGraph.DECKS.MAIN:
			return mid_entry_point

		DeckGraph.DECKS.LOWER:
			return lower_bucket_point

	return throw_point


func _estimate_move_and_bail_duration(
	actor,
	bucket_point: ShipActionPoint,
	start_point: ShipActionPoint = null
) -> float:

	var start_deck = start_point.deck if start_point != null else actor.location
	var start_position = start_point.get_position_for_actor(actor) if start_point != null else actor.position

	return _estimate_route_duration(actor, bucket_point, start_deck, start_position, MoveAndBailWaterAction.SCOOP_DURATION)


func _estimate_route_duration(
	actor,
	target: ShipActionPoint,
	from_deck: int,
	from_position: Vector2,
	floor_duration: float
) -> float:

	var route = route_planner.find_route(actor, target, from_deck, from_position)

	if route.is_empty():
		return INF

	return max(MoveToPointAction.get_travel_duration_for_points(actor, route, from_position, from_deck), floor_duration)


func is_repair_trip_safe(
	actor,
	hole: ShipHolePoint,
	repair_trip,
	flood_rate: float
) -> bool:

	if flood_rate <= 0.0:
		return actor.ship.health_system.water_level < ShipHealthSystem.MAX_WATER_LEVEL

	return actor.ship.health_system.can_survive_repair_trip(
		hole,
		flood_rate,
		repair_trip["repair_complete_time"],
		repair_trip["total_time"],
		REPAIR_SAFETY_LEEWAY
	)


func estimate_repair_trip(actor, hole: ShipHolePoint) -> Dictionary:
	var hole_route = route_planner.find_route(actor, hole)

	if hole_route.is_empty():
		return {"total_time": INF, "repair_complete_time": INF}

	var repair_complete_time = MoveToPointAction.get_travel_duration_for_points(actor, hole_route) + hole.repair_duration()
	var bail_time: float

	if actor.bucket_amount > 0.0:
		bail_time = _estimate_throw_duration_from_bucket(actor, hole)
	else:
		var projected_after_repair = actor.ship.health_system.get_projected_water_level(repair_complete_time)
		var bucket_point = (
			lower_bucket_point
			if projected_after_repair < ShipHealthSystem.MID_DECK_WATER_LEVEL
			else _get_bucket_point_for_deck(hole.deck, action_points.get_point(&"WaterThrowSpot"))
		)
		bail_time = _estimate_move_and_bail_duration(actor, bucket_point, hole) + _estimate_throw_duration_from_bucket(actor, bucket_point)

	# an unroutable bail leg is INF, which carries through to the total
	return {"total_time": repair_complete_time + bail_time, "repair_complete_time": repair_complete_time}


func _estimate_throw_duration_from_bucket(actor, bucket_point: ShipActionPoint) -> float:

	var from_position = bucket_point.get_position_for_actor(actor)

	return throw_points.map(func(throw_point): return (
		MoveAndThrowBucketWaterAction.THROW_DURATION if throw_point == bucket_point
		else _estimate_route_duration(
			actor, throw_point, bucket_point.deck, from_position, MoveAndThrowBucketWaterAction.THROW_DURATION
		)
	)).min()


## Bail on while there is water left; while the hull is holed, only once it reaches LOW_WATER_LEVEL.
func _should_queue_bail_cycle(actor, actions: Array, drain_to_zero: bool) -> bool:
	var time_until_bail = route_planner.estimate_time_until_bail_complete(actor, actions)
	var projected_water = actor.ship.health_system.get_projected_water_level(
		time_until_bail,
		_get_pending_bail_events(actor)
	)

	if drain_to_zero or not action_points.hull_holes.any(
		func(hole): return hole.grade > ShipHolePoint.MIN_GRADE
	):
		return projected_water > 0.0

	return projected_water >= LOW_WATER_LEVEL
