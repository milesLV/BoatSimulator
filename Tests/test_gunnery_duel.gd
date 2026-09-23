extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_gunnery_duel.gd
#
# The whole loop on the real map: targeting, hole picking, the gate, the crew cycling
# reload and fire. Assertions are deliberately loose - this is here to catch crashes and the
# failure where every cannon holds fire forever, not to pin down fine behaviour.

const FRAME_LIMIT := 3600 # ~60 seconds at 60 Hz
const SHOTS_WANTED := 6


func _run() -> void:

	seed(20260830)


	# change_scene_to_file, not add_child: the map root *is* the ship registry, and ships look
	# it up as current_scene while they are readying. Parent them in by hand and they ready
	# before current_scene is set, never register, and never find a target.
	change_scene_to_file("res://Scenes/game_map.tscn")

	await _settle()

	var map = current_scene
	var player: Sloop = map.get_node("Player")
	var enemy: Sloop = map.get_node("Enemy")

	# the map lays the two out bow to bow with no sail set, so neither can ever bear. Put them
	# in parallel columns half a broadside apart and let them get on with it.
	enemy.rotation = player.rotation
	enemy.global_position = player.global_position + Vector2(500.0, 0.0)

	player.request(&"request_current_cannon_duty")
	enemy.request(&"request_current_cannon_duty")

	var start_fired = Cannonball.shots_fired
	var frames := 0

	while frames < FRAME_LIMIT and Cannonball.shots_fired - start_fired < SHOTS_WANTED:
		await process_frame
		frames += 1

		if player.is_sunk() or enemy.is_sunk():
			break

	var fired = Cannonball.shots_fired - start_fired

	print("duel: %d shots in %d frames, player water %f, enemy water %f" % [
		fired,
		frames,
		player.health_system.water_level,
		enemy.health_system.water_level,
	])

	check(is_instance_valid(player) and is_instance_valid(enemy))
	check(fired > 0) # somebody has to actually pull a trigger

	await despawn(map)


	finish("test_gunnery_duel")
