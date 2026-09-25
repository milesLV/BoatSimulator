extends "res://Tests/harness.gd"


func _run() -> void:

	var r := RadialMenu.RADIUS * 0.6

	check(RadialMenu.sector_at(Vector2.LEFT * r, 2) == 0, "the left half is not the first of two")
	check(RadialMenu.sector_at(Vector2.UP.rotated(-0.01) * r, 5) == 0, "just left of the top is not the first section")

	for count in [5, 6]:
		var step: float = TAU / count
		for i in count:
			# just clockwise of each boundary is that boundary's section
			var offset := Vector2.UP.rotated(step * (i - 1) + 0.01) * r
			check(RadialMenu.sector_at(offset, count) == i, "%d of %d read as %d" % [i, count, RadialMenu.sector_at(offset, count)])

	check(RadialMenu.sector_at(Vector2.RIGHT * (RadialMenu.DEAD_ZONE - 1.0), 5) == -1, "the dead zone picked")
	check(RadialMenu.sector_at(Vector2.RIGHT * (RadialMenu.RADIUS + 1.0), 5) == -1, "outside the ring picked")

	var menu := RadialMenu.new()
	var label := Label.new()
	menu.add_child(label)
	root.add_child(menu)

	# the left half of a two-way ring
	var mid := Vector2.LEFT * RadialMenu.LABEL_RADIUS
	menu._fit(label, RadialMenu.AMPLIFIED_PREFIX + "Fire at mast", mid, 0, 2)
	var half := label.get_minimum_size() / 2.0
	check("\n" in label.text, "a long label stayed on one line: %s" % label.text)
	check(
		[half, -half, Vector2(half.x, -half.y), Vector2(-half.x, half.y)].all(
			func(corner): return RadialMenu.sector_at(mid + corner, 2) == 0
		),
		"the label spills out of its section"
	)

	menu._fit(label, "Unbreakablylongwordthatgoesonandon", Vector2.UP.rotated(-TAU / 12.0) * RadialMenu.LABEL_RADIUS, 0, 6)
	check(label.get_theme_font_size(&"font_size") < RadialMenu.FONT_SIZE, "a word too wide kept its size")

	menu.free()

	finish("test_radial_menu")
