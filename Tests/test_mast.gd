extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_mast.gd
#
# A shot the roll said missed flies on over the ship. When it crosses the mast it lodges there
# and opens one hole, capped at grade 1 instead of the usual 5. Nothing else damages the mast,
# it lets no water in, and repair duty leaves it alone - "H" is its only repair route.
#
# The chance is forced to 1 throughout, so a failure here can never be a lucky roll.

const FRAME_LIMIT := 240
## The mast is 120px from where the balls start, ~15 physics frames at 500px/s. A ball that
## lasts longer than this flew past it.
const MAST_FRAMES := 25
const REPAIR_STEP := 0.1
const REPAIR_TIME_LIMIT := 120.0


func _run() -> void:

	Cannonball.mast_strike_chance = 1.0

	await _test_strike()
	await _test_geometry_gates_it()
	await _test_only_a_shot_over_the_ship()
	await _test_cap()
	await _test_repair()

	finish("test_mast")


# --- helpers ------------------------------------------------------------------------------


## Physics frames the ball lasted, which says where it died: the mast at 120px, the hull just
## short of it, or its own range limit.
func _frames_until_gone(ball: Cannonball) -> int:

	for frame in FRAME_LIMIT:
		if not is_instance_valid(ball):
			return frame

		await physics_frame

	check(false, "ball neither hit nor expired within %d frames" % FRAME_LIMIT)

	return FRAME_LIMIT


func _mast_grade(ship: Sloop) -> int:
	return ship.action_points.mast_holes.reduce(func(total, hole): return total + hole.grade, 0)


func _hull_grade(ship: Sloop) -> int:
	return ship.action_points.hull_holes.reduce(func(total, hole): return total + hole.grade, 0)


# --- the tests ----------------------------------------------------------------------------


## The whole point: a miss straight over the ship's centre opens one grade-1 mast hole and
## stops there, without counting as a hit.
func _test_strike() -> void:

	var ship = await spawn_frozen_ship()
	var shots_hit_before = Cannonball.shots_hit
	var frames = await _frames_until_gone(spawn_ball(ship, false))

	check(frames < MAST_FRAMES, "the ball flew on past the mast: %d frames" % frames)
	check(
		_mast_grade(ship) == ShipHealthSystem.MAST_HOLE_DAMAGE,
		"mast grade %d after one strike" % _mast_grade(ship)
	)
	check(_hull_grade(ship) == 0, "the mast strike holed the hull: %d" % _hull_grade(ship))
	check(Cannonball.shots_hit == shots_hit_before, "a mast strike counted as a hit")

	await despawn(ship)


## It is the mast that stops the ball, not the ship: the same miss down the length of the hull
## goes clean through.
func _test_geometry_gates_it() -> void:

	var ship = await spawn_frozen_ship()
	var frames = await _frames_until_gone(spawn_ball(ship, false, Vector2(60.0, -120.0)))

	check(frames >= MAST_FRAMES, "something stopped the ball short: %d frames" % frames)
	check(_mast_grade(ship) == 0, "a miss clear of the mast still holed it")

	await despawn(ship)


## Only a shot that actually passes over the ship can reach the mast.
func _test_only_a_shot_over_the_ship() -> void:

	var ship = await spawn_frozen_ship()

	# a shot that connects stops in the hull, well short of the mast
	await _frames_until_gone(spawn_ball(ship, true))

	check(_mast_grade(ship) == 0, "a hull hit holed the mast")
	check(
		_hull_grade(ship) == Cannonball.CANNONBALL_HOLE_DAMAGE,
		"the hull hit went nowhere: %d" % _hull_grade(ship)
	)

	# a miss that runs out of range before it gets there
	await _frames_until_gone(spawn_ball(ship, false, Vector2(0.0, -120.0), PI / 2.0, 60.0))

	check(_mast_grade(ship) == 0, "a ball that never reached the ship holed the mast")

	# and a miss that passes the ship entirely, never touching the hull
	await _frames_until_gone(spawn_ball(ship, false, Vector2(400.0, -120.0)))

	check(_mast_grade(ship) == 0, "a ball that missed the ship holed the mast")

	await despawn(ship)


## Three mast holes, each of them capped at 1, and the cap is the mast's alone.
func _test_cap() -> void:

	var ship = await spawn_frozen_ship()

	for shot in 4:
		await _frames_until_gone(spawn_ball(ship, false))

	check(
		_mast_grade(ship) == ship.action_points.mast_holes.size() * ShipHealthSystem.MAST_HOLE_DAMAGE,
		"mast grade %d after four strikes" % _mast_grade(ship)
	)

	var mast_hole: MastHole = ship.action_points.mast_holes.front()

	mast_hole.set_grade(ShipHolePoint.MAX_GRADE)

	check(mast_hole.grade == 1, "%s went past its cap: %d" % [mast_hole.name, mast_hole.grade])

	var hull_hole: ShipHolePoint = ship.action_points.hull_holes.front()

	hull_hole.set_grade(ShipHolePoint.MAX_GRADE)

	check(hull_hole.grade == ShipHolePoint.MAX_GRADE, "the cap leaked onto the hull holes")

	await despawn(ship)


## Repair duty walks past mast damage; "H" is what clears it.
func _test_repair() -> void:

	var ship: Sloop = load("res://Scenes/Sloop.tscn").instantiate()

	root.add_child(ship)

	await _settle()

	ship.process_mode = Node.PROCESS_MODE_DISABLED

	for hole in ship.action_points.holes:
		hole.set_grade(0)

	for hole in ship.action_points.mast_holes:
		hole.set_grade(ShipHealthSystem.MAST_HOLE_DAMAGE)

	var holed = _mast_grade(ship)
	var crewmate = ship.get_current_crewmate()

	ship.repair_duty_controller.assign_crewmate(crewmate)
	await _step_crew(ship, 5.0)

	check(_mast_grade(ship) == holed, "repair duty patched the mast on its own")
	check(ship.request(&"request_repair_mast"), "H queued no repair")

	await _step_crew(ship, REPAIR_TIME_LIMIT)

	check(_mast_grade(ship) == 0, "the mast was still holed: grade %d" % _mast_grade(ship))

	await despawn(ship)


## Runs the crew by hand, the way test_two_crew_repair does - the ship's own processing is off,
## so nothing else moves. Stops early once the mast is clear, there being nothing left to watch.
func _step_crew(ship: Sloop, seconds: float) -> void:

	var elapsed := 0.0

	while elapsed < seconds and _mast_grade(ship) > 0:
		for crewmate in ship.get_crewmates():
			crewmate.action_executor._physics_process(REPAIR_STEP)

		elapsed += REPAIR_STEP
