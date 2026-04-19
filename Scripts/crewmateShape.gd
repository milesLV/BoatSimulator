extends Node2D

@export var fill_color := Color(0.0, 0.553, 1.0, 1.0)

const RADIUS := 4
const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 0.5

func _ready():
	queue_redraw()

func _draw():
	# Fill
	draw_circle(Vector2.ZERO, RADIUS, fill_color)
	
	# Outline
	draw_arc(
		Vector2.ZERO,
		RADIUS,
		0,
		TAU,
		100, # number of segments (smoothness)
		OUTLINE_COLOR,
		OUTLINE_WIDTH
	)
