extends SceneTree

# Shared boot for the headless suites: `godot --headless --script Tests/test_x.gd`
# instances the script as the SceneTree, so _run has to be deferred past _init.


func _init() -> void:

	call_deferred("_run")


## Lets queue_free, _ready and other deferred work land before assertions.
func _settle() -> void:

	for i in 4:
		await process_frame


func _run() -> void:

	pass


## assert() only logs headless, so a failed one would leave the suite reporting success.
## Count instead, and let the exit code carry the verdict. push_error prints the file and
## line, so [param message] is only worth passing to carry a runtime value.
var failure_count := 0


func check(condition: bool, message := "check failed") -> void:

	if condition:
		return

	failure_count += 1
	push_error("FAILED: %s" % message)


func finish(label: String) -> void:

	# push_error already printed each failure, with the line it happened on
	print("%s: ok" % label if failure_count == 0 else "%s: %d FAILED" % [label, failure_count])

	quit(failure_count)


func despawn(node: Node) -> void:

	node.queue_free()

	await _settle()


## A whole hull that holds still. HoleStarb2 ships at grade 5, so the grades are reset too.
## The crew have the sails set and the helm over within a couple of frames otherwise;
## physics processing off rather than process_mode DISABLED, which pulls the body out of the
## physics space and stops both move_and_slide and collisions.
func spawn_frozen_ship(at := Vector2.ZERO) -> Sloop:

	var ship: Sloop = load("res://Scenes/Sloop.tscn").instantiate()

	root.add_child(ship)

	await _settle()

	ship.set_physics_process(false)

	for crewmate in ship.get_crewmates():
		crewmate.action_executor.cancel_plan()
		crewmate.action_executor.set_physics_process(false)

	ship.global_position = at
	ship.rotation = 0.0
	ship.velocity = Vector2.ZERO
	ship.movement_controller.current_velocity = 0.0
	ship.movement_controller.current_angular_velocity = 0.0

	for hole in ship.action_points.holes:
		hole.set_grade(0)

	return ship


## A cannonball placed by hand: [param from] the ship it is aimed at, flying along
## [param heading]. By default it sits below the hull and comes straight up through it.
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
