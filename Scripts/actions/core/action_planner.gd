extends RefCounted
class_name ShipActionPlanner

const LOW_WATER_LEVEL := 20.0
const MID_DECK_WATER_LEVEL := 232.0
const REPAIR_SAFETY_LEEWAY := 0.5
const HELP_SINK_WINDOW := 5.0

var action_points: ShipActionPointContainer
var route_planner: ShipRoutePlanner


func _init(new_action_points: ShipActionPointContainer) -> void:

	action_points = new_action_points
	route_planner = ShipRoutePlanner.new(action_points)


func build_go_to_point(
	actor,
	point: ShipActionPoint
) -> Array[ActionDefinition]:

	return route_planner.build_go_to_point(
		actor,
		point
	)


func build_station_control(
	actor,
	station: StationPoint
) -> Array[ActionDefinition]:

	if station == null:
		return []

	var actions = build_go_to_point(
		actor,
		station
	)

	actions.append(HoldStationAction.new(station))

	return actions


func build_cannon_station_actions(
	actor,
	station: CannonStationPoint
) -> Array[ActionDefinition]:

	if station == null:
		return []

	var actions = build_go_to_point(
		actor,
		station
	)

	actions.append(ClaimStationAction.new(station))

	return actions


func build_drop_anchor(actor) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.anchor_system == null
		or not actor.ship.anchor_system.can_drop()
	):
		return []

	var anchor_point = action_points.get_point(&"Anchor")

	if anchor_point == null:
		return []

	var actions = build_go_to_point(
		actor,
		anchor_point
	)

	if actions.is_empty():
		return []

	actions.append(RigAnchorAction.new(anchor_point))

	actions.append(
		TriggerShipStateAction.new(
			"trigger_anchor_drop",
			actor.ship.anchor_system,
			&"start_dropping",
			[],
			anchor_point
		)
	)

	return actions


func build_raise_anchor(actor) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.anchor_system == null
		or not actor.ship.anchor_system.can_raise()
	):
		return []

	var anchor_point = action_points.get_point(&"Anchor")

	if anchor_point == null:
		return []

	var actions = build_go_to_point(
		actor,
		anchor_point
	)

	if actions.is_empty():
		return []

	actions.append(RaiseAnchorAction.new(anchor_point))

	return actions


func build_bail_water(
	actor,
	drain_to_zero := false
) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return []

	var bucket_point = action_points.get_point(&"BucketLD")
	var throw_point = action_points.get_point(&"WaterThrowSpot")
	var mid_entry_point = action_points.get_point(&"Main2MidBottom")

	if (
		bucket_point == null
		or throw_point == null
	):
		return []

	if actor.bucket_amount > 0.0:
		var throw_actions = build_go_to_point(
			actor,
			throw_point
		)

		if (
			actor.location != throw_point.deck
			and throw_actions.is_empty()
		):
			return []

		throw_actions.append(ThrowBucketWaterAction.new(throw_point))

		throw_actions.append(ContinueBailingAction.new(drain_to_zero))

		return throw_actions

	if _should_use_mid_deck_bailing(
		actor,
		bucket_point,
		mid_entry_point,
		throw_point
	):
		var mid_actions = _build_mid_deck_bail_cycle(
			actor,
			bucket_point,
			mid_entry_point,
			throw_point
		)

		if not mid_actions.is_empty():
			mid_actions.append(ContinueBailingAction.new(drain_to_zero))

			return mid_actions

	var actions = _build_single_bail_cycle(
		actor,
		bucket_point,
		throw_point
	)

	if actions.is_empty():
		return []

	if not _should_queue_bail_cycle(
		actor,
		actions,
		drain_to_zero
	):
		return []

	actions.append(ContinueBailingAction.new(drain_to_zero))

	return actions


func build_repair_hole(
	actor,
	hole: ShipHolePoint
) -> Array[ActionDefinition]:

	if (
		actor == null
		or hole == null
	):
		return []

	var actions = build_go_to_point(
		actor,
		hole
	)

	if (
		actor.location != hole.deck
		and actions.is_empty()
	):
		_print_route_failure(
			"repair_hole",
			{
				"actor_deck": DeckGraph.get_deck_name(
					actor.location
				),
				"target_hole": hole.name,
				"target_deck": DeckGraph.get_deck_name(hole.deck)
			}
		)
		return []

	actions.append(RepairHoleAction.new(hole))

	actions.append(ContinueRepairingAction.new())

	return actions


func build_repair_safety_bail_cycle(actor) -> Array[ActionDefinition]:

	return _build_repair_bail_cycle(
		actor
	)


func build_flooded_mid_deck_entry_bail(
	actor,
	target_point: ShipActionPoint
) -> Array[ActionDefinition]:

	if (
		actor == null
		or target_point == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return []

	if actor.bucket_amount > 0.0:
		return []

	var mid_entry_point = action_points.get_point(&"Main2MidBottom")
	var throw_point = action_points.get_point(&"WaterThrowSpot")

	if (
		mid_entry_point == null
		or throw_point == null
	):
		return []

	if not _is_mid_deck_flooded_by_arrival(
		actor,
		mid_entry_point
	):
		return []

	if (
		target_point.deck != DeckGraph.DECKS.MID
		and target_point.deck != DeckGraph.DECKS.LOWER
	):
		return []

	if (
		actor.location == DeckGraph.DECKS.MID
		or actor.location == DeckGraph.DECKS.LOWER
	):
		return _build_flooded_repair_area_bail(
			actor,
			mid_entry_point,
			throw_point
		)

	var actions = build_go_to_point(
		actor,
		mid_entry_point
	)

	if actions.is_empty():
		_print_route_failure(
			"flooded_mid_deck_entry_bail",
			{
				"actor_deck": DeckGraph.get_deck_name(
					actor.location
				),
				"target_hole": target_point.name,
				"target_deck": DeckGraph.get_deck_name(
					target_point.deck
				),
				"bucket_point": mid_entry_point.name
			}
		)
		return []

	_replace_bucket_route_with_scoop(
		actions,
		mid_entry_point
	)

	if mid_entry_point != throw_point:
		var throw_route = build_go_to_point_from_deck(
			mid_entry_point.deck,
			throw_point,
			mid_entry_point.global_position
		)

		if (
			mid_entry_point.deck != throw_point.deck
			and throw_route.is_empty()
		):
			_print_route_failure(
				"flooded_mid_deck_entry_throw_route",
				{
					"from_deck": DeckGraph.get_deck_name(
						mid_entry_point.deck
					),
					"to_deck": DeckGraph.get_deck_name(
						throw_point.deck
					),
					"start_point": mid_entry_point.name,
					"throw_point": throw_point.name,
					"target_hole": target_point.name
				}
			)
			return []

		actions.append_array(throw_route)

	actions.append(ThrowBucketWaterAction.new(throw_point))
	actions.append(ContinueRepairingAction.new())

	return actions


func _is_mid_deck_flooded_by_arrival(
	actor,
	mid_entry_point: ShipActionPoint
) -> bool:

	if (
		actor == null
		or mid_entry_point == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	if actor.ship.health_system.get_water_level() > MID_DECK_WATER_LEVEL:
		return true

	var time_to_mid_deck = _estimate_move_duration_to_point(
		actor,
		mid_entry_point
	)

	if time_to_mid_deck == INF:
		return false

	return (
		actor.ship.health_system.get_projected_water_level(time_to_mid_deck)
		> MID_DECK_WATER_LEVEL
	)


func _build_flooded_repair_area_bail(
	actor,
	mid_entry_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> Array[ActionDefinition]:

	var lower_bucket_point = action_points.get_point(&"BucketLD")

	if lower_bucket_point == null:
		return []

	var actions = _build_mid_deck_bail_cycle(
		actor,
		lower_bucket_point,
		mid_entry_point,
		throw_point
	)

	if actions.is_empty():
		return []

	actions.append(ContinueRepairingAction.new())

	return actions


func can_repair_hole_safely(
	actor,
	hole: ShipHolePoint,
	effective_flood_rate := -1.0
) -> bool:

	var repair_trip = estimate_repair_trip(
		actor,
		hole
	)

	return is_repair_trip_safe(
		actor,
		hole,
		repair_trip,
		effective_flood_rate
	)


func estimate_repair_bail_cycle_duration(actor) -> float:

	var actions = _build_repair_bail_cycle(actor)

	if actions.is_empty():
		return INF

	var duration = _estimate_total_action_duration(
		actor,
		actions
	)

	if (
		actor != null
		and actor.bucket_amount > 0.0
	):
		duration += _estimate_empty_bucket_cycle_after_throw(actor)

	return duration


func _estimate_empty_bucket_cycle_after_throw(actor) -> float:

	if actor == null:
		return INF

	var lower_bucket_point = action_points.get_point(&"BucketLD")
	var throw_point = action_points.get_point(&"WaterThrowSpot")

	if (
		lower_bucket_point == null
		or throw_point == null
	):
		return INF

	if (
		actor.ship != null
		and actor.ship.health_system != null
		and actor.ship.health_system.get_water_level() > MID_DECK_WATER_LEVEL
	):
		return (
			BailWaterAction.DURATION
			+ ThrowBucketWaterAction.DURATION
		)

	return (
		_estimate_move_and_bail_duration_from_point(
			actor,
			throw_point,
			lower_bucket_point
		)
		+ _estimate_throw_duration_from_bucket(
			actor,
			lower_bucket_point
		)
	)


func estimate_travel_duration_to_point(
	actor,
	point: ShipActionPoint
) -> float:

	return _estimate_move_duration_to_point(
		actor,
		point
	)


func estimate_repair_trip_duration(
	actor,
	hole: ShipHolePoint
) -> float:

	var repair_trip = estimate_repair_trip(
		actor,
		hole
	)

	return repair_trip["total_time"]


func estimate_repair_trip(
	actor,
	hole: ShipHolePoint
) -> Dictionary:

	return _estimate_repair_trip(
		actor,
		hole
	)


func _build_mid_deck_bail_cycle(
	actor,
	lower_bucket_point: ShipActionPoint,
	mid_entry_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> Array[ActionDefinition]:

	var bucket_point = _get_mid_deck_bucket_point(
		actor,
		lower_bucket_point,
		mid_entry_point,
		throw_point
	)

	if bucket_point == null:
		_print_route_failure(
			"mid_deck_bail_cycle",
			{
				"reason": "missing bucket point"
			}
		)
		return []

	var actions = build_go_to_point(
		actor,
		bucket_point
	)

	if (
		actor.location != bucket_point.deck
		and actions.is_empty()
	):
		_print_route_failure(
			"mid_deck_bail_cycle",
			{
				"actor_deck": DeckGraph.get_deck_name(
					actor.location
				),
				"bucket_point": bucket_point.name,
				"bucket_deck": DeckGraph.get_deck_name(bucket_point.deck)
			}
		)
		return []

	_replace_bucket_route_with_scoop(
		actions,
		bucket_point
	)

	if bucket_point != throw_point:
		var throw_route = build_go_to_point_from_deck(
			bucket_point.deck,
			throw_point,
			bucket_point.global_position
		)

		if (
			bucket_point.deck != throw_point.deck
			and throw_route.is_empty()
		):
			_print_route_failure(
				"mid_deck_throw_route",
				{
					"from_deck": DeckGraph.get_deck_name(
						bucket_point.deck
					),
					"to_deck": DeckGraph.get_deck_name(
						throw_point.deck
					),
					"bucket_point": bucket_point.name,
					"throw_point": throw_point.name
				}
			)
			return []

		actions.append_array(throw_route)

	actions.append(ThrowBucketWaterAction.new(throw_point))

	return actions


func _build_repair_bail_cycle(actor) -> Array[ActionDefinition]:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return []

	var lower_bucket_point = action_points.get_point(&"BucketLD")
	var throw_point = action_points.get_point(&"WaterThrowSpot")
	var mid_entry_point = action_points.get_point(&"Main2MidBottom")

	if (
		lower_bucket_point == null
		or throw_point == null
	):
		_print_route_failure(
			"repair_bail_cycle",
			{
				"reason": "missing lower bucket point or throw point"
			}
		)
		return []

	var actions: Array[ActionDefinition] = []

	if actor.bucket_amount > 0.0:
		actions = build_go_to_point(
			actor,
			throw_point
		)

		if (
			actor.location != throw_point.deck
			and actions.is_empty()
		):
			_print_route_failure(
				"repair_bail_cycle_throw",
				{
					"actor_deck": DeckGraph.get_deck_name(
						actor.location
					),
					"throw_point": throw_point.name,
					"throw_deck": DeckGraph.get_deck_name(throw_point.deck)
				}
			)
			return []

		actions.append(ThrowBucketWaterAction.new(throw_point))
	else:
		if _should_use_mid_deck_bailing(
			actor,
			lower_bucket_point,
			mid_entry_point,
			throw_point
		):
			actions = _build_mid_deck_bail_cycle(
				actor,
				lower_bucket_point,
				mid_entry_point,
				throw_point
			)

		if actions.is_empty():
			actions = _build_single_bail_cycle(
				actor,
				lower_bucket_point,
				throw_point
			)

	if actions.is_empty():
		_print_route_failure(
			"repair_bail_cycle",
			{
				"actor_deck": DeckGraph.get_deck_name(
					actor.location
				),
				"bucket_point": lower_bucket_point.name,
				"throw_point": throw_point.name
			}
		)
		return []

	actions.append(ContinueRepairingAction.new())

	return actions


func _build_single_bail_cycle(
	actor,
	bucket_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> Array[ActionDefinition]:

	var actions = build_go_to_point(
		actor,
		bucket_point
	)

	if (
		actor.location != bucket_point.deck
		and actions.is_empty()
	):
		_print_route_failure(
			"single_bail_cycle",
			{
				"actor_deck": DeckGraph.get_deck_name(
					actor.location
				),
				"bucket_point": bucket_point.name,
				"bucket_deck": DeckGraph.get_deck_name(bucket_point.deck)
			}
		)
		return []

	_replace_bucket_route_with_scoop(
		actions,
		bucket_point
	)

	var throw_route = build_go_to_point_from_deck(
		bucket_point.deck,
		throw_point,
		bucket_point.global_position
	)

	if (
		bucket_point.deck != throw_point.deck
		and throw_route.is_empty()
	):
		_print_route_failure(
			"single_bail_throw_route",
			{
				"from_deck": DeckGraph.get_deck_name(
					bucket_point.deck
				),
				"to_deck": DeckGraph.get_deck_name(
					throw_point.deck
				),
				"bucket_point": bucket_point.name,
				"throw_point": throw_point.name
			}
		)
		return []

	actions.append_array(throw_route)

	actions.append(ThrowBucketWaterAction.new(throw_point))

	return actions


func build_go_to_point_from_deck(
	start_deck: int,
	point: ShipActionPoint,
	start_position = null
) -> Array[ActionDefinition]:

	return route_planner.build_go_to_point_from_deck(
		start_deck,
		point,
		start_position
	)


func build_transition_actions(
	actor,
	target_deck: int
) -> Array[ActionDefinition]:

	return route_planner.build_transition_actions(
		actor,
		target_deck
	)


func build_transition_actions_from_deck(
	start_deck: int,
	target_deck: int,
	start_position = null
) -> Array[ActionDefinition]:

	return route_planner.build_transition_actions_from_deck(
		start_deck,
		target_deck,
		start_position
	)


func _should_use_mid_deck_bailing(
	actor,
	lower_bucket_point: ShipActionPoint,
	mid_entry_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> bool:

	if (
		actor == null
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	if actor.ship.health_system.get_water_level() > MID_DECK_WATER_LEVEL:
		return true

	var bucket_point = _get_mid_deck_bucket_point(
		actor,
		lower_bucket_point,
		mid_entry_point,
		throw_point
	)

	if bucket_point == null:
		return false

	var estimated_duration = _estimate_move_and_bail_duration(
		actor,
		bucket_point
	)

	if estimated_duration == INF:
		return false

	var projected_water = actor.ship.health_system.get_projected_water_level(estimated_duration)

	return projected_water > MID_DECK_WATER_LEVEL


func _get_mid_deck_bucket_point(
	actor,
	lower_bucket_point: ShipActionPoint,
	mid_entry_point: ShipActionPoint,
	throw_point: ShipActionPoint
) -> ShipActionPoint:

	if actor == null:
		return throw_point

	match actor.location:
		DeckGraph.DECKS.UPPER, DeckGraph.DECKS.MAIN:
			return mid_entry_point

		DeckGraph.DECKS.LOWER:
			return lower_bucket_point

	return throw_point


func _estimate_move_and_bail_duration(
	actor,
	bucket_point: ShipActionPoint
) -> float:

	if (
		actor == null
		or bucket_point == null
	):
		return INF

	var route_actions = build_go_to_point(
		actor,
		bucket_point
	)

	if (
		actor.location != bucket_point.deck
		and route_actions.is_empty()
	):
		return INF

	var route_points = _get_move_route_points(
		route_actions,
		bucket_point
	)

	return max(
		MoveToPointAction.get_travel_duration_for_points(
			actor,
			route_points
		),
		BailWaterAction.DURATION
	)


func _get_bail_target_water_level(drain_to_zero: bool) -> float:

	if (
		drain_to_zero
		or not _has_damaged_holes()
	):
		return 0.0

	return LOW_WATER_LEVEL


func is_repair_trip_safe(
	actor,
	hole: ShipHolePoint,
	repair_trip: Dictionary,
	effective_flood_rate := -1.0
) -> bool:

	if (
		actor == null
		or hole == null
		or repair_trip.is_empty()
		or not repair_trip.has("total_time")
		or not repair_trip.has("repair_complete_time")
		or actor.ship == null
		or actor.ship.health_system == null
	):
		return false

	if repair_trip["total_time"] == INF:
		return false

	var total_time = repair_trip["total_time"]
	var repair_complete_time = repair_trip["repair_complete_time"]
	var flood_rate = effective_flood_rate
	var water_level = actor.ship.health_system.get_water_level()

	if flood_rate < 0.0:
		flood_rate = actor.ship.health_system.get_flood_rate()

	if flood_rate <= 0.0:
		return water_level < (
			actor.ship.health_system.MAX_WATER_LEVEL
		)

	return ShipFloodForecast.can_survive_repair_trip(
		water_level,
		actor.ship.health_system.MAX_WATER_LEVEL,
		flood_rate,
		_get_flooding_hole_grade(hole),
		repair_complete_time,
		total_time,
		REPAIR_SAFETY_LEEWAY
	)


func _estimate_repair_trip(
	actor,
	hole: ShipHolePoint
) -> Dictionary:

	var time_to_hole = _estimate_move_duration_to_point(
		actor,
		hole
	)

	if time_to_hole == INF:
		return _get_unreachable_repair_trip()

	var repair_duration = float(
		hole.grade
	) + RepairHoleAction.EXTRA_REPAIR_SECONDS
	var repair_complete_time = time_to_hole + repair_duration

	if actor.bucket_amount > 0.0:
		var time_to_throw = _estimate_throw_duration_from_bucket(
			actor,
			hole
		)

		if time_to_throw == INF:
			return _get_unreachable_repair_trip()

		return {
			"total_time": repair_complete_time + time_to_throw,
			"repair_complete_time": repair_complete_time
		}

	var projected_after_repair = actor.ship.health_system.get_projected_water_level(repair_complete_time)
	var bucket_point = _get_bucket_point_after_repair(
		hole,
		projected_after_repair
	)

	if bucket_point == null:
		return {
			"total_time": repair_complete_time,
			"repair_complete_time": repair_complete_time
		}

	var time_to_bucket = _estimate_move_and_bail_duration_from_point(
		actor,
		hole,
		bucket_point
	)

	if time_to_bucket == INF:
		return _get_unreachable_repair_trip()

	var time_to_throw = _estimate_throw_duration_from_bucket(
		actor,
		bucket_point
	)

	if time_to_throw == INF:
		return _get_unreachable_repair_trip()

	return {
		"total_time": (
			repair_complete_time
			+ time_to_bucket
			+ time_to_throw
		),
		"repair_complete_time": repair_complete_time
	}


func _get_unreachable_repair_trip() -> Dictionary:

	return {
		"total_time": INF,
		"repair_complete_time": INF
	}


func _get_flooding_hole_grade(hole: ShipHolePoint) -> float:

	if (
		hole == null
		or (
			hole.deck != DeckGraph.DECKS.MID
			and hole.deck != DeckGraph.DECKS.LOWER
		)
	):
		return 0.0

	return float(
		hole.grade
	)


func _estimate_move_duration_to_point(
	actor,
	point: ShipActionPoint
) -> float:

	return route_planner.estimate_move_duration_to_point(
		actor,
		point
	)


func _get_bucket_point_after_repair(
	hole: ShipHolePoint,
	projected_water: float
) -> ShipActionPoint:

	var lower_bucket_point = action_points.get_point(&"BucketLD")
	var mid_entry_point = action_points.get_point(&"Main2MidBottom")
	var throw_point = action_points.get_point(&"WaterThrowSpot")

	if projected_water > MID_DECK_WATER_LEVEL:
		match hole.deck:
			DeckGraph.DECKS.UPPER, DeckGraph.DECKS.MAIN:
				return mid_entry_point

			DeckGraph.DECKS.LOWER:
				return lower_bucket_point

		return throw_point

	return lower_bucket_point


func _estimate_move_and_bail_duration_from_point(
	actor,
	start_point: ShipActionPoint,
	bucket_point: ShipActionPoint
) -> float:

	var route_actions = build_go_to_point_from_deck(
		start_point.deck,
		bucket_point,
		start_point.global_position
	)

	if (
		start_point.deck != bucket_point.deck
		and route_actions.is_empty()
	):
		return INF

	var route_points = _get_move_route_points(
		route_actions,
		bucket_point
	)

	return max(
		MoveToPointAction.get_travel_duration_for_points(
			actor,
			route_points,
			start_point.get_position_for_actor(actor)
		),
		BailWaterAction.DURATION
	)


func _estimate_throw_duration_from_bucket(
	actor,
	bucket_point: ShipActionPoint
) -> float:

	var throw_point = action_points.get_point(&"WaterThrowSpot")

	if throw_point == null:
		return INF

	var movement_duration := 0.0

	if bucket_point != throw_point:
		var route_actions = build_go_to_point_from_deck(
			bucket_point.deck,
			throw_point,
			bucket_point.global_position
		)

		if (
			bucket_point.deck != throw_point.deck
			and route_actions.is_empty()
		):
			return INF

		var route_points = _get_move_route_points(
			route_actions,
			throw_point
		)

		movement_duration = MoveToPointAction.get_travel_duration_for_points(
			actor,
			route_points,
			bucket_point.get_position_for_actor(actor)
		)

	return movement_duration + ThrowBucketWaterAction.DURATION


func _has_damaged_holes() -> bool:

	return _get_closest_damaged_hole() != null


func _get_closest_damaged_hole(
	actor = null,
	excluded_holes: Array = []
) -> ShipHolePoint:

	if action_points == null:
		return null

	var closest_hole: ShipHolePoint = null
	var closest_distance := INF

	for hole in action_points.get_holes_ref():
		if hole.grade <= ShipHolePoint.MIN_GRADE:
			continue

		if excluded_holes.has(
			hole
		):
			continue

		var distance := 0.0

		if actor != null:
			distance = actor.global_position.distance_to(hole.global_position)

		if (
			closest_hole == null
			or distance < closest_distance
		):
			closest_hole = hole
			closest_distance = distance

	return closest_hole


func _should_queue_bail_cycle(
	actor,
	actions: Array,
	drain_to_zero := false
) -> bool:

	var time_until_bail = _estimate_time_until_bail_complete(
		actor,
		actions
	)
	var projected_water = actor.ship.health_system.get_projected_water_level(time_until_bail)
	var target_water_level = _get_bail_target_water_level(drain_to_zero)

	if target_water_level <= 0.0:
		return projected_water > 0.0

	return projected_water >= target_water_level


func _estimate_time_until_bail_complete(
	actor,
	actions: Array
) -> float:

	return route_planner.estimate_time_until_bail_complete(
		actor,
		actions
	)


func _estimate_total_action_duration(
	actor,
	actions: Array
) -> float:

	return route_planner.estimate_total_action_duration(
		actor,
		actions
	)


func _replace_bucket_route_with_scoop(
	actions: Array,
	bucket_point: ShipActionPoint
) -> void:

	var route_points = _get_move_route_points(
		actions,
		bucket_point
	)

	actions.clear()
	actions.append(
		MoveAndBailWaterAction.new(
			bucket_point,
			route_points
		)
	)


func _get_move_route_points(
	actions: Array,
	bucket_point: ShipActionPoint
) -> Array:

	return route_planner.get_move_route_points(
		actions,
		bucket_point
	)


func _print_route_failure(
	route_name: String,
	details: Dictionary = {}
) -> void:

	ShipDebugLog.route_failure(
		route_name,
		details
	)
