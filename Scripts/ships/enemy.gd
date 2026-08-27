extends Sloop

var target: PlayerShip = null

func _control(_delta: float) -> bool:

	if target == null:
		target = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if target == null:
		return false

	var to_target = (target.global_position - global_position).normalized()
	var forward = Vector2.RIGHT.rotated(rotation)

	var angle = forward.angle_to(to_target)

	set_movement_input(clamp(angle, -1.0, 1.0), 0.0, 0.0)

	return true
