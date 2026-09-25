extends Node2D
class_name ShipActionPointContainer

var points: Dictionary = {}
var cannon_stations: Array[CannonStationPoint] = []
var holes: Array[ShipHolePoint] = []
## Holes that let water in, unlike the mast and wheel holes.
var hull_holes: Array[ShipHolePoint] = []
var mast_holes: Array[MastHole] = []
var wheel_holes: Array[WheelHole] = []
var transitions: Array[DeckTransitionPoint] = []

func _ready() -> void:

	_register_recursive(self)
	_connect_stairs()


func _register_recursive(node: Node) -> void:

	if node is ShipActionPoint:
		if points.has(node.name):
			push_error("Duplicate action point: %s" % node.name)
			return

		points[node.name] = node

		if node is CannonStationPoint:
			cannon_stations.append(node)

		if node is ShipHolePoint:
			holes.append(node)

			if node is WheelHole:
				wheel_holes.append(node)
			elif node is MastHole:
				mast_holes.append(node)
			else:
				hull_holes.append(node)

		if node is DeckTransitionPoint:
			transitions.append(node)

	for child in node.get_children():
		_register_recursive(child)


func _connect_stairs() -> void:

	for stair in get_children():
		if not stair is DeckStairTransition:
			continue

		var ends: Array = stair.get_children()

		if ends[0].deck != stair.from_deck:
			ends.reverse()

		ends[0].deck_connection = ends[1]

		if stair.bidirectional:
			ends[1].deck_connection = ends[0]


func get_station(point_name: StringName) -> StationPoint:

	var point = get_point(point_name)

	if point is StationPoint:
		return point

	push_error("Action point is not a station: %s" % point_name)

	return null


func get_closest_hole(from_position: Vector2) -> ShipHolePoint:

	# reduce seeds the accumulator with the first hole, so closest is never null
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
