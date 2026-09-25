class_name ShipCannonDirector
extends RefCounted

const SIDE_TIE_EPSILON := 0.001

var ship: Node2D
var cannons: Array = []
var target_ship: Node = null
var active_broadside := -1


func _init(new_ship: Node2D, new_cannons: Array) -> void:
	ship = new_ship
	cannons = new_cannons


func refresh_targets(ships: Array) -> void:

	# pop_front is null on an empty array, where front() errors
	target_ship = ships.filter(func(candidate): return candidate != ship and not candidate.is_sunk()).pop_front()


func update_active_cannon(tracking_enabled: bool) -> void:

	if get_target_ship() == null:
		clear_active_cannons()
		return

	var port_closest = _get_closest_distance(Cannon.Side.PORT)
	var starboard_closest = _get_closest_distance(Cannon.Side.STARBOARD)

	if port_closest == INF and starboard_closest == INF:
		active_broadside = -1
	elif abs(port_closest - starboard_closest) <= SIDE_TIE_EPSILON:
		if active_broadside == -1:
			active_broadside = Cannon.Side.PORT
	elif port_closest < starboard_closest:
		active_broadside = Cannon.Side.PORT
	else:
		active_broadside = Cannon.Side.STARBOARD

	for cannon in cannons:
		cannon.tracking_target = target_ship if tracking_enabled and cannon.broadside == active_broadside else null


## Distance from the target to the nearest cannon on [param side], INF when it has none.
func _get_closest_distance(side: int) -> float:

	var distances = (
		cannons
			.filter(func(cannon): return cannon.broadside == side)
			.map(func(cannon): return cannon.global_position.distance_to(target_ship.global_position))
	)

	return distances.min() if not distances.is_empty() else INF


func clear_active_cannons() -> void:

	active_broadside = -1

	for cannon in cannons:
		cannon.tracking_target = null


func get_target_ship() -> Node:

	return target_ship if is_instance_valid(target_ship) and not target_ship.is_sunk() else null
