class_name DeckTransitionPoint
extends ShipActionPoint

var deck_connection: DeckTransitionPoint


func _ready() -> void:

	super()


func set_connected_point(point: DeckTransitionPoint) -> void:

	deck_connection = point


func clear_connected_point() -> void:

	deck_connection = null


func get_destination_deck() -> int:

	if deck_connection == null:
		return deck

	return deck_connection.deck


func connects(
	from_deck: int,
	to_deck: int
) -> bool:

	return (
		deck == from_deck
		and get_destination_deck() == to_deck
	)
