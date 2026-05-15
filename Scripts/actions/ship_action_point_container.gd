extends Node2D
class_name ShipActionPointContainer

var points: Dictionary = {}
var stations: Array[StationPoint] = []
var holes: Array[ShipHolePoint] = []
var transitions: Array[DeckTransitionPoint] = []
var deck_connections: Dictionary = {}

func _ready() -> void:

	_register_points()


func _register_points() -> void:

	points.clear()
	stations.clear()
	holes.clear()
	transitions.clear()
	deck_connections.clear()

	for child in get_children():

		_register_recursive(
			child
		)

	_resolve_transition_points()


func _register_recursive(
	node: Node
) -> void:

	if node is ShipActionPoint:

		if points.has(node.name):

			push_error(
				"Duplicate action point: %s"
				% node.name
			)

			return


		points[node.name] = node

		if not DeckGraph.is_valid_deck(
			node.deck
		):
			push_error(
				"%s has invalid deck: %s"
				% [
					node.name,
					node.deck
				]
			)

		if node is StationPoint:
			stations.append(
				node
			)

		if node is ShipHolePoint:
			holes.append(
				node
			)

		if node is DeckTransitionPoint:
			transitions.append(
				node
			)


	for child in node.get_children():

		_register_recursive(
			child
		)


func _resolve_transition_points() -> void:

	var transition_groups: Dictionary = {}

	for transition in transitions:

		var group_key = _get_transition_group_key(
			transition
		)

		if not transition_groups.has(
			group_key
		):
			transition_groups[group_key] = []

		transition_groups[group_key].append(
			transition
		)


	for group_key in transition_groups.keys():

		var endpoints: Array = transition_groups[
			group_key
		]

		if endpoints.size() != 2:

			push_error(
				"Transition group %s must have exactly 2 endpoints, found %s."
				% [
					group_key,
					endpoints.size()
				]
			)

			continue


		var first: DeckTransitionPoint = endpoints[0]
		var second: DeckTransitionPoint = endpoints[1]

		if first.deck == second.deck:

			push_error(
				"Transition group %s connects %s to itself."
				% [
					group_key,
					DeckGraph.get_deck_name(
						first.deck
					)
				]
			)

			continue


		var transition_group = _get_transition_group(
			first
		)

		first.set_connected_point(
			second
		)

		second.set_connected_point(
			first
		)

		if transition_group == null:

			_add_deck_connection(
				first,
				second
			)

			_add_deck_connection(
				second,
				first
			)

			continue


		_add_group_connection(
			transition_group,
			first,
			second
		)

		if transition_group.bidirectional:

			_add_group_connection(
				transition_group,
				second,
				first,
				true
			)


func _get_transition_group_key(
	transition: DeckTransitionPoint
) -> String:

	var parent = transition.get_parent()

	if parent != self:
		return String(parent.get_path())

	return _get_name_pair_key(
		String(transition.name)
	)


func _get_transition_group(
	transition: DeckTransitionPoint
) -> DeckStairTransition:

	var parent = transition.get_parent()

	if parent is DeckStairTransition:
		return parent

	return null


func _get_name_pair_key(
	point_name: String
) -> String:

	if point_name.ends_with(
		"Top"
	):
		return point_name.trim_suffix(
			"Top"
		)

	if point_name.ends_with(
		"Bottom"
	):
		return point_name.trim_suffix(
			"Bottom"
		)

	return point_name


func _add_group_connection(
	transition_group: DeckStairTransition,
	first: DeckTransitionPoint,
	second: DeckTransitionPoint,
	reversed := false
) -> void:

	var from_deck = transition_group.from_deck
	var to_deck = transition_group.to_deck

	if reversed:
		from_deck = transition_group.to_deck
		to_deck = transition_group.from_deck

	var start_point = _get_endpoint_on_deck(
		first,
		second,
		from_deck
	)

	var destination_point = _get_endpoint_on_deck(
		first,
		second,
		to_deck
	)

	if (
		start_point == null
		or destination_point == null
	):
		push_error(
			"Transition group %s direction does not match its endpoint decks."
			% transition_group.name
		)

		return

	_add_deck_connection(
		start_point,
		destination_point
	)


func _get_endpoint_on_deck(
	first: DeckTransitionPoint,
	second: DeckTransitionPoint,
	deck: int
) -> DeckTransitionPoint:

	if first.deck == deck:
		return first

	if second.deck == deck:
		return second

	return null


func _add_deck_connection(
	start_point: DeckTransitionPoint,
	destination_point: DeckTransitionPoint
) -> void:

	if not deck_connections.has(
		start_point.deck
	):
		deck_connections[start_point.deck] = {}

	deck_connections[start_point.deck][destination_point.deck] = (
		start_point
	)


func get_transition_path(
	start_deck: int,
	target_deck: int
) -> Array[int]:

	return DeckGraph.get_transition_path(
		deck_connections,
		start_deck,
		target_deck
	)


func get_station(
	point_name: StringName
) -> StationPoint:

	var point = get_point(
		point_name
	)

	if point is StationPoint:
		return point

	push_error(
		"Action point is not a station: %s"
		% point_name
	)

	return null


func get_transition_point(
	from_deck: int,
	to_deck: int
) -> DeckTransitionPoint:

	var neighbors: Dictionary = deck_connections.get(
		from_deck,
		{}
	)

	var point: DeckTransitionPoint = neighbors.get(
		to_deck
	)

	if point != null:
		return point

	push_error(
		"No scene transition endpoint from %s to %s."
		% [
			DeckGraph.get_deck_name(from_deck),
			DeckGraph.get_deck_name(to_deck)
		]
	)

	return null


func get_point(
	point_name: StringName
) -> ShipActionPoint:

	if not points.has(point_name):

		push_error(
			"Action point not found: %s"
			% point_name
		)

		return null


	return points[point_name]


func has_point(
	point_name: StringName
) -> bool:

	return points.has(
		point_name
	)
