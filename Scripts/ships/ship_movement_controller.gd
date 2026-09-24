class_name ShipMovementController
extends RefCounted

const MAX_WHEEL_TURN := 2 * TAU
const WHEEL_TURN_SPEED := 2.0
const BOAT_TURN_SPEED := 1.5

const BASE_SAIL_ANGLE = deg_to_rad(90)
const SAIL_TURN_SPEED := deg_to_rad(60)
const SAIL_SPEED := 40.0

const MAX_VELOCITY := 300.0
const ACCELERATION := 60.0

var ship: CharacterBody2D
var sail: Node2D
var station_controller: ShipStationController
var anchor_system: AnchorSystem
var mast_system: MastSystem

var wheel_rotation := 0.0
var sail_length := 0.0
var current_velocity := 0.0
var current_angular_velocity := 0.0

var turn_input := 0.0
var sail_input := 0.0
var sail_rotation_input := 0.0


func _init(
	new_ship: CharacterBody2D,
	new_sail: Node2D,
	new_station_controller: ShipStationController,
	new_anchor_system: AnchorSystem,
	new_mast_system: MastSystem
) -> void:

	ship = new_ship
	sail = new_sail
	station_controller = new_station_controller
	anchor_system = new_anchor_system
	mast_system = new_mast_system


## The wheel after [param step] seconds of holding [param turn]. It stops dead at the
## stops, which is what makes a turn flatten out instead of tightening forever.
static func advance_wheel(wheel: float, turn: float, step: float) -> float:

	return clamp(wheel + turn * WHEEL_TURN_SPEED * step, -MAX_WHEEL_TURN, MAX_WHEEL_TURN)


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

	anchor_system.physics_process(delta)

	# sail input only arrives from a crewmate on the station, so this is them hauling on it
	mast_system.physics_process(delta)

	_process_wheel(delta)
	_process_ship_velocity(delta)
	_process_sail_rotation(delta)


func _process_wheel(delta: float) -> void:

	if station_controller.get_operator_by_name(&"Wheel") != null:
		wheel_rotation = advance_wheel(wheel_rotation, turn_input, delta)

	current_angular_velocity = (
		anchor_system.damp(current_angular_velocity, delta, AnchorSystem.ANCHOR_ANGULAR_ACELERATION)
		if anchor_system.is_holding_ship
		else wheel_angular_velocity(wheel_rotation)
	)

	ship.rotation += current_angular_velocity * delta


func _process_ship_velocity(delta: float) -> void:

	if mast_system.sails_locked():
		sail_length = mast_system.fold_sails(sail_length, delta)
	else:
		sail_length = clampf(sail_length + sail_input * SAIL_SPEED * delta, 0.0, 100.0)

	var target_velocity = sail_length / 100.0 * MAX_VELOCITY

	current_velocity = (
		anchor_system.damp(current_velocity, delta, AnchorSystem.ANCHOR_DECELERATION)
		if anchor_system.is_holding_ship
		else move_toward(current_velocity, target_velocity, ACCELERATION * delta)
	)

	ship.velocity = Vector2.RIGHT.rotated(ship.rotation) * current_velocity
	ship.move_and_slide()


func _process_sail_rotation(delta: float) -> void:

	sail.rotation = clampf(sail.rotation + sail_rotation_input * SAIL_TURN_SPEED * delta, 0.0, 2.0 * BASE_SAIL_ANGLE)
