class_name RadialMenu
extends Control

## Hold a bound key and a ring of options opens at screen centre; release over one (or click it)
## to pick it. A quick tap never opens the ring and does the key's plain action instead.

const RADIUS := 400.0
const DEAD_ZONE := 20.0
const OPEN_DELAY := 0.2
const LABEL_RADIUS := RADIUS * 0.6
const HIGHLIGHT := Color("9dffb0")
const FONT_SIZE := 32
const MIN_FONT_SIZE := 10

## action -> {labels, on_pick, on_tap}
var bindings := {}
var held_action: StringName = &""
var held_time := 0.0
var hovered := -1
var labels: Array[Label] = []


func _ready() -> void:

	add_to_group(&"radial_menu")
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()


## [param on_pick] gets the index of the chosen label; [param on_tap] runs on a quick press.
func bind(action: StringName, option_labels: Array[String], on_pick: Callable, on_tap: Callable) -> void:

	bindings[action] = {"labels": option_labels, "on_pick": on_pick, "on_tap": on_tap}


## The section under [param offset] from the centre, 0 at the top going clockwise; -1 off the ring.
static func sector_at(offset: Vector2, count: int) -> int:

	if offset.length() < DEAD_ZONE or offset.length() > RADIUS:
		return -1

	var from_top := wrapf(offset.angle() + PI / 2.0, 0.0, TAU)

	return int(from_top / (TAU / count)) % count


func _process(delta: float) -> void:

	if held_action == &"":
		for action in bindings:
			if Input.is_action_just_pressed(action):
				held_action = action
				held_time = 0.0
		return

	held_time += delta

	if not visible and held_time >= OPEN_DELAY:
		_open()

	if visible:
		var count = labels.size()
		var now = sector_at(get_local_mouse_position() - size / 2.0, count)
		if now != hovered:
			hovered = now
			queue_redraw()

	if Input.is_action_just_released(held_action):
		var binding = bindings[held_action]

		if not visible:
			binding["on_tap"].call()
		elif hovered != -1:
			binding["on_pick"].call(hovered)

		_close()


func _input(event: InputEvent) -> void:

	if (
		visible and hovered != -1
		and event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		bindings[held_action]["on_pick"].call(hovered)
		get_viewport().set_input_as_handled()
		_close()


func _open() -> void:

	var option_labels: Array = bindings[held_action]["labels"]
	var step := TAU / option_labels.size()

	# the chord across a section at the label's radius, less a margin, is all the width it has
	var max_width := 2.0 * LABEL_RADIUS * sin(step / 2.0) * 0.9

	for i in option_labels.size():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fit(label, option_labels[i], max_width)
		add_child(label)
		# middle of the section, measured clockwise from the top
		var mid := Vector2.UP.rotated(step * (i + 0.5)) * LABEL_RADIUS
		label.position = size / 2.0 + mid - label.get_minimum_size() / 2.0
		labels.append(label)

	hovered = -1
	show()
	queue_redraw()


## Breaks [param text] onto a new line before any word that would run past [param max_width],
## and shrinks the font only when a word is too wide on its own or the lines are too tall.
func _fit(label: Label, text: String, max_width: float) -> void:

	var font := label.get_theme_font(&"font")
	var font_size := FONT_SIZE
	var width := func(line: String) -> float:
		return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	while true:
		var lines: Array[String] = []

		for word in text.split(" "):
			if not lines.is_empty() and width.call(lines.back() + " " + word) <= max_width:
				lines[-1] += " " + word
			else:
				lines.append(word)

		var fits = (
			lines.all(func(line): return width.call(line) <= max_width)
			and lines.size() * font.get_height(font_size) <= RADIUS - DEAD_ZONE
		)

		if fits or font_size <= MIN_FONT_SIZE:
			label.text = "\n".join(lines)
			label.add_theme_font_size_override(&"font_size", font_size)
			return

		font_size -= 1


## Forgets the key too, so after a click its release does nothing.
func _close() -> void:

	for label in labels:
		label.queue_free()

	labels.clear()
	held_action = &""
	hovered = -1
	hide()


func _draw() -> void:

	var centre := size / 2.0
	var count := labels.size()

	if count == 0:
		return

	var step := TAU / count

	draw_circle(centre, RADIUS, Color(0.0, 0.0, 0.0, 0.45))
	draw_arc(centre, RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.6), 1.5)

	for i in count:
		draw_line(centre, centre + Vector2.UP.rotated(step * i) * RADIUS, Color(1.0, 1.0, 1.0, 0.6), 1.5)

	if hovered == -1:
		return

	# the hovered section's whole outline: both edges and the rim between them
	var start := Vector2.UP.rotated(step * hovered)
	var end := Vector2.UP.rotated(step * (hovered + 1))
	draw_line(centre, centre + start * RADIUS, HIGHLIGHT, 3.0)
	draw_line(centre, centre + end * RADIUS, HIGHLIGHT, 3.0)
	draw_arc(centre, RADIUS, start.angle(), start.angle() + step, 32, HIGHLIGHT, 3.0)
