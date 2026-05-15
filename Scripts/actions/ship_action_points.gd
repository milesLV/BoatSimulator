extends Node2D
class_name ShipActionPoint

@export var deck: DeckGraph.DECKS


func _ready() -> void:

	assert(
		name != "",
		"ShipActionPoint must have a name."
	)

	if not DeckGraph.is_valid_deck(
		deck
	):
		push_error(
			"%s has invalid deck: %s"
			% [
				name,
				deck
			]
		)


func get_deck_name() -> String:

	return DeckGraph.get_deck_name(
		deck
	)


func is_on_deck(
	deck_id: int
) -> bool:

	return deck == deck_id


func get_position_for_actor(
	actor: Node2D
) -> Vector2:

	var actor_parent = actor.get_parent()

	if actor_parent is Node2D:

		return actor_parent.to_local(
			global_position
		)

	return position
