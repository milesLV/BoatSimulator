class_name Sloop
extends CharacterBody2D

const SINK_FADE_DURATION := 7.0

@onready var sail: Sprite2D = $Sail
@onready var action_points: ShipActionPointContainer = $ShipActionPoints
@onready var cannons = get_children().filter(func(n): return n is Cannon)

var anchor_system: AnchorSystem
var mast_system: MastSystem
var motion_predictor: ShipMotionPredictor
var action_planner: ShipActionPlanner
var station_controller: ShipStationController
var cannon_director: ShipCannonDirector
var cannon_duty_controller: ShipCannonDutyController
var repair_duty_controller: ShipRepairDutyController
var movement_controller: ShipMovementController
var crew_task_controller: ShipCrewTaskController
var health_system: ShipHealthSystem
var sink_fade_elapsed := 0.0
var crewmates: Array[Crewmate] = []
var current_crewmate: Crewmate


func _ready() -> void:

	_create_systems()

	var registry := GlobalShipRegistry.from_tree(get_tree())

	if registry != null:
		registry.ships.append(self)

	crewmates.assign(get_children().filter(func(child): return child is Crewmate))
	current_crewmate = crewmates[0]
	ShipDebugLog.write(&"crew", "Selected: %s" % current_crewmate.name)
	$Helmsman.set_location(DeckGraph.DECKS.UPPER)
	$Cannoneer.set_location(DeckGraph.DECKS.MAIN)

	# every ship registers in its own _ready, so wait a frame for the rest
	await get_tree().process_frame

	cannon_director.refresh_targets(registry.ships if registry != null else [])


func _exit_tree() -> void:

	_unregister_from_game_map()


func _unregister_from_game_map() -> void:

	var registry := GlobalShipRegistry.from_tree(get_tree())

	if registry != null:
		registry.ships.erase(self)


func _physics_process(delta: float) -> void:

	health_system.physics_process(delta)
	_process_sink_fade(delta)
	motion_predictor.physics_process(delta)

	if is_sunk() or not _control():
		return

	movement_controller.physics_process(delta)
	cannon_director.update_active_cannon(cannon_duty_controller.has_duty_crewmate())
	cannon_duty_controller.update()


## False skips movement and cannons this frame.
func _control() -> bool:

	return true


func set_movement_input(turn: float, sail_length: float, sail_rotation: float) -> void:

	movement_controller.set_input(turn, sail_length, sail_rotation)


func change_crewmate() -> void:

	current_crewmate = crewmates[(crewmates.find(current_crewmate) + 1) % crewmates.size()]
	ShipDebugLog.write(&"crew", "Selected: %s" % current_crewmate.name)


func request(method: StringName, args: Array = []) -> bool:

	if is_sunk():
		return false

	return crew_task_controller.callv(method, args)


func apply_cannonball_hit(hit_position: Vector2, hole_damage: int) -> ShipHolePoint:

	return null if is_sunk() else health_system.apply_cannonball_hit(hit_position, hole_damage)


func apply_mast_hit(from: Vector2, to: Vector2, holes := 1, reach := 0.0) -> bool:

	return not is_sunk() and health_system.apply_mast_hit(from, to, holes, reach)


func apply_wheel_hit(from: Vector2, to: Vector2, holes := 1, reach := 0.0) -> bool:

	return not is_sunk() and health_system.apply_wheel_hit(from, to, holes, reach)


func is_sunk() -> bool:
	return health_system != null and health_system.sunk_state


func on_sunk() -> void:

	_unregister_from_game_map()
	set_movement_input(0.0, 0.0, 0.0)

	for cannon in cannons:
		cannon.range_area.hide()

	cannon_director.clear_active_cannons()
	cannon_duty_controller.clear_assignment()
	repair_duty_controller.clear_all()

	for crewmate in crewmates:
		crew_task_controller.clear_station_and_actions(crewmate)


func _process_sink_fade(delta: float) -> void:

	if not is_sunk() or sink_fade_elapsed >= SINK_FADE_DURATION:
		return

	sink_fade_elapsed = min(sink_fade_elapsed + delta, SINK_FADE_DURATION)

	modulate.a = lerp(1.0, 0.05, sink_fade_elapsed / SINK_FADE_DURATION)

	if sink_fade_elapsed < SINK_FADE_DURATION:
		return

	collision_layer = 0
	collision_mask = 0


func _create_systems() -> void:

	anchor_system = AnchorSystem.new()

	mast_system = MastSystem.new(action_points.mast_holes)

	health_system = ShipHealthSystem.new(self, action_points)

	action_planner = ShipActionPlanner.new(action_points)

	station_controller = ShipStationController.new(self)

	cannon_director = ShipCannonDirector.new(self, cannons)

	cannon_duty_controller = ShipCannonDutyController.new(self)

	repair_duty_controller = ShipRepairDutyController.new(self)

	crew_task_controller = ShipCrewTaskController.new(self)

	movement_controller = ShipMovementController.new(self)

	motion_predictor = ShipMotionPredictor.new(self, movement_controller)
