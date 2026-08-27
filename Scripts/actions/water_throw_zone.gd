class_name WaterThrowZone
extends ShipActionPoint


func _ready() -> void:

	super._ready()
	assert(_get_polygon().size() >= 3, "WaterThrowZone requires a polygon.")


func get_position_for_actor(actor: Node2D, start_position = null) -> Vector2:
	var zone_polygon = _get_polygon()

	if actor == null or zone_polygon.size() < 3:
		return position

	var actor_parent = actor.get_parent() as Node2D

	if actor_parent == null:
		return position

	var origin: Vector2 = actor.position

	if start_position is Vector2:
		origin = start_position

	var local_origin = to_local(actor_parent.to_global(origin))
	var exit_position = _get_lower_deck_exit_position(actor)

	if exit_position != null:
		local_origin = exit_position
	elif Geometry2D.is_point_in_polygon(local_origin, zone_polygon):
		return origin

	return actor_parent.to_local(to_global(_closest_border_point(local_origin, zone_polygon)))


func contains_actor(actor: Node2D, tolerance := 1.0) -> bool:

	var zone_polygon = _get_polygon()

	if actor == null or zone_polygon.size() < 3:
		return false

	var local_position = to_local(actor.global_position)

	if Geometry2D.is_point_in_polygon(local_position, zone_polygon):
		return true

	return local_position.distance_to(
		_closest_border_point(local_position, zone_polygon)
	) <= tolerance


## Nearest point anywhere on the zone's outline, in zone-local space.
func _closest_border_point(local_position: Vector2, zone_polygon: PackedVector2Array) -> Vector2:
	var closest: Vector2 = zone_polygon[0]
	var closest_distance := INF

	for i in range(zone_polygon.size()):
		var candidate = Geometry2D.get_closest_point_to_segment(
			local_position,
			zone_polygon[i],
			zone_polygon[(i + 1) % zone_polygon.size()]
		)
		var distance = local_position.distance_squared_to(candidate)

		if distance < closest_distance:
			closest = candidate
			closest_distance = distance

	return closest


func _get_polygon() -> PackedVector2Array:

	var value = get("polygon")

	if value is PackedVector2Array:
		return value

	return PackedVector2Array()


func _get_lower_deck_exit_position(actor: Node2D):

	var ship = actor.get("ship")

	if (
		ship == null
		or ship.health_system == null
		or ship.health_system.water_level
		>= ShipHealthSystem.MID_DECK_WATER_LEVEL
	):
		return null

	var bucket_point = get_parent().get_node_or_null("BucketLD") as ShipActionPoint

	if bucket_point == null:
		return null

	return to_local(bucket_point.global_position)
