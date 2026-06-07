class_name ShipCannonDirector
extends RefCounted

const SIDE_TIE_EPSILON := 0.001

var ship: Node2D
var cannons: Array = []
var target_ship: Node = null
var active_broadside := -1


func _init(
	new_ship: Node2D,
	new_cannons: Array
) -> void:

	ship = new_ship
	cannons = new_cannons


func refresh_targets(ships: Array) -> void:

	target_ship = null

	for candidate in ships:

		if candidate != ship:
			target_ship = candidate
			return


func update_active_cannon(tracking_enabled: bool) -> void:

	if (
		target_ship == null
		or not is_instance_valid(target_ship)
	):
		clear_active_cannons()
		return

	var port_closest := INF
	var starboard_closest := INF

	for cannon in cannons:

		var dist = cannon.global_position.distance_to(target_ship.global_position)

		match cannon.broadside:
			CannonSide.Value.PORT:
				port_closest = min(
					port_closest,
					dist
				)

			CannonSide.Value.STARBOARD:
				starboard_closest = min(
					starboard_closest,
					dist
				)

	var chosen_broadside := active_broadside

	if (
		port_closest == INF
		and starboard_closest == INF
	):
		chosen_broadside = -1
	elif abs(port_closest - starboard_closest) <= SIDE_TIE_EPSILON:
		if chosen_broadside == -1:
			chosen_broadside = CannonSide.Value.PORT
	elif port_closest < starboard_closest:
		chosen_broadside = CannonSide.Value.PORT
	else:
		chosen_broadside = CannonSide.Value.STARBOARD

	active_broadside = chosen_broadside

	for cannon in cannons:

		var is_active_broadside = (
			tracking_enabled
			and active_broadside != -1
			and cannon.broadside == active_broadside
		)

		cannon.set_tracking_enabled(is_active_broadside)

		if is_active_broadside:
			cannon.set_tracking_target(target_ship)
		else:
			cannon.set_tracking_target(null)


func clear_active_cannons() -> void:

	active_broadside = -1

	for cannon in cannons:

		cannon.set_tracking_enabled(false)
		cannon.set_tracking_target(null)


func get_active_broadside() -> int:

	return active_broadside


func get_target_ship() -> Node:

	if (
		target_ship == null
		or not is_instance_valid(target_ship)
	):
		return null

	return target_ship
