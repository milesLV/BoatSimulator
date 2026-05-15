class_name Crewmate
extends Node2D

const RUN_SPEED := 100.0

@onready var action_executor = $ActionExecutor
@onready var ship = get_parent()
@onready var ship_action_points: ShipActionPointContainer = (
	ship.get_node("ShipActionPoints")
)

var location: DeckGraph.DECKS
var requested_station: StationPoint = null

func set_location(
	new_location: int
) -> void:

	# want to also set the transparency and size to mimic the crewmate
	# being further away from top of ship (or larger if on Upper deck)
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

	location = new_location

func is_on_deck(
	deck_id: int
) -> bool:

	return location == deck_id
