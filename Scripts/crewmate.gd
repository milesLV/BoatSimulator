class_name Crewmate
extends Node2D

const OUTLINE_COLOR := Color.WHITE
const OUTLINE_WIDTH := 1

@export var fill_color := Color(0.0, 0.553, 1.0, 1.0)
var radius := 7.5
var location = null

func _ready():
	queue_redraw()

func _draw():
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

func setColor(color):
	#* 4 colors:
		#* Blue = one currently controlling
		#* Green = ally / one not controlling
		#* Red = enemy
		#* Purple = ally on other ship
	fill_color = color

func setSize(_radius):
	# want to make it so when going through the transition points, 
	# change size (Upper2Main = get a little bigger
	# and then get smaller to simulate jumping, other 2 = linearly 
	#going up or down in size if going up or down stairs
	radius = _radius

func setLocation(_location):
	# location can be one of "Upper deck", "Main deck", "Mid-deck", or "Lower deck"
	# want to also set the transparency and size to mimic the crewmate
	# being further away from top of ship (or larger if on Upper deck)
	location = _location
