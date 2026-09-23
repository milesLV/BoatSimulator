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


static func _static_init() -> void:
	if OS.is_debug_build():
		_self_check()


func _init(new_ship: CharacterBody2D, new_movement: ShipMovementController) -> void:
	ship = new_ship
	movement = new_movement


## The wheel after [param step] seconds of holding [param turn_input]. It stops dead at the
## stops, which is what makes a predicted turn flatten out instead of tightening forever.
static func advance_wheel(wheel: float, turn_input: float, step: float) -> float:

	return clamp(
		wheel + turn_input * ShipMovementController.WHEEL_TURN_SPEED * step,
		-ShipMovementController.MAX_WHEEL_TURN,
		ShipMovementController.MAX_WHEEL_TURN
	)


static func wheel_angular_velocity(wheel: float) -> float:

	return (wheel / ShipMovementController.MAX_WHEEL_TURN) * ShipMovementController.BOAT_TURN_SPEED


func physics_process(delta: float) -> void:

	if movement == null:
		return

	_time_since_sample += delta

	if _time_since_sample < SAMPLE_INTERVAL:
		return

	_time_since_sample = 0.0

	_push_sample(_angular_samples, movement.current_angular_velocity)
	_push_sample(_speed_samples, movement.current_velocity)


## State [param seconds] from now. [param exact] replays the ship's own controls, which is
## only ours to read for the ship the cannon is bolted to.
func at(seconds: float, exact := false) -> Dictionary:

	var states = series(seconds, seconds, exact)

	return states.back() if not states.is_empty() else {
		"position": ship.global_position,
		"rotation": ship.rotation,
	}


## States at every [param sample_step] out to [param seconds], from a single forward
## integration, so scanning a timeline costs one pass rather than one per sample.
func series(seconds: float, sample_step: float, exact := false) -> Array[Dictionary]:

	return _integrate(seconds, sample_step, exact and movement != null)


## One forward integration. [param exact] replays the ship's own controls; otherwise the
## last second of watched motion is differenced into an acceleration and held constant.
func _integrate(seconds: float, sample_step: float, exact: bool) -> Array[Dictionary]:

	var rotation = ship.rotation
	var position = ship.global_position
	var angular_velocity = movement.current_angular_velocity if movement != null else 0.0
	var speed = movement.current_velocity if movement != null else ship.velocity.length()

	var wheel := 0.0
	var sail := 0.0
	var anchored := false
	var wheel_manned := false
	var angular_acceleration := 0.0
	var linear_acceleration := 0.0

	if exact:
		wheel = movement.wheel_rotation
		sail = movement.sail_length
		anchored = movement.anchor_system != null and movement.anchor_system.is_holding_ship

		# the helm only answers while someone is on it, the same gate _process_wheel uses
		wheel_manned = (
			movement.station_controller != null
			and movement.station_controller.get_operator_by_name(&"Wheel") != null
		)
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
			angular_velocity = clamp(
				angular_velocity + angular_acceleration * step,
				-ShipMovementController.BOAT_TURN_SPEED,
				ShipMovementController.BOAT_TURN_SPEED
			)
			speed = clamp(
				speed + linear_acceleration * step,
				0.0,
				ShipMovementController.MAX_VELOCITY
			)
		elif anchored:
			angular_velocity = movement.anchor_system.damp(
				angular_velocity,
				step,
				AnchorSystem.ANCHOR_ANGULAR_ACELERATION
			)
			speed = movement.anchor_system.damp(speed, step, AnchorSystem.ANCHOR_DECELERATION)
		else:
			if wheel_manned:
				wheel = advance_wheel(wheel, movement.turn_input, step)

			sail = clamp(
				sail + movement.sail_input * ShipMovementController.SAIL_SPEED * step,
				0.0,
				100.0
			)

			# omega tracks the wheel directly, so it flattens out when the wheel hits its stop
			angular_velocity = wheel_angular_velocity(wheel)
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


static func _self_check() -> void:

	# holding the helm over ramps the wheel up and then it stops at the stop
	var wheel := 0.0

	for i in 200:
		wheel = advance_wheel(wheel, 1.0, PREDICT_STEP)

	assert(is_equal_approx(wheel, ShipMovementController.MAX_WHEEL_TURN))

	# so the predicted turn flattens out at the ship's top turn rate rather than tightening forever
	assert(is_equal_approx(
		wheel_angular_velocity(wheel),
		ShipMovementController.BOAT_TURN_SPEED
	))

	# a wheel already hard over does not creep past the stop
	assert(is_equal_approx(
		advance_wheel(ShipMovementController.MAX_WHEEL_TURN, 1.0, PREDICT_STEP),
		ShipMovementController.MAX_WHEEL_TURN
	))

	assert(is_zero_approx(wheel_angular_velocity(0.0)))
