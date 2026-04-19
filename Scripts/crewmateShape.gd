extends Node2D

@export var radius := 4
@export var color := Color(0.0, 0.553, 1.0, 1.0)
@export var outline_color := Color.WHITE
@export var outline_width := 0.

func _ready():
	queue_redraw()

func _draw():
	# Fill
	draw_circle(Vector2.ZERO, radius, color)
	
	# Outline
	draw_arc(
		Vector2.ZERO,
		radius,
		0,
		TAU,
		64, # number of segments (smoothness)
		outline_color,
		outline_width
	)
