extends "res://Tests/harness.gd"

# Loose on purpose: catches crashes and cannons that hold fire forever.

const FRAME_LIMIT := 3600
const SHOTS_WANTED := 6


func _run() -> void:

	seed(20260830)


	# not add_child: ships register with current_scene while readying, so the map must be it
	change_scene_to_file("res://Scenes/game_map.tscn")

	await _settle()

	var map = current_scene
	var player: Sloop = map.get_node("Player")
	var enemy: Sloop = map.get_node("Enemy")

	# the map lays them out bow to bow, where neither can bear
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
	check(fired > 0)

	await despawn(map)


	finish("test_gunnery_duel")
