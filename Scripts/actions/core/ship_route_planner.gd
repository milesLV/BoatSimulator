class_name ShipRoutePlanner
extends RefCounted

var action_points: ShipActionPointContainer


func _init(new_action_points: ShipActionPointContainer) -> void:
	action_points = new_action_points


func build_go_to_point(actor, point: ShipActionPoint) -> Array[ActionDefinition]:
	if point == null:
		return []

	var actions = build_transition_actions(actor, point.deck)

	if actor.location != point.deck and actions.is_empty():
		return []

	actions.append(MoveToPointAction.new(point))

	return actions


func build_go_to_point_from_deck(
	start_deck: int,
	point: ShipActionPoint,
	start_position = null
) -> Array[ActionDefinition]:

	if point == null:
		return []

	var actions = build_transition_actions_from_deck(
		start_deck,
		point.deck,
		start_position
	)

	if start_deck != point.deck and actions.is_empty():
		return []

	actions.append(MoveToPointAction.new(point))

	return actions


func build_transition_actions(actor, target_deck: int) -> Array[ActionDefinition]:
	if actor == null:
		return []

	return build_transition_actions_from_deck(
		actor.location,
		target_deck,
		actor.global_position
	)


func build_transition_actions_from_deck(
	start_deck: int,
	target_deck: int,
	start_position = null
) -> Array[ActionDefinition]:

	var deck_path = action_points.get_transition_path(start_deck, target_deck)

	if deck_path.is_empty():
		push_error(
			"No deck path from %s to %s."
			% [
				DeckGraph.get_deck_name(start_deck),
				DeckGraph.get_deck_name(target_deck)
			]
		)
		ShipDebugLog.route_failure(
			"transition_path",
			{
				"from_deck": DeckGraph.get_deck_name(start_deck),
				"to_deck": DeckGraph.get_deck_name(target_deck),
				"start_position": _get_start_position(start_position)
			}
		)
		return []

	if deck_path.size() <= 1:
		return []

	var actions: Array[ActionDefinition] = []
	var current_position = _get_start_position(start_position)

	for i in range(deck_path.size() - 1):
		var from_deck: int = deck_path[i]
		var to_deck: int = deck_path[i + 1]
		var start_point = _get_transition_point_for_step(
			from_deck,
			to_deck,
			current_position
		)

		if start_point == null:
			ShipDebugLog.route_failure(
				"transition_start_point",
				{
					"from_deck": DeckGraph.get_deck_name(from_deck),
					"to_deck": DeckGraph.get_deck_name(to_deck),
					"current_position": current_position
				}
			)
			return []

		var destination_point = start_point.deck_connection

		if destination_point == null:
			push_error(
				"Transition point %s has no connected destination."
				% start_point.name
			)
			ShipDebugLog.route_failure(
				"transition_destination",
				{
					"transition_point": start_point.name,
					"from_deck": DeckGraph.get_deck_name(from_deck),
					"to_deck": DeckGraph.get_deck_name(to_deck)
				}
			)
			return []

		actions.append(MoveToPointAction.new(start_point))
		actions.append(MoveToPointAction.new(destination_point))
		current_position = destination_point.global_position

	return actions


func estimate_move_duration_to_point(actor, point: ShipActionPoint) -> float:
	var route_actions = build_go_to_point(actor, point)

	if actor.location != point.deck and route_actions.is_empty():
		return INF

	var route_points = get_move_route_points(route_actions, point)

	return MoveToPointAction.get_travel_duration_for_points(actor, route_points)


func estimate_total_action_duration(actor, actions: Array) -> float:
	if actor == null:
		return 0.0

	var elapsed := 0.0
	var current_position: Vector2 = actor.position

	for action in actions:
		if action == null:
			continue

		if action is MoveAndBailWaterAction:
			var move_and_bail_action := action as MoveAndBailWaterAction
			var move_and_bail_positions = (
				MoveToPointAction.get_route_positions_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position
				)
			)

			elapsed += max(
				MoveToPointAction.get_travel_duration_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position
				),
				BailWaterAction.DURATION
			)

			if not move_and_bail_positions.is_empty():
				current_position = move_and_bail_positions[
					move_and_bail_positions.size() - 1
				]

			continue

		if action is MoveToPointAction:
			var move_action := action as MoveToPointAction
			var move_target_position = move_action.point.get_position_for_actor(actor)
			elapsed += current_position.distance_to(move_target_position) / Crewmate.RUN_SPEED
			current_position = move_target_position
			continue

		elapsed += action.get_duration(actor)

	return elapsed


func estimate_time_until_bail_complete(actor, actions: Array) -> float:
	if actor == null:
		return 0.0

	var elapsed := 0.0
	var current_position: Vector2 = actor.position

	for action in actions:
		if action == null:
			continue

		if action is MoveAndBailWaterAction:
			var move_and_bail_action := action as MoveAndBailWaterAction
			var move_and_bail_duration = max(
				MoveToPointAction.get_travel_duration_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position
				),
				BailWaterAction.DURATION
			)
			var move_and_bail_positions = (
				MoveToPointAction.get_route_positions_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position
				)
			)

			elapsed += move_and_bail_duration

			if not move_and_bail_positions.is_empty():
				current_position = move_and_bail_positions[
					move_and_bail_positions.size() - 1
				]

			return elapsed

		if action is MoveToPointAction:
			var move_action := action as MoveToPointAction
			var move_target_position = move_action.point.get_position_for_actor(actor)
			elapsed += current_position.distance_to(move_target_position) / Crewmate.RUN_SPEED
			current_position = move_target_position
		else:
			elapsed += action.get_duration(actor)

		if action is BailWaterAction:
			return elapsed

	return elapsed


func get_move_route_points(actions: Array, destination_point: ShipActionPoint) -> Array:
	var route_points: Array = []

	for action in actions:
		if not (action is MoveToPointAction):
			continue

		route_points.append(action.point)

	if (
		destination_point != null
		and (
			route_points.is_empty()
			or route_points[route_points.size() - 1] != destination_point
		)
	):
		route_points.append(destination_point)

	return route_points


func _get_start_position(start_position) -> Vector2:
	if start_position is Vector2:
		return start_position

	return Vector2.ZERO


func _get_transition_point_for_step(
	from_deck: int,
	to_deck: int,
	current_position: Vector2
) -> DeckTransitionPoint:

	return action_points.get_closest_transition_point(
		from_deck,
		to_deck,
		current_position
	)
