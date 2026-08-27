extends Polygon2D

var full_polygon := PackedVector2Array()
var min_y := 0.0
var max_y := 0.0


func _ready() -> void:

	full_polygon = polygon

	if not full_polygon.is_empty():
		var ys := Array(full_polygon).map(func(p: Vector2): return p.y)
		min_y = ys.min()
		max_y = ys.max()

	set_fill(0.0)


func _process(_delta: float) -> void:

	var ship = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if ship == null or ship.health_system == null:
		set_fill(0.0)
		return

	set_fill(ship.health_system.water_level / ShipHealthSystem.MAX_WATER_LEVEL)


func set_fill(fill: float) -> void:

	if full_polygon.is_empty():
		return

	var clamped_fill = clamp(fill, 0.0, 1.0)

	if clamped_fill <= 0.0:
		polygon = PackedVector2Array()
		return

	if clamped_fill >= 1.0:
		polygon = full_polygon
		return

	var waterline = lerp(max_y, min_y, clamped_fill)
	polygon = _clip_below(full_polygon, waterline)


func _clip_below(points: PackedVector2Array, waterline: float) -> PackedVector2Array:

	var result := PackedVector2Array()
	var previous = points[-1]
	var previous_inside = previous.y >= waterline

	for current in points:
		var current_inside = current.y >= waterline

		if current_inside != previous_inside:
			result.append(
				previous.lerp(current, (waterline - previous.y) / (current.y - previous.y))
			)

		if current_inside:
			result.append(current)

		previous = current
		previous_inside = current_inside

	return result
