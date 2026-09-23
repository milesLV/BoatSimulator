extends RefCounted
class_name ShipActionPlanner

const LOW_WATER_LEVEL := 20.0
const REPAIR_SAFETY_LEEWAY := 0.5

var action_points
var route_planner
## The two fixed bailing points: where the bucket is filled on the lower deck,
## and the mid deck's entrance, which doubles as a bucket point once it floods.
var lower_bucket_point: ShipActionPoint
var mid_entry_point: ShipActionPoint


func _init(new_action_points) -> void:

	action_points = new_action_points
	route_planner = ShipRoutePlanner.new(action_points)
	lower_bucket_point = action_points.get_point(&"BucketLD")
	mid_entry_point = action_points.get_point(&"Main2MidBottom")


func build_go_to_station(
	actor,
	station: ShipActionPoint,
	on_arrival: ActionDefinition
) -> Array[ActionDefinition]:

	if station == null:
		return []

	var actions = route_planner.build_go_to_point(actor, station)

	actions.append(on_arrival)

	return actions


## Route to the anchor point, or [] when the anchor cannot accept the order.
func _build_anchor_route(actor, ready_check: StringName) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.anchor_system == null
		or not actor.ship.anchor_system.call(ready_check)
	):
		return []

	var anchor_point = action_points.get_point(&"Anchor")

	if anchor_point == null:
		return []

	return route_planner.build_go_to_point(actor, anchor_point)


func build_drop_anchor(actor) -> Array[ActionDefinition]:

	var actions = _build_anchor_route(actor, &"can_drop")

	if actions.is_empty():
		return []

	var anchor_point = action_points.get_point(&"Anchor")

	actions.append(RigAnchorAction.new(anchor_point))
	actions.append(DropAnchorAction.new())

	return actions


func build_raise_anchor(actor) -> Array[ActionDefinition]:

	var actions = _build_anchor_route(actor, &"can_raise")

	if actions.is_empty():
		return []

	actions.append(RaiseAnchorAction.new(action_points.get_point(&"Anchor")))

	return actions


func build_bail_water(actor, drain_to_zero := false) -> Array[ActionDefinition]:
	if actor == null or actor.ship == null or actor.ship.health_system == null:
		return []

	if lower_bucket_point == null:
		return []

	var builder := func(throw_point):
		var actions = _build_bail_candidate(actor, throw_point)

		if actions.is_empty():
			return []

		if (
			actor.bucket_amount <= 0.0
			and not _should_queue_bail_cycle(actor, actions, drain_to_zero)
		):
			return []

		return actions

	return _best_over_throw_points(actor, builder)


func build_repair_hole(actor, hole: ShipHolePoint) -> Array[ActionDefinition]:
	if actor == null or hole == null:
		return []

	var actions = route_planner.build_go_to_point(actor, hole)

	if actor.location != hole.deck and actions.is_empty():
		ShipDebugLog.route_failure(
			"repair_hole",
			{
				"actor_deck": DeckGraph.get_deck_name(actor.location),
				"target_hole": hole.name,
				"target_deck": DeckGraph.get_deck_name(hole.deck)
			}
		)
		return []

	actions.append(RepairHoleAction.new(hole))

	return actions


func build_flooded_mid_deck_entry_bail(
	actor,
	target_point: ShipActionPoint
) -> Array[ActionDefinition]:

	return _best_over_throw_points(
		actor,
		func(throw_point): return _build_flooded_mid_deck_entry_bail_for_throw(
			actor,
			target_point,
			throw_point
		)
	)


func _build_flooded_mid_deck_entry_bail_for_throw(
	actor,
	target_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> Array[ActionDefinition]:

	if (
		actor == null
		or target_point == null
		or throw_point == null
		or actor.ship == null
		or actor.ship.health_system == null
		or actor.bucket_amount > 0.0
		or not target_point.deck in DeckGraph.FLOODED_DECKS
	):
		return []

	if mid_entry_point == null or not _is_mid_deck_flooded_by_arrival(actor, mid_entry_point):
		return []

	if actor.location in DeckGraph.FLOODED_DECKS:
		if lower_bucket_point == null:
			return []

		return _build_mid_deck_bail_cycle(actor, throw_point)

	return _build_scoop_and_throw(
		actor,
		mid_entry_point,
		throw_point,
		"flooded_mid_deck_entry_bail"
	)


## True when the mid deck is still flooded by the time the actor reaches
## [param point], so bailing there is worth planning for.
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

	var duration = route_planner.estimate_total_action_duration(actor, actions)

	if (
		actor != null
		and actor.bucket_amount > 0.0
		and actions.back() is MoveAndThrowBucketWaterAction
	):
		return _get_bail_plan_score(actor, actions, actions.back().point)

	return duration


func _build_mid_deck_bail_cycle(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:

	var bucket_point = _get_bucket_point_for_deck(actor.location, throw_point)

	return _build_scoop_and_throw(actor, bucket_point, throw_point, "mid_deck_bail_cycle")


## One bail plan for a single throw point: throw what is carried, else scoop first.
func _build_bail_candidate(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:

	if actor.bucket_amount > 0.0:
		return _build_throw_actions(actor, throw_point)

	var actions: Array[ActionDefinition] = []

	if _should_use_mid_deck_bailing(actor, throw_point):
		actions = _build_mid_deck_bail_cycle(actor, throw_point)

	if actions.is_empty():
		actions = _build_scoop_and_throw(actor, lower_bucket_point, throw_point, "single_bail_cycle")

	return actions


## Route to the bucket, scoop there, then route on to the throw point and throw.
func _build_scoop_and_throw(
	actor,
	bucket_point: ShipActionPoint,
	throw_point: ShipActionPoint,
	log_name: String
) -> Array[ActionDefinition]:

	var actions = route_planner.build_go_to_point(actor, bucket_point)

	if actor.location != bucket_point.deck and actions.is_empty():
		ShipDebugLog.route_failure(
			log_name,
			{
				"actor_deck": DeckGraph.get_deck_name(actor.location),
				"bucket_point": bucket_point.name,
				"bucket_deck": DeckGraph.get_deck_name(bucket_point.deck)
			}
		)
		return []

	var scoop_route = route_planner.get_move_route_points(actions, bucket_point)
	actions.assign([MoveAndBailWaterAction.new(bucket_point, scoop_route)])

	var throw_route = route_planner.build_go_to_point(
		actor,
		throw_point,
		bucket_point.deck,
		bucket_point.get_position_for_actor(actor)
	)

	if bucket_point.deck != throw_point.deck and throw_route.is_empty():
		ShipDebugLog.route_failure(
			log_name + "_throw_route",
			{
				"from_deck": DeckGraph.get_deck_name(bucket_point.deck),
				"to_deck": DeckGraph.get_deck_name(throw_point.deck),
				"bucket_point": bucket_point.name,
				"throw_point": throw_point.name
			}
		)
		return []

	_append_buffered_throw(actions, throw_route, throw_point)

	return actions


func _build_throw_actions(actor, throw_point: ShipActionPoint) -> Array[ActionDefinition]:
	var throw_route = route_planner.build_go_to_point(actor, throw_point)

	if actor.location != throw_point.deck and throw_route.is_empty():
		return []

	var actions: Array[ActionDefinition] = []
	_append_buffered_throw(actions, throw_route, throw_point)
	return actions


func _get_throw_points() -> Array[ShipActionPoint]:

	var result: Array[ShipActionPoint] = []

	result.assign(
		[&"WaterThrowSpot", &"AftBuckettingZone"]
			.filter(action_points.has_point)
			.map(action_points.get_point)
	)

	return result


## Best-scoring plan across every throw point [param builder] can serve.
func _best_over_throw_points(actor, builder: Callable) -> Array[ActionDefinition]:
	var best_actions: Array[ActionDefinition] = []
	var best_score := INF

	for throw_point in _get_throw_points():
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
		removals.append({
			"time": own_bail_time,
			"amount": Crewmate.MAX_BUCKET_AMOUNT
		})

	return duration + _estimate_next_cycle_from_throw(actor, throw_point, duration, removals)


func _estimate_next_cycle_from_throw(
	actor,
	throw_point: ShipActionPoint,
	elapsed: float,
	removals: Array
) -> float:

	if (
		actor == null
		or throw_point == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return 0.0

	var projected_mid_water = actor.ship.health_system.get_projected_water_level(
		elapsed + BailWaterAction.DURATION,
		removals
	)

	if projected_mid_water >= ShipHealthSystem.MID_DECK_WATER_LEVEL:
		return BailWaterAction.DURATION + ThrowBucketWaterAction.DURATION

	if lower_bucket_point == null:
		return INF

	var pickup_duration = _estimate_move_and_bail_duration(actor, lower_bucket_point, throw_point)
	return pickup_duration + _estimate_throw_duration_from_bucket(actor, lower_bucket_point)


func _get_pending_bail_events(actor) -> Array:

	var events: Array = []

	if actor == null or actor.ship == null:
		return events

	for crewmate in actor.ship.get_crewmates():
		if crewmate == null or crewmate == actor or crewmate.action_executor == null:
			continue

		var elapsed := 0.0
		var instances: Array = []

		if crewmate.action_executor.current_action != null:
			instances.append(crewmate.action_executor.current_action)

		instances.append_array(crewmate.action_executor.queued_actions)

		for instance in instances:
			var definition = instance.definition
			var duration = instance.get_remaining_time(crewmate)
			elapsed += duration

			if definition.fills_bucket:
				events.append({
					"time": elapsed,
					"amount": Crewmate.MAX_BUCKET_AMOUNT
				})
				break

	return events


func _should_use_mid_deck_bailing(actor, throw_point: ShipActionPoint) -> bool:

	if actor == null or actor.ship == null or actor.ship.health_system == null:
		return false

	var bucket_point = _get_bucket_point_for_deck(actor.location, throw_point)

	return bucket_point != null and _is_mid_deck_flooded_by_arrival(actor, bucket_point)


## Where a crewmate standing on [param deck] should fill the bucket.
func _get_bucket_point_for_deck(deck, throw_point: ShipActionPoint) -> ShipActionPoint:

	match deck:
		DeckGraph.DECKS.UPPER, DeckGraph.DECKS.MAIN:
			return mid_entry_point

		DeckGraph.DECKS.LOWER:
			return lower_bucket_point

	return throw_point


## Time to reach the bucket and scoop, starting from [param start_point] or the actor.
func _estimate_move_and_bail_duration(
	actor,
	bucket_point: ShipActionPoint,
	start_point: ShipActionPoint = null
) -> float:

	if actor == null or bucket_point == null:
		return INF

	var start_deck = (
		start_point.deck if start_point != null else actor.location
	)
	var start_position = (
		start_point.get_position_for_actor(actor)
		if start_point != null
		else actor.position
	)

	return _estimate_route_duration(
		actor,
		bucket_point,
		start_deck,
		start_position,
		BailWaterAction.DURATION
	)


## Travel time to [param target] from [param from_deck]/[param from_position],
## never below [param floor_duration]. INF when a cross-deck route fails to build.
func _estimate_route_duration(
	actor,
	target: ShipActionPoint,
	from_deck: int,
	from_position: Vector2,
	floor_duration: float
) -> float:

	var route_actions = route_planner.build_go_to_point(actor, target, from_deck, from_position)

	if from_deck != target.deck and route_actions.is_empty():
		return INF

	return max(
		MoveToPointAction.get_travel_duration_for_points(
			actor,
			route_planner.get_move_route_points(route_actions, target),
			from_position,
			from_deck
		),
		floor_duration
	)


func is_repair_trip_safe(
	actor,
	hole: ShipHolePoint,
	repair_trip,
	effective_flood_rate := -1.0
) -> bool:

	if (
		actor == null
		or hole == null
		or repair_trip == null
		or not repair_trip["reachable"]
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	var flood_rate = effective_flood_rate
	var water_level = actor.ship.health_system.water_level

	if flood_rate < 0.0:
		flood_rate = actor.ship.health_system.get_flood_rate()

	if flood_rate <= 0.0:
		return water_level < ShipHealthSystem.MAX_WATER_LEVEL

	return actor.ship.health_system.can_survive_repair_trip(
		hole,
		flood_rate,
		repair_trip["repair_complete_time"],
		repair_trip["total_time"],
		REPAIR_SAFETY_LEEWAY
	)


func estimate_repair_trip(actor, hole: ShipHolePoint) -> Dictionary:
	var hole_route = route_planner.build_route_plan(actor, hole)
	var time_to_hole = hole_route["total_duration"] if hole_route["reachable"] else INF

	if time_to_hole == INF:
		return _repair_trip(INF, INF)

	var repair_duration = float(hole.grade) + RepairHoleAction.EXTRA_REPAIR_SECONDS
	var repair_complete_time = time_to_hole + repair_duration

	if actor.bucket_amount > 0.0:
		var bucket_throw_time = _estimate_throw_duration_from_bucket(actor, hole)

		if bucket_throw_time == INF:
			return _repair_trip(INF, INF)

		return _repair_trip(repair_complete_time + bucket_throw_time, repair_complete_time)

	var projected_after_repair = actor.ship.health_system.get_projected_water_level(repair_complete_time)
	var bucket_point = (
		lower_bucket_point
		if projected_after_repair < ShipHealthSystem.MID_DECK_WATER_LEVEL
		else _get_bucket_point_for_deck(hole.deck, action_points.get_point(&"WaterThrowSpot"))
	)

	if bucket_point == null:
		return _repair_trip(repair_complete_time, repair_complete_time)

	var time_to_bucket = _estimate_move_and_bail_duration(actor, bucket_point, hole)

	if time_to_bucket == INF:
		return _repair_trip(INF, INF)

	var time_to_throw = _estimate_throw_duration_from_bucket(actor, bucket_point)

	if time_to_throw == INF:
		return _repair_trip(INF, INF)

	return _repair_trip(
		(
			repair_complete_time
			+ time_to_bucket
			+ time_to_throw
		),
		repair_complete_time
	)


func _repair_trip(total_time: float, repair_complete_time: float) -> Dictionary:
	return {
		"total_time": total_time,
		"repair_complete_time": repair_complete_time,
		"reachable": total_time < INF
	}


func _estimate_throw_duration_from_bucket(
	actor,
	bucket_point: ShipActionPoint,
	throw_point: ShipActionPoint = null
) -> float:

	if throw_point == null:
		var best_duration := INF

		for candidate in _get_throw_points():
			best_duration = min(
				best_duration,
				_estimate_throw_duration_from_bucket(actor, bucket_point, candidate)
			)

		return best_duration

	if bucket_point == throw_point:
		return ThrowBucketWaterAction.DURATION

	return _estimate_route_duration(
		actor,
		throw_point,
		bucket_point.deck,
		bucket_point.get_position_for_actor(actor),
		ThrowBucketWaterAction.DURATION
	)


func _has_damaged_holes() -> bool:

	if action_points == null:
		return false

	return action_points.hull_holes.any(
		func(hole): return hole.grade > ShipHolePoint.MIN_GRADE
	)


func _should_queue_bail_cycle(actor, actions: Array, drain_to_zero := false) -> bool:
	var time_until_bail = route_planner.estimate_time_until_bail_complete(actor, actions)
	var projected_water = actor.ship.health_system.get_projected_water_level(
		time_until_bail,
		_get_pending_bail_events(actor)
	)
	var target_water_level = (
		0.0 if drain_to_zero or not _has_damaged_holes() else LOW_WATER_LEVEL
	)

	return (
		projected_water > 0.0
		if target_water_level <= 0.0
		else projected_water >= target_water_level
	)


func _append_buffered_throw(
	actions: Array,
	throw_route: Array,
	throw_point: ShipActionPoint
) -> void:

	var route_points = route_planner.get_move_route_points(throw_route, throw_point)
	actions.append(MoveAndThrowBucketWaterAction.new(throw_point, route_points))
