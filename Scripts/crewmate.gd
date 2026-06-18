class_name Crewmate
extends Node2D

signal location_changed(deck)

const RUN_SPEED := 100.0
const DEFAULT_ACTION_IDLE_DELAY := 3.0
const MAX_BUCKET_AMOUNT := 50.0

@export var default_station_name: StringName
@export var defaults_to_cannon_duty := false

@onready var action_executor = $ActionExecutor
@onready var ship = get_parent()
@onready var body = $Body
@onready var ship_action_points: ShipActionPointContainer = (
	ship.get_action_points()
)

var location := -1
var transition_from_deck := -1
var transition_to_deck := -1
var requested_station: StationPoint = null
var bucket_amount := 0.0
var _idle_time := 0.0

func _ready() -> void:

	if body.has_method(
		"set_location"
	):
		location_changed.connect(body.set_location)

	call_deferred("_apply_startup_default_action")

func _physics_process(delta: float) -> void:
	if not _can_run_default_action():
		_idle_time = 0.0
		return

	_idle_time += delta

	if _idle_time < DEFAULT_ACTION_IDLE_DELAY:
		return

	if _default_action_is_satisfied():
		return

	_request_default_action()
	_idle_time = 0.0



func set_location(new_location: int) -> void:

	if not DeckGraph.is_valid_deck(
		new_location
	):

		push_error(
			"Invalid deck: %s"
			% DeckGraph.get_deck_name(new_location)
		)

		return

	if location == new_location:
		clear_deck_transition()
		return

	clear_deck_transition()
	location = new_location
	location_changed.emit(location)


func begin_deck_transition(
	from_deck: int,
	to_deck: int
) -> void:

	if (
		not DeckGraph.is_valid_deck(from_deck)
		or not DeckGraph.is_valid_deck(to_deck)
	):
		return

	if location != from_deck:
		set_location(from_deck)

	transition_from_deck = from_deck
	transition_to_deck = to_deck


func complete_deck_transition() -> void:

	var destination_deck = transition_to_deck

	clear_deck_transition()

	if DeckGraph.is_valid_deck(destination_deck):
		set_location(destination_deck)


func clear_deck_transition() -> void:

	transition_from_deck = -1
	transition_to_deck = -1


func is_transitioning_decks() -> bool:

	return (
		DeckGraph.is_valid_deck(transition_from_deck)
		and DeckGraph.is_valid_deck(transition_to_deck)
	)


func is_on_deck(deck_id: int) -> bool:

	return location == deck_id


func _can_run_default_action() -> bool:

	if ship == null:
		return false

	if (
		ship.has_method("is_sunk")
		and ship.is_sunk()
	):
		return false

	if not _has_default_action():
		return false

	if _is_on_repair_duty():
		return false

	if (
		action_executor != null
		and action_executor.has_actions()
	):
		return false

	if ship.has_method(
		"is_crewmate_selected"
	) and ship.is_crewmate_selected(self):
		return false

	return true


func _is_on_repair_duty() -> bool:

	return (
		ship != null
		and ship.repair_duty_controller != null
		and ship.repair_duty_controller.is_repair_duty_crewmate(self)
	)


func _has_default_action() -> bool:

	return (
		default_station_name != StringName()
		or defaults_to_cannon_duty
	)


func _default_action_is_satisfied() -> bool:

	if defaults_to_cannon_duty:
		if (
			ship != null
			and ship.cannon_duty_controller != null
			and ship.cannon_duty_controller.is_duty_crewmate(self)
		):
			return true

	if default_station_name != StringName():
		if (
			ship != null
			and ship.station_controller != null
			and ship.station_controller.get_operator_by_name(
				default_station_name
			) == self
		):
			return true

	return false


func _apply_startup_default_action() -> void:

	await get_tree().process_frame

	if not _has_default_action():
		return

	if _default_action_is_satisfied():
		return

	_request_default_action(true)
	_idle_time = 0.0


func _request_default_action(_ignore_selected := false) -> void:

	if ship == null:
		return

	if (
		ship.has_method("is_sunk")
		and ship.is_sunk()
	):
		return

	if (
		not _ignore_selected
		and ship.has_method("is_crewmate_selected")
		and ship.is_crewmate_selected(self)
	):
		return

	if defaults_to_cannon_duty:
		if ship.has_method(
			"request_cannon_duty_for"
		):
			ship.request_cannon_duty_for(self)

	if default_station_name != StringName():
		if ship.station_controller != null:
			ship.station_controller.request_station_control(
				self,
				default_station_name,
				1.0
			)
