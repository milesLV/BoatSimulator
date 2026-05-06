class_name Crewmate
extends Node2D

const VALID_DECKS := [ # location can only be one of these
	DeckGraph.UPPER,
	DeckGraph.MAIN,
	DeckGraph.MID,
	DeckGraph.LOWER
]
const RUN_SPEED := 100.0

@onready var action_executor = $ActionExecutor
@onready var ship = get_parent()
@onready var ship_action_points = ship.get_node("ShipActionPoints")

var location: String = ""

func set_location(new_location: String) -> void:

	# want to also set the transparency and size to mimic the crewmate
	# being further away from top of ship (or larger if on Upper deck)
	if not VALID_DECKS.has(
		new_location
	):

		push_error(
			"Invalid deck: %s"
			% new_location
		)

		return

	location = new_location

func is_on_deck(
	deck_name: String
) -> bool:

	return location == deck_name
