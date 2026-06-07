class_name Sloop
extends CharacterBody2D

@onready var action_points_path: NodePath = ^"ShipActionPoints"
@onready var sail = $Sail
@onready var helmsman = $Helmsman
@onready var cannoneer = $Cannoneer
@onready var action_points: ShipActionPointContainer = get_node_or_null(action_points_path)
@onready var cannons = get_children().filter(func(n): return n is Cannon)

var anchor_system: AnchorSystem
var action_planner: ShipActionPlanner
var station_controller: ShipStationController
var cannon_director: ShipCannonDirector
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController
var movement_controller: ShipMovementController
var crew_controller: ShipCrewController
var crew_command_controller: ShipCrewCommandController
var crew_task_controller: ShipCrewTaskController
var health_system: ShipHealthSystem


func _ready() -> void:

	if not _validate_action_points():
		return

	_create_systems()
	_register_with_game_map()
	_initialize_crew()
	await _refresh_cannon_targets_deferred()


func _exit_tree() -> void:

	var game_map = get_tree().current_scene

	if (
		game_map != null
		and game_map.has_method("unregister_ship")
	):
		game_map.unregister_ship(self)


func _physics_process(delta: float) -> void:

	_process_health(delta)

	if is_sunk():
		return

	_process_movement(delta)
	update_cannon_systems()


func get_action_points() -> ShipActionPointContainer:

	if action_points == null:
		action_points = get_node_or_null(action_points_path)

	return action_points


func set_movement_input(
	turn: float,
	sail_length: float,
	sail_rotation: float
) -> void:

	if (
		movement_controller == null
		or is_sunk()
	):
		return

	movement_controller.set_input(
		turn,
		sail_length,
		sail_rotation
	)


func reset_movement_input() -> void:

	if movement_controller == null:
		return

	movement_controller.reset_input()


func get_current_crewmate() -> Crewmate:

	if crew_controller == null:
		return null

	return crew_controller.get_current_crewmate()


func get_crewmates() -> Array[Crewmate]:

	if crew_controller == null:
		return []

	return crew_controller.get_crewmates()


func change_crewmate() -> Crewmate:

	if crew_controller == null:
		return null

	return crew_controller.change_crewmate()


func is_crewmate_selected(crewmate: Crewmate) -> bool:

	if crew_controller == null:
		return false

	return crew_controller.is_selected(
		crewmate
	)


func request_station_control(
	station_name: StringName,
	requested_input: float
) -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_station_control(
		station_name,
		requested_input
	)


func request_anchor_drop() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_anchor_drop()


func request_anchor_raise() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_anchor_raise()


func request_anchor_toggle() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_anchor_toggle()


func request_bail_water() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_bail_water()


func request_repair_ship() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_repair_ship()


func request_current_cannon_duty() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_current_cannon_duty()


func request_cannon_duty_for(crewmate: Crewmate) -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_cannon_duty_for(
		crewmate
	)


func request_cancel_action() -> bool:

	if (
		crew_command_controller == null
		or is_sunk()
	):
		return false

	return crew_command_controller.request_cancel_action()


func update_cannon_systems() -> void:

	if (
		cannon_director == null
		or is_sunk()
	):
		return

	var tracking_enabled = (
		cannon_duty_controller != null
		and cannon_duty_controller.has_duty_crewmate()
	)

	cannon_director.update_active_cannon(tracking_enabled)

	if cannon_duty_controller != null:
		cannon_duty_controller.update()


func update_active_cannon() -> void:

	update_cannon_systems()


func _process_movement(delta: float) -> void:

	if (
		movement_controller == null
		or is_sunk()
	):
		return

	movement_controller.physics_process(delta)


func _process_health(delta: float) -> void:

	if health_system == null:
		return

	health_system.physics_process(delta)


func apply_cannonball_hit(
	hit_position: Vector2,
	hole_damage: int
) -> bool:

	if (
		health_system == null
		or is_sunk()
	):
		return false

	return health_system.apply_cannonball_hit(
		hit_position,
		hole_damage
	)


func get_water_level() -> float:

	if health_system == null:
		return 0.0

	return health_system.get_water_level()


func is_sunk() -> bool:
	return (
		health_system != null
		and health_system.is_sunk()
	)


func on_sunk() -> void:

	reset_movement_input()

	if cannon_director != null:
		cannon_director.clear_active_cannons()

	if cannon_duty_controller != null:
		cannon_duty_controller.clear_assignment()

	if repair_duty_controller != null:
		repair_duty_controller.clear_all()

	if station_controller != null:
		for crewmate in get_crewmates():
			station_controller.detach_crewmate(crewmate)

	for crewmate in get_crewmates():
		crewmate.requested_station = null

		if crewmate.action_executor != null:
			crewmate.action_executor.cancel_plan()


func _validate_action_points() -> bool:

	if action_points != null:
		return true

	push_error(
		"Sloop requires a ShipActionPointContainer at %s."
		% action_points_path
	)

	return false


func _create_systems() -> void:

	anchor_system = AnchorSystem.new(self)

	health_system = ShipHealthSystem.new(
		self,
		action_points
	)

	action_planner = ShipActionPlanner.new(action_points)

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

	repair_duty_controller = ShipRepairDutyController.new(
		self,
		action_points,
		action_planner
	)

	crew_task_controller = ShipCrewTaskController.new(
		station_controller,
		cannon_duty_controller,
		repair_duty_controller
	)

	station_controller.set_task_controller(crew_task_controller)
	cannon_duty_controller.set_task_controller(crew_task_controller)
	repair_duty_controller.set_task_controller(crew_task_controller)

	movement_controller = ShipMovementController.new(
		self,
		sail,
		station_controller,
		anchor_system
	)

	crew_controller = ShipCrewController.new(self)

	crew_command_controller = ShipCrewCommandController.new(
		crew_controller,
		action_planner,
		station_controller,
		cannon_duty_controller,
		repair_duty_controller,
		anchor_system,
		crew_task_controller
	)


func _register_with_game_map() -> void:

	var game_map = get_tree().current_scene

	if (
		game_map != null
		and game_map.has_method("register_ship")
	):
		game_map.register_ship(self)


func _initialize_crew() -> void:

	if crew_controller == null:
		return

	crew_controller.initialize()


func _refresh_cannon_targets_deferred() -> void:

	await get_tree().process_frame

	if cannon_director == null:
		return

	cannon_director.refresh_targets(_get_target_ships())


func _get_target_ships() -> Array:

	var game_map = get_tree().current_scene

	if game_map == null:
		return []

	if game_map.has_method(
		"get_other_ships"
	):
		return game_map.get_other_ships(
			self
		)

	var ships_property = game_map.get("ships")

	if ships_property is Array:
		return ships_property

	return []
