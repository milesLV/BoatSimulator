class_name Sloop
extends CharacterBody2D

@onready var action_points_path: NodePath = ^"ShipActionPoints"
@onready var sail = $Sail
@onready var helmsman = $Helmsman
@onready var cannoneer = $Cannoneer
@onready var action_points: ShipActionPointContainer = get_node_or_null(
	action_points_path
)
@onready var cannons = get_children().filter(func(n): return n is Cannon)
@onready var action_planner: ShipActionPlanner
@onready var station_controller: ShipStationController
@onready var cannon_director: ShipCannonDirector
@onready var cannon_duty_controller: ShipCannonDutyController


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
var current_angular_velocity := 0.0
var anchor_system: AnchorSystem

var crewmates: Array = []
var current_crewmate = null
var selected_index := 0

# Inputs
var turn_input := 0.0
var sail_input := 0.0
var sail_rotation_input := 0.0

func _ready():
	var game_map = get_tree().current_scene

	if action_points == null:
		push_error(
			"Sloop requires a ShipActionPointContainer at %s."
			% action_points_path
		)
		return

	anchor_system = AnchorSystem.new(
		self
	)

	action_planner = ShipActionPlanner.new(
		action_points
	)

	station_controller = ShipStationController.new(
		action_points,
		action_planner
	)

	cannon_director = ShipCannonDirector.new(
		self,
		cannons
	)

	cannon_duty_controller = ShipCannonDutyController.new(
		self,
		action_points,
		station_controller,
		action_planner,
		cannon_director
	)

	if (
		game_map != null
		and game_map.has_method(
			"register_ship"
		)
	):
		game_map.register_ship(self)

	crewmates = get_children().filter(func(n): return n is Crewmate)
	current_crewmate = crewmates[0]

	print(
		"Selected:",
		current_crewmate.name
	)
	_initialize_crewmates()
	
	
	await get_tree().process_frame

	var target_ships: Array = []

	if (
		game_map != null
		and game_map.has_method(
			"get_other_ships"
		)
	):
		target_ships = game_map.get_other_ships(
			self
		)
	elif game_map != null:
		var ships_property = game_map.get(
			"ships"
		)

		if ships_property is Array:
			target_ships = ships_property

	cannon_director.refresh_targets(
		target_ships
	)

func _exit_tree():
	var game_map = get_tree().current_scene

	if (
		game_map != null
		and game_map.has_method(
			"unregister_ship"
		)
	):
		game_map.unregister_ship(self)

func _physics_process(delta):
	_process_movement(delta)
	update_active_cannon()

func get_action_points() -> ShipActionPointContainer:

	if action_points == null:
		action_points = get_node_or_null(
			action_points_path
		)

	return action_points

func _process_movement(delta):
	if anchor_system != null:
		anchor_system.physics_process(
			delta
		)

	# WHEEL CONTROL
	if (
		station_controller.get_operator_by_name(
			&"Wheel"
		)
		!= null
	):

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

	rotation += current_angular_velocity * delta

	# SAIL CONTROL
	sail_length += sail_input * SAIL_SPEED * delta
	sail_length = clamp(sail_length, 0, 100)

	# SPEED CONTROL
	var target_velocity = (sail_length / 100.0) * MAX_VELOCITY

	if (
		anchor_system != null
		and anchor_system.affects_ship_movement()
	):
		current_velocity = anchor_system.apply_velocity(
			current_velocity,
			delta
		)
	elif current_velocity < target_velocity:
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

func update_active_cannon():

	if cannon_director == null:
		return

	var tracking_enabled = (
		cannon_duty_controller != null
		and cannon_duty_controller.has_duty_crewmate()
	)

	cannon_director.update_active_cannon(
		tracking_enabled
	)

	if cannon_duty_controller != null:
		cannon_duty_controller.update()

func _initialize_crewmates() -> void:

	helmsman.set_location(
		DeckGraph.DECKS.UPPER
	)

	cannoneer.set_location(
		DeckGraph.DECKS.MAIN
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


func is_crewmate_selected(
	_crewmate: Crewmate
) -> bool:

	return false

func request_station_control(
	station_name: StringName,
	requested_input: float
) -> bool:

	return station_controller.request_station_control(
		current_crewmate,
		station_name,
		requested_input
	)


func request_anchor_drop() -> bool:

	if (
		current_crewmate == null
		or action_planner == null
	):
		return false

	var actions = action_planner.build_drop_anchor(
		current_crewmate
	)

	return _queue_current_crewmate_actions(
		actions
	)


func request_anchor_raise() -> bool:

	if (
		current_crewmate == null
		or action_planner == null
	):
		return false

	var actions = action_planner.build_raise_anchor(
		current_crewmate
	)

	return _queue_current_crewmate_actions(
		actions
	)


func request_anchor_toggle() -> bool:

	if anchor_system == null:
		return false

	if anchor_system.can_drop():
		return request_anchor_drop()

	if anchor_system.can_raise():
		return request_anchor_raise()

	return false


func request_current_cannon_duty() -> bool:

	return request_cannon_duty_for(
		current_crewmate
	)


func request_cannon_duty_for(
	crewmate: Crewmate
) -> bool:

	if (
		crewmate == null
		or cannon_duty_controller == null
	):
		return false

	return cannon_duty_controller.assign_crewmate(
		crewmate
	)


func request_cancel_action() -> bool:

	if current_crewmate == null:
		return false

	if (
		cannon_duty_controller != null
		and cannon_duty_controller.is_duty_crewmate(
			current_crewmate
		)
	):
		var cleared_duty = cannon_duty_controller.clear_assignment()

		if cleared_duty:
			return true

	current_crewmate.requested_station = null

	if (
		current_crewmate.action_executor != null
		and current_crewmate.action_executor.has_actions()
	):
		current_crewmate.action_executor.cancel_plan()

		if station_controller != null:
			station_controller.detach_crewmate(
				current_crewmate
			)

		return true

	if station_controller != null:
		var detached = station_controller.detach_crewmate(
			current_crewmate
		)

		if detached:
			return true

	return _request_passive_decay_cancel()


func _queue_current_crewmate_actions(
	actions: Array
) -> bool:

	if (
		current_crewmate == null
		or actions.is_empty()
	):
		return false

	_clear_cannon_duty_for_current_crewmate()

	current_crewmate.requested_station = null
	current_crewmate.action_executor.cancel_plan()
	current_crewmate.action_executor.queue_actions(
		actions
	)

	return true


func _request_passive_decay_cancel() -> bool:

	if (
		anchor_system != null
		and anchor_system.is_passive_decay_active()
	):
		return request_anchor_raise()

	return false


func _clear_cannon_duty_for_current_crewmate() -> void:

	if (
		current_crewmate == null
		or cannon_duty_controller == null
		or not cannon_duty_controller.is_duty_crewmate(
			current_crewmate
		)
	):
		return

	cannon_duty_controller.clear_assignment()
