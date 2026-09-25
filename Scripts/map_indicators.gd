extends CanvasLayer

## Screen edge to medallion centre; 0 derives it from the arrow's reach.
@export var edge_padding: float = 0.0
## Render target size, in pixels, for each boat view.
@export var view_px: int = 160
## For a ship with no CollisionPolygon2D to measure.
const DEFAULT_HULL_RADIUS := 150.0

## Screen pixels past the edge before the arrow is fully opaque.
const ARROW_FADE_DISTANCE := 400.0
const ARROW_MIN_ALPHA := 0.01

@onready var medallion_template: Sprite2D = $MapMedallion
@onready var arrow_template: Sprite2D = $MapArrow

var _arrow_offset: Vector2
var _arrow_rotation: float
var _indicators: Dictionary = {}
var _next_bit := 1  # bit 0 stays the default layer for the rest of the world


func _ready() -> void:

	_arrow_offset = arrow_template.position - medallion_template.position
	_arrow_rotation = arrow_template.rotation

	if edge_padding <= 0.0:
		edge_padding = _arrow_offset.length() + arrow_template.get_rect().size.y * arrow_template.scale.y * 0.5

	medallion_template.hide()
	arrow_template.hide()


func _process(_delta: float) -> void:

	var registry := GlobalShipRegistry.from_tree(get_tree())
	var ships: Array = registry.ships if registry != null else []

	for ship in _indicators.keys():
		if not is_instance_valid(ship) or ship not in ships:
			for node in _indicators[ship]["sprites"] + [_indicators[ship]["viewport"]]:
				node.queue_free()

			_indicators.erase(ship)

	var xform := get_viewport().get_canvas_transform()
	var rect := get_viewport().get_visible_rect()

	for ship in ships:

		if not _indicators.has(ship):
			_indicators[ship] = _build_indicator(ship)

		_update_indicator(_indicators[ship], ship, xform, rect)


## Point on the padded viewport border along the direction of `screen_pos`.
static func project_to_edge(screen_pos: Vector2, rect: Rect2, padding: float) -> Vector2:

	var centre := rect.position + rect.size * 0.5
	var half := (rect.size * 0.5 - Vector2(padding, padding)).max(Vector2.ONE)
	var d := screen_pos - centre

	if d.is_zero_approx():
		return centre

	var q := half / d.abs()  # a zero component divides to INF, so minf takes the other axis

	return centre + d * minf(q.x, q.y)


static func distance_outside_rect(point: Vector2, rect: Rect2) -> float:

	return (rect.position - point).max(point - rect.end).max(Vector2.ZERO).length()


static func arrow_alpha(edge_distance: float) -> float:

	return lerpf(ARROW_MIN_ALPHA, 1.0, clampf(edge_distance / ARROW_FADE_DISTANCE, 0.0, 1.0))


## Returns [position, rotation] swinging the arrow round the medallion toward `target`.
static func place_arrow(medallion_pos: Vector2, target: Vector2, arrow_offset: Vector2, base_rotation: float) -> Array:

	var to_target := target - medallion_pos

	if to_target.is_zero_approx():
		return [medallion_pos + arrow_offset, base_rotation]

	var delta := to_target.angle() - arrow_offset.angle()

	return [medallion_pos + arrow_offset.rotated(delta), base_rotation + delta]


func _build_indicator(ship: Node2D) -> Dictionary:

	var mask := 1 << _next_bit
	_next_bit += 1

	_assign_visibility_layer(ship, mask)

	var radius := _hull_radius(ship)

	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * (view_px * 0.5 / radius)

	var sub := SubViewport.new()
	sub.size = Vector2i(view_px, view_px)
	sub.transparent_bg = true
	sub.disable_3d = true
	sub.handle_input_locally = false
	sub.audio_listener_enable_2d = false
	sub.canvas_cull_mask = mask
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub.add_child(camera)
	add_child(sub)
	sub.world_2d = get_viewport().world_2d
	camera.make_current()

	var medallion: Sprite2D = medallion_template.duplicate()
	var boat := Sprite2D.new()
	boat.texture = sub.get_texture()
	var arrow: Sprite2D = arrow_template.duplicate()
	var sprites := [medallion, boat, arrow]

	for node in sprites:
		node.hide()
		add_child(node)

	return {
		"medallion": medallion,
		"boat": boat,
		"arrow": arrow,
		"sprites": sprites,
		"viewport": sub,
		"camera": camera,
		"radius": radius,
	}


func _update_indicator(indicator: Dictionary, ship: Node2D, xform: Transform2D, rect: Rect2) -> void:

	var screen_pos := xform * ship.global_position
	var screen_radius: float = xform.get_scale().x * indicator["radius"]

	if rect.grow(screen_radius).has_point(screen_pos):
		indicator["viewport"].render_target_update_mode = SubViewport.UPDATE_DISABLED

		for sprite in indicator["sprites"]:
			sprite.hide()

		return

	var medallion: Sprite2D = indicator["medallion"]
	medallion.position = project_to_edge(screen_pos, rect, edge_padding)

	var boat: Sprite2D = indicator["boat"]
	boat.position = medallion.position

	var placement := place_arrow(medallion.position, screen_pos, _arrow_offset, _arrow_rotation)
	var arrow: Sprite2D = indicator["arrow"]
	arrow.position = placement[0]
	arrow.rotation = placement[1]
	# measured from the hull, so the fade starts at zero exactly as the boat leaves
	arrow.modulate.a = arrow_alpha(distance_outside_rect(screen_pos, rect) - screen_radius)

	indicator["camera"].global_position = ship.global_position
	indicator["viewport"].render_target_update_mode = SubViewport.UPDATE_ALWAYS

	for sprite in indicator["sprites"]:
		sprite.show()


## Cannon range cones stay on the default layer so they never reach the medallion.
func _assign_visibility_layer(ship: Node2D, mask: int) -> void:

	_set_subtree_layer(ship, mask)

	# Godot only draws an item when every ancestor also shares a bit with the cull mask
	var ancestor := ship.get_parent()

	while ancestor is CanvasItem:
		ancestor.visibility_layer |= mask
		ancestor = ancestor.get_parent()


func _set_subtree_layer(node: Node, mask: int) -> void:

	if node.name == "CannonRange":
		return

	if node is CanvasItem:
		node.visibility_layer = mask

	for child in node.get_children():
		_set_subtree_layer(child, mask)


func _hull_radius(ship: Node2D) -> float:

	for child in ship.get_children():

		if child is CollisionPolygon2D and not child.polygon.is_empty():
			var reach: Array = Array(child.polygon).map(func(p: Vector2): return (p * child.scale).length())
			return reach.max() * ship.scale.x

	return DEFAULT_HULL_RADIUS
