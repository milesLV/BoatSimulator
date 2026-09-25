extends "res://Tests/harness.gd"


func _run() -> void:

	var script = load("res://Scripts/map_indicators.gd")
	var rect := Rect2(Vector2.ZERO, Vector2(1152, 648))
	var centre := rect.size * 0.5
	var padding := 125.0  # what map_indicators derives from the authored arrow reach
	var half := rect.size * 0.5 - Vector2(padding, padding)

	var edge = script.project_to_edge(centre + Vector2(4000, -4000), rect, padding)
	assert(edge.x > centre.x and edge.y < centre.y)
	assert(absf(edge.x - centre.x) <= half.x + 0.01)
	assert(absf(edge.y - centre.y) <= half.y + 0.01)
	assert(is_equal_approx(script.project_to_edge(centre + Vector2(9000, 10), rect, padding).x, centre.x + half.x))
	# a zero direction must not divide by zero
	assert(script.project_to_edge(centre, rect, padding) == centre)

	var offset := Vector2(-3, -98)
	var base_rotation := 0.0
	var target := Vector2(500, 300)
	var medallion := Vector2(400, 300)
	var placement = script.place_arrow(medallion, target, offset, base_rotation)
	var arrow_pos: Vector2 = placement[0]
	assert(is_equal_approx((arrow_pos - medallion).length(), offset.length()))
	assert(is_equal_approx((arrow_pos - medallion).angle(), (target - medallion).angle()))
	assert(is_equal_approx(placement[1], (target - medallion).angle() - offset.angle() + base_rotation))
	assert(script.place_arrow(medallion, medallion, offset, base_rotation)[0] == medallion + offset)

	for degrees in range(0, 360, 15):
		var dir := Vector2.RIGHT.rotated(deg_to_rad(degrees)) * 5000.0
		var med = script.project_to_edge(centre + dir, rect, padding)
		var arrow = script.place_arrow(med, centre + dir, offset, base_rotation)[0]
		assert(rect.has_point(med))
		assert(rect.has_point(arrow))

	assert(is_equal_approx(script.arrow_alpha(0.0), 0.01))
	assert(is_equal_approx(script.arrow_alpha(script.ARROW_FADE_DISTANCE), 1.0))
	assert(is_equal_approx(script.arrow_alpha(99999.0), 1.0))
	assert(is_equal_approx(script.arrow_alpha(-50.0), 0.01))
	assert(script.arrow_alpha(script.ARROW_FADE_DISTANCE * 0.5) > script.arrow_alpha(script.ARROW_FADE_DISTANCE * 0.25))

	assert(is_equal_approx(script.distance_outside_rect(centre, rect), 0.0))
	assert(is_equal_approx(script.distance_outside_rect(Vector2(rect.end.x + 300.0, centre.y), rect), 300.0))
	assert(is_equal_approx(script.distance_outside_rect(Vector2(-40.0, -30.0), rect), Vector2(40.0, 30.0).length()))

	# 151 is the sloop's hull radius
	var near: float = script.distance_outside_rect(rect.end + Vector2(10, 10), rect) - 151.0
	assert(script.arrow_alpha(near) < 0.2)
	assert(is_equal_approx(script.arrow_alpha(script.distance_outside_rect(rect.end + Vector2(2000, 2000), rect) - 151.0), 1.0))

	var gui = load("res://Scenes/gameGui.tscn").instantiate()
	root.add_child(gui)
	await process_frame

	var world := Node2D.new()
	var ship := Node2D.new()
	var hull := Node2D.new()
	var range_area := Node2D.new()
	range_area.name = "CannonRange"
	var cone := Node2D.new()
	range_area.add_child(cone)
	ship.add_child(hull)
	ship.add_child(range_area)
	world.add_child(ship)
	root.add_child(world)

	gui._assign_visibility_layer(ship, 8)
	assert(ship.visibility_layer == 8)
	assert(hull.visibility_layer == 8)
	assert(world.visibility_layer & 8 != 0)
	assert(world.visibility_layer & 1 != 0)
	assert(range_area.visibility_layer == 1)
	assert(cone.visibility_layer == 1)

	print("map indicator geometry ok")
	quit()
