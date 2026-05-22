extends Node2D

const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 1

@export var fill_color := Color(0.0, 0.553, 1.0, 1.0)

var radius := 7.5
var location = null

func _ready() -> void:

	queue_redraw()

func _draw() -> void:

	# Fill
	draw_circle(Vector2.ZERO, radius, fill_color)
	
	# Outline
	draw_arc(
		Vector2.ZERO,
		radius,
		0,
		TAU,
		100, # number of segments (smoothness)
		OUTLINE_COLOR,
		OUTLINE_WIDTH
	)

func set_color(color: Color) -> void:

	#* 4 colors:
		#* Blue = one currently controlling
		#* Green = ally / one not controlling
		#* Red = enemy
		#* Purple = ally on other ship
	fill_color = color
	queue_redraw()

func setColor(color: Color) -> void:

	set_color(
		color
	)


func set_size(new_radius: float) -> void:

	radius = new_radius
	queue_redraw()


func setSize(new_radius: float) -> void:

	set_size(
		new_radius
	)


func set_location(new_location: int) -> void:

	if not DeckGraph.is_valid_deck(
		new_location
	):
		return

	location = new_location
	_apply_deck_visuals()
	queue_redraw()


func setLocation(new_location: int) -> void:

	set_location(
		new_location
	)


func _apply_deck_visuals() -> void:

	match location:
		DeckGraph.DECKS.UPPER:
			radius = 7.5
			modulate.a = 1.0
		DeckGraph.DECKS.MAIN:
			radius = 6.75
			modulate.a = 0.85
		DeckGraph.DECKS.MID:
			radius = 6.0
			modulate.a = 0.7
		DeckGraph.DECKS.LOWER:
			radius = 5.25
			modulate.a = 0.55
