extends "res://Tests/harness.gd"

# Ships keep processing so their collision stays live for the ball's Area2D.

const SAMPLES := 300
const FREQUENCY_TOLERANCE := 0.10 # ~4 standard errors at n = 300


func _run() -> void:


	await _test_miss_passes_through()
	await _test_impact_decides_the_hole()
	await _test_a_capped_hole_absorbs_nothing()
	await _test_far_side_hole_is_not_graded()
	await _test_the_shoulder_is_not_the_stem()
	await _test_observed_frequency()


	finish("test_accuracy_gate")


func _test_miss_passes_through() -> void:

	var ship = await spawn_frozen_ship()

	# this shot crosses the mast; mast strikes are test_mast's concern
	var mast_chance = Cannonball.mast_strike_chance
	Cannonball.mast_strike_chance = 0.0

	var ball = spawn_ball(ship, false)
	var before = Cannonball.shots_hit

	await frames_until_gone(ball)

	Cannonball.mast_strike_chance = mast_chance

	check(grade_sum(ship.action_points.holes) == 0)
	check(Cannonball.shots_hit == before)

	await despawn(ship)


func _test_impact_decides_the_hole() -> void:

	var ship = await spawn_frozen_ship()
	var far_end: ShipHolePoint = ship.action_points.get_point(&"HolePort1")

	# the ball comes in amidships
	var struck = ship.action_points.get_closest_hole(ship.global_position + Vector2(0.0, -52.0))

	check(struck != far_end, "the test aimed at the hole it means to rule out")

	await frames_until_gone(spawn_ball(ship, true))

	check(
		struck.grade == Ammunition.CANNONBALL.hole_damage,
		"%s took %d" % [struck.name, struck.grade]
	)
	check(far_end.grade == 0, "a hole the far end of the hull took the damage")
	check(grade_sum(ship.action_points.holes) == Ammunition.CANNONBALL.hole_damage)

	await despawn(ship)


func _test_a_capped_hole_absorbs_nothing() -> void:

	var ship = await spawn_frozen_ship()

	await frames_until_gone(spawn_ball(ship, true))

	var struck = ship.action_points.hull_holes.filter(func(hole): return hole.grade > 0).front()

	struck.set_grade(ShipHolePoint.MAX_GRADE)

	var before = grade_sum(ship.action_points.holes)

	await frames_until_gone(spawn_ball(ship, true))

	check(grade_sum(ship.action_points.holes) == before, "the shot spilled past %s" % struck.name)

	await despawn(ship)


## Regression: the target can turn mid-flight, so the aimed hole may end up on the far side.
func _test_far_side_hole_is_not_graded() -> void:

	var ship = await spawn_frozen_ship()

	# the ball comes in from -y, so a starboard hole is on the far side of the hull
	var far_side: ShipHolePoint = ship.action_points.get_point(&"HoleStarb1")

	check(ship.to_local(far_side.global_position).y > 0.0, "HoleStarb1 is not on the far side")

	var ball = spawn_ball(ship, true)

	await frames_until_gone(ball)

	check(far_side.grade == 0, "the far-side hole took the damage: grade %d" % far_side.grade)
	check(
		grade_sum(ship.action_points.holes) == Ammunition.CANNONBALL.hole_damage,
		"the hit went nowhere: total grade %d" % grade_sum(ship.action_points.holes)
	)

	for hole in ship.action_points.holes:
		check(
			hole.grade == 0 or ship.to_local(hole.global_position).y < 0.0,
			"%s took the damage on the far side" % hole.name
		)

	await despawn(ship)


## Regression: HoleBow sits 69px back in the stem, so nearest-node lookup stole shoulder hits.
func _test_the_shoulder_is_not_the_stem() -> void:

	var ship = await spawn_frozen_ship()

	await frames_until_gone(spawn_ball(ship, true, Vector2(300.0, 20.0), PI))

	check(ship.action_points.get_point(&"HoleStarb9").grade > 0, "the shoulder took nothing")
	check(ship.action_points.get_point(&"HoleBow").grade == 0, "the stem took the shoulder's hit")

	await despawn(ship)

	for offset in [0.0, 6.0, -6.0]:
		ship = await spawn_frozen_ship()

		await frames_until_gone(spawn_ball(ship, true, Vector2(300.0, offset), PI))

		check(
			ship.action_points.get_point(&"HoleBow").grade > 0,
			"the bow hole took nothing from a shot %.0f off the centreline" % offset
		)
		check(
			ship.action_points.get_point(&"HoleStarb9").grade == 0
			and ship.action_points.get_point(&"HolePort8").grade == 0,
			"a shoulder took the bow's hit from %.0f off the centreline" % offset
		)

		await despawn(ship)


func _test_observed_frequency() -> void:

	seed(20260830)

	var shooter = await spawn_frozen_ship()
	var target = await spawn_frozen_ship(Vector2(0.0, 1100.0))

	target.velocity = Vector2(300.0, 0.0)

	var cannon: Cannon = shooter.cannons.filter(
		func(candidate): return candidate.broadside == Cannon.Side.STARBOARD
	).front()

	var expected = CannonAccuracy.for_shot(cannon, shooter, target)

	# a middling chance, so the count can tell the model from a constant
	check(expected > 0.1 and expected < 0.9)

	var hits := 0

	for i in SAMPLES:
		cannon.loaded = true
		cannon.hold_fire = false
		cannon.current_target = target
		cannon.last_direction_aimed = Vector2.RIGHT.rotated(cannon.sprite.global_rotation)

		check(cannon.fire(), "cannon refused to fire on sample %d" % i)

		var ball = cannon.cannon_mouth.get_child(cannon.cannon_mouth.get_child_count() - 1)

		if ball.will_hit:
			hits += 1

		ball.free()

	var observed = float(hits) / SAMPLES

	print("gate: expected %f, observed %f over %d shots" % [expected, observed, SAMPLES])

	check(absf(observed - expected) < FREQUENCY_TOLERANCE)

	await despawn(shooter)
	await despawn(target)
