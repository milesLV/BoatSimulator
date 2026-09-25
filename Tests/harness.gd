extends SceneTree

# `godot --headless --script Tests/test_x.gd` makes the script the SceneTree, so _run waits past _init.


func _init() -> void:

	call_deferred("_run")


func _settle() -> void:

	for i in 4:
		await process_frame


func _run() -> void:

	pass


## assert() only logs when headless, so failures are counted into the exit code instead.
var failure_count := 0


func check(condition: bool, message := "check failed") -> void:

	if condition:
		return

	failure_count += 1
	push_error("FAILED: %s" % message)


func finish(label: String) -> void:

	print("%s: ok" % label if failure_count == 0 else "%s: %d FAILED" % [label, failure_count])

	quit(failure_count)


func grade_sum(holes: Array) -> int:

	return holes.reduce(func(total, hole): return total + hole.grade, 0)


func despawn(node: Node) -> void:

	node.queue_free()

	await _settle()


func spawn_ship() -> Sloop:

	var ship: Sloop = load("res://Scenes/Sloop.tscn").instantiate()
	root.add_child(ship)
	await _settle()

	return ship


## Physics off rather than PROCESS_MODE_DISABLED, which would pull the body out of the physics space.
func spawn_frozen_ship(at := Vector2.ZERO) -> Sloop:

	var ship: Sloop = await spawn_ship()
	ship.set_physics_process(false)

	for crewmate in ship.crewmates:
		crewmate.action_executor.cancel_plan()
		crewmate.action_executor.set_physics_process(false)

	ship.global_position = at
	ship.rotation = 0.0
	ship.velocity = Vector2.ZERO
	ship.movement_controller.current_velocity = 0.0
	ship.movement_controller.current_angular_velocity = 0.0

	# HoleStarb2 ships at grade 5
	for hole in ship.action_points.holes:
		hole.set_grade(0)

	return ship


func frames_until_gone(ball: Node, limit := 240) -> int:

	for frame in limit:
		if not is_instance_valid(ball):
			return frame

		await physics_frame

	check(false, "ball neither hit nor expired within %d frames" % limit)

	return limit


## By default the ball starts below the hull and flies straight up through it.
func spawn_ball(
	ship: Sloop,
	will_hit: bool,
	from := Vector2(0.0, -120.0),
	heading := PI / 2.0,
	range_limit := 400.0
) -> Cannonball:

	var ball: Cannonball = load("res://Scenes/cannonball.tscn").instantiate()

	root.add_child(ball)

	ball.global_position = ship.global_position + from
	ball.global_rotation = heading
	ball.max_range = range_limit
	ball.owner_node = null
	ball.will_hit = will_hit

	return ball
