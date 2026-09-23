extends Node2D
class_name ShipActionPointContainer

var points: Dictionary = {}
var stations: Array[StationPoint] = []
var cannon_stations: Array[CannonStationPoint] = []
var holes: Array[ShipHolePoint] = []
## Holes that let water in, and the mast holes that do not. Everything automatic - flooding,
## gunnery, repair duty - works off hull_holes; the mast is damaged and repaired on its own.
var hull_holes: Array[ShipHolePoint] = []
var mast_holes: Array[ShipHolePoint] = []
var transitions: Array[DeckTransitionPoint] = []

func _ready() -> void:

	for child in get_children():
		_register_recursive(child)

	_resolve_transition_points()


func _register_recursive(node: Node) -> void:

	if node is ShipActionPoint:
		if points.has(node.name):
			push_error("Duplicate action point: %s" % node.name)
			return

		points[node.name] = node

		if node is StationPoint:
			stations.append(node)

		if node is CannonStationPoint:
			cannon_stations.append(node)

		if node is ShipHolePoint:
			holes.append(node)

			if DeckGraph.FLOODED_DECKS.has(node.deck):
				hull_holes.append(node)
			else:
				mast_holes.append(node)

		if node is DeckTransitionPoint:
			transitions.append(node)

	for child in node.get_children():
		_register_recursive(child)


func _resolve_transition_points() -> void:

	var transition_groups: Dictionary = {}

	for transition in transitions:
		transition.deck_connection = null
		transition_groups.get_or_add(_get_transition_group_key(transition), []).append(transition)

	for group_key in transition_groups.keys():
		var endpoints: Array = transition_groups[group_key]

		if endpoints.size() != 2:
			push_error(
				"Transition group %s must have exactly 2 endpoints, found %s."
				% [group_key, endpoints.size()]
			)
			continue

		var first: DeckTransitionPoint = endpoints[0]
		var second: DeckTransitionPoint = endpoints[1]

		if first.deck == second.deck:
			push_error(
				"Transition group %s connects %s to itself."
				% [group_key, DeckGraph.get_deck_name(first.deck)]
			)
			continue

		var transition_group = first.get_parent() as DeckStairTransition

		if transition_group == null:
			first.deck_connection = second
			second.deck_connection = first
			continue

		_add_group_connection(transition_group, first, second)

		if transition_group.bidirectional:
			_add_group_connection(transition_group, second, first, true)


func _get_transition_group_key(transition: DeckTransitionPoint) -> String:

	var parent = transition.get_parent()

	if parent != self:
		return String(parent.get_path())

	# trim_suffix leaves the name alone when the suffix is absent.
	return String(transition.name).trim_suffix("Top").trim_suffix("Bottom")


func _add_group_connection(
	transition_group: DeckStairTransition,
	first: DeckTransitionPoint,
	second: DeckTransitionPoint,
	reversed := false
) -> void:

	var from_deck = transition_group.to_deck if reversed else transition_group.from_deck
	var to_deck = transition_group.from_deck if reversed else transition_group.to_deck

	var start_point = _get_endpoint_on_deck(first, second, from_deck)

	var destination_point = _get_endpoint_on_deck(first, second, to_deck)

	if start_point == null or destination_point == null:
		push_error(
			"Transition group %s direction does not match its endpoint decks."
			% transition_group.name
		)

		return

	start_point.deck_connection = destination_point


func _get_endpoint_on_deck(
	first: DeckTransitionPoint,
	second: DeckTransitionPoint,
	deck: int
) -> DeckTransitionPoint:

	return first if first.deck == deck else (second if second.deck == deck else null)


func get_station(point_name: StringName) -> StationPoint:

	var point = get_point(point_name)

	if point is StationPoint:
		return point

	push_error("Action point is not a station: %s" % point_name)

	return null


func get_closest_hole(from_position: Vector2) -> ShipHolePoint:

	# reduce seeds the accumulator with the first hole, so closest is never null.
	return hull_holes.reduce(func(closest, hole): return (
		hole
		if hole.global_position.distance_to(from_position)
		< closest.global_position.distance_to(from_position)
		else closest
	))


func get_point(point_name: StringName) -> ShipActionPoint:

	if not points.has(point_name):
		push_error("Action point not found: %s" % point_name)
		return null

	return points[point_name]


func has_point(point_name: StringName) -> bool:

	return points.has(point_name)
