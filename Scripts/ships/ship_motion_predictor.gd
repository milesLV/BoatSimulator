class_name ShipMotionPredictor
extends RefCounted

## Predicts a ship's pose: exactly by replaying its own helm, or by extrapolating recent motion.

const PREDICT_STEP := 0.05
const SAMPLE_INTERVAL := 0.1
const SAMPLE_COUNT := 10

var ship: Sloop
var movement: ShipMovementController

var _angular_samples: Array[float] = []
var _speed_samples: Array[float] = []
var _time_since_sample := 0.0


func _init(new_ship: Sloop, new_movement: ShipMovementController) -> void:
	ship = new_ship
	movement = new_movement


func physics_process(delta: float) -> void:

	_time_since_sample += delta

	if _time_since_sample < SAMPLE_INTERVAL:
		return

	_time_since_sample = 0.0

	_push_sample(_angular_samples, movement.current_angular_velocity)
	_push_sample(_speed_samples, movement.current_velocity)


## [param exact] replays the helm, which only the firing ship can read.
func at(seconds: float, exact := false) -> Dictionary:

	return series(seconds, seconds, exact).back()


func series(seconds: float, sample_step: float, exact := false) -> Array[Dictionary]:

	var rotation = ship.rotation
	var position = ship.global_position
	var angular_velocity = movement.current_angular_velocity
	var speed = movement.current_velocity

	var wheel := 0.0
	var mast: MastSystem = null
	var sail := 0.0
	var anchored := false
	var wheel_manned := false
	var wheel_damage := 0
	var angular_acceleration := 0.0
	var linear_acceleration := 0.0

	if exact:
		wheel = movement.wheel_rotation
		sail = movement.sail_length
		anchored = ship.anchor_system.is_holding_ship

		wheel_manned = ship.station_controller.get_operator_by_name(&"Wheel") != null
		wheel_damage = movement.wheel_damage()
		mast = ship.mast_system.snapshot()
	else:
		angular_acceleration = _estimate_rate(_angular_samples)
		linear_acceleration = _estimate_rate(_speed_samples)

	var states: Array[Dictionary] = []
	var elapsed := 0.0
	var next_sample = sample_step
	var remaining = maxf(seconds, 0.0)

	while remaining > 0.0:
		var step = minf(PREDICT_STEP, remaining)
		remaining -= step

		if not exact:
			var max_turn := ShipMovementController.BOAT_TURN_SPEED
			angular_velocity = clampf(angular_velocity + angular_acceleration * step, -max_turn, max_turn)
			speed = clampf(speed + linear_acceleration * step, 0.0, ShipMovementController.MAX_VELOCITY)
		elif anchored:
			angular_velocity = ship.anchor_system.damp(angular_velocity, step, AnchorSystem.ANCHOR_ANGULAR_ACELERATION)
			speed = ship.anchor_system.damp(speed, step, AnchorSystem.ANCHOR_DECELERATION)
		else:
			if wheel_manned:
				wheel = ShipMovementController.advance_wheel(wheel, movement.turn_input, step, wheel_damage)

			# same order as ShipMovementController: mast first, then sails
			mast.physics_process(step)
			sail = ShipMovementController.advance_sail(sail, movement.sail_input, mast, step)
			angular_velocity = ShipMovementController.wheel_angular_velocity(wheel)
			speed = ShipMovementController.advance_speed(speed, sail, step)

		rotation += angular_velocity * step
		position += Vector2.RIGHT.rotated(rotation) * speed * step
		elapsed += step

		if elapsed >= next_sample - PREDICT_STEP * 0.5:
			states.append({"position": position, "rotation": rotation})
			next_sample += sample_step

	return states


func _push_sample(samples: Array[float], value: float) -> void:

	samples.append(value)

	if samples.size() > SAMPLE_COUNT:
		samples.remove_at(0)


func _estimate_rate(samples: Array[float]) -> float:

	if samples.size() < 2:
		return 0.0

	return (samples[-1] - samples[0]) / ((samples.size() - 1) * SAMPLE_INTERVAL)
