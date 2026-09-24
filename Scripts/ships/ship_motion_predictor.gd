class_name ShipMotionPredictor
extends RefCounted

## Where a ship will be, and which way it will be pointing, some seconds from now.
##
## Two paths. For the ship we are firing from we know the helm, and the movement controller
## has no angular acceleration of its own (omega is read straight off the wheel), so
## replaying its control laws forward is exact rather than estimated. For anyone else we
## only watch what they do: a second of angular and linear velocity history, differenced
## into an acceleration and held constant.

const PREDICT_STEP := 0.05
const SAMPLE_INTERVAL := 0.1
const SAMPLE_COUNT := 10 # 1.0 seconds of history

var ship: CharacterBody2D
var movement: ShipMovementController

var _angular_samples: Array[float] = []
var _speed_samples: Array[float] = []
var _time_since_sample := 0.0


func _init(new_ship: CharacterBody2D, new_movement: ShipMovementController) -> void:
	ship = new_ship
	movement = new_movement


func physics_process(delta: float) -> void:

	_time_since_sample += delta

	if _time_since_sample < SAMPLE_INTERVAL:
		return

	_time_since_sample = 0.0

	_push_sample(_angular_samples, movement.current_angular_velocity)
	_push_sample(_speed_samples, movement.current_velocity)


## State [param seconds] from now. [param exact] replays the ship's own controls, which is
## only ours to read for the ship the cannon is bolted to.
func at(seconds: float, exact := false) -> Dictionary:

	return series(seconds, seconds, exact).back()


## States at every [param sample_step] out to [param seconds], from a single forward
## integration, so scanning a timeline costs one pass rather than one per sample.
## [param exact] replays the ship's own controls; otherwise the last second of watched
## motion is differenced into an acceleration and held constant.
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
	var angular_acceleration := 0.0
	var linear_acceleration := 0.0

	if exact:
		wheel = movement.wheel_rotation
		sail = movement.sail_length
		anchored = movement.anchor_system.is_holding_ship

		# the helm only answers while someone is on it, the same gate _process_wheel uses
		wheel_manned = movement.station_controller.get_operator_by_name(&"Wheel") != null
		mast = movement.mast_system.snapshot()
	else:
		angular_acceleration = _estimate_rate(_angular_samples)
		linear_acceleration = _estimate_rate(_speed_samples)

	var states: Array[Dictionary] = []
	var elapsed := 0.0
	var next_sample = sample_step
	var remaining = maxf(seconds, 0.0)

	# the last step is short, so we land exactly on the horizon
	while remaining > 0.0:
		var step = minf(PREDICT_STEP, remaining)
		remaining -= step

		if not exact:
			var max_turn := ShipMovementController.BOAT_TURN_SPEED
			angular_velocity = clampf(angular_velocity + angular_acceleration * step, -max_turn, max_turn)
			speed = clampf(speed + linear_acceleration * step, 0.0, ShipMovementController.MAX_VELOCITY)
		elif anchored:
			angular_velocity = movement.anchor_system.damp(angular_velocity, step, AnchorSystem.ANCHOR_ANGULAR_ACELERATION)
			speed = movement.anchor_system.damp(speed, step, AnchorSystem.ANCHOR_DECELERATION)
		else:
			if wheel_manned:
				wheel = ShipMovementController.advance_wheel(wheel, movement.turn_input, step)

			# the mast moves first and a mast that is not standing furls the sails, in the same
			# order as ShipMovementController
			mast.physics_process(step)

			if mast.sails_locked():
				sail = mast.fold_sails(sail, step)
			else:
				sail = clampf(sail + movement.sail_input * ShipMovementController.SAIL_SPEED * step, 0.0, 100.0)

			angular_velocity = ShipMovementController.wheel_angular_velocity(wheel)
			speed = move_toward(
				speed,
				(sail / 100.0) * ShipMovementController.MAX_VELOCITY,
				ShipMovementController.ACCELERATION * step
			)

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


## Change per second across the whole buffer. Zero until there is something to difference.
func _estimate_rate(samples: Array[float]) -> float:

	if samples.size() < 2:
		return 0.0

	return (samples[-1] - samples[0]) / ((samples.size() - 1) * SAMPLE_INTERVAL)
