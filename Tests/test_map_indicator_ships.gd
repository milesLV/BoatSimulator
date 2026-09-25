extends "res://Tests/harness.gd"


func _run() -> void:

	# headless gives a 64x64 window, which would put every ship off screen
	root.size = Vector2i(1152, 648)
	assert(root.get_visible_rect().size == Vector2(1152, 648))

	change_scene_to_file("res://Scenes/game_map.tscn")
	await _settle()

	var map = current_scene
	var gui = map.get_node("GameGui")
	var camera: Camera2D = map.get_node("Camera2D")
	var player = map.get_player_ship()
	var enemy = map.ships.filter(func(ship): return ship != player)[0]

	assert(map.ships.size() == 2)
	assert(gui._indicators.size() == 2)

	for ship in map.ships:
		var idle = gui._indicators[ship]
		assert(not idle["medallion"].visible)
		assert(not idle["boat"].visible)
		assert(not idle["arrow"].visible)
		assert(idle["viewport"].render_target_update_mode == SubViewport.UPDATE_DISABLED)

	var masks := {}

	for ship in map.ships:
		var mask: int = gui._indicators[ship]["viewport"].canvas_cull_mask
		assert(not masks.has(mask))
		masks[mask] = true
		assert(ship.visibility_layer == mask)
		assert(ship.get_parent().visibility_layer & mask != 0)

		for cannon in ship.cannons:
			assert(cannon.visibility_layer == mask)
			assert(cannon.get_node("CannonRange").visibility_layer == 1)

	camera.is_following = false
	camera.global_position = Vector2(50_000.0, 50_000.0)
	await _settle()

	var rect := root.get_visible_rect()

	for ship in map.ships:
		var live = gui._indicators[ship]
		assert(live["medallion"].visible and live["boat"].visible and live["arrow"].visible)
		assert(live["viewport"].render_target_update_mode == SubViewport.UPDATE_ALWAYS)
		assert(rect.has_point(live["medallion"].position))
		assert(live["boat"].position == live["medallion"].position)
		var radius: float = (live["arrow"].position - live["medallion"].position).length()
		assert(is_equal_approx(radius, gui._arrow_offset.length()))
		assert(is_equal_approx(live["arrow"].modulate.a, 1.0))
		assert(live["camera"].global_position == ship.global_position)

	# the two ships start close together, so move the enemy off before looking

	enemy.global_position = Vector2(20_000.0, 20_000.0)
	camera.global_position = player.global_position
	await _settle()

	assert(not gui._indicators[player]["medallion"].visible)
	assert(gui._indicators[player]["viewport"].render_target_update_mode == SubViewport.UPDATE_DISABLED)
	assert(gui._indicators[enemy]["medallion"].visible)

	var orphaned_viewport = gui._indicators[enemy]["viewport"]
	var orphaned_medallion = gui._indicators[enemy]["medallion"]
	enemy.queue_free()
	await _settle()

	assert(map.ships.size() == 1)
	assert(gui._indicators.size() == 1)
	assert(gui._indicators.has(player))
	assert(not is_instance_valid(orphaned_viewport))
	assert(not is_instance_valid(orphaned_medallion))

	var measured: float = gui._hull_radius(player)
	assert(measured > 100.0 and measured < 200.0)  # sloop is ~151 units bow to stern
	assert(is_equal_approx(measured, gui._indicators[player]["radius"]))

	var shapeless := Node2D.new()
	root.add_child(shapeless)
	assert(is_equal_approx(gui._hull_radius(shapeless), gui.DEFAULT_HULL_RADIUS))

	print("map indicator ship checks passed")
	quit()
