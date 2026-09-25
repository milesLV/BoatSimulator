extends "res://Tests/harness.gd"

const HORIZON := 2.0
const POSITION_TOLERANCE := 5.0 # px after 2s, from the two different integration steps
const ROTATION_TOLERANCE := 0.001


func _run() -> void:

	_test_wheel_stops()
	await _test_exact_matches_controller()
	await _test_unmanned_helm_does_not_turn()
	await _test_downed_mast_furls()
	await _test_raise_finishes_mid_horizon()
	await _test_observed_and_clamps()
	await _test_anchored_and_series()

	finish("test_motion_predictor")


func _test_wheel_stops() -> void:

	var wheel := 0.0

	for i in 200:
		wheel = ShipMovementController.advance_wheel(wheel, 1.0, ShipMotionPredictor.PREDICT_STEP)

	check(is_equal_approx(wheel, ShipMovementController.MAX_WHEEL_TURN), "the wheel ran past its stop")
	check(is_equal_approx(ShipMovementController.wheel_angular_velocity(wheel), ShipMovementController.BOAT_TURN_SPEED))
	check(is_zero_approx(ShipMovementController.wheel_angular_velocity(0.0)))


## Enabling physics processing inside a physics_frame callback only takes effect a frame later.
func _start_running(ship: Sloop) -> void:

	ship.set_physics_process(true)

	await physics_frame
	await physics_frame


## Real frames: move_and_slide integrates on engine frames, not on the delta it is handed.
func _run_frames(ship: Sloop) -> void:

	for i in int(round(HORIZON * Engine.physics_ticks_per_second)):
		await physics_frame

	ship.set_physics_process(false)


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

	# so the agreement above is not two zeroes matching
	check(absf(ship.rotation) > 0.5, "the ship barely turned: %f" % ship.rotation)
	check(ship.global_position.length() > 100.0, "the ship barely moved: %s" % ship.global_position)

	await despawn(ship)


func _test_downed_mast_furls() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller

	ship.mast_system.state = MastSystem.State.DOWN
	ship.mast_system.angle = MastSystem.FALLEN
	movement.sail_length = 100.0
	movement.current_velocity = ShipMovementController.MAX_VELOCITY
	movement.set_input(0.0, 0.0, 0.0)

	await _start_running(ship)

	var predicted = ship.motion_predictor.at(HORIZON, true)

	await _run_frames(ship)

	check(movement.sail_length == 0.0, "the sails were still at %.1f" % movement.sail_length)
	check(
		Vector2(predicted["position"]).distance_to(ship.global_position) < POSITION_TOLERANCE,
		"predicted %s, actual %s" % [predicted["position"], ship.global_position]
	)

	await despawn(ship)


func _test_raise_finishes_mid_horizon() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller

	ship.mast_system.state = MastSystem.State.RAISING
	ship.mast_system.angle = 0.1 * MastSystem.FALLEN
	movement.sail_length = 50.0
	movement.current_velocity = 0.5 * ShipMovementController.MAX_VELOCITY
	movement.set_input(0.0, 1.0, 0.0)

	await _start_running(ship)

	var predicted = ship.motion_predictor.at(HORIZON, true)

	await _run_frames(ship)

	check(ship.mast_system.state == MastSystem.State.STANDING, "the mast did not stand")
	check(movement.sail_length > 0.0, "the sails never let out again")
	check(
		Vector2(predicted["position"]).distance_to(ship.global_position) < POSITION_TOLERANCE,
		"predicted %s, actual %s" % [predicted["position"], ship.global_position]
	)

	await despawn(ship)


func _test_unmanned_helm_does_not_turn() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller

	check(ship.station_controller.get_operator_by_name(&"Wheel") == null)

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


func _test_observed_and_clamps() -> void:

	var ship = await spawn_frozen_ship()
	var movement = ship.movement_controller
	var predictor = ship.motion_predictor

	movement.current_angular_velocity = 0.5
	movement.current_velocity = 0.0

	var steady = predictor.at(HORIZON, false)

	check(absf(steady["rotation"] - 0.5 * HORIZON) < 0.01)
	check(Vector2(steady["position"]).distance_to(ship.global_position) < 0.01)

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

	ship.anchor_system.is_holding_ship = true

	var held = predictor.at(HORIZON, true)

	check(
		Vector2(held["position"]).distance_to(ship.global_position)
		< Vector2(under_way["position"]).distance_to(ship.global_position)
	, "the anchor did not slow the predicted run")

	ship.anchor_system.is_holding_ship = false

	var states = predictor.series(HORIZON, 0.1, true)

	check(states.size() >= 20)
	check(Vector2(states.back()["position"]).distance_to(Vector2(under_way["position"]))
		< 0.01)
	check(absf(states.back()["rotation"] - float(under_way["rotation"])) < 0.001)

	await despawn(ship)
