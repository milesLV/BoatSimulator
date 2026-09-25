extends "res://Tests/harness.gd"

# Shooter at the origin facing +x, target abeam to starboard with its port side (y < 0) facing.

const TARGET_RANGE := 400.0
const LONG_RANGE := 1000.0

var shooter: Sloop
var target: Sloop
var cannon: Cannon


func _run() -> void:

	await _test_pure_geometry()
	await _test_hull_matches_the_scene()
	await _test_hole_choice()
	await _test_flood_flips_the_deck_priority()
	await _test_never_the_far_side()
	await _test_spent_near_holes_do_not_promote_the_far_ones()
	await _test_slew_tolerance()
	await _test_reload_clock()
	await _test_anticipation()
	await _test_fallback()

	finish("test_aim_for_holes")


func _make_pair(range_to_target := TARGET_RANGE) -> void:

	shooter = await spawn_frozen_ship()
	target = await spawn_frozen_ship(Vector2(0.0, range_to_target))

	cannon = shooter.cannons.filter(
		func(candidate): return candidate.broadside == Cannon.Side.STARBOARD
	).front()

	check(cannon != null and cannon.ammo.max_range > 0.0)


func _tear_down() -> void:

	await despawn(shooter)
	await despawn(target)


func _pick() -> Dictionary:

	return AimForHoles.pick_shot(cannon, shooter, target)


func _set_grades(ship: Sloop, grades) -> void:

	if grades is int:
		for hole in ship.action_points.holes:
			hole.set_grade(grades)

		return

	for hole_name in grades:
		ship.action_points.get_point(StringName(hole_name)).set_grade(int(grades[hole_name]))


func _test_hull_matches_the_scene() -> void:

	var ship = await spawn_frozen_ship()
	var collision: CollisionPolygon2D = ship.get_node("SloopCollision")
	var scene = collision.transform * collision.polygon

	check(scene.size() == AimForHoles.HULL.size(), "the hull changed shape")

	for index in mini(scene.size(), AimForHoles.HULL.size()):
		check(
			scene[index].distance_to(AimForHoles.HULL[index]) < 0.5,
			"HULL[%d] is %s, the scene says %s" % [index, AimForHoles.HULL[index], scene[index]]
		)

	await despawn(ship)


func _test_pure_geometry() -> void:

	var cannon_now = {"position": Vector2.ZERO, "rotation": PI / 2.0} # muzzle pointing +y
	var target_now = {"position": Vector2(0.0, 400.0), "rotation": 0.0}
	var near_side = Vector2(4.0, -29.0)
	var far_side = Vector2(4.0, 29.0)

	check(AimForHoles.is_hittable(cannon_now, near_side, target_now, 1200.0))
	check(not AimForHoles.is_hittable(cannon_now, far_side, target_now, 1200.0))

	var spun = {"position": Vector2(0.0, 400.0), "rotation": PI}

	check(not AimForHoles.is_hittable(cannon_now, near_side, spun, 1200.0))
	check(AimForHoles.is_hittable(cannon_now, far_side, spun, 1200.0))

	# regression: nearly bow-on, side holes tip slightly toward the gun but are still blocked
	for tilt in [-0.17, 0.17]:
		var bow_on = {"position": Vector2(0.0, 400.0), "rotation": -PI / 2.0 + tilt}

		check(
			AimForHoles.is_hittable(cannon_now, Vector2(80.0, 0.0), bow_on, 1200.0),
			"the bow hole is the shot a bow-on target offers"
		)

		for side in [Vector2(-107.0, -25.0), Vector2(-107.0, 25.0), near_side, far_side]:
			check(
				not AimForHoles.is_hittable(cannon_now, side, bow_on, 1200.0),
				"%s was hittable through the length of the hull" % side
			)

	check(not AimForHoles.is_hittable(cannon_now, near_side, target_now, 100.0))

	var turned_gun = {"position": Vector2.ZERO, "rotation": -PI / 2.0}

	check(not AimForHoles.is_hittable(turned_gun, near_side, target_now, 1200.0))

	check(not AimForHoles.is_hittable(
		{"position": Vector2(4.0, 371.0), "rotation": PI / 2.0},
		near_side,
		target_now,
		1200.0
	), "a hole we are standing on counted as a shot")

	await _make_pair()

	var state = AimForHoles.cannon_state(cannon, shooter, {
		"position": Vector2(500.0, 0.0),
		"rotation": PI / 2.0,
	})

	var offset = shooter.to_local(cannon.global_position)

	check(Vector2(state["position"]).distance_to(
		Vector2(500.0, 0.0) + offset.rotated(PI / 2.0)
	) < 0.01, "the muzzle did not ride round with the ship")
	check(is_equal_approx(state["rotation"], PI / 2.0 + cannon.rotation))

	await _tear_down()


func _test_hole_choice() -> void:

	await _make_pair()

	cannon.loaded = true

	var shot = _pick()
	var hole: ShipHolePoint = shot["hole"]

	check(hole != null)
	check(hole.deck == DeckGraph.DECKS.LOWER)
	check(String(hole.name).begins_with("HolePort"))
	check(shot["fire_now"])

	# a half-open lower hole is worth less than a fresh one
	_set_grades(target, {"HolePort7": 3})

	hole = _pick()["hole"]

	check(String(hole.name) == "HolePort8")

	_set_grades(target, {"HolePort7": 5, "HolePort8": 5})

	hole = _pick()["hole"]

	check(hole.deck == DeckGraph.DECKS.MID)
	check(hole.grade < ShipHolePoint.MAX_GRADE)

	await _tear_down()


func _test_flood_flips_the_deck_priority() -> void:

	# at long range both holes share a bearing, so slew time doesn't affect the choice
	await _make_pair(LONG_RANGE)

	cannon.loaded = true

	_set_grades(target, 5)
	_set_grades(target, {"HolePort7": 3, "HolePort6": 0}) # lower half-open, mid fresh

	target.health_system.water_level = 0.0

	var hole: ShipHolePoint = _pick()["hole"]

	check(String(hole.name) == "HolePort7")
	check(hole.deck == DeckGraph.DECKS.LOWER)

	target.health_system.water_level = ShipHealthSystem.MID_DECK_WATER_LEVEL + 50.0

	hole = _pick()["hole"]

	check(String(hole.name) == "HolePort6")
	check(hole.deck == DeckGraph.DECKS.MID)

	await _tear_down()


func _test_never_the_far_side() -> void:

	await _make_pair()

	cannon.loaded = true

	var picked := 0

	for step in 24:
		target.rotation = step * TAU / 24.0

		var shot = _pick()
		var hole: ShipHolePoint = shot["hole"]

		if hole == null:
			continue

		picked += 1

		var facing = AimForHoles.outward_normal(
			target.to_local(hole.global_position)
		).rotated(target.rotation)

		check(
			(cannon.global_position - hole.global_position).normalized().dot(facing)
			>= AimForHoles.MIN_EXPOSURE,
			"%s was picked while barely facing the gun" % hole.name
		)

		check(hole.grade < ShipHolePoint.MAX_GRADE)

	check(picked > 0)

	await _tear_down()


## Bow-on, only the bow hole and the two shoulder holes beside it face the gun.
func _test_spent_near_holes_do_not_promote_the_far_ones() -> void:

	await _make_pair()

	target.rotation = -PI / 2.0 # bow toward the shooter
	cannon.loaded = true

	_set_grades(target, {"HoleBow": ShipHolePoint.MAX_GRADE})

	var hole: ShipHolePoint = _pick()["hole"]

	check(
		hole == null or hole.name in [&"HoleBow", &"HolePort8", &"HoleStarb9"],
		"the gunner promoted %s once the bow hole was spent" % (hole.name if hole else "")
	)

	await _tear_down()


func _test_slew_tolerance() -> void:

	await _make_pair()

	_set_grades(target, 5)
	_set_grades(target, {"HolePort2": 0, "HolePort6": 4}) # far and worth 3, near and worth 1

	cannon.loaded = true

	var hole: ShipHolePoint = _pick()["hole"]

	check(String(hole.name) == "HolePort6")

	# mid-reload the slew is free, so it goes for the better hole
	cannon.loaded = false

	hole = _pick()["hole"]

	check(String(hole.name) == "HolePort2")

	await _tear_down()


func _test_reload_clock() -> void:

	await _make_pair()

	var duty = shooter.cannon_duty_controller

	cannon.loaded = true
	check(is_zero_approx(duty.get_reload_remaining(cannon)))

	cannon.loaded = false
	check(is_equal_approx(
		duty.get_reload_remaining(cannon),
		ReloadCannonAction.RELOAD_DURATION
	))

	var station: CannonStationPoint = shooter.action_points.cannon_stations.filter(
		func(candidate): return candidate.cannon == cannon
	).front()

	check(station != null)

	var crewmate = shooter.crewmates.front()

	duty.assign_crewmate(crewmate)
	crewmate.action_executor.cancel_plan()
	crewmate.action_executor.queue_actions([ReloadCannonAction.new(station)])

	for i in 10:
		crewmate.action_executor._physics_process(0.1)

	check(absf(duty.get_reload_remaining(cannon) - 1.0) < 0.05)

	var other: Cannon = shooter.cannons.filter(
		func(candidate): return candidate != cannon
	).front()

	other.loaded = false

	check(is_equal_approx(
		duty.get_reload_remaining(other),
		ReloadCannonAction.RELOAD_DURATION
	))

	await _tear_down()


func _test_anticipation() -> void:

	await _make_pair()

	cannon.loaded = true

	# facing side spent, far side fresh
	_set_grades(target, 0)

	for hole in target.action_points.holes:
		if AimForHoles.outward_normal(target.to_local(hole.global_position)).y <= 0.0:
			hole.set_grade(ShipHolePoint.MAX_GRADE)

	target.movement_controller.current_angular_velocity = 0.0

	var shot = _pick()

	check(shot["hole"] != null)
	check(shot["hole"].grade == ShipHolePoint.MAX_GRADE)
	check(shot["fire_now"])

	var held := 0
	var fired := 0

	for rate in [0.4, 0.7, 1.0, 1.4]:
		target.rotation = 0.0
		target.movement_controller.current_angular_velocity = rate
		target.motion_predictor._angular_samples.clear()
		target.motion_predictor._speed_samples.clear()

		shot = _pick()

		check(shot["hole"] != null)

		if shot["fire_now"]:
			fired += 1
		else:
			check(shot["hole"].grade < ShipHolePoint.MAX_GRADE)
			held += 1

	check(held > 0)
	check(fired > 0)

	await _tear_down()


func _test_fallback() -> void:

	await _make_pair(5000.0)
	var shot = _pick()

	check(shot["hole"] == null)
	check(Vector2(shot["aim_point"]) == target.global_position)
	check(shot["fire_now"])

	await _tear_down()
