class_name RadialMenu
extends Control

## Hold a bound key to open a ring of options; a quick tap does the key's plain action instead.

const RADIUS := 400.0
const DEAD_ZONE := 20.0
const OPEN_DELAY := 0.2
const LABEL_RADIUS := RADIUS * 0.6
const HIGHLIGHT := Color("9dffb0")
const FONT_SIZE := 32
const MIN_FONT_SIZE := 10
const LABEL_PADDING := 12.0
const AMPLIFIED_PREFIX := "(All crewmates) "

## action -> {labels, on_pick, on_tap}
var bindings := {}
var held_action: StringName = &""
var held_time := 0.0
var hovered := -1
var labels: Array[Label] = []
var amplified := false
## Tab presses since the ring opened.
var cycle := 0
## Set by the labels callable; only a ring with a hint pages with Tab.
var hint := ""
var _hint_label: Label = null


func _ready() -> void:

	add_to_group(&"radial_menu")
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()


## option_labels(amplified, cycle) -> Array, on_pick(index, amplified), on_tap(amplified).
func bind(action: StringName, option_labels: Callable, on_pick: Callable, on_tap: Callable) -> void:

	bindings[action] = {"labels": option_labels, "on_pick": on_pick, "on_tap": on_tap}


## -1 off the ring. Section 0 ends at the top, so options run clockwise from the left.
static func sector_at(offset: Vector2, count: int) -> int:

	if offset.length() < DEAD_ZONE or offset.length() > RADIUS:
		return -1

	var step := TAU / count
	var from_start := wrapf(offset.angle() + PI / 2.0 + step, 0.0, TAU)

	return int(from_start / step) % count


func _process(delta: float) -> void:

	if held_action == &"":
		for action in bindings:
			if Input.is_action_just_pressed(action):
				held_action = action
				held_time = 0.0
		return

	held_time += delta

	if not visible and held_time >= OPEN_DELAY:
		show()

	var turned = visible and hint != "" and Input.is_action_just_pressed(&"cycleAmmo")
	cycle += int(turned)

	if visible and (turned or labels.is_empty() or Input.is_action_pressed(&"amplify") != amplified):
		_build_labels()

	if visible:
		var now = sector_at(get_local_mouse_position() - size / 2.0, labels.size())
		if now != hovered:
			hovered = now
			queue_redraw()

	if Input.is_action_just_released(held_action):
		var binding = bindings[held_action]

		if not visible:
			binding["on_tap"].call(Input.is_action_pressed(&"amplify"))
		elif hovered != -1:
			binding["on_pick"].call(hovered, amplified)

		_close()


func _input(event: InputEvent) -> void:

	if (
		visible and hovered != -1
		and event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		bindings[held_action]["on_pick"].call(hovered, amplified)
		get_viewport().set_input_as_handled()
		_close()


func _build_labels() -> void:

	_free_labels()
	amplified = Input.is_action_pressed(&"amplify")

	var option_labels: Array = bindings[held_action]["labels"].call(amplified, cycle)
	var step := TAU / option_labels.size()

	for i in option_labels.size():
		var mid := Vector2.UP.rotated(step * (i - 0.5)) * LABEL_RADIUS
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fit(label, (AMPLIFIED_PREFIX if amplified else "") + option_labels[i], mid, i, option_labels.size())
		add_child(label)
		label.position = size / 2.0 + mid - label.get_minimum_size() / 2.0
		labels.append(label)

	if hint != "":
		_hint_label = Label.new()
		_hint_label.text = hint
		_hint_label.add_theme_font_size_override(&"font_size", MIN_FONT_SIZE * 2)
		add_child(_hint_label)
		_hint_label.position = size / 2.0 + Vector2(RADIUS - _hint_label.get_minimum_size().x, -RADIUS)

	queue_redraw()


## Wraps at the widest width that fits the section, shrinking the font only when none does.
func _fit(label: Label, text: String, mid: Vector2, index: int, count: int) -> void:

	var font := label.get_theme_font(&"font")
	var words := text.split(" ")

	for font_size in range(FONT_SIZE, MIN_FONT_SIZE - 1, -1):
		var width := func(line: String) -> float:
			return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		for max_width in range(int(2.0 * RADIUS), 0, -8):
			var lines: Array[String] = []

			for word in words:
				if not lines.is_empty() and width.call(lines.back() + " " + word) <= max_width:
					lines[-1] += " " + word
				else:
					lines.append(word)

			var half := Vector2(
				lines.map(width).max(), lines.size() * font.get_height(font_size)
			) / 2.0 + Vector2.ONE * LABEL_PADDING

			var corners := [half, -half, Vector2(half.x, -half.y), Vector2(-half.x, half.y)]

			if corners.all(func(corner): return sector_at(mid + corner, count) == index):
				label.text = "\n".join(lines)
				label.add_theme_font_size_override(&"font_size", font_size)
				return

			# narrower only helps while some line is still wider than a single word
			if lines.size() == words.size():
				break

	label.text = text
	label.add_theme_font_size_override(&"font_size", MIN_FONT_SIZE)


## Forgets the key too, so after a click its release does nothing.
func _close() -> void:

	_free_labels()
	held_action = &""
	hovered = -1
	cycle = 0
	hint = ""
	hide()


func _free_labels() -> void:

	for label in labels:
		label.queue_free()

	labels.clear()

	if _hint_label != null:
		_hint_label.queue_free()
		_hint_label = null


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

	var start := Vector2.UP.rotated(step * (hovered - 1))
	var end := Vector2.UP.rotated(step * hovered)
	draw_line(centre, centre + start * RADIUS, HIGHLIGHT, 3.0)
	draw_line(centre, centre + end * RADIUS, HIGHLIGHT, 3.0)
	draw_arc(centre, RADIUS, start.angle(), start.angle() + step, 32, HIGHLIGHT, 3.0)
