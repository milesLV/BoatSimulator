extends Sloop

var target: PlayerShip = null

func _control() -> bool:

	if target == null:
		target = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if target == null:
		return false

	set_movement_input(clampf(get_angle_to(target.global_position), -1.0, 1.0), 0.0, 0.0)

	return true
