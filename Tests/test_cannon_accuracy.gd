extends "res://Tests/harness.gd"

const MAX_RANGE := 1200.0


func _run() -> void:

	_test_monotonic()
	_test_bounds()
	_test_anchors()
	await _test_for_shot()
	_test_percent_format()

	finish("test_cannon_accuracy")


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


## Includes max_range 0, which divides by zero on the way in.
func _test_bounds() -> void:

	for distance in [0.0, 1.0, 100.0, 700.0, 5000.0]:
		for max_range in [0.0, 1.0, MAX_RANGE]:
			for turn in [0.0, 1.5, 50.0]:
				for speed in [0.0, 300.0, 9000.0]:
					var chance = CannonAccuracy.hit_chance(distance, max_range, turn, speed)

					check(not is_nan(chance))
					check(chance >= 0.0 and chance <= 1.0)

	check(CannonAccuracy.hit_chance(700.0, 0.0, 0.0, 0.0) < 0.01)


func _test_anchors() -> void:

	check(CannonAccuracy.hit_chance(150.0, MAX_RANGE, 0.0, 300.0) > 0.98)

	check(CannonAccuracy.hit_chance(600.0, MAX_RANGE, 0.0, 0.0) > 0.9)

	var long_shot = CannonAccuracy.hit_chance(1200.0, MAX_RANGE, 0.0, 300.0)
	check(long_shot > 0.05 and long_shot < 0.30)

	check(
		CannonAccuracy.hit_chance(400.0, MAX_RANGE, 1.5, 0.0)
		< CannonAccuracy.hit_chance(400.0, MAX_RANGE, 0.0, 0.0)
	, "helm hard over shoots no worse than steady")


func _test_for_shot() -> void:

	var shooter: Sloop = await spawn_ship()
	var target: Sloop = await spawn_ship()

	shooter.process_mode = Node.PROCESS_MODE_DISABLED
	target.process_mode = Node.PROCESS_MODE_DISABLED

	shooter.global_position = Vector2.ZERO
	shooter.rotation = 0.0
	target.global_position = Vector2(0.0, 600.0)
	shooter.velocity = Vector2(100.0, 0.0)
	target.velocity = Vector2(-50.0, 0.0)
	shooter.movement_controller.current_angular_velocity = 0.4

	var cannon: Cannon = shooter.cannons.front()

	check(cannon.ammo.max_range > 0.0)

	# the gun is not at the ship's origin, so this comparison is meaningful
	check(cannon.global_position.distance_to(shooter.global_position) > 1.0)

	check(is_equal_approx(
		CannonAccuracy.for_shot(cannon, shooter, target),
		CannonAccuracy.hit_chance(
			cannon.global_position.distance_to(target.global_position),
			cannon.ammo.max_range,
			0.4,
			150.0
		)
	), "for_shot read the conditions off the wrong nodes")

	check(is_zero_approx(CannonAccuracy.for_shot(null, shooter, target)))
	check(is_zero_approx(CannonAccuracy.for_shot(cannon, shooter, null)))
	check(is_zero_approx(CannonAccuracy.for_shot(cannon, null, target)))

	await despawn(shooter)
	await despawn(target)


func _test_percent_format() -> void:

	check(Cannonball.format_percent(100.0) == "100")
	check(Cannonball.format_percent(0.0) == "0")
	check(Cannonball.format_percent(12.3456) == "12.3")
	check(Cannonball.format_percent(1.23456) == "1.23")
	check(is_equal_approx(float(Cannonball.format_percent(6.25)), 6.25))
