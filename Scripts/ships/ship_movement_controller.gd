class_name ShipMovementController
extends RefCounted

const MAX_WHEEL_TURN := 2 * TAU
const WHEEL_TURN_SPEED := 2.0
## Turn speed each open wheel hole takes off: WHEEL_TURN_SPEED / 8, so four holes halve it.
const WHEEL_DAMAGE_SLOWDOWN := 0.25
const BOAT_TURN_SPEED := 1.5

const BASE_SAIL_ANGLE = deg_to_rad(90)
const SAIL_TURN_SPEED := deg_to_rad(60)
const SAIL_SPEED := 40.0

const MAX_VELOCITY := 300.0
const ACCELERATION := 60.0

var ship: Sloop

var wheel_rotation := 0.0
var sail_length := 0.0
var current_velocity := 0.0
var current_angular_velocity := 0.0

var turn_input := 0.0
var sail_input := 0.0
var sail_rotation_input := 0.0


func _init(new_ship: Sloop) -> void:

	ship = new_ship


## Clamped at the stops, so a held turn flattens out instead of tightening forever.
static func advance_wheel(wheel: float, turn: float, step: float, damage := 0) -> float:

	return clamp(wheel + turn * (WHEEL_TURN_SPEED - damage * WHEEL_DAMAGE_SLOWDOWN) * step, -MAX_WHEEL_TURN, MAX_WHEEL_TURN)


func wheel_damage() -> int:

	return ship.action_points.wheel_holes.filter(func(hole): return hole.grade > 0).size()


static func advance_sail(sail: float, input: float, mast: MastSystem, step: float) -> float:

	return mast.fold_sails(sail, step) if mast.sails_locked() else clampf(sail + input * SAIL_SPEED * step, 0.0, 100.0)


static func advance_speed(speed: float, sail: float, step: float) -> float:

	return move_toward(speed, sail / 100.0 * MAX_VELOCITY, ACCELERATION * step)


## Omega is read straight off the wheel: the ship has no angular inertia of its own.
static func wheel_angular_velocity(wheel: float) -> float:

	return wheel / MAX_WHEEL_TURN * BOAT_TURN_SPEED


func set_input(
	new_turn_input: float,
	new_sail_input: float,
	new_sail_rotation_input: float
) -> void:

	turn_input = new_turn_input
	sail_input = new_sail_input
	sail_rotation_input = new_sail_rotation_input


func physics_process(delta: float) -> void:

	ship.anchor_system.physics_process(delta)

	ship.mast_system.physics_process(delta)

	_process_wheel(delta)
	_process_ship_velocity(delta)
	ship.sail.rotation = clampf(ship.sail.rotation + sail_rotation_input * SAIL_TURN_SPEED * delta, 0.0, 2.0 * BASE_SAIL_ANGLE)


func _process_wheel(delta: float) -> void:

	if ship.station_controller.get_operator_by_name(&"Wheel") != null:
		wheel_rotation = advance_wheel(wheel_rotation, turn_input, delta, wheel_damage())

	current_angular_velocity = (
		ship.anchor_system.damp(current_angular_velocity, delta, AnchorSystem.ANCHOR_ANGULAR_ACELERATION)
		if ship.anchor_system.is_holding_ship
		else wheel_angular_velocity(wheel_rotation)
	)

	ship.rotation += current_angular_velocity * delta


func _process_ship_velocity(delta: float) -> void:

	sail_length = advance_sail(sail_length, sail_input, ship.mast_system, delta)

	current_velocity = (
		ship.anchor_system.damp(current_velocity, delta, AnchorSystem.ANCHOR_DECELERATION)
		if ship.anchor_system.is_holding_ship
		else advance_speed(current_velocity, sail_length, delta)
	)

	ship.velocity = Vector2.RIGHT.rotated(ship.rotation) * current_velocity
	ship.move_and_slide()
