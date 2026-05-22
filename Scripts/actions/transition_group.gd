class_name DeckStairTransition
extends ColorRect

@export var from_deck: DeckGraph.DECKS
@export var to_deck: DeckGraph.DECKS
@export var bidirectional := true

const STAIR_COLOR = Color("#924e42")

func _ready() -> void:
	color = STAIR_COLOR
