extends CharacterBody2D

@export var wheel_speed := 2.0
@export var boat_turn_speed := 1.5
@export var sail_speed := 40.0
@export var max_velocity := 300.0
@export var acceleration := 60.0
@export var sail_turn_speed := deg_to_rad(60)  # degrees/sec → radians

@onready var sail_pivot = $"MastPoint"

const MAX_WHEEL_ROT := 4 * PI
const BASE_SAIL_ANGLE = deg_to_rad(90)
const MAX_SAIL_ANGLE = deg_to_rad(90)

var wheel_rotation := 0.0
var sail_length := 0.0
var current_velocity := 0.0

# Inputs (set externally)
var turn_input := 0.0
var sail_input := 0.0

func _physics_process(delta):
	_process_movement(delta)

func _process_movement(delta):

	# --------------------
	# WHEEL CONTROL
	# --------------------
	wheel_rotation += turn_input * wheel_speed * delta
	wheel_rotation = clamp(wheel_rotation, -MAX_WHEEL_ROT, MAX_WHEEL_ROT)

	rotation += (wheel_rotation / MAX_WHEEL_ROT) * boat_turn_speed * delta

	# --------------------
	# SAIL CONTROL
	# --------------------
	sail_length += sail_input * sail_speed * delta
	sail_length = clamp(sail_length, 0, 100)

	# --------------------
	# SPEED CONTROL
	# --------------------
	var target_velocity = (sail_length / 100.0) * max_velocity

	if current_velocity < target_velocity:
		current_velocity += acceleration * delta
	elif current_velocity > target_velocity:
		current_velocity -= acceleration * delta

	# --------------------
	# MOVE SHIP
	# --------------------
	velocity = Vector2.RIGHT.rotated(rotation) * current_velocity
	move_and_slide()
	
		# --------------------
	# SAIL ROTATION (LEFT / RIGHT)
	# --------------------
	var sail_rotation_input = 0.0

	if Input.is_action_pressed("adjustSailLeft"):
		sail_rotation_input -= 1.0
	if Input.is_action_pressed("adjustSailRight"):
		sail_rotation_input += 1.0

	# Apply input
	sail_pivot.rotation += sail_rotation_input * sail_turn_speed * delta

	# Clamp relative to base angle
	sail_pivot.rotation = clamp(
		sail_pivot.rotation,
		BASE_SAIL_ANGLE - MAX_SAIL_ANGLE,
		BASE_SAIL_ANGLE + MAX_SAIL_ANGLE
	)
