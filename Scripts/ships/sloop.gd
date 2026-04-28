class_name Sloop
extends CharacterBody2D

@onready var sail_pivot = $"MastPoint"
@onready var cannons = [
	$"CannonPort1",
	$"CannonStarboard1"
]

const MAX_WHEEL_TURN := 2 * TAU
const WHEEL_TURN_SPEED := 2.0
const BOAT_TURN_SPEED := 1.5

const BASE_SAIL_ANGLE = deg_to_rad(90)
const MAX_SAIL_ANGLE = deg_to_rad(89)
const SAIL_TURN_SPEED := deg_to_rad(60)
const SAIL_SPEED := 40.0

const MAX_VELOCITY := 300.0
const ACCELERATION := 60.0

var wheel_rotation := 0.0
var sail_length := 0.0
var current_velocity := 0.0

# Inputs (set externally)
var turn_input := 0.0
var sail_input := 0.0
var sail_rotation_input := 0.0

var other_ships: Array = []
var targetShip: Node = null

func _ready():
	var game_map = get_tree().current_scene
	game_map.register_ship(self)
	
	await get_tree().process_frame
	
	_initialize_other_ships()
	
	if other_ships.size() > 0:
		targetShip = other_ships[0] # initial target
	else:
		targetShip = null

func _exit_tree():
	var game_map = get_tree().current_scene
	game_map.unregister_ship(self)

func _physics_process(delta):
	_process_movement(delta)
	update_active_cannon()

func _process_movement(delta):

	# WHEEL CONTROL
	wheel_rotation += turn_input * WHEEL_TURN_SPEED * delta
	wheel_rotation = clamp(wheel_rotation, -MAX_WHEEL_TURN, MAX_WHEEL_TURN)

	rotation += (wheel_rotation / MAX_WHEEL_TURN) * BOAT_TURN_SPEED * delta

	# SAIL CONTROL
	sail_length += sail_input * SAIL_SPEED * delta
	sail_length = clamp(sail_length, 0, 100)

	# SPEED CONTROL
	var target_velocity = (sail_length / 100.0) * MAX_VELOCITY

	if current_velocity < target_velocity:
		current_velocity += ACCELERATION * delta
	elif current_velocity > target_velocity:
		current_velocity -= ACCELERATION * delta

	# MOVE SHIP
	velocity = Vector2.RIGHT.rotated(rotation) * current_velocity
	move_and_slide()
	
	# SAIL ROTATION (LEFT / RIGHT)
	sail_pivot.rotation += sail_rotation_input * SAIL_TURN_SPEED * delta

	# Clamp relative to base angle
	sail_pivot.rotation = clamp(
		sail_pivot.rotation,
		BASE_SAIL_ANGLE - MAX_SAIL_ANGLE,
		BASE_SAIL_ANGLE + MAX_SAIL_ANGLE
	)

func _initialize_other_ships():
	var game_map = get_tree().current_scene
	
	other_ships.clear()
	
	for ship in game_map.ships:
		if ship != self:
			other_ships.append(ship)
			
func update_active_cannon():

	if targetShip == null or not is_instance_valid(targetShip):
		return
	
	var closest_cannon = null
	var closest_dist = INF

	for cannon in cannons:
		var dist = cannon.global_position.distance_to(targetShip.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_cannon = cannon

	#if closest_cannon != null:
		#print("Active cannon:", closest_cannon.name)

	# Assigning which cannon is closest
	for cannon in cannons:
		if cannon == closest_cannon:
			cannon.is_actively_tracking = true
			cannon.target_global = targetShip
		else:
			cannon.is_actively_tracking = false
			cannon.target_global = null
