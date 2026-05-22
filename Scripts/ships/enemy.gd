extends Sloop

var target: PlayerShip = null

func _physics_process(delta):

	if target == null:
		target = _get_player_target()

	if target == null:
		return

	var to_target = (target.global_position - global_position).normalized()
	var forward = Vector2.RIGHT.rotated(rotation)

	var angle = forward.angle_to(to_target)

	turn_input = clamp(angle, -1.0, 1.0)
	#sail_input = 1.0

	_process_movement(delta)
	update_active_cannon()


func _get_player_target() -> PlayerShip:

	var game_map = get_tree().current_scene

	if (
		game_map == null
		or not game_map.has_method(
			"get_player_ship"
		)
	):
		return null

	return game_map.get_player_ship()
