extends "res://Tests/harness.gd"

## Balls reach the mast in ~15 frames; one that lasts longer flew past it.
const MAST_FRAMES := 25
const REPAIR_STEP := 0.1
const REPAIR_TIME_LIMIT := 120.0


func _run() -> void:

	Cannonball.mast_strike_chance = 1.0

	await _test_strike()
	await _test_geometry_gates_it()
	await _test_only_a_shot_over_the_ship()
	await _test_aimed_at_the_mast()
	await _test_cap()
	await _test_repair()

	finish("test_mast")


func _test_strike() -> void:

	var ship = await spawn_frozen_ship()
	var shots_hit_before = Cannonball.shots_hit
	var frames = await frames_until_gone(spawn_ball(ship, false))

	check(frames < MAST_FRAMES, "the ball flew on past the mast: %d frames" % frames)
	check(
		grade_sum(ship.action_points.mast_holes) == ShipHealthSystem.MAST_HOLE_DAMAGE,
		"mast grade %d after one strike" % grade_sum(ship.action_points.mast_holes)
	)
	check(grade_sum(ship.action_points.hull_holes) == 0, "the mast strike holed the hull: %d" % grade_sum(ship.action_points.hull_holes))
	check(Cannonball.shots_hit == shots_hit_before, "a mast strike counted as a hit")

	await despawn(ship)


func _test_geometry_gates_it() -> void:

	var ship = await spawn_frozen_ship()
	var frames = await frames_until_gone(spawn_ball(ship, false, Vector2(60.0, -120.0)))

	check(frames >= MAST_FRAMES, "something stopped the ball short: %d frames" % frames)
	check(grade_sum(ship.action_points.mast_holes) == 0, "a miss clear of the mast still holed it")

	await despawn(ship)


func _test_aimed_at_the_mast() -> void:

	Cannonball.mast_strike_chance = 0.0

	var ship = await spawn_frozen_ship()
	var ball = spawn_ball(ship, true)
	ball.aimed_part = ship.action_points.mast_holes[0]

	await frames_until_gone(ball)

	check(grade_sum(ship.action_points.mast_holes) == ShipHealthSystem.MAST_HOLE_DAMAGE, "the aimed shot missed the mast")
	check(grade_sum(ship.action_points.hull_holes) == 0, "the aimed shot holed the hull")

	Cannonball.mast_strike_chance = 1.0
	await despawn(ship)


func _test_only_a_shot_over_the_ship() -> void:

	var ship = await spawn_frozen_ship()

	await frames_until_gone(spawn_ball(ship, true))

	check(grade_sum(ship.action_points.mast_holes) == 0, "a hull hit holed the mast")
	check(
		grade_sum(ship.action_points.hull_holes) == Ammunition.CANNONBALL.hole_damage,
		"the hull hit went nowhere: %d" % grade_sum(ship.action_points.hull_holes)
	)

	await frames_until_gone(spawn_ball(ship, false, Vector2(0.0, -120.0), PI / 2.0, 60.0))

	check(grade_sum(ship.action_points.mast_holes) == 0, "a ball that never reached the ship holed the mast")

	await frames_until_gone(spawn_ball(ship, false, Vector2(400.0, -120.0)))

	check(grade_sum(ship.action_points.mast_holes) == 0, "a ball that missed the ship holed the mast")

	await despawn(ship)


func _test_cap() -> void:

	var ship = await spawn_frozen_ship()

	for shot in 4:
		await frames_until_gone(spawn_ball(ship, false))

	check(
		grade_sum(ship.action_points.mast_holes) == ship.action_points.mast_holes.size() * ShipHealthSystem.MAST_HOLE_DAMAGE,
		"mast grade %d after four strikes" % grade_sum(ship.action_points.mast_holes)
	)

	var mast_hole: MastHole = ship.action_points.mast_holes.front()

	mast_hole.set_grade(ShipHolePoint.MAX_GRADE)

	check(mast_hole.grade == 1, "%s went past its cap: %d" % [mast_hole.name, mast_hole.grade])

	var hull_hole: ShipHolePoint = ship.action_points.hull_holes.front()

	hull_hole.set_grade(ShipHolePoint.MAX_GRADE)

	check(hull_hole.grade == ShipHolePoint.MAX_GRADE, "the cap leaked onto the hull holes")

	await despawn(ship)


func _test_repair() -> void:

	var ship: Sloop = await spawn_ship()
	ship.process_mode = Node.PROCESS_MODE_DISABLED

	for hole in ship.action_points.holes:
		hole.set_grade(0)

	for hole in ship.action_points.mast_holes:
		hole.set_grade(ShipHealthSystem.MAST_HOLE_DAMAGE)

	var holed = grade_sum(ship.action_points.mast_holes)
	var crewmate = ship.current_crewmate

	ship.repair_duty_controller.assign_crewmate(crewmate)
	await _step_crew(ship, 5.0)

	check(grade_sum(ship.action_points.mast_holes) == holed, "repair duty patched the mast on its own")
	check(ship.request(&"request_repair_mast"), "H queued no repair")

	await _step_crew(ship, REPAIR_TIME_LIMIT)

	check(grade_sum(ship.action_points.mast_holes) == 0, "the mast was still holed: grade %d" % grade_sum(ship.action_points.mast_holes))

	await despawn(ship)


## The ship's own processing is off, so step the crew by hand.
func _step_crew(ship: Sloop, seconds: float) -> void:

	var elapsed := 0.0

	while elapsed < seconds and grade_sum(ship.action_points.mast_holes) > 0:
		for crewmate in ship.crewmates:
			crewmate.action_executor._physics_process(REPAIR_STEP)

		elapsed += REPAIR_STEP
