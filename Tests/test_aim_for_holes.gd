extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_aim_for_holes.gd
#
# aimForHoles picks which hole a ball is spent on. Nothing about that choice is visible in
# play beyond a cannon that aims slightly oddly, so it is all checked here.
#
# Geometry used throughout: shooter at the origin pointing +x, target dead abeam to starboard,
# so the target's port side (local y < 0) is the side facing the guns.

const TARGET_RANGE := 400.0
const LONG_RANGE := 1000.0

# the pair under test, one at a time, set up by _make_pair
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


# --- setup helpers ------------------------------------------------------------------------


func _make_pair(range_to_target := TARGET_RANGE) -> void:

	shooter = await spawn_frozen_ship()
	target = await spawn_frozen_ship(Vector2(0.0, range_to_target))

	cannon = shooter.cannons.filter(
		func(candidate): return candidate.broadside == CannonSide.Value.STARBOARD
	).front()

	check(cannon != null and cannon.max_range > 0.0)


func _tear_down() -> void:

	await despawn(shooter)
	await despawn(target)


## What the mode makes of the pair as it stands.
func _pick() -> Dictionary:

	return AimForHoles.pick_shot(cannon, shooter, target)


## Grades by hole name, or one grade for the whole hull.
func _set_grades(ship: Sloop, grades) -> void:

	if grades is int:
		for hole in ship.action_points.holes:
			hole.set_grade(grades)

		return

	for hole_name in grades:
		ship.action_points.get_point(StringName(hole_name)).set_grade(int(grades[hole_name]))


# --- the pure functions -------------------------------------------------------------------


## The outline the normals are read off is a copy of SloopCollision's polygon, and a copy goes
## stale the first time the hull is redrawn. This is what says so.
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



## is_hittable and cannon_state take plain dictionaries, so the geometry rules can be checked
## without a scene at all.
func _test_pure_geometry() -> void:

	var cannon_now = {"position": Vector2.ZERO, "rotation": PI / 2.0} # muzzle pointing +y
	var target_now = {"position": Vector2(0.0, 400.0), "rotation": 0.0}
	var near_side = Vector2(4.0, -29.0)
	var far_side = Vector2(4.0, 29.0)

	check(AimForHoles.is_hittable(cannon_now, near_side, target_now, 1200.0))
	check(not AimForHoles.is_hittable(cannon_now, far_side, target_now, 1200.0))

	# turn the target end for end and the sides swap over
	var spun = {"position": Vector2(0.0, 400.0), "rotation": PI}

	check(not AimForHoles.is_hittable(cannon_now, near_side, spun, 1200.0))
	check(AimForHoles.is_hittable(cannon_now, far_side, spun, 1200.0))

	# the reported bug: nearly bow-on, the side rows tip a few degrees toward the gun, which
	# the old half-plane rule counted as a shot straight down the length of the hull
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

	# out of range
	check(not AimForHoles.is_hittable(cannon_now, near_side, target_now, 100.0))

	# outside the mount's 45 degree arc: same hole, gun pointing the other way
	var turned_gun = {"position": Vector2.ZERO, "rotation": -PI / 2.0}

	check(not AimForHoles.is_hittable(turned_gun, near_side, target_now, 1200.0))

	# a hole we are standing on is not a shot
	check(not AimForHoles.is_hittable(
		{"position": Vector2(4.0, 371.0), "rotation": PI / 2.0},
		near_side,
		target_now,
		1200.0
	), "a hole we are standing on counted as a shot")

	# the muzzle rides round with the ship it is bolted to
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


# --- which hole ---------------------------------------------------------------------------


## Fresh lower-deck holes first, then top them up, then the mid deck. Grade 5 holes are never
## chosen while anything else on that side is still worth hitting.
func _test_hole_choice() -> void:

	await _make_pair()

	cannon.loaded = true

	# everything fresh: take a lower-deck hole on the facing side
	var shot = _pick()
	var hole: ShipHolePoint = shot["hole"]

	check(hole != null)
	check(hole.deck == DeckGraph.DECKS.LOWER)
	check(String(hole.name).begins_with("HolePort"))
	check(shot["fire_now"])

	# a half-open lower hole is worth less than a fresh one, so the fresh one goes first
	_set_grades(target, {"HolePort7": 3})

	hole = _pick()["hole"]

	check(String(hole.name) == "HolePort8")

	# with the facing lower deck spent it drops to the mid deck, and never back to a grade 5
	_set_grades(target, {"HolePort7": 5, "HolePort8": 5})

	hole = _pick()["hole"]

	check(hole.deck == DeckGraph.DECKS.MID)
	check(hole.grade < ShipHolePoint.MAX_GRADE)

	await _tear_down()


## A lower-deck hole is worth several mid-deck ones only while the target is dry. Once its
## water is over the mid deck both flood alike and a fresh mid hole is the better ball.
func _test_flood_flips_the_deck_priority() -> void:

	# at long range the two candidates sit on nearly the same bearing, so the slew tolerance
	# stays out of it and the choice is purely the score
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


## The vision rule, swept exhaustively: whatever we pick, it has to be a hole facing us.
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

		# nothing is spent here, so it should never come back with a spent hole
		check(hole.grade < ShipHolePoint.MAX_GRADE)

	check(picked > 0)

	await _tear_down()


## The reported scenario: bow-on, the bow hole capped out, and the gunner must not fall back on
## the rows down the sides of a hull the ball cannot get through. The two shoulder holes either
## side of the bow are fair game - the hull turns half toward the gun there.
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


## A hole the barrel cannot reach in time is worth nothing, so a far high-scoring hole loses to
## a near mediocre one - unless the gun is reloading anyway, in which case the slew is free.
func _test_slew_tolerance() -> void:

	await _make_pair()

	_set_grades(target, 5)
	_set_grades(target, {"HolePort2": 0, "HolePort6": 4}) # far and worth 3, near and worth 1

	cannon.loaded = true

	var hole: ShipHolePoint = _pick()["hole"]

	check(String(hole.name) == "HolePort6")

	# mid-reload the barrel has two seconds to spare, so it goes for the better hole
	cannon.loaded = false

	hole = _pick()["hole"]

	check(String(hole.name) == "HolePort2")

	await _tear_down()


## The gun's idea of when it is loaded again comes from the gunner actually reloading it.
func _test_reload_clock() -> void:

	await _make_pair()

	var duty = shooter.cannon_duty_controller

	# nobody on it: a fired gun is a whole reload away
	cannon.loaded = true
	check(is_zero_approx(duty.get_reload_remaining(cannon)))

	cannon.loaded = false
	check(is_equal_approx(
		duty.get_reload_remaining(cannon),
		ReloadCannonAction.RELOAD_DURATION
	))

	var station: CannonStationPoint = shooter.action_points.cannon_stations.filter(
		func(candidate): return candidate.get_cannon(shooter) == cannon
	).front()

	check(station != null)

	var crewmate = shooter.get_crewmates().front()

	duty.assign_crewmate(crewmate)
	crewmate.action_executor.cancel_plan()
	crewmate.action_executor.queue_actions([ReloadCannonAction.new(station)])

	for i in 10:
		crewmate.action_executor._physics_process(0.1)

	check(absf(duty.get_reload_remaining(cannon) - 1.0) < 0.05)

	# a reload for the other gun tells us nothing about this one
	var other: Cannon = shooter.cannons.filter(
		func(candidate): return candidate != cannon
	).front()

	other.loaded = false

	check(is_equal_approx(
		duty.get_reload_remaining(other),
		ReloadCannonAction.RELOAD_DURATION
	))

	await _tear_down()


## Everything in view spent. Either nothing is coming, and it takes the free shot at a spent
## hole, or the two ships are about to turn something fresh into view and the gun has to decide
## between holding a loaded barrel and squeezing one more ball in first.
func _test_anticipation() -> void:

	await _make_pair()

	cannon.loaded = true

	# the far side is fresh, the facing side is spent
	_set_grades(target, 0)

	for hole in target.action_points.holes:
		if AimForHoles.outward_normal(target.to_local(hole.global_position)).y <= 0.0:
			hole.set_grade(ShipHolePoint.MAX_GRADE)

	# nothing is turning, so nothing fresh is ever coming into view: take the free shot
	target.movement_controller.current_angular_velocity = 0.0

	var shot = _pick()

	check(shot["hole"] != null)
	check(shot["hole"].grade == ShipHolePoint.MAX_GRADE)
	check(shot["fire_now"])

	# now put it into a turn. Slow turns leave time to hold for the fresh side; fast ones leave
	# room to spend a ball on a spent hole first. Both branches have to be reachable.
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
			# holding is only ever worth it for a hole that is worth damaging
			check(shot["hole"].grade < ShipHolePoint.MAX_GRADE)
			held += 1

	check(held > 0)
	check(fired > 0)

	await _tear_down()


## Nothing hittable at all: aim at the ship and fire.
func _test_fallback() -> void:

	await _make_pair(5000.0)
	var shot = _pick()

	check(shot["hole"] == null)
	check(Vector2(shot["aim_point"]) == target.global_position)
	check(shot["fire_now"])

	await _tear_down()
