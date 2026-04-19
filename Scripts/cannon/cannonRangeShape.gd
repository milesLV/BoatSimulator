@tool
extends CollisionPolygon2D

@onready var segments := []

@export var inner_radius := 0.0
@export var outer_radius := 400.0
@export var start_angle := 45.0
@export var step := 2.5

func _ready():
	# Grab CollisionPolygon2D inside each Area2D
	for child in get_children():
		if child is Area2D and child.get_child_count() > 0:
			var poly = child.get_child(0)
			if poly is CollisionPolygon2D:
				segments.append(poly)

	rebuild()

# Core builder
func rebuild(_v = null):
	if !is_inside_tree():
		return

	var points := PackedVector2Array()

	# Filled sector (center piece)
	if inner_radius <= 0.0:
		points.append(Vector2.ZERO)

	# Outer arc
	var angle := start_angle
	while angle >= -start_angle:
		var r := deg_to_rad(angle)
		points.append(Vector2(
			cos(r) * outer_radius,
			sin(r) * outer_radius
		))
		angle -= step

	# Inner arc (only if ring)
	if inner_radius > 0.0:
		angle = -start_angle
		while angle <= start_angle:
			var r := deg_to_rad(angle)
			points.append(Vector2(
				cos(r) * inner_radius,
				sin(r) * inner_radius
			))
			angle += step
	else:
		points.append(Vector2.ZERO)

	polygon = points
