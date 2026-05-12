class_name Sloop
extends CharacterBody2D

@onready var sail = $Sail
@onready var helmsman = $Helmsman
@onready var cannoneer = $Cannoneer
@onready var cannons = get_children().filter(func(n): return n is Cannon)

const MAX_WHEEL_TURN := 2 * TAU
const WHEEL_TURN_SPEED := 2.0
const BOAT_TURN_SPEED := 1.5

const BASE_SAIL_ANGLE = deg_to_rad(90)
const MAX_SAIL_ANGLE = deg_to_rad(90)
const SAIL_TURN_SPEED := deg_to_rad(60)
const SAIL_SPEED := 40.0

const MAX_VELOCITY := 300.0
const ACCELERATION := 60.0

var wheel_rotation := 0.0
var sail_length := 0.0
var current_velocity := 0.0

var crewmates: Array = []
var current_crewmate = null
var selected_index := 0
var station_operators := {}

# Inputs
var turn_input := 0.0
var sail_input := 0.0
var sail_rotation_input := 0.0

var other_ships: Array = []
var targetShip: Node = null

func _ready():
	var game_map = get_tree().current_scene
	game_map.register_ship(self)
	crewmates = get_children().filter(func(n): return n is Crewmate)
	current_crewmate = crewmates[0]

	print(
		"Selected:",
		current_crewmate.name
	)
	_initialize_crewmates()
	
	
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
	if get_operator("Wheel") != null:

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


	# SHIP ROTATION (always)
	rotation += (
		(wheel_rotation / MAX_WHEEL_TURN)
		* BOAT_TURN_SPEED
		* delta
	)

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
	sail.rotation += sail_rotation_input * SAIL_TURN_SPEED * delta

	# Clamp relative to base angle
	sail.rotation = clamp(
		sail.rotation,
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

func _initialize_crewmates() -> void:

	helmsman.set_location(
		DeckGraph.UPPER
	)

	cannoneer.set_location(
		DeckGraph.MAIN
	)

func _change_crewmate() -> void:

	selected_index += 1

	selected_index %= crewmates.size()

	current_crewmate = (
		crewmates[selected_index]
	)

	print(
		"Selected:",
		current_crewmate.name
	)

func has_operator(station_id: String) -> bool: # if crewmate crankin' it
	return station_operators.has(station_id)


func get_operator(station_id: String) -> Crewmate:
	return station_operators.get(station_id)


func set_operator(
	station_id: String,
	crewmate: Crewmate
) -> void:

	station_operators[station_id] = crewmate


func clear_operator(
	station_id: String
) -> void:

	station_operators.erase(station_id)

func request_station_control(
	station_id: String,
	operator_deck: String,
	requested_input: float
) -> bool:

	var operator = get_operator(
		station_id
	)

	# Already occupied.
	if operator != null:
		return true

	# No input means no request.
	if requested_input == 0.0:
		return false
	
	if (
		current_crewmate.requested_station
		== station_id
	):
		return false

	# Preempt current station.
	if (
		current_crewmate.action_executor.current_action
		!= null
	):

		current_crewmate.action_executor.interrupt_current()

		current_crewmate.action_executor.clear_queue()

	current_crewmate.requested_station = station_id
	current_crewmate.action_executor.queue_actions(
		ActionBuilder.build_station_control(
			current_crewmate,
			station_id,
			operator_deck
		)
	)


	return false
