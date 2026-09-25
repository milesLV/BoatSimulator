extends "res://Tests/harness.gd"


func _run() -> void:

	var ship: Sloop = load("res://Scenes/Sloop.tscn").instantiate()
	root.add_child(ship)
	await process_frame
	ship.process_mode = Node.PROCESS_MODE_DISABLED

	var actor = ship.current_crewmate
	var progress = load("res://Scenes/crewActionProgress.tscn").instantiate()
	assert(progress.get_node_or_null("Countdown") != null)
	assert(progress.get_displayed_crewmate(ship) == actor)
	progress.show_other_crewmate = true
	var other_actor = progress.get_displayed_crewmate(ship)
	assert(other_actor != null and other_actor != actor)
	ship.change_crewmate()
	assert(progress.get_displayed_crewmate(ship) == actor)
	ship.change_crewmate()
	progress.free()
	var vertical = load("res://Scenes/verticalProgress.tscn").instantiate()
	vertical.source = vertical.Source.MAST
	root.add_child(vertical)
	await process_frame
	vertical.set_progress(0.427)
	assert(vertical.get_node("Text/Label").text == "Mast")
	assert(vertical.get_node("Text/Percentage").text == "43%")
	vertical.queue_free()
	await process_frame

	actor.action_executor.cancel_plan()
	var actions = ship.action_planner.build_drop_anchor(actor)
	actor.action_executor.queue_actions(actions)

	var timing = ship.action_planner.route_planner.get_plan_timing(
		actor,
		actor.action_executor.plan_actions
	)
	assert(timing["durations"].size() == 2)
	assert(timing["total_duration"] > RigAnchorAction.RIG_DURATION)

	var remaining = timing["remaining"]
	actor.action_executor.current_action.elapsed = (
		actor.action_executor.current_action.duration / 2.0
	)
	timing = ship.action_planner.route_planner.get_plan_timing(
		actor,
		actor.action_executor.plan_actions
	)
	assert(timing["remaining"] < remaining)
	remaining = timing["remaining"]

	actor.action_executor._physics_process(
		actor.action_executor.current_action.get_remaining_time(actor)
	)
	timing = ship.action_planner.route_planner.get_plan_timing(
		actor,
		actor.action_executor.plan_actions
	)
	assert(timing["durations"].size() == 2)
	assert(timing["remaining"] < remaining)

	actor.action_executor.cancel_plan()
	assert(actor.action_executor.plan_actions.is_empty())

	ship.queue_free()
	await process_frame

	var game_map = load("res://Scenes/game_map.tscn").instantiate()
	root.add_child(game_map)
	current_scene = game_map
	await process_frame
	var player = game_map.get_node("Player")
	game_map.ships.append(player)
	var anchor_progress = game_map.get_node("GameGui/AnchorProgress")
	anchor_progress._process(0.0)
	assert(not anchor_progress.visible)

	player.anchor_system.start_dropping()
	player.anchor_system.physics_process(AnchorSystem.DROP_DURATION * 0.1)
	anchor_progress._process(0.0)
	assert(anchor_progress.visible)
	assert(anchor_progress.get_node("Text/Label").text == "Anchor")
	assert(anchor_progress.get_node("Text/Percentage").text == "90%")

	var health_gui = game_map.get_node("GameGui/HealthGui")
	assert(health_gui is Control)
	var water_polygon = health_gui.get_node("WaterPolygon")
	var health_image = health_gui.get_node("SloopHealthGui")
	assert(water_polygon.z_index > health_image.z_index)
	assert(water_polygon.position.x >= 0.0)
	assert(water_polygon.position.y >= 0.0)
	assert(water_polygon.min_y < water_polygon.max_y)
	for point in water_polygon.full_polygon:
		var local_point = water_polygon.position + point * water_polygon.scale
		assert(local_point.x >= 0.0)
		assert(local_point.y >= 0.0)
		assert(local_point.x <= health_gui.size.x)
		assert(local_point.y <= health_gui.size.y)
	player.health_system.water_level = 0.0
	water_polygon._process(0.0)
	assert(water_polygon.polygon.is_empty())
	player.health_system.water_level = ShipHealthSystem.MAX_WATER_LEVEL
	water_polygon._process(0.0)
	assert(water_polygon.polygon.size() == water_polygon.full_polygon.size())

	var wheel = game_map.get_node("GameGui/WheelIndicator")
	var wheel_base_rotation = wheel.base_rotation
	player.movement_controller.wheel_rotation = 0.0
	wheel._process(0.0)
	assert(wheel.tint_material.get_shader_parameter("tint") == Color.BLACK)
	assert(is_equal_approx(wheel.rotation, wheel_base_rotation))
	player.movement_controller.wheel_rotation = -ShipMovementController.MAX_WHEEL_TURN
	wheel._process(0.0)
	assert(wheel.tint_material.get_shader_parameter("tint") == Color(0.0, 1.0, 0.0))
	player.movement_controller.wheel_rotation = ShipMovementController.MAX_WHEEL_TURN
	wheel._process(0.0)
	assert(wheel.tint_material.get_shader_parameter("tint") == Color(1.0, 0.0, 0.0))
	player.movement_controller.wheel_rotation = ShipMovementController.MAX_WHEEL_TURN / 4.0
	wheel._process(0.0)
	assert(is_equal_approx(wheel.rotation, wheel_base_rotation + ShipMovementController.MAX_WHEEL_TURN / 4.0))
	player.movement_controller.wheel_rotation = ShipMovementController.MAX_WHEEL_TURN * 2.0
	wheel._process(0.0)
	assert(is_equal_approx(wrapf(wheel.rotation - wheel_base_rotation, -PI, PI), 0.0))

	game_map.queue_free()
	await process_frame
	quit()
