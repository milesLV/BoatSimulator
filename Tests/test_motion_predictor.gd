extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_motion_predictor.gd
#
# The anticipation branch of aimForHoles is only as good as this. The load-bearing test is the
# first one: the exact path claims to replay ShipMovementController's own control laws, so it
# has to still agree with the controller after anyone edits either of them.

const HORIZON := 2.0
const POSITION_TOLERANCE := 5.0 # px after 2s, from the two different integration steps
const ROTATION_TOLERANCE := 0.001


func _run() -> void:

	await _test_exact_matches_controller()
	await _test_unmanned_helm_does_not_turn()
	await _test_observed_and_clamps()
	await _test_anchored_and_series()

	finish("test_motion_predictor")


## Wake the ship up and wait for the toggle to actually take: enabling physics processing
## inside a physics_frame callback does not register until the frame after, so predicting
## before this returns would be predicting from a state one step stale.
func _start_running(ship: Sloop) -> void:

	ship.set_physics_process(true)

	await physics_frame
	await physics_frame


## Run the prediction horizon through real physics frames. Stepping the controller by hand
## does not do: move_and_slide integrates against the engine's own frames, not against
## whatever delta it is handed.
func _run_frames(ship: Sloop) -> void:

	for i in int(round(HORIZON * Engine.physics_ticks_per_second)):
		await physics_frame

	ship.set_physics_process(false)


## Predict two seconds, then actually run those two seconds through the real controller and
## check we landed in the same place. Steps differ (0.05 vs the physics tick), so the position
## carries a little integration error; the rotation should not.
func _test_exact_matches_controller() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller

	movement.wheel_rotation = 3.0
	movement.sail_length = 50.0
	movement.current_velocity = 50.0 / 100.0 * ShipMovementController.MAX_VELOCITY
	movement.set_input(0.0, 0.0, 0.0)

	await _start_running(ship)

	var predicted = ship.motion_predictor.at(HORIZON, true)

	await _run_frames(ship)

	check(
		absf(predicted["rotation"] - ship.rotation) < ROTATION_TOLERANCE,
		"predicted heading %f, actual %f" % [predicted["rotation"], ship.rotation]
	)
	check(
		Vector2(predicted["position"]).distance_to(ship.global_position) < POSITION_TOLERANCE,
		"predicted %s, actual %s" % [predicted["position"], ship.global_position]
	)

	# and it actually turned and moved, so the agreement above is not two zeroes matching
	check(absf(ship.rotation) > 0.5, "the ship barely turned: %f" % ship.rotation)
	check(ship.global_position.length() > 100.0, "the ship barely moved: %s" % ship.global_position)

	await despawn(ship)


## Turn input with nobody on the wheel moves nothing, in the controller or in the prediction.
func _test_unmanned_helm_does_not_turn() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller

	check(movement.station_controller.get_operator_by_name(&"Wheel") == null)

	movement.wheel_rotation = 0.0
	movement.set_input(1.0, 0.0, 0.0)

	await _start_running(ship)

	var predicted = ship.motion_predictor.at(HORIZON, true)

	await _run_frames(ship)

	check(is_zero_approx(ship.rotation), "the ship turned with nobody on the wheel: %f" % ship.rotation)
	check(
		absf(predicted["rotation"] - ship.rotation) < ROTATION_TOLERANCE,
		"predicted heading %f, actual %f" % [predicted["rotation"], ship.rotation]
	)

	await despawn(ship)


## The enemy path: no helm to read, just what it has been doing lately.
func _test_observed_and_clamps() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller
	var predictor = ship.motion_predictor

	# steady turn, no history to difference: it keeps turning at the rate we can see
	movement.current_angular_velocity = 0.5
	movement.current_velocity = 0.0

	var steady = predictor.at(HORIZON, false)

	check(absf(steady["rotation"] - 0.5 * HORIZON) < 0.01)
	check(Vector2(steady["position"]).distance_to(ship.global_position) < 0.01)

	# an absurd extrapolated acceleration still cannot predict a ship doing the impossible
	predictor._angular_samples.assign([0.0, 100.0])
	predictor._speed_samples.assign([0.0, 100000.0])

	var wild = predictor.at(HORIZON, false)

	check(absf(wild["rotation"]) <= ShipMovementController.BOAT_TURN_SPEED * HORIZON + 0.01)
	check(
		Vector2(wild["position"]).distance_to(ship.global_position)
		<= ShipMovementController.MAX_VELOCITY * HORIZON + 0.01
	, "predicted travel beat the ship's top speed")

	await despawn(ship)


func _test_anchored_and_series() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller
	var predictor = ship.motion_predictor

	movement.sail_length = 100.0
	movement.current_velocity = ShipMovementController.MAX_VELOCITY

	var under_way = predictor.at(HORIZON, true)

	movement.anchor_system.is_holding_ship = true

	var held = predictor.at(HORIZON, true)

	check(
		Vector2(held["position"]).distance_to(ship.global_position)
		< Vector2(under_way["position"]).distance_to(ship.global_position)
	, "the anchor did not slow the predicted run")

	movement.anchor_system.is_holding_ship = false

	# a timeline scan and a single lookup come off the same integration
	var states = predictor.series(HORIZON, 0.1, true)

	check(states.size() >= 20)
	check(Vector2(states.back()["position"]).distance_to(Vector2(under_way["position"]))
		< 0.01)
	check(absf(states.back()["rotation"] - float(under_way["rotation"])) < 0.001)

	await despawn(ship)
