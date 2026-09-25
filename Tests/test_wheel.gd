extends "res://Tests/harness.gd"


func _run() -> void:

	await _test_registration()
	await _test_aimed_hits()
	await _test_stray_strike()
	await _test_repair_order()
	_test_turn_rate()
	_test_handles()

	finish("test_wheel")


## A shot at the wheel that comes straight down on it from 120px off; the frames it lasted.
func _shot_at_wheel(ship: Sloop, ammo: Ammunition) -> int:

	var wheel: WheelHole = ship.action_points.wheel_holes[0]
	var ball = spawn_ball(ship, true, wheel.global_position - ship.global_position + Vector2(0.0, -120.0))
	ball.ammo = ammo
	ball.aimed_part = wheel

	return await frames_until_gone(ball)


func _test_registration() -> void:

	var ship = await spawn_frozen_ship()
	var points: ShipActionPointContainer = ship.action_points

	check(points.wheel_holes.size() == 4, "wheel holes: %d" % points.wheel_holes.size())
	check(points.mast_holes.size() == 3, "mast holes: %d" % points.mast_holes.size())
	check(not points.hull_holes.any(func(hole): return hole is PartHole), "a wheel or mast hole floods")
	check(points.wheel_holes.all(func(hole): return hole.deck == points.get_station(&"Wheel").deck), "wheel holes off the wheel's deck")

	await despawn(ship)


func _test_aimed_hits() -> void:

	var ship = await spawn_frozen_ship()

	await _shot_at_wheel(ship, Ammunition.CANNONBALL)
	check(ship.movement_controller.wheel_damage() == 1, "a cannonball opened %d" % ship.movement_controller.wheel_damage())

	await _shot_at_wheel(ship, Ammunition.CHAINSHOT)
	check(ship.movement_controller.wheel_damage() == 4, "a chainshot after it left %d open" % ship.movement_controller.wheel_damage())

	check(await _shot_at_wheel(ship, Ammunition.CANNONBALL) < 40, "a full wheel let the ball through")
	check(grade_sum(ship.action_points.hull_holes + ship.action_points.mast_holes) == 0, "a shot at the wheel holed something else")

	await despawn(ship)


func _test_stray_strike() -> void:

	var chance = Cannonball.mast_strike_chance
	Cannonball.mast_strike_chance = 1.0

	var ship = await spawn_frozen_ship()
	var wheel: Vector2 = ship.action_points.wheel_holes[0].global_position - ship.global_position

	await frames_until_gone(spawn_ball(ship, false, wheel + Vector2(0.0, -120.0)))

	check(ship.movement_controller.wheel_damage() == 1, "a stray over the wheel opened %d" % ship.movement_controller.wheel_damage())
	check(grade_sum(ship.action_points.hull_holes + ship.action_points.mast_holes) == 0, "the stray holed something else")

	Cannonball.mast_strike_chance = chance
	await despawn(ship)


func _test_repair_order() -> void:

	var ship = await spawn_frozen_ship()
	var holes: Array[WheelHole] = ship.action_points.wheel_holes
	var executor: ActionExecutor = ship.current_crewmate.action_executor
	var repairing := func(): return executor.current_action != null and executor.current_action.definition is RepairHoleAction

	holes[0].set_grade(1)
	ship.crew_task_controller.request_repair_wheel()

	for step in 600:
		if repairing.call():
			break
		executor._physics_process(0.05)

	executor._physics_process(1.0)
	var underway := executor.current_action

	ship.crew_task_controller.request_repair_wheel()

	check(executor.current_action == underway and underway.elapsed >= 1.0, "ordering it again started the repair over")

	holes[1].set_grade(1)
	var queued := executor.queued_actions.filter(func(instance): return instance.definition is RepairHoleAction)

	check(executor.current_action == underway, "a new hole started the repair over")
	check(queued.size() == 1 and queued[0].definition.point == holes[1], "the new hole did not join the trip")
	check(underway in executor.plan_actions, "the progress ring lost the repair under way")

	await despawn(ship)


func _test_turn_rate() -> void:

	var whole := ShipMovementController.advance_wheel(0.0, 1.0, 1.0)
	var holed := ShipMovementController.advance_wheel(0.0, 1.0, 1.0, 4)

	check(is_equal_approx(holed, whole / 2.0), "four holes turn %s against %s" % [holed, whole])


func _test_handles() -> void:

	var indicator: TextureRect = load("res://Scripts/wheel_indicator.gd").new()
	root.add_child(indicator)

	var holes: Array[WheelHole] = []

	for i in 4:
		holes.append(WheelHole.new())
		holes[i].grade = 1

	indicator.update_handles(holes)
	var taken: Array = indicator._handles.values()

	check(taken.size() == 4 and taken.all(func(i): return taken.count(i) == 1), "handles taken: %s" % [taken])

	var patched_handle = indicator._handles[holes[0]]
	holes[0].grade = 0
	indicator.update_handles(holes)

	check(patched_handle not in indicator._handles.values(), "a patched hole kept its handle off")
	check(indicator._handles.size() == 3, "handles off after a patch: %d" % indicator._handles.size())

	for hole in holes:
		hole.free()

	indicator.free()
