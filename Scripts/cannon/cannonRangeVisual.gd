@tool
extends Polygon2D

@export var display_color: Color = Color(1, 0, 0, 0.35): set = _set_color

var source: CollisionPolygon2D

func _ready():
	_find_source()
	_update_polygon()

func _process(_delta):
	if Engine.is_editor_hint():
		_update_polygon()

func _set_color(c):
	display_color = c
	color = display_color

func _find_source():
	var parent = get_parent()
	if parent == null:
		return

	for child in parent.get_children():
		if child is CollisionPolygon2D:
			source = child
			return

func _update_polygon():
	if source == null:
		_find_source()
		if source == null:
			return

	polygon = source.polygon
	color = display_color
