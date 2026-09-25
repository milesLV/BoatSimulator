class_name ShipHolePoint
extends ShipActionPoint

signal grade_changed(hole: ShipHolePoint, old_grade: int, new_grade: int)

const MIN_GRADE := 0
const MAX_GRADE := 5
const DEBUG_RADIUS := 5.0

# ColorBrewer 5-class YlOrRd; a hole at its max_grade is always the darkest red.
const GRADE_COLORS: Array[Color] = [
	Color("ffffb2"),
	Color("fecc5c"),
	Color("fd8d3c"),
	Color("f03b20"),
	Color("bd0026"),
]

@export_range(MIN_GRADE, MAX_GRADE) # TODO: stop exporting once testing is done
var grade: int = MIN_GRADE

@export_range(MIN_GRADE, MAX_GRADE) var max_grade: int = MAX_GRADE


func _draw() -> void:

	if grade <= MIN_GRADE:
		return

	draw_circle(
		Vector2.ZERO,
		DEBUG_RADIUS * DeckGraph.DECK_SIZE_SCALE[deck],
		Color(GRADE_COLORS[grade - max_grade - 1], DeckGraph.DECK_ALPHA[deck])
	)


func set_grade(new_grade: int) -> void:

	var clamped_grade = clampi(new_grade, MIN_GRADE, max_grade)

	if grade != clamped_grade:
		var old_grade = grade
		grade = clamped_grade
		grade_changed.emit(self, old_grade, grade)

	queue_redraw()


func repair_duration() -> float:

	return float(grade) + RepairHoleAction.EXTRA_REPAIR_SECONDS


func _get_ship() -> Sloop:

	var node = get_parent()

	while node != null and not node is Sloop:
		node = node.get_parent()

	return node
