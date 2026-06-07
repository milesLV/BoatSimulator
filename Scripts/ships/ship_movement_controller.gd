class_name ShipMovementController
extends RefCounted

const MAX_WHEEL_TURN := 2 * TAU
const WHEEL_TURN_SPEED := 2.0
const BOAT_TURN_SPEED := 1.5

const BASE_SAIL_ANGLE = deg_to_rad(90)
const MAX_SAIL_ANGLE = deg_to_rad(90)
const SAIL_TURN_SPEED := deg_to_rad(60)
const SAIL_SPEED := 40.0

const MAX_VELOCITY := 300.0
const ACCELERATION := 60.0

var ship: CharacterBody2D
var sail: Node2D
var station_controller: ShipStationController
var anchor_system: AnchorSystem

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
	new_anchor_system: AnchorSystem
) -> void:

	ship = new_ship
	sail = new_sail
	station_controller = new_station_controller
	anchor_system = new_anchor_system


func set_input(
	new_turn_input: float,
	new_sail_input: float,
	new_sail_rotation_input: float
) -> void:

	turn_input = new_turn_input
	sail_input = new_sail_input
	sail_rotation_input = new_sail_rotation_input


func reset_input() -> void:

	set_input(
		0.0,
		0.0,
		0.0
	)


func physics_process(delta: float) -> void:

	if ship == null:
		return

	if anchor_system != null:
		anchor_system.physics_process(delta)

	_process_wheel(delta)
	_process_ship_velocity(delta)
	_process_sail_rotation(delta)


func _process_wheel(delta: float) -> void:

	if _has_wheel_operator():
		wheel_rotation += (
			turn_input
			* WHEEL_TURN_SPEED
			* delta
		)

		wheel_rotation = clamp(
			wheel_rotation,
			-MAX_WHEEL_TURN,
			MAX_WHEEL_TURN
		)

	var target_angular_velocity = (
		(wheel_rotation / MAX_WHEEL_TURN)
		* BOAT_TURN_SPEED
	)

	if (
		anchor_system != null
		and anchor_system.locks_steering()
	):
		current_angular_velocity = anchor_system.apply_angular_velocity(
			current_angular_velocity,
			delta
		)
	else:
		current_angular_velocity = target_angular_velocity

	ship.rotation += current_angular_velocity * delta


func _process_ship_velocity(delta: float) -> void:

	sail_length += sail_input * SAIL_SPEED * delta
	sail_length = clamp(
		sail_length,
		0,
		100
	)

	var target_velocity = (
		(sail_length / 100.0)
		* MAX_VELOCITY
	)

	if (
		anchor_system != null
		and anchor_system.affects_ship_movement()
	):
		current_velocity = anchor_system.apply_velocity(
			current_velocity,
			delta
		)
	else:
		current_velocity = move_toward(
			current_velocity,
			target_velocity,
			ACCELERATION * delta
		)

	ship.velocity = Vector2.RIGHT.rotated(
		ship.rotation
	) * current_velocity
	ship.move_and_slide()


func _process_sail_rotation(delta: float) -> void:

	if sail == null:
		return

	sail.rotation += sail_rotation_input * SAIL_TURN_SPEED * delta
	sail.rotation = clamp(
		sail.rotation,
		BASE_SAIL_ANGLE - MAX_SAIL_ANGLE,
		BASE_SAIL_ANGLE + MAX_SAIL_ANGLE
	)


func _has_wheel_operator() -> bool:

	return (
		station_controller != null
		and station_controller.get_operator_by_name(&"Wheel")
		!= null
	)
