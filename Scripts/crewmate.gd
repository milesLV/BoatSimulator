class_name Crewmate
extends Node2D

signal location_changed(deck)

const RUN_SPEED := 100.0

@onready var action_executor = $ActionExecutor
@onready var ship = get_parent()
@onready var body = $Body
@onready var ship_action_points: ShipActionPointContainer = (
	ship.get_action_points()
)

var location := -1
var requested_station: StationPoint = null

func _ready() -> void:

	if body.has_method(
		"set_location"
	):
		location_changed.connect(
			body.set_location
		)


func set_location(
	new_location: int
) -> void:

	if not DeckGraph.is_valid_deck(
		new_location
	):

		push_error(
			"Invalid deck: %s"
			% DeckGraph.get_deck_name(
				new_location
			)
		)

		return

	if location == new_location:
		return

	location = new_location
	location_changed.emit(
		location
	)

func is_on_deck(
	deck_id: int
) -> bool:

	return location == deck_id
