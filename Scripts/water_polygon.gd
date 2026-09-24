extends Polygon2D

var full_polygon := PackedVector2Array()
var min_y := 0.0
var max_y := 0.0


func _ready() -> void:

	full_polygon = polygon
	var ys := Array(full_polygon).map(func(p: Vector2): return p.y)
	min_y = ys.min()
	max_y = ys.max()

	set_fill(0.0)


func _process(_delta: float) -> void:

	var ship = GlobalShipRegistry.get_player_ship_from_tree(get_tree())

	if ship == null:
		set_fill(0.0)
		return

	set_fill(ship.health_system.water_level / ShipHealthSystem.MAX_WATER_LEVEL)


## A full ship clips nothing away, but an empty one would leave a sliver along the bottom.
func set_fill(fill: float) -> void:

	if fill <= 0.0:
		polygon = PackedVector2Array()
		return

	polygon = _clip_below(full_polygon, lerp(max_y, min_y, minf(fill, 1.0)))


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
