extends "res://Tests/harness.gd"


func _run() -> void:

	for scene_path in ["res://Scenes/enemy.tscn", "res://Scenes/player.tscn"]:
		var ship = load(scene_path).instantiate()
		root.add_child(ship)
		await process_frame
		ship.process_mode = Node.PROCESS_MODE_DISABLED

		ship.on_sunk()

		for cannon in ship.cannons:
			assert(not cannon.range_area.visible)

		ship.queue_free()
		await process_frame

	quit()
