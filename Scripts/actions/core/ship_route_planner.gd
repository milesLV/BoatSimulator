class_name ShipRoutePlanner
extends RefCounted

const START_NODE_KEY := "__start"
const TARGET_NODE_KEY := "__target"

var action_points: ShipActionPointContainer


func _init(new_action_points: ShipActionPointContainer) -> void:
	action_points = new_action_points


func build_route_plan(
	actor,
	point: ShipActionPoint,
	start_deck = null,
	start_position = null
) -> Dictionary:

	if point == null:
		return _unreachable_route("missing target point")

	var origin_deck = _resolve_start_deck(
		actor,
		start_deck
	)
	var origin_position = _resolve_start_position(
		actor,
		start_position
	)

	return _build_weighted_route_plan(
		actor,
		origin_deck,
		origin_position,
		point,
		point.deck
	)


func build_go_to_point(actor, point: ShipActionPoint) -> Array[ActionDefinition]:
	if point == null:
		return []

	var route_plan = build_route_plan(actor, point)

	if not route_plan["reachable"]:
		_log_unreachable_route(
			"go_to_point",
			route_plan,
			_resolve_start_deck(actor, null),
			point.deck,
			point
		)
		return []

	return _route_to_move_actions(route_plan)


func build_go_to_point_from_deck(
	start_deck: int,
	point: ShipActionPoint,
	start_position = null,
	actor = null
) -> Array[ActionDefinition]:

	if point == null:
		return []

	var route_plan = build_route_plan(
		actor,
		point,
		start_deck,
		start_position
	)

	if not route_plan["reachable"]:
		_log_unreachable_route(
			"go_to_point_from_deck",
			route_plan,
			start_deck,
			point.deck,
			point
		)
		return []

	return _route_to_move_actions(route_plan)


func build_transition_actions(actor, target_deck: int) -> Array[ActionDefinition]:
	if actor == null:
		return []

	return build_transition_actions_from_deck(
		actor.location,
		target_deck,
		actor.position,
		actor
	)


func build_transition_actions_from_deck(
	start_deck: int,
	target_deck: int,
	start_position = null,
	actor = null
) -> Array[ActionDefinition]:

	if start_deck == target_deck:
		return []

	var route_plan = _build_weighted_route_plan(
		actor,
		start_deck,
		_resolve_start_position(
			actor,
			start_position
		),
		null,
		target_deck
	)

	if not route_plan["reachable"]:
		_log_unreachable_route(
			"transition_actions",
			route_plan,
			start_deck,
			target_deck
		)
		return []

	return _route_to_move_actions(route_plan)


func estimate_move_duration_to_point(actor, point: ShipActionPoint) -> float:
	var route_plan = build_route_plan(actor, point)

	if not route_plan["reachable"]:
		return INF

	return route_plan["total_duration"]


func estimate_total_action_duration(actor, actions: Array) -> float:
	return _estimate_action_duration_until(
		actor,
		actions,
		false
	)


func estimate_time_until_bail_complete(actor, actions: Array) -> float:
	return _estimate_action_duration_until(
		actor,
		actions,
		true
	)


func _estimate_action_duration_until(
	actor,
	actions: Array,
	stop_at_bail: bool
) -> float:

	if actor == null:
		return 0.0

	var elapsed := 0.0
	var current_position: Vector2 = actor.position
	var current_deck = actor.location

	for action in actions:
		if action == null:
			continue

		if action is MoveAndBailWaterAction:
			var move_and_bail_action := action as MoveAndBailWaterAction
			var move_and_bail_duration = max(
				MoveToPointAction.get_travel_duration_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position,
					current_deck
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
				if move_and_bail_action.point != null:
					current_deck = move_and_bail_action.point.deck

			if stop_at_bail:
				return elapsed

			continue

		if action is MoveToPointAction:
			var move_action := action as MoveToPointAction
			var move_target_position = move_action.point.get_position_for_actor(actor)
			elapsed += MoveToPointAction.get_travel_duration_to_point(
				actor,
				move_action.point,
				current_position,
				current_deck
			)
			current_position = move_target_position
			current_deck = move_action.point.deck
			continue

		elapsed += action.get_duration(actor)

		if stop_at_bail and action is BailWaterAction:
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


func _build_weighted_route_plan(
	actor,
	start_deck: int,
	start_position: Vector2,
	target_point: ShipActionPoint,
	target_deck: int
) -> Dictionary:

	if action_points == null:
		return _unreachable_route("missing action points")

	if (
		target_point == null
		and start_deck == target_deck
	):
		return _route_from_segments(
			[],
			target_deck
		)

	var nodes = _build_route_nodes(
		actor,
		start_deck,
		start_position,
		target_point
	)
	var distances := {}
	var previous_keys := {}
	var previous_segments := {}
	var unvisited: Array = []

	for key in nodes.keys():
		distances[key] = INF
		unvisited.append(key)

	distances[START_NODE_KEY] = 0.0

	var destination_key := ""

	while not unvisited.is_empty():
		var current_key = _pop_closest_unvisited(
			unvisited,
			distances
		)

		if current_key == "":
			break

		var current_distance: float = distances.get(
			current_key,
			INF
		)

		if current_distance == INF:
			break

		var current_node: Dictionary = nodes[current_key]

		if _route_destination_reached(
			current_key,
			current_node,
			target_point,
			target_deck
		):
			destination_key = current_key
			break

		for edge in _get_route_edges(
			actor,
			current_key,
			current_node,
			nodes,
			target_point
		):
			var next_key: String = edge["to_key"]

			if not unvisited.has(next_key):
				continue

			var segment: Dictionary = edge["segment"]
			var next_distance = current_distance + segment["duration"]

			if next_distance >= distances.get(next_key, INF):
				continue

			distances[next_key] = next_distance
			previous_keys[next_key] = current_key
			previous_segments[next_key] = segment

	if destination_key == "":
		return _unreachable_route("no weighted path")

	return _reconstruct_route_plan(
		destination_key,
		previous_keys,
		previous_segments,
		target_deck
	)


func _build_route_nodes(
	actor,
	start_deck: int,
	start_position: Vector2,
	target_point: ShipActionPoint
) -> Dictionary:

	var nodes := {}

	nodes[START_NODE_KEY] = {
		"point": null,
		"deck": start_deck,
		"position": start_position
	}

	for transition in action_points.get_transition_points_ref():
		if transition == null:
			continue

		nodes[_get_point_key(transition)] = {
			"point": transition,
			"deck": transition.deck,
			"position": _get_point_position(
				actor,
				transition
			)
		}

	if target_point != null:
		nodes[TARGET_NODE_KEY] = {
			"point": target_point,
			"deck": target_point.deck,
			"position": _get_point_position(
				actor,
				target_point
			)
		}

	return nodes


func _get_route_edges(
	actor,
	current_key: String,
	current_node: Dictionary,
	nodes: Dictionary,
	target_point: ShipActionPoint
) -> Array:

	var edges: Array = []
	var current_deck: int = current_node["deck"]
	var current_point = current_node["point"]

	if (
		target_point != null
		and current_deck == target_point.deck
		and current_key != TARGET_NODE_KEY
	):
		_append_route_edge(
			edges,
			actor,
			current_node,
			TARGET_NODE_KEY,
			nodes
		)

	for transition in action_points.get_transition_points_ref():
		if (
			transition == null
			or transition.deck != current_deck
		):
			continue

		var transition_key = _get_point_key(transition)

		if transition_key == current_key:
			continue

		_append_route_edge(
			edges,
			actor,
			current_node,
			transition_key,
			nodes
		)

	if current_point is DeckTransitionPoint:
		var destination_point: DeckTransitionPoint = current_point.deck_connection

		if destination_point != null:
			_append_route_edge(
				edges,
				actor,
				current_node,
				_get_point_key(destination_point),
				nodes
			)

	return edges


func _append_route_edge(
	edges: Array,
	actor,
	current_node: Dictionary,
	next_key: String,
	nodes: Dictionary
) -> void:

	if not nodes.has(next_key):
		return

	var next_node: Dictionary = nodes[next_key]
	var next_point: ShipActionPoint = next_node["point"]

	if next_point == null:
		return

	var from_position: Vector2 = current_node["position"]
	var to_position: Vector2 = next_node["position"]
	var from_deck: int = current_node["deck"]
	var to_deck: int = next_node["deck"]
	var duration = _estimate_segment_duration(
		actor,
		next_point,
		from_position,
		to_position,
		from_deck
	)

	edges.append(
		{
			"to_key": next_key,
			"segment": {
				"target_point": next_point,
				"from_position": from_position,
				"to_position": to_position,
				"from_deck": from_deck,
				"to_deck": to_deck,
				"duration": duration
			}
		}
	)


func _route_destination_reached(
	current_key: String,
	current_node: Dictionary,
	target_point: ShipActionPoint,
	target_deck: int
) -> bool:

	if target_point != null:
		return current_key == TARGET_NODE_KEY

	return (
		current_key != START_NODE_KEY
		and current_node["deck"] == target_deck
	)


func _reconstruct_route_plan(
	destination_key: String,
	previous_keys: Dictionary,
	previous_segments: Dictionary,
	target_deck: int
) -> Dictionary:

	var key = destination_key
	var segments: Array = []

	while key != START_NODE_KEY:
		if (
			not previous_keys.has(key)
			or not previous_segments.has(key)
		):
			return _unreachable_route("broken route reconstruction")

		segments.push_front(previous_segments[key])
		key = previous_keys[key]

	return _route_from_segments(
		segments,
		target_deck
	)


func _unreachable_route(reason := "") -> Dictionary:

	return {
		"reachable": false,
		"route_points": [],
		"total_duration": INF,
		"final_deck": -1,
		"failure_reason": reason
	}


func _route_from_segments(
	segments: Array,
	final_deck := -1
) -> Dictionary:

	var route_points: Array = []
	var total_duration := 0.0

	for segment in segments:
		if not (segment is Dictionary):
			continue

		route_points.append(segment["target_point"])
		total_duration += segment["duration"]

	return {
		"reachable": true,
		"route_points": route_points,
		"total_duration": total_duration,
		"final_deck": final_deck,
		"failure_reason": ""
	}


func _route_to_move_actions(route_plan: Dictionary) -> Array[ActionDefinition]:

	var actions: Array[ActionDefinition] = []

	if not route_plan["reachable"]:
		return actions

	for route_point in route_plan["route_points"]:
		if route_point == null:
			continue

		actions.append(MoveToPointAction.new(route_point))

	return actions


func _pop_closest_unvisited(
	unvisited: Array,
	distances: Dictionary
) -> String:

	var best_key := ""
	var best_distance := INF
	var best_index := -1

	for i in range(unvisited.size()):
		var key: String = unvisited[i]
		var distance: float = distances.get(
			key,
			INF
		)

		if distance < best_distance:
			best_distance = distance
			best_key = key
			best_index = i

	if best_index >= 0:
		unvisited.remove_at(best_index)

	return best_key


func _estimate_segment_duration(
	actor,
	target_point: ShipActionPoint,
	from_position: Vector2,
	to_position: Vector2,
	from_deck: int
) -> float:

	if actor != null:
		return MoveToPointAction.get_travel_duration_to_point(
			actor,
			target_point,
			from_position,
			from_deck
		)

	var speed = MoveToPointAction.get_effective_run_speed(
		null,
		from_deck,
		target_point.deck,
		target_point
	)

	if speed <= 0.0:
		return INF

	return from_position.distance_to(to_position) / speed


func _get_point_position(
	actor,
	point: ShipActionPoint
) -> Vector2:

	if actor != null:
		return point.get_position_for_actor(actor)

	return point.global_position


func _resolve_start_position(
	actor,
	start_position
) -> Vector2:

	if start_position is Vector2:
		return start_position

	if actor != null:
		return actor.position

	return Vector2.ZERO


func _resolve_start_deck(
	actor,
	start_deck
) -> int:

	if start_deck is int:
		return start_deck

	if actor != null:
		return actor.location

	return -1


func _get_point_key(point: ShipActionPoint) -> String:

	return "point_%s" % point.get_instance_id()


func _log_unreachable_route(
	route_name: String,
	route_plan,
	from_deck: int,
	to_deck: int,
	point: ShipActionPoint = null
) -> void:

	var target_point_name := ""

	if point != null:
		target_point_name = String(point.name)

	ShipDebugLog.route_failure(
		route_name,
		{
			"from_deck": DeckGraph.get_deck_name(from_deck),
			"to_deck": DeckGraph.get_deck_name(to_deck),
			"target_point": target_point_name,
			"reason": route_plan["failure_reason"]
		}
	)
