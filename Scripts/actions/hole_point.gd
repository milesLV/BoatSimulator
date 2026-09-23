class_name ShipHolePoint
extends ShipActionPoint

signal grade_changed(hole: ShipHolePoint, old_grade: int, new_grade: int)

const MIN_GRADE := 0
const MAX_GRADE := 5
const DEBUG_RADIUS := 5.0
## Flip to true to draw each hole's estimated repair trip time above it.
const SHOW_REPAIR_TRIP_DEBUG := false
const DEBUG_TRIP_LABEL_OFFSET := Vector2(0.0, -12.0)
const DEBUG_TRIP_FONT_SIZE := 12
const DEBUG_TRIP_COLOR := Color(0.1, 0.35, 1.0)

# ColorBrewer 5-class YlOrRd (colorbrewer2.org) — indexed by grade - 1.
const GRADE_COLORS: Array[Color] = [
	Color("ffffb2"),
	Color("fecc5c"),
	Color("fd8d3c"),
	Color("f03b20"),
	Color("bd0026"),
]

@export_range(MIN_GRADE, MAX_GRADE) # exporting just for now for testing, delete later
var grade: int = MIN_GRADE # default = no hole

## How far this hole can be opened. The mast holes cap at 2; hull holes go the whole way.
@export_range(MIN_GRADE, MAX_GRADE) var max_grade: int = MAX_GRADE


func _draw() -> void:

	if grade <= MIN_GRADE:
		return

	draw_circle(
		Vector2.ZERO,
		DEBUG_RADIUS * DeckGraph.DECK_SIZE_SCALE[deck],
		Color(GRADE_COLORS[grade - 1], DeckGraph.DECK_ALPHA[deck])
	)

	if SHOW_REPAIR_TRIP_DEBUG:
		_draw_repair_trip_debug_label()


## Only the trip label changes between grade changes, so this idles without it.
func _process(_delta: float) -> void:

	if SHOW_REPAIR_TRIP_DEBUG and grade > MIN_GRADE:
		queue_redraw()


func set_grade(new_grade: int) -> void:

	var clamped_grade = clampi(new_grade, MIN_GRADE, max_grade)

	if grade != clamped_grade:
		var old_grade = grade
		grade = clamped_grade
		grade_changed.emit(self, old_grade, grade)

	queue_redraw()


func _draw_repair_trip_debug_label() -> void:

	var font = ThemeDB.get_fallback_font()

	if font == null:
		return

	var label = _get_repair_trip_debug_text()
	var text_size = font.get_string_size(
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		DEBUG_TRIP_FONT_SIZE
	)
	var label_position = (
		DEBUG_TRIP_LABEL_OFFSET
		- Vector2(text_size.x / 2.0, DEBUG_RADIUS)
	)

	draw_string(
		font,
		label_position,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		DEBUG_TRIP_FONT_SIZE,
		DEBUG_TRIP_COLOR
	)


func _get_repair_trip_debug_text() -> String:

	var ship = _get_ship()

	if ship == null or ship.action_planner == null:
		return "--"

	var crewmate = ship.get_current_crewmate()

	if crewmate == null:
		return "--"

	var repair_trip = ship.action_planner.estimate_repair_trip(crewmate, self)
	var total_time = repair_trip["total_time"]

	if total_time == INF:
		return "inf"

	return "%.1f" % total_time


func _get_ship() -> Sloop:

	var node = get_parent()

	while node != null and not node is Sloop:
		node = node.get_parent()

	return node
