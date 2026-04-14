@tool
extends CollisionPolygon2D

@export var inner_radius: float = 0.0: set = _set_inner
@export var outer_radius: float = 400.0: set = _set_outer
@export var start_angle: float = 45.0: set = _set_start
@export var step: float = 2.5: set = _set_step

func _enter_tree():
	if Engine.is_editor_hint():
		rebuild()

# --- Setters (no recursion issues) ---
func _set_inner(v): inner_radius = v; rebuild()
func _set_outer(v): outer_radius = v; rebuild()
func _set_start(v): start_angle = v; rebuild()
func _set_step(v): step = v; rebuild()

@onready var segments := []

func _ready():
	# Grab CollisionPolygon2D inside each Area2D
	for child in get_children():
		if child is Area2D and child.get_child_count() > 0:
			var poly = child.get_child(0)
			if poly is CollisionPolygon2D:
				segments.append(poly)

	rebuild()

# --- Core builder ---
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
