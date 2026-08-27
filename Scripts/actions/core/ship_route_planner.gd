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

	var origin_deck = MoveToPointAction.resolve_start_deck(actor, start_deck)
	var origin_position = MoveToPointAction.resolve_start_position(actor, start_position)

	return _build_weighted_route_plan(actor, origin_deck, origin_position, point)


func build_go_to_point(
	actor,
	point: ShipActionPoint,
	start_deck = null,
	start_position = null
) -> Array[ActionDefinition]:

	if point == null:
		return []

	var route_plan = build_route_plan(actor, point, start_deck, start_position)

	if not route_plan["reachable"]:
		ShipDebugLog.route_failure(
			"go_to_point",
			{
				"from_deck": DeckGraph.get_deck_name(
					MoveToPointAction.resolve_start_deck(actor, start_deck)
				),
				"to_deck": DeckGraph.get_deck_name(point.deck),
				"target_point": String(point.name),
				"reason": route_plan["failure_reason"]
			}
		)
		return []

	return _route_to_move_actions(route_plan)


func estimate_total_action_duration(actor, actions: Array) -> float:

	var durations = estimate_action_durations(actor, actions)

	if durations.any(func(duration): return duration < 0.0):
		return INF

	return durations.reduce(func(a, b): return a + b, 0.0)


func estimate_time_until_bail_complete(actor, actions: Array) -> float:

	if actor == null:
		return 0.0

	var elapsed := 0.0
	var durations = estimate_action_durations(actor, actions)

	for i in range(actions.size()):
		if durations[i] < 0.0:
			return INF

		elapsed += durations[i]

		if actions[i].fills_bucket:
			return elapsed

	return INF


func estimate_action_durations(
	actor,
	actions: Array,
	start_position = null,
	start_deck = null
) -> Array[float]:

	if actor == null:
		return []

	var durations: Array[float] = []
	var current_position = MoveToPointAction.resolve_start_position(actor, start_position)
	var current_deck = MoveToPointAction.resolve_start_deck(actor, start_deck)

	for action in actions:
		if action == null:
			durations.append(0.0)
			continue

		if action is MoveAndBailWaterAction:
			var move_and_bail_action := action as MoveAndBailWaterAction
			durations.append(max(
				MoveToPointAction.get_travel_duration_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position,
					current_deck
				),
				BailWaterAction.DURATION
			))
			var move_and_bail_positions = (
				MoveToPointAction.get_route_positions_for_points(
					actor,
					move_and_bail_action.route_points,
					current_position
				)
			)

			if not move_and_bail_positions.is_empty():
				current_position = move_and_bail_positions.back()
				if move_and_bail_action.point != null:
					current_deck = move_and_bail_action.point.deck

			continue

		if action is MoveToPointAction:
			var move_action := action as MoveToPointAction

			if move_action.point == null:
				durations.append(0.0)
				continue

			durations.append(MoveToPointAction.get_travel_duration_to_point(
				actor,
				move_action.point,
				current_position,
				current_deck
			))
			current_position = move_action.point.get_position_for_actor(actor, current_position)
			current_deck = move_action.point.deck
			continue

		durations.append(action.get_duration(actor))

	return durations


func get_plan_timing(actor, instances: Array[ActionInstance]) -> Dictionary:
	var timing := {
		"durations": [],
		"total_duration": 0.0,
		"elapsed": 0.0,
		"remaining": 0.0
	}

	if actor == null or instances.is_empty():
		return timing

	var current: ActionInstance = null
	var queued_definitions: Array = []
	var start_position: Vector2 = actor.position
	var start_deck: int = actor.location

	for instance in instances:
		if instance.finished:
			if instance.duration > 0.0:
				timing["durations"].append(instance.duration)
				timing["elapsed"] += instance.duration
		elif instance.started:
			current = instance
		elif instance.definition != null:
			queued_definitions.append(instance.definition)

	if current != null:
		if current.duration < 0.0:
			return timing

		if current.duration > 0.0:
			timing["durations"].append(current.duration)
			timing["elapsed"] += min(current.elapsed, current.duration)

		if current.definition is MoveToPointAction:
			var move_action := current.definition as MoveToPointAction
			start_position = current.get_runtime_value(
				MoveToPointAction.RUNTIME_TARGET_POSITION,
				move_action.point.get_position_for_actor(actor, actor.position)
			)
			start_deck = current.get_runtime_value(
				MoveToPointAction.RUNTIME_TARGET_DECK,
				move_action.point.deck
			)

	var queued_durations = estimate_action_durations(
		actor,
		queued_definitions,
		start_position,
		start_deck
	)

	for duration in queued_durations:
		if duration < 0.0:
			break

		if duration > 0.0:
			timing["durations"].append(duration)

	timing["total_duration"] = timing["durations"].reduce(func(a, b): return a + b, 0.0)

	timing["remaining"] = max(timing["total_duration"] - timing["elapsed"], 0.0)

	return timing


func get_move_route_points(actions: Array, destination_point: ShipActionPoint) -> Array:

	return MoveAndBailWaterAction.build_route_points(
		destination_point,
		actions
			.filter(func(action): return action is MoveToPointAction)
			.map(func(action): return action.point)
	)


func _build_weighted_route_plan(
	actor,
	start_deck: int,
	start_position: Vector2,
	target_point: ShipActionPoint
) -> Dictionary:

	if action_points == null:
		return _unreachable_route("missing action points")

	var nodes = _build_route_nodes(actor, start_deck, start_position, target_point)
	var distances := {}
	var previous_keys := {}
	var previous_segments := {}
	var unvisited: Array = nodes.keys()

	for key in unvisited:
		distances[key] = INF

	distances[START_NODE_KEY] = 0.0

	while not unvisited.is_empty():
		var current_key = _pop_closest_unvisited(unvisited, distances)
		var current_distance: float = distances[current_key]

		if current_distance == INF:
			break

		if is_same(current_key, TARGET_NODE_KEY):
			return _reconstruct_route_plan(TARGET_NODE_KEY, previous_keys, previous_segments)

		var current_node: Dictionary = nodes[current_key]

		for edge in _get_route_edges(actor, current_key, current_node, nodes, target_point):
			var next_key = edge["to_key"]

			if not unvisited.has(next_key):
				continue

			var segment: Dictionary = edge["segment"]
			var next_distance = current_distance + segment["duration"]

			if next_distance >= distances.get(next_key, INF):
				continue

			distances[next_key] = next_distance
			previous_keys[next_key] = current_key
			previous_segments[next_key] = segment

	return _unreachable_route("no weighted path")


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

	for transition in action_points.transitions:
		if transition == null:
			continue

		nodes[transition] = {
			"point": transition,
			"deck": transition.deck,
			"position": transition.get_position_for_actor(actor)
		}

	nodes[TARGET_NODE_KEY] = {
		"point": target_point,
		"deck": target_point.deck,
		"position": target_point.get_position_for_actor(actor)
	}

	return nodes


func _get_route_edges(
	actor,
	current_key,
	current_node: Dictionary,
	nodes: Dictionary,
	target_point: ShipActionPoint
) -> Array:

	var edges: Array = []
	var current_deck: int = current_node["deck"]
	var current_point = current_node["point"]

	if current_deck == target_point.deck and not is_same(current_key, TARGET_NODE_KEY):
		_append_route_edge(edges, actor, current_node, TARGET_NODE_KEY, nodes)

	for transition in action_points.transitions:
		if transition == null or transition.deck != current_deck:
			continue

		if is_same(transition, current_key):
			continue

		_append_route_edge(edges, actor, current_node, transition, nodes)

	if current_point is DeckTransitionPoint:
		var destination_point: DeckTransitionPoint = current_point.deck_connection

		if destination_point != null:
			_append_route_edge(edges, actor, current_node, destination_point, nodes)

	return edges


func _append_route_edge(
	edges: Array,
	actor,
	current_node: Dictionary,
	next_key,
	nodes: Dictionary
) -> void:

	if not nodes.has(next_key):
		return

	var next_node: Dictionary = nodes[next_key]
	var next_point: ShipActionPoint = next_node["point"]

	if next_point == null:
		return

	edges.append(
		{
			"to_key": next_key,
			"segment": {
				"target_point": next_point,
				"duration": MoveToPointAction.get_travel_duration_to_point(
					actor,
					next_point,
					current_node["position"],
					current_node["deck"]
				)
			}
		}
	)


func _reconstruct_route_plan(
	destination_key,
	previous_keys: Dictionary,
	previous_segments: Dictionary
) -> Dictionary:

	var key = destination_key
	var route_points: Array = []
	var total_duration := 0.0

	while not is_same(key, START_NODE_KEY):
		if not previous_keys.has(key) or not previous_segments.has(key):
			return _unreachable_route("broken route reconstruction")

		var segment: Dictionary = previous_segments[key]
		route_points.push_front(segment["target_point"])
		total_duration += segment["duration"]
		key = previous_keys[key]

	return {
		"reachable": true,
		"route_points": route_points,
		"total_duration": total_duration,
		"failure_reason": ""
	}


func _unreachable_route(reason := "") -> Dictionary:

	return {
		"reachable": false,
		"route_points": [],
		"total_duration": INF,
		"failure_reason": reason
	}


func _route_to_move_actions(route_plan: Dictionary) -> Array[ActionDefinition]:

	var actions: Array[ActionDefinition] = []

	actions.assign(
		route_plan["route_points"].map(
			func(point): return MoveToPointAction.new(point)
		)
	)

	return actions


func _pop_closest_unvisited(unvisited: Array, distances: Dictionary):
	var best_key = unvisited.reduce(
		func(best, key): return key if distances[key] < distances[best] else best
	)

	unvisited.erase(best_key)

	return best_key
