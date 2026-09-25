extends "res://Tests/harness.gd"


func _run() -> void:

	await _test_mast_strike()
	await _test_reach()
	await _test_hull_hit()
	await _test_order()

	finish("test_ammunition")


func _mast_grades(ship: Sloop) -> Array:
	return ship.action_points.mast_holes.map(func(hole): return hole.grade)


func _test_mast_strike() -> void:

	var ship = await spawn_frozen_ship()
	var mast: Vector2 = ship.action_points.mast_holes.front().global_position
	var across := func(): return ship.apply_mast_hit(
		mast + Vector2(0.0, -50.0), mast + Vector2(0.0, 50.0), Ammunition.CHAINSHOT.mast_holes_per_hit
	)

	check(across.call(), "chainshot missed the mast")
	check(_mast_grades(ship) == [1, 1, 0], "fresh mast: %s" % [_mast_grades(ship)])

	for hole in ship.action_points.mast_holes:
		hole.set_grade(0)

	ship.action_points.mast_holes[0].set_grade(1)
	across.call()

	check(_mast_grades(ship) == [1, 1, 1], "one hole open: %s" % [_mast_grades(ship)])
	check(ship.mast_system.is_compromised(), "mast stood with every hole open")

	await despawn(ship)


func _test_reach() -> void:

	var ship = await spawn_frozen_ship()
	var mast: Vector2 = ship.action_points.mast_holes.front().global_position
	var beside := func(ammo): return ship.apply_mast_hit(
		mast + Vector2(15.0, -50.0), mast + Vector2(15.0, 50.0), ammo.mast_holes_per_hit, ammo.reach
	)

	check(not beside.call(Ammunition.CANNONBALL), "cannonball caught the mast from 15px off")
	check(beside.call(Ammunition.CHAINSHOT), "chainshot missed the mast from 15px off")

	for hole in ship.action_points.mast_holes:
		hole.set_grade(0)

	var ball = spawn_ball(ship, false)
	ball.ammo = Ammunition.CHAINSHOT
	ball.aimed_part = ship.action_points.mast_holes[0]

	await frames_until_gone(ball)

	check(_mast_grades(ship) == [1, 1, 0], "bad-roll chainshot at the mast: %s" % [_mast_grades(ship)])

	await despawn(ship)


func _test_hull_hit() -> void:

	var ship = await spawn_frozen_ship()
	var ball = spawn_ball(ship, true)
	ball.ammo = Ammunition.CHAINSHOT

	await frames_until_gone(ball)

	var total = ship.action_points.hull_holes.reduce(func(sum, hole): return sum + hole.grade, 0)

	check(total == Ammunition.CHAINSHOT.hole_damage, "chainshot opened %d hull grades" % total)

	await despawn(ship)


func _test_order() -> void:

	var ship = await spawn_frozen_ship()
	var crewmate: Crewmate = ship.crewmates[0]
	var station: CannonStationPoint = ship.action_points.cannon_stations[0]

	ship.station_controller.set_operator(station, crewmate)
	ship.current_crewmate = crewmate

	check(ship.request(&"request_cannon_aim", [Ammunition.CHAINSHOT, Cannon.AimTarget.MAST]), "order refused")
	check(station.cannon.ammo == Ammunition.CHAINSHOT and crewmate.ammo == Ammunition.CHAINSHOT, "ammo not loaded")
	check(station.cannon.aim_target == Cannon.AimTarget.MAST, "aim not set")
	check(station.cannon.ammo == Ammunition.CHAINSHOT, "the claimed cannon kept its old ammunition")

	check(ship.request(&"request_cannon_default_aim"), "default order refused")
	check(station.cannon.aim_target == Cannon.AimTarget.MAST, "default aim lost the ammo's default")

	await despawn(ship)
