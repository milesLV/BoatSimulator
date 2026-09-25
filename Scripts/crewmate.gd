class_name Crewmate
extends Node2D

const RUN_SPEED := 100.0
const DEFAULT_ACTION_IDLE_DELAY := 3.0
const MAX_BUCKET_AMOUNT := 50.0
const SAIL_CONTACT_ALPHA := 0.50

@export var default_station_name: StringName
@export var defaults_to_cannon_duty := false

@onready var action_executor = $ActionExecutor
@onready var ship: Sloop = get_parent()
@onready var body = $Body

var location := -1
var bucket_amount := 0.0
var aim_target := Cannon.AimTarget.WHEEL # TODO: back to HULL after wheel-damage testing
var ammo := Ammunition.CANNONBALL
var _idle_time := 0.0

func _ready() -> void:

	await get_tree().process_frame
	_try_default_action()

func _physics_process(delta: float) -> void:
	_update_sail_contact_alpha()

	if not _can_run_default_action():
		_idle_time = 0.0
		return

	_idle_time += delta

	if _idle_time < DEFAULT_ACTION_IDLE_DELAY:
		return

	_try_default_action()


func _update_sail_contact_alpha() -> void:

	var touching_sail := (
		location == DeckGraph.DECKS.MAIN
		and ship.sail.get_rect().has_point(ship.sail.to_local(global_position))
	)

	modulate.a = SAIL_CONTACT_ALPHA if touching_sail else 1.0


func set_location(new_location: int) -> void:

	if location == new_location:
		return

	location = new_location
	body.set_location(location)


func _can_run_default_action() -> bool:

	return (
		not ship.is_sunk()
		and (default_station_name != StringName() or defaults_to_cannon_duty)
		and not ship.repair_duty_controller.active_crewmates.has(self)
		and not action_executor.has_actions()
		and ship.current_crewmate != self
	)


func _default_action_is_satisfied() -> bool:

	return (
		(defaults_to_cannon_duty and ship.cannon_duty_controller.is_duty_crewmate(self))
		or (default_station_name != StringName() and ship.station_controller.get_operator_by_name(default_station_name) == self)
	)


func _try_default_action() -> void:

	if _default_action_is_satisfied():
		return

	if defaults_to_cannon_duty:
		ship.request(&"request_cannon_duty_for", [self])

	if default_station_name != StringName():
		ship.station_controller.request_station_control(self, default_station_name, 1.0)

	_idle_time = 0.0


# A rebuilt bound Callable compares equal, so no handler cache is needed to find the connection.
static func set_queue_finished_listener(
	crewmate: Crewmate,
	handler: Callable,
	connected: bool
) -> void:

	var bound := handler.bind(crewmate)
	var signal_ref: Signal = crewmate.action_executor.queue_finished

	if connected == signal_ref.is_connected(bound):
		return

	if connected:
		signal_ref.connect(bound)
	else:
		signal_ref.disconnect(bound)
