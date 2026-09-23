extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_cannon_accuracy.gd
#
# The probability model itself: does it move the right way with each condition, does it stay
# a probability everywhere, and does for_shot read the conditions off the right things.

const MAX_RANGE := 1200.0


func _run() -> void:

	_test_monotonic()
	_test_bounds()
	_test_anchors()
	await _test_for_shot()
	_test_percent_format()

	finish("test_cannon_accuracy")


## Every condition the design called out has to push the number the right way.
func _test_monotonic() -> void:

	# further is harder
	var previous := 1.1

	for step in 12:
		var chance = CannonAccuracy.hit_chance(100.0 + step * 100.0, MAX_RANGE, 0.0, 150.0)
		check(chance < previous)
		previous = chance

	# hauling your own helm over is harder
	previous = 1.1

	for step in 8:
		var chance = CannonAccuracy.hit_chance(600.0, MAX_RANGE, step * 0.2, 0.0)
		check(chance <= previous)
		previous = chance

	# a target crossing faster is harder
	previous = 1.1

	for step in 8:
		var chance = CannonAccuracy.hit_chance(600.0, MAX_RANGE, 0.0, step * 40.0)
		check(chance <= previous)
		previous = chance


## It is a probability for every input, including the degenerate ones. max_range 0 divides by
## zero on the way in, so pin down what that does rather than meeting it in a playtest.
func _test_bounds() -> void:

	for distance in [0.0, 1.0, 100.0, 700.0, 5000.0]:
		for max_range in [0.0, 1.0, MAX_RANGE]:
			for turn in [0.0, 1.5, 50.0]:
				for speed in [0.0, 300.0, 9000.0]:
					var chance = CannonAccuracy.hit_chance(distance, max_range, turn, speed)

					check(not is_nan(chance))
					check(chance >= 0.0 and chance <= 1.0)

	# no range to speak of: everything past the hull is a guess, not a certainty
	check(CannonAccuracy.hit_chance(700.0, 0.0, 0.0, 0.0) < 0.01)


## The calibration the model was built around, run here as well as at class load.
func _test_anchors() -> void:

	# point-blank at a sitting duck while under way: cannot realistically miss
	check(CannonAccuracy.hit_chance(150.0, MAX_RANGE, 0.0, 300.0) > 0.98)

	# parallel run, matched speed: the lead term vanishes, so range barely matters
	check(CannonAccuracy.hit_chance(600.0, MAX_RANGE, 0.0, 0.0) > 0.9)

	# max range at a target crossing at full speed: roughly the Trafalgar hit rate
	var long_shot = CannonAccuracy.hit_chance(1200.0, MAX_RANGE, 0.0, 300.0)
	check(long_shot > 0.05 and long_shot < 0.30)

	# hauling the helm over throws the shot
	check(
		CannonAccuracy.hit_chance(400.0, MAX_RANGE, 1.5, 0.0)
		< CannonAccuracy.hit_chance(400.0, MAX_RANGE, 0.0, 0.0)
	, "helm hard over shoots no worse than steady")


## for_shot has to take the range from the gun, the lead from the closing speed, and the slew
## error from the firing ship's own turn rate. Reading any of those off the wrong node is a
## silent bug: the gate still returns a plausible number, just not the right one.
func _test_for_shot() -> void:

	var shooter: Sloop = load("res://Scenes/Sloop.tscn").instantiate()
	var target: Sloop = load("res://Scenes/Sloop.tscn").instantiate()

	root.add_child(shooter)
	root.add_child(target)

	await _settle()

	shooter.process_mode = Node.PROCESS_MODE_DISABLED
	target.process_mode = Node.PROCESS_MODE_DISABLED

	shooter.global_position = Vector2.ZERO
	shooter.rotation = 0.0
	target.global_position = Vector2(0.0, 600.0)
	shooter.velocity = Vector2(100.0, 0.0)
	target.velocity = Vector2(-50.0, 0.0)
	shooter.movement_controller.current_angular_velocity = 0.4

	var cannon: Cannon = shooter.cannons.front()

	check(cannon.max_range > 0.0)

	# the gun is not at the ship's origin, so this comparison is meaningful
	check(cannon.global_position.distance_to(shooter.global_position) > 1.0)

	check(is_equal_approx(
		CannonAccuracy.for_shot(cannon, shooter, target),
		CannonAccuracy.hit_chance(
			cannon.global_position.distance_to(target.global_position),
			cannon.max_range,
			0.4,
			150.0
		)
	), "for_shot read the conditions off the wrong nodes")

	check(is_zero_approx(CannonAccuracy.for_shot(null, shooter, target)))
	check(is_zero_approx(CannonAccuracy.for_shot(cannon, shooter, null)))
	check(is_zero_approx(CannonAccuracy.for_shot(cannon, null, target)))

	await despawn(shooter)
	await despawn(target)


## Godot has no %g, so the 3-sig-fig percentage is hand-rolled. It has been wrong before.
func _test_percent_format() -> void:

	check(Cannonball.format_percent(100.0) == "100")
	check(Cannonball.format_percent(0.0) == "0")
	check(Cannonball.format_percent(12.3456) == "12.3")
	check(Cannonball.format_percent(1.23456) == "1.23")
	check(is_equal_approx(float(Cannonball.format_percent(6.25)), 6.25))
