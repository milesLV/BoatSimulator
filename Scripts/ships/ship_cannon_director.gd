class_name ShipCannonDirector
extends RefCounted

var ship: Node2D
var cannons: Array = []
var other_ships: Array = []
var target_ship: Node = null


func _init(
	new_ship: Node2D,
	new_cannons: Array
) -> void:

	ship = new_ship
	cannons = new_cannons


func refresh_targets(
	ships: Array
) -> void:

	other_ships.clear()

	for candidate in ships:

		if candidate != ship:
			other_ships.append(
				candidate
			)

	if other_ships.size() > 0:
		target_ship = other_ships[0]
	else:
		target_ship = null


func update_active_cannon() -> void:

	if (
		target_ship == null
		or not is_instance_valid(target_ship)
	):
		clear_active_cannons()
		return

	var closest_cannon = null
	var closest_dist = INF

	for cannon in cannons:

		var dist = cannon.global_position.distance_to(
			target_ship.global_position
		)

		if dist < closest_dist:
			closest_dist = dist
			closest_cannon = cannon

	for cannon in cannons:

		cannon.is_actively_tracking = (
			cannon == closest_cannon
		)

		if cannon.is_actively_tracking:
			cannon.target_global = target_ship
		else:
			cannon.target_global = null


func clear_active_cannons() -> void:

	for cannon in cannons:

		cannon.is_actively_tracking = false
		cannon.target_global = null
