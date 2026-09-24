extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_mast_fall.gd
#
# With every mast hole open the mast topples in 5.93 s and bounces once for 0.91 s. A crewmate
# catches it and hauls it up at 10%/s; let go and it falls again from rest. Raised while still
# holed it is only propped: S or a ball brings it down, patching a hole makes it sound.

const DT := 1.0 / 60.0


func _run() -> void:

	ShipDebugLog.muted[&"mast"] = true

	_test_trigger()
	_test_fall_and_bounce()
	_test_half_fall_bounce()
	_test_raise_and_release()
	_test_sails_furled_by_the_top()
	_test_propped()
	await _test_ball_knocks_it_loose()

	finish("test_mast_fall")


# --- helpers ------------------------------------------------------------------------------


func _holes(open_count: int) -> Array[MastHole]:

	var holes: Array[MastHole] = []

	for i in 3:
		var hole := MastHole.new()
		hole.set_grade(1 if i < open_count else 0)
		holes.append(hole)

	return holes


func _free(holes: Array[MastHole]) -> void:

	for hole in holes:
		hole.free()


## Steps until [param done] says so, or 20 s pass; returns the seconds taken.
func _step_until(mast: MastSystem, done: Callable) -> float:

	var elapsed := 0.0

	while not done.call() and elapsed < 20.0:
		mast.physics_process(DT)
		elapsed += DT

	return elapsed


# --- the tests ----------------------------------------------------------------------------


## Only all three at their cap brings it down, and a hole mid-repair still counts.
func _test_trigger() -> void:

	var holes := _holes(2)
	var mast := MastSystem.new(holes)

	check(mast.state == MastSystem.State.STANDING, "two open holes felled the mast")
	check(not mast.sails_locked())

	holes[2].set_grade(1)

	check(mast.state == MastSystem.State.FALLING, "three open holes left the mast standing")
	check(mast.sails_locked())

	_free(holes)


func _test_fall_and_bounce() -> void:

	var holes := _holes(3)
	var mast := MastSystem.new(holes)

	var fall_time := _step_until(mast, func(): return mast.has_bounced)

	check(absf(fall_time - 5.93) < 0.05, "the fall took %.3f s" % fall_time)

	var lowest := 1.0
	var bounce_time := 0.0

	while mast.state == MastSystem.State.FALLING and bounce_time < 5.0:
		mast.physics_process(DT)
		bounce_time += DT
		lowest = minf(lowest, mast.angle / MastSystem.FALLEN)

	var apex := 1.0 - lowest

	check(mast.state == MastSystem.State.DOWN, "the mast never settled")
	check(absf(bounce_time - 0.91) < 0.03, "the bounce took %.3f s" % bounce_time)
	check(absf(apex - 0.0515) < 0.003, "the bounce peaked at %.2f%%" % (apex * 100.0))
	check(is_zero_approx(mast.upright_progress()))

	_free(holes)


## Let go at 45 degrees it lands slower, so it bounces lower and shorter.
func _test_half_fall_bounce() -> void:

	var holes := _holes(3)
	var mast := MastSystem.new(holes)

	mast.angle = PI / 4.0
	_step_until(mast, func(): return mast.has_bounced)

	var lowest := 1.0
	var bounce_time := 0.0

	while mast.state == MastSystem.State.FALLING and bounce_time < 5.0:
		mast.physics_process(DT)
		bounce_time += DT
		lowest = minf(lowest, mast.angle / MastSystem.FALLEN)

	var apex := 1.0 - lowest

	check(absf(bounce_time - 0.77) < 0.03, "the half-fall bounce took %.3f s" % bounce_time)
	check(absf(apex - 0.0366) < 0.003, "the half-fall bounce peaked at %.2f%%" % (apex * 100.0))

	_free(holes)


func _test_raise_and_release() -> void:

	var holes := _holes(3)
	var mast := MastSystem.new(holes)

	_step_until(mast, func(): return mast.state == MastSystem.State.DOWN)

	mast.begin_raising()

	for i in 60:
		mast.physics_process(DT)

	check(mast.state == MastSystem.State.RAISING)
	check(
		absf(mast.upright_progress() - 0.1) < 0.001,
		"a second's hauling raised it %.3f" % mast.upright_progress()
	)

	# let go: it falls again, from rest
	mast.cancel_raising()
	mast.physics_process(DT)

	check(mast.state == MastSystem.State.FALLING, "letting go did not drop it")
	check(
		mast.angular_velocity < MastSystem.TOPPLE_GRAVITY * DT * 1.001,
		"the fall carried speed over from the haul: %f" % mast.angular_velocity
	)

	# and a catch mid-bounce throws the bounce away
	_step_until(mast, func(): return mast.has_bounced)
	mast.begin_raising()

	check(mast.state == MastSystem.State.RAISING and mast.angular_velocity == 0.0)

	_free(holes)


## Caught high up, hauling takes under the 2 s the sails need on their own, so they hurry.
func _test_sails_furled_by_the_top() -> void:

	var holes := _holes(3)
	var mast := MastSystem.new(holes)

	mast.angle = 0.1 * MastSystem.FALLEN

	var sail_length := 100.0

	# same order as ShipMovementController: the mast, then the sails
	mast.begin_raising()

	while mast.state != MastSystem.State.PROPPED:
		mast.physics_process(DT)
		sail_length = mast.fold_sails(sail_length, DT)

	check(sail_length == 0.0, "the mast was up with the sails still at %.1f" % sail_length)

	_free(holes)


func _test_propped() -> void:

	var holes := _holes(3)
	var mast := MastSystem.new(holes)

	mast.begin_raising()
	_step_until(mast, func(): return mast.state == MastSystem.State.PROPPED)

	check(mast.state == MastSystem.State.PROPPED, "hauled up with every hole open, it is sound")
	check(mast.just_raised(), "R would not go to the mast right after the raise")

	var copy := mast.snapshot()
	for i in int(MastSystem.REPAIR_PROMPT_WINDOW / DT) + 1:
		copy.physics_process(DT)

	check(not copy.just_raised(), "R still went to the mast after the window")

	# S or a ball through the rigging both come through knock_loose
	check(mast.knock_loose(), "the propped mast was not knocked loose")
	check(mast.state == MastSystem.State.FALLING)
	check(not mast.knock_loose(), "a falling mast was knocked loose twice")

	# propped, then patched: sound again, and neither S nor a ball bothers it
	mast.angle = 0.0
	mast.state = MastSystem.State.PROPPED
	holes[0].set_grade(0)

	check(mast.state == MastSystem.State.STANDING, "a patched hole left it propped")
	check(not mast.knock_loose())

	mast.begin_raising()

	check(mast.state == MastSystem.State.STANDING, "S felled a mast with a patched hole")

	_free(holes)


## The real ship: a ball through the rigging of a propped, fully holed mast stops there and
## brings it down, though there is no hole left for it to open.
func _test_ball_knocks_it_loose() -> void:

	Cannonball.mast_strike_chance = 1.0

	var ship = await spawn_frozen_ship()

	for hole in ship.action_points.mast_holes:
		hole.set_grade(1)

	check(ship.mast_system.state == MastSystem.State.FALLING, "the ship's mast stood")

	ship.mast_system.angle = 0.0
	ship.mast_system.state = MastSystem.State.PROPPED

	var ball = spawn_ball(ship, false)

	for frame in 40:
		if not is_instance_valid(ball):
			break

		await physics_frame

	check(not is_instance_valid(ball), "the ball flew on through the rigging")
	check(ship.mast_system.state == MastSystem.State.FALLING, "the propped mast stayed up")

	await despawn(ship)
