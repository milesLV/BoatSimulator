extends Polygon2D

## Wider than any hull, so the clip box only ever cuts along the waterline.
const INF_EXTENT := 100000.0

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

	var waterline: float = lerp(max_y, min_y, minf(fill, 1.0))
	var below := PackedVector2Array([
		Vector2(-INF_EXTENT, waterline), Vector2(INF_EXTENT, waterline),
		Vector2(INF_EXTENT, max_y), Vector2(-INF_EXTENT, max_y),
	])
	var clipped := Geometry2D.intersect_polygons(full_polygon, below)

	polygon = clipped[0] if not clipped.is_empty() else PackedVector2Array()
