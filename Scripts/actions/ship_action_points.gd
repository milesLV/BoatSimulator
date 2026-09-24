extends Node2D
class_name ShipActionPoint

@export var deck: DeckGraph.DECKS


func _ready() -> void:

	if not DeckGraph.is_valid_deck(deck):
		push_error("%s has invalid deck: %s" % [name, deck])


func get_position_for_actor(actor: Node2D, _start_position = null) -> Vector2:
	return actor.get_parent().to_local(global_position)


func contains_actor(actor: Node2D, tolerance := 1.0) -> bool:

	return actor.position.distance_to(get_position_for_actor(actor)) <= tolerance
