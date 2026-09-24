extends Node2D

const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 1
const BASE_RADIUS := 7.5

@export var fill_color := Color(0.0, 0.553, 1.0, 1.0)

var radius := BASE_RADIUS

func _draw() -> void:

	draw_circle(Vector2.ZERO, radius, fill_color)

	draw_arc(Vector2.ZERO, radius, 0, TAU, 100, OUTLINE_COLOR, OUTLINE_WIDTH)

func set_location(new_location: int) -> void:

	radius = BASE_RADIUS * DeckGraph.DECK_SIZE_SCALE[new_location]
	modulate.a = DeckGraph.DECK_ALPHA[new_location]
	queue_redraw()
