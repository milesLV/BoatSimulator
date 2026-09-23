class_name Sloop
extends CharacterBody2D

const SINK_FADE_DURATION := 7.0
const ACTION_POINTS_PATH: NodePath = ^"ShipActionPoints"

@onready var sail = $Sail
@onready var helmsman = $Helmsman
@onready var cannoneer = $Cannoneer
@onready var action_points: ShipActionPointContainer = get_node_or_null(ACTION_POINTS_PATH)
@onready var cannons = get_children().filter(func(n): return n is Cannon)

var anchor_system: AnchorSystem
var motion_predictor: ShipMotionPredictor
var action_planner: ShipActionPlanner
var station_controller: ShipStationController
var cannon_director: ShipCannonDirector
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController
var movement_controller: ShipMovementController
var crew_controller: ShipCrewController
var crew_task_controller: ShipCrewTaskController
var health_system: ShipHealthSystem
var sink_fade_elapsed := 0.0
var sink_fade_active := false


func _ready() -> void:

	if action_points == null:
		push_error(
			"Sloop requires a ShipActionPointContainer at %s."
			% ACTION_POINTS_PATH
		)

		return

	_create_systems()

	var registry := GlobalShipRegistry.from_tree(get_tree())

	if registry != null:
		registry.register_ship(self)

	crew_controller.initialize()
	await _refresh_cannon_targets_deferred()


func _exit_tree() -> void:

	_unregister_from_game_map()


func _unregister_from_game_map() -> void:

	var registry := GlobalShipRegistry.from_tree(get_tree())

	if registry != null:
		registry.ships.erase(self)


func _physics_process(delta: float) -> void:

	_process_health(delta)
	_process_sink_fade(delta)

	if motion_predictor != null:
		motion_predictor.physics_process(delta)

	if is_sunk() or not _control(delta):
		return

	_process_movement(delta)
	update_cannon_systems()


## Where each ship decides what it wants this frame: the player reads the
## keyboard, the enemy chases. False skips movement and cannons this frame.
func _control(_delta: float) -> bool:

	return true


func set_movement_input(turn: float, sail_length: float, sail_rotation: float) -> void:
	if movement_controller == null or is_sunk():
		return

	movement_controller.set_input(turn, sail_length, sail_rotation)


func reset_movement_input() -> void:

	if movement_controller == null:
		return

	movement_controller.set_input(0.0, 0.0, 0.0)


func get_current_crewmate() -> Crewmate:

	return crew_controller.get_current_crewmate()


func get_crewmates() -> Array[Crewmate]:

	return crew_controller.get_crewmates()


func change_crewmate() -> Crewmate:

	return crew_controller.change_crewmate()


func is_crewmate_selected(crewmate: Crewmate) -> bool:

	return crewmate != null and crew_controller.current_crewmate == crewmate


## Every crew request shares the same gate, so they go through one door.
func request(method: StringName, args: Array = []) -> bool:

	if crew_task_controller == null or is_sunk():
		return false

	return crew_task_controller.callv(method, args)


func update_cannon_systems() -> void:

	if cannon_director == null or is_sunk():
		return

	var tracking_enabled = (
		cannon_duty_controller != null
		and cannon_duty_controller.has_duty_crewmate()
	)

	cannon_director.update_active_cannon(tracking_enabled)

	if cannon_duty_controller != null:
		cannon_duty_controller.update()


func _process_movement(delta: float) -> void:

	if movement_controller == null or is_sunk():
		return

	movement_controller.physics_process(delta)


func _process_health(delta: float) -> void:

	if health_system == null:
		return

	health_system.physics_process(delta)


func apply_cannonball_hit(hit_position: Vector2, hole_damage: int) -> ShipHolePoint:

	if health_system == null or is_sunk():
		return null

	return health_system.apply_cannonball_hit(hit_position, hole_damage)


func apply_mast_hit(from: Vector2, to: Vector2) -> bool:

	if health_system == null or is_sunk():
		return false

	return health_system.apply_mast_hit(from, to)


func is_sunk() -> bool:
	return health_system != null and health_system.sunk_state


func on_sunk() -> void:

	_unregister_from_game_map()
	reset_movement_input()

	if not sink_fade_active:
		sink_fade_active = true
		sink_fade_elapsed = 0.0

	for cannon in cannons:
		cannon.range_area.hide()

	if cannon_director != null:
		cannon_director.clear_active_cannons()

	if cannon_duty_controller != null:
		cannon_duty_controller.clear_assignment()

	if repair_duty_controller != null:
		repair_duty_controller.clear_all()

	for crewmate in get_crewmates():
		crew_task_controller.clear_station_and_actions(crewmate)


func _process_sink_fade(delta: float) -> void:

	if not sink_fade_active:
		return

	sink_fade_elapsed = min(sink_fade_elapsed + delta, SINK_FADE_DURATION)

	modulate.a = lerp(1.0, 0.05, sink_fade_elapsed / SINK_FADE_DURATION)

	if sink_fade_elapsed < SINK_FADE_DURATION:
		return

	sink_fade_active = false
	collision_layer = 0
	collision_mask = 0


func _create_systems() -> void:

	anchor_system = AnchorSystem.new(self)

	health_system = ShipHealthSystem.new(self, action_points)

	action_planner = ShipActionPlanner.new(action_points)

	station_controller = ShipStationController.new(action_points, action_planner)

	cannon_director = ShipCannonDirector.new(self, cannons)

	cannon_duty_controller = ShipCannonDutyController.new(
		self,
		action_points,
		station_controller,
		action_planner,
		cannon_director
	)

	repair_duty_controller = ShipRepairDutyController.new(self, action_points, action_planner)

	crew_controller = ShipCrewController.new(self)

	crew_task_controller = ShipCrewTaskController.new(
		crew_controller,
		station_controller,
		cannon_duty_controller,
		repair_duty_controller,
		action_planner,
		anchor_system
	)

	station_controller.crew_task_controller = crew_task_controller
	cannon_duty_controller.crew_task_controller = crew_task_controller
	repair_duty_controller.crew_task_controller = crew_task_controller

	movement_controller = ShipMovementController.new(self, sail, station_controller, anchor_system)

	motion_predictor = ShipMotionPredictor.new(self, movement_controller)


func _refresh_cannon_targets_deferred() -> void:

	await get_tree().process_frame

	if cannon_director == null:
		return

	var registry := GlobalShipRegistry.from_tree(get_tree())

	cannon_director.refresh_targets(registry.get_other_ships(self) if registry != null else [])
