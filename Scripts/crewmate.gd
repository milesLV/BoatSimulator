class_name Crewmate
extends Node2D

signal location_changed(deck)

const RUN_SPEED := 100.0
const DEFAULT_ACTION_IDLE_DELAY := 3.0
const MAX_BUCKET_AMOUNT := 50.0
const SAIL_CONTACT_ALPHA := 0.50

@export var default_station_name: StringName
@export var defaults_to_cannon_duty := false

@onready var action_executor = $ActionExecutor
@onready var ship: Sloop = get_parent()
@onready var body = $Body
@onready var sail: Sprite2D = ship.get_node("Sail")

var location := -1
var transition_to_deck := -1
var bucket_amount := 0.0
var _idle_time := 0.0

func _ready() -> void:

	location_changed.connect(body.set_location)

	call_deferred("_apply_startup_default_action")

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
		and sail.get_rect().has_point(sail.to_local(global_position))
	)

	modulate.a = SAIL_CONTACT_ALPHA if touching_sail else 1.0


func set_location(new_location: int) -> void:

	if not DeckGraph.is_valid_deck(new_location):
		push_error("Invalid deck: %s" % DeckGraph.get_deck_name(new_location))
		return

	clear_deck_transition()

	if location == new_location:
		return

	location = new_location
	location_changed.emit(location)


func begin_deck_transition(from_deck: int, to_deck: int) -> void:
	if not DeckGraph.is_valid_deck(from_deck) or not DeckGraph.is_valid_deck(to_deck):
		return

	if location != from_deck:
		set_location(from_deck)

	transition_to_deck = to_deck


func complete_deck_transition() -> void:

	var destination_deck = transition_to_deck

	clear_deck_transition()

	if DeckGraph.is_valid_deck(destination_deck):
		set_location(destination_deck)


func clear_deck_transition() -> void:

	transition_to_deck = -1


func _can_run_default_action() -> bool:

	return (
		ship != null
		and not ship.is_sunk()
		and _has_default_action()
		and not _is_on_repair_duty()
		and not (action_executor != null and action_executor.has_actions())
		and not ship.is_crewmate_selected(self)
	)


func _is_on_repair_duty() -> bool:

	return (
		ship != null
		and ship.repair_duty_controller != null
		and ship.repair_duty_controller.is_repair_duty_crewmate(self)
	)


func _has_default_action() -> bool:

	return default_station_name != StringName() or defaults_to_cannon_duty


func _default_action_is_satisfied() -> bool:

	if ship == null:
		return false

	if (
		defaults_to_cannon_duty
		and ship.cannon_duty_controller != null
		and ship.cannon_duty_controller.is_duty_crewmate(self)
	):
		return true

	return (
		default_station_name != StringName()
		and ship.station_controller != null
		and ship.station_controller.get_operator_by_name(default_station_name) == self
	)


func _apply_startup_default_action() -> void:

	await get_tree().process_frame

	_try_default_action(true)


## Requests the default duty unless the crewmate is already doing it.
func _try_default_action(ignore_selected := false) -> void:

	if not _has_default_action() or _default_action_is_satisfied():
		return

	_request_default_action(ignore_selected)
	_idle_time = 0.0


func _request_default_action(ignore_selected := false) -> void:

	if ship == null or ship.is_sunk() or (not ignore_selected and ship.is_crewmate_selected(self)):
		return

	if defaults_to_cannon_duty:
		ship.request(&"request_cannon_duty_for", [self])

	if default_station_name != StringName() and ship.station_controller != null:
		ship.station_controller.request_station_control(self, default_station_name, 1.0)


# A bound Callable compares equal to any identical rebuild, so this finds the
# connection made from the same crewmate without a handler cache.
static func set_queue_finished_listener(
	crewmate: Crewmate,
	handler: Callable,
	connected: bool
) -> void:

	if crewmate == null or crewmate.action_executor == null:
		return

	var bound := handler.bind(crewmate)
	var signal_ref: Signal = crewmate.action_executor.queue_finished

	if connected == signal_ref.is_connected(bound):
		return

	if connected:
		signal_ref.connect(bound)
	else:
		signal_ref.disconnect(bound)
