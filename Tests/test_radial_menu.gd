extends "res://Tests/harness.gd"

# godot --headless --script Tests/test_radial_menu.gd
#
# Which section the mouse is over: 0 straight up, counting clockwise, -1 off the ring.


func _run() -> void:

	var r := RadialMenu.RADIUS * 0.6

	check(RadialMenu.sector_at(Vector2.UP * r, 5) == 0, "straight up is not the first section")

	for count in [5, 6]:
		var step: float = TAU / count
		for i in count:
			# just clockwise of each boundary is that boundary's section
			var offset := Vector2.UP.rotated(step * i + 0.01) * r
			check(RadialMenu.sector_at(offset, count) == i, "%d of %d read as %d" % [i, count, RadialMenu.sector_at(offset, count)])

	check(RadialMenu.sector_at(Vector2.RIGHT * (RadialMenu.DEAD_ZONE - 1.0), 5) == -1, "the dead zone picked")
	check(RadialMenu.sector_at(Vector2.RIGHT * (RadialMenu.RADIUS + 1.0), 5) == -1, "outside the ring picked")

	# a label too wide for its section breaks between words; a word that cannot fit shrinks
	var menu := RadialMenu.new()
	var label := Label.new()
	menu.add_child(label)
	root.add_child(menu)

	menu._fit(label, "Repair whole ship", 150.0)
	check("\n" in label.text, "a long label stayed on one line: %s" % label.text)

	menu._fit(label, "Unbreakablylongword", 100.0)
	check(label.get_theme_font_size(&"font_size") < RadialMenu.FONT_SIZE, "a word too wide kept its size")

	menu.free()

	finish("test_radial_menu")
