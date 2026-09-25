class_name ShipRoutePlanner
extends RefCounted

const START_NODE_KEY := "__start"
const TARGET_NODE_KEY := "__target"

var action_points: ShipActionPointContainer


func _init(new_action_points: ShipActionPointContainer) -> void:
	action_points = new_action_points


## The route's points, ending at [param point]; empty when it cannot be reached.
func find_route(actor, point: ShipActionPoint, start_deck = null, start_position = null) -> Array:

	var nodes = _build_route_nodes(
		actor,
		MoveToPointAction.resolve_start_deck(actor, start_deck),
		MoveToPointAction.resolve_start_position(actor, start_position),
		point
	)
	var distances := {}
	var previous_keys := {}
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
			return _reconstruct_route_points(nodes, previous_keys)

		var current_node: Dictionary = nodes[current_key]

		for next_key in _get_neighbour_keys(current_key, current_node, point):
			if not unvisited.has(next_key):
				continue

			var next_distance = current_distance + MoveToPointAction.get_travel_duration_for_points(
				actor, [nodes[next_key]["point"]], current_node["position"], current_node["deck"]
			)

			if next_distance < distances[next_key]:
				distances[next_key] = next_distance
				previous_keys[next_key] = current_key

	ShipDebugLog.write(&"route", "No route from %s to %s." % [
		DeckGraph.get_deck_name(MoveToPointAction.resolve_start_deck(actor, start_deck)), point.name
	])

	return []


func estimate_total_action_duration(actor, actions: Array) -> float:

	var durations = estimate_action_durations(actor, actions)

	if durations.any(func(duration): return duration < 0.0):
		return INF

	return durations.reduce(func(a, b): return a + b, 0.0)


func estimate_time_until_bail_complete(actor, actions: Array) -> float:

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

	var durations: Array[float] = []
	var current_position = MoveToPointAction.resolve_start_position(actor, start_position)
	var current_deck = MoveToPointAction.resolve_start_deck(actor, start_deck)

	for action in actions:
		if action is MoveToPointAction:
			var travel = MoveToPointAction.get_travel_duration_for_points(actor, action.route_points, current_position, current_deck)
			durations.append(max(travel, MoveAndBailWaterAction.SCOOP_DURATION) if action is MoveAndBailWaterAction else travel)
			current_position = MoveToPointAction.get_route_positions_for_points(actor, action.route_points, current_position).back()
			current_deck = action.point.deck
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
		else:
			queued_definitions.append(instance.definition)

	if current != null:
		if current.duration < 0.0:
			return timing

		if current.duration > 0.0:
			timing["durations"].append(current.duration)
			timing["elapsed"] += min(current.elapsed, current.duration)

		if current.definition is MoveToPointAction:
			start_position = current.runtime_state[&"route_positions"].back()
			start_deck = current.definition.point.deck

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


## Transitions on this deck, the stair's far end when on one, and the target once on its deck.
func _get_neighbour_keys(current_key, current_node: Dictionary, target_point: ShipActionPoint) -> Array:

	var keys: Array = []
	keys.assign(action_points.transitions.filter(func(transition): return (
		transition.deck == current_node["deck"] and not is_same(transition, current_key)
	)))

	if current_node["deck"] == target_point.deck:
		keys.append(TARGET_NODE_KEY)

	if current_node["point"] is DeckTransitionPoint and current_node["point"].deck_connection != null:
		keys.append(current_node["point"].deck_connection)

	return keys


func _reconstruct_route_points(nodes: Dictionary, previous_keys: Dictionary) -> Array:

	var route_points: Array = []
	var key = TARGET_NODE_KEY

	while not is_same(key, START_NODE_KEY):
		route_points.push_front(nodes[key]["point"])
		key = previous_keys[key]

	return route_points


func _pop_closest_unvisited(unvisited: Array, distances: Dictionary):
	var best_key = unvisited.reduce(
		func(best, key): return key if distances[key] < distances[best] else best
	)

	unvisited.erase(best_key)

	return best_key
