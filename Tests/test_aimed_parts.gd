extends "res://Tests/harness.gd"

## Balls reach the crewmate in well under this; one lasting longer flew past.
const STOP_FRAMES := 25


func _run() -> void:

	Cannonball.mast_strike_chance = 0.0

	await _test_crew_strike()
	await _test_picking()

	finish("test_aimed_parts")


func _test_crew_strike() -> void:

	var ship = await spawn_frozen_ship()
	var crewmate: Crewmate = ship.crewmates[0]
	var hits_before = Cannonball.shots_hit
	# where they stand, which deck, whether the roll hit, whether the ball comes down on them
	var cases := [
		[Vector2(0.0, 40.0), DeckGraph.DECKS.MAIN, true, true],
		[Vector2(0.0, 40.0), DeckGraph.DECKS.MAIN, false, false],
		[Vector2(40.0, 40.0), DeckGraph.DECKS.MAIN, true, false],
		[Vector2(0.0, 40.0), DeckGraph.DECKS.MID, true, false],
	]

	for case in cases:
		crewmate.global_position = ship.global_position + case[0]
		crewmate.location = case[1]

		var ball = spawn_ball(ship, case[2])
		ball.aimed_part = crewmate

		var stopped = await frames_until_gone(ball) < STOP_FRAMES

		check(stopped == case[3], "%s on deck %d, hit roll %s: stopped %s" % [case[0], case[1], case[2], stopped])

	check(Cannonball.shots_hit == hits_before + 1, "crew hits counted: %d" % (Cannonball.shots_hit - hits_before))

	for hole in ship.action_points.holes:
		check(hole.grade == 0, "%s holed by a shot at the crew" % hole.name)

	await despawn(ship)


func _test_picking() -> void:

	var ship = await spawn_frozen_ship()
	var cannon: Cannon = ship.cannons[0]
	var crew = ship.crewmates

	cannon.aim_target = Cannon.AimTarget.CREW

	for crewmate in crew:
		crewmate.location = DeckGraph.DECKS.LOWER

	check(cannon._aimed_part(ship) == null, "aimed at a crewmate below decks")

	crew[1].location = DeckGraph.DECKS.MAIN

	check(cannon._aimed_part(ship) == crew[1], "missed the one crewmate up top")

	cannon.aim_target = Cannon.AimTarget.WHEEL

	check(cannon._aimed_part(ship) is WheelHole, "wheel aim missed the wheel")

	cannon.aim_target = Cannon.AimTarget.HULL

	check(cannon._aimed_part(ship) == null, "hull aim picked a part")

	await despawn(ship)
